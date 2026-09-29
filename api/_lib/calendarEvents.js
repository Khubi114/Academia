// api/_lib/calendarEvents.js
// Pure functions that translate Google Calendar events into the row shape
// stored in `calendar_events_cache` (and read by the Flutter app).
// No I/O here, so it is fully unit-testable.

const COURSE_CODE_RE = /^([A-Z]{2,4}\s?\d{3,5})/;

/**
 * Google returns RFC3339 timestamps carrying the calendar's own UTC offset
 * (e.g. 2026-09-29T09:00:00+10:00). Reading the wall-clock text directly keeps
 * the time the user sees in Google Calendar, independent of the server's
 * timezone (Vercel runs in UTC).
 */
function wallClock(dateTime) {
  return { date: dateTime.slice(0, 10), time: dateTime.slice(11, 16) };
}

/** @returns a cache row, or null for cancelled / undated events. */
function normalizeEvent(e, userId) {
  if (!e || e.status === 'cancelled') return null;

  const isAllDay = Boolean(e.start?.date && !e.start?.dateTime);
  if (!e.start?.dateTime && !e.start?.date) return null;

  const start = isAllDay
    ? { date: e.start.date, time: '00:00' }
    : wallClock(e.start.dateTime);
  const end = isAllDay || !e.end?.dateTime
    ? { date: start.date, time: isAllDay ? '23:59' : start.time }
    : wallClock(e.end.dateTime);

  const title = e.summary || 'Untitled';
  const code = title.match(COURSE_CODE_RE);

  return {
    id: e.id,
    user_id: userId,
    title,
    source: e.extendedProperties?.private?.academiaSource === 'canvas'
      ? 'canvas'
      : 'google_calendar',
    event_date: start.date,
    start_time: start.time,
    end_time: end.time,
    location: e.location || '',
    course_code: code ? code[0].trim() : '',
    description: e.description || '',
    is_all_day: isAllDay,
    cached_at: new Date().toISOString(),
  };
}

/** Splits a Google `items` page into rows to upsert and ids to delete. */
function partitionChanges(items, userId) {
  const upserts = [];
  const deletedIds = [];
  for (const item of items || []) {
    if (item.status === 'cancelled') {
      deletedIds.push(item.id);
      continue;
    }
    const row = normalizeEvent(item, userId);
    if (row) upserts.push(row);
  }
  return { upserts, deletedIds };
}

module.exports = { normalizeEvent, partitionChanges, wallClock };
