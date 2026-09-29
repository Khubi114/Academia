// api/_lib/canvasMap.js
// Pure Canvas → database mapping and change detection. No I/O.

const crypto = require('crypto');

const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

function sha1(text) {
  return crypto.createHash('sha1').update(text).digest('hex');
}

function stripHtml(html) {
  return String(html || '')
    .replace(/<[^>]*>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Time-dependent status. Deliberately NOT part of the content hash. */
function resolveStatus({ dueAt, submitted, graded }, now = new Date()) {
  if (graded) return 'graded';
  if (submitted) return 'submitted';
  if (!dueAt) return 'upcoming';
  const due = new Date(dueAt);
  if (due < now) return 'overdue';
  return due - now <= 48 * 3600 * 1000 ? 'due_soon' : 'upcoming';
}

function formatDueDate(dueAt) {
  if (!dueAt) return 'No due date';
  const d = new Date(dueAt);
  return `${MONTHS[d.getUTCMonth()]} ${d.getUTCDate()}, ${d.getUTCFullYear()}`;
}

/** Stable fields only — if none of these change, the row is untouched. */
function assignmentHash(a) {
  return sha1(
    JSON.stringify([
      a.title, a.course_id, a.due_at, a.points, a.submitted,
      a.score, a.description, a.html_url,
    ])
  );
}

/** Same buckets as the app's CanvasService, so both sides colour courses alike. */
function colorForCourse(code) {
  const upper = String(code || '').toUpperCase();
  if (['COS', 'TNE', 'INF', 'SWE', 'CIS', 'CS'].some((k) => upper.includes(k))) return 'primary';
  if (['MAT', 'STA', 'PHY'].some((k) => upper.includes(k))) return 'secondary';
  return 'teal';
}

function mapAssignment(raw, course, userId, now = new Date()) {
  const sub = raw.submission || null;
  const submitted = Boolean(
    sub && (sub.submitted_at || ['submitted', 'graded'].includes(sub.workflow_state))
  );
  const graded = Boolean(sub && sub.workflow_state === 'graded' && sub.score != null);

  const row = {
    id: String(raw.id),
    user_id: userId,
    course_id: String(course.id),
    title: raw.name || 'Untitled',
    course_name: course.name || 'Unknown course',
    course_code: course.course_code || '',
    course_color: colorForCourse(course.course_code),
    due_at: raw.due_at || null,
    points: Math.round(raw.points_possible || 0),
    submitted,
    score: graded ? sub.score : null,
    description: stripHtml(raw.description).slice(0, 2000),
    html_url: raw.html_url || '',
  };
  row.content_hash = assignmentHash(row);
  row.due_date = formatDueDate(row.due_at);
  row.status = resolveStatus({ dueAt: row.due_at, submitted, graded }, now);
  return row;
}

function mapCourse(raw, userId) {
  return {
    id: String(raw.id),
    user_id: userId,
    name: raw.name || 'Unknown course',
    course_code: raw.course_code || '',
    term: raw.term?.name || '',
    updated_at: new Date().toISOString(),
  };
}

function mapModule(raw, courseId, userId) {
  const row = {
    id: String(raw.id),
    user_id: userId,
    course_id: String(courseId),
    name: raw.name || 'Module',
    position: raw.position || 0,
    state: raw.state || '',
    items_count: raw.items_count || 0,
    unlock_at: raw.unlock_at || null,
  };
  row.content_hash = sha1(JSON.stringify([row.name, row.position, row.state, row.items_count, row.unlock_at]));
  return row;
}

/**
 * Compares freshly fetched rows with stored ones.
 * @param {Array} fresh   rows from Canvas (must include id, content_hash)
 * @param {Array} stored  rows from the database (id, content_hash)
 * @param {Set<string>} [protectedKeys] stored rows whose group failed to load
 *        this run (e.g. a course whose fetch errored) — never reported removed
 * @param {(row)=>string} [groupOf] maps a stored row to its protectedKeys key
 */
function diffRows(fresh, stored, protectedKeys = new Set(), groupOf = () => '') {
  const storedById = new Map(stored.map((r) => [r.id, r]));
  const freshIds = new Set(fresh.map((r) => r.id));

  const added = [];
  const updated = [];
  for (const row of fresh) {
    const old = storedById.get(row.id);
    if (!old) added.push(row);
    else if (old.content_hash !== row.content_hash) updated.push(row);
  }
  const removed = stored.filter(
    (r) => !freshIds.has(r.id) && !protectedKeys.has(groupOf(r))
  );
  return { added, updated, removed };
}

module.exports = {
  stripHtml, resolveStatus, formatDueDate, assignmentHash,
  mapAssignment, mapCourse, mapModule, diffRows, colorForCourse,
};
