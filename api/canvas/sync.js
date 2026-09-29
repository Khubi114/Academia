// POST /api/canvas/sync
// Pulls courses, assignments and modules from Canvas, detects what changed
// since the last run (via per-row content hashes), writes only the changes to
// Supabase and — when the user enabled it — mirrors due dates to Google
// Calendar. Returns a change summary the app turns into "2 new, 1 updated".

const { endpoint, HttpError } = require('../_lib/http');
const { supabaseAdmin } = require('../_lib/supabase');
const { calendarClientFor } = require('../_lib/google');
const { CanvasClient } = require('../_lib/canvasApi');
const { mapAssignment, mapCourse, mapModule, diffRows } = require('../_lib/canvasMap');
const { upsertEvent, deleteEvent } = require('../_lib/canvasCalendar');

const CONCURRENCY = 4;
const MAX_CALENDAR_WRITES = 60; // keep a run inside the function time limit

/** Runs `fn` over `items` with limited parallelism, never rejecting. */
async function mapSettled(items, fn) {
  const results = new Array(items.length);
  let next = 0;
  async function worker() {
    while (next < items.length) {
      const i = next++;
      try {
        results[i] = { ok: true, value: await fn(items[i]) };
      } catch (error) {
        results[i] = { ok: false, error };
      }
    }
  }
  await Promise.all(Array.from({ length: Math.min(CONCURRENCY, items.length) }, worker));
  return results;
}

async function stored(table, userId, columns) {
  const { data, error } = await supabaseAdmin.from(table).select(columns).eq('user_id', userId);
  if (error) throw error;
  return data || [];
}

async function write(table, rows, conflict) {
  if (!rows.length) return;
  const { error } = await supabaseAdmin.from(table).upsert(rows, { onConflict: conflict });
  if (error) throw error;
}

async function remove(table, userId, ids) {
  if (!ids.length) return;
  const { error } = await supabaseAdmin.from(table).delete().eq('user_id', userId).in('id', ids);
  if (error) throw error;
}

module.exports = endpoint(['POST'], async ({ userId }) => {
  const { data: settings } = await supabaseAdmin
    .from('user_settings')
    .select('canvas_token, canvas_domain, canvas_calendar_sync')
    .eq('user_id', userId)
    .maybeSingle();
  if (!settings?.canvas_token) throw new HttpError(401, 'No Canvas connection found');

  const canvas = new CanvasClient(settings.canvas_domain || 'canvas.instructure.com', settings.canvas_token);

  // ── 1. Fetch ────────────────────────────────────────────────────────────
  const rawCourses = (await canvas.courses()).filter((c) => c.id && !c.access_restricted_by_date);
  const courseRows = rawCourses.map((c) => mapCourse(c, userId));

  const perCourse = await mapSettled(rawCourses, async (course) => ({
    course,
    assignments: await canvas.assignments(course.id),
    modules: await canvas.modules(course.id).catch(() => []), // modules can be disabled per course
  }));

  const failedCourses = new Set();
  const assignmentRows = [];
  const moduleRows = [];
  perCourse.forEach((r, i) => {
    const courseId = String(rawCourses[i].id);
    if (!r.ok) {
      failedCourses.add(courseId);
      console.warn(`[canvas/sync] course ${courseId} failed:`, r.error.message);
      return;
    }
    const now = new Date();
    r.value.assignments.forEach((a) => assignmentRows.push(mapAssignment(a, r.value.course, userId, now)));
    r.value.modules.forEach((m) => moduleRows.push(mapModule(m, courseId, userId)));
  });

  // ── 2. Diff against what we stored last time ──────────────────────────────
  const storedAssignments = await stored(
    'assignments', userId, 'id, course_id, content_hash, due_at, calendar_event_id'
  );
  const storedModules = await stored('canvas_modules', userId, 'id, course_id, content_hash');
  const storedCourses = await stored('canvas_courses', userId, 'id');

  const byCourse = (r) => r.course_id;
  const aDiff = diffRows(assignmentRows, storedAssignments, failedCourses, byCourse);
  const mDiff = diffRows(moduleRows, storedModules, failedCourses, byCourse);
  const freshCourseIds = new Set(courseRows.map((c) => c.id));
  const removedCourses = storedCourses.filter((c) => !freshCourseIds.has(c.id));

  // ── 3. Persist only the changes ───────────────────────────────────────────
  await write('canvas_courses', courseRows, 'id,user_id');
  await write('canvas_modules', [...mDiff.added, ...mDiff.updated], 'id,user_id');
  await write('assignments', [...aDiff.added, ...aDiff.updated], 'id,user_id');
  await remove('assignments', userId, aDiff.removed.map((r) => r.id));
  await remove('canvas_modules', userId, mDiff.removed.map((r) => r.id));
  await remove('canvas_courses', userId, removedCourses.map((c) => c.id));

  // Refresh time-based statuses (overdue / due_soon) on unchanged rows too.
  const changedIds = new Set([...aDiff.added, ...aDiff.updated].map((r) => r.id));
  const statusOnly = assignmentRows
    .filter((r) => !changedIds.has(r.id))
    .map((r) => ({ id: r.id, user_id: userId, status: r.status }));
  for (const chunk of chunks(statusOnly, 50)) {
    await Promise.all(
      chunk.map((r) =>
        supabaseAdmin.from('assignments').update({ status: r.status }).eq('user_id', userId).eq('id', r.id)
      )
    );
  }

  // ── 4. Mirror to Google Calendar (opt-in) ─────────────────────────────────
  const calendarSummary = { enabled: Boolean(settings.canvas_calendar_sync), created: 0, deleted: 0, skipped: 0 };
  if (calendarSummary.enabled) {
    try {
      const calendar = await calendarClientFor(userId);
      const changed = [...aDiff.added, ...aDiff.updated];
      // Rows that pre-date the toggle being switched on still need an event.
      const backfillIds = new Set(
        storedAssignments.filter((r) => !r.calendar_event_id && !changedIds.has(r.id)).map((r) => r.id)
      );
      const backfill = assignmentRows.filter((r) => backfillIds.has(r.id));

      const toUpsert = [...changed, ...backfill].filter((r) => r.due_at);
      // A due date that was removed in Canvas → drop the event.
      const dueRemoved = changed.filter((r) => !r.due_at).map((r) => r.id);
      const toDelete = [...aDiff.removed.map((r) => r.id), ...dueRemoved];

      let budget = MAX_CALENDAR_WRITES;
      for (const id of toDelete) {
        if (budget-- <= 0) { calendarSummary.skipped++; continue; }
        await deleteEvent(calendar, userId, id);
        calendarSummary.deleted++;
      }
      const marked = [];
      const results = await mapSettled(toUpsert.slice(0, Math.max(budget, 0)), (row) =>
        upsertEvent(calendar, userId, row).then((eventId) => ({ id: row.id, eventId }))
      );
      results.forEach((r) => {
        if (r.ok) { marked.push(r.value); calendarSummary.created++; }
      });
      calendarSummary.skipped += Math.max(toUpsert.length - marked.length, 0);
      await Promise.all(
        marked.map((m) =>
          supabaseAdmin.from('assignments').update({ calendar_event_id: m.eventId }).eq('user_id', userId).eq('id', m.id)
        )
      );
    } catch (err) {
      // Calendar trouble must not fail the Canvas sync itself.
      calendarSummary.error = err instanceof HttpError ? err.message : 'Google Calendar write failed';
      console.warn('[canvas/sync] calendar mirror failed:', err.message);
    }
  }

  return {
    success: true,
    courses: { total: courseRows.length, removed: removedCourses.length, failed: failedCourses.size },
    assignments: {
      total: assignmentRows.length,
      added: aDiff.added.length,
      updated: aDiff.updated.length,
      removed: aDiff.removed.length,
      changes: [
        ...aDiff.added.map((r) => ({ type: 'added', id: r.id, title: r.title, course: r.course_code })),
        ...aDiff.updated.map((r) => ({ type: 'updated', id: r.id, title: r.title, course: r.course_code })),
        ...aDiff.removed.map((r) => ({ type: 'removed', id: r.id })),
      ].slice(0, 50),
    },
    modules: { total: moduleRows.length, added: mDiff.added.length, updated: mDiff.updated.length, removed: mDiff.removed.length },
    calendar: calendarSummary,
    synced_at: new Date().toISOString(),
  };
});

function* chunks(arr, size) {
  for (let i = 0; i < arr.length; i += size) yield arr.slice(i, i + size);
}
