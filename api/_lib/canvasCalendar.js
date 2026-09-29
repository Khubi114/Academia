// api/_lib/canvasCalendar.js
// Mirrors Canvas assignment due dates into the user's Google Calendar.
//
// Idempotency trick: we give every calendar event a DETERMINISTIC id derived
// from (user, assignment). Google accepts client-chosen ids made of [a-v0-9],
// which a sha1 hex digest satisfies. So a retry after a partial failure can
// never create duplicates: insert → 409 → patch the same event instead.

const crypto = require('crypto');

const EVENT_MINUTES = 30; // event ends at the deadline, starts 30 min before

function eventIdFor(userId, assignmentId) {
  return 'ac' + crypto.createHash('sha1').update(`${userId}:${assignmentId}`).digest('hex');
}

function toGoogleEvent(row) {
  const end = new Date(row.due_at);
  const start = new Date(end.getTime() - EVENT_MINUTES * 60000);
  const prefix = row.submitted ? '✓ ' : '';
  return {
    summary: `${prefix}${row.course_code ? row.course_code + ': ' : ''}${row.title}`,
    description:
      `Due in Canvas${row.points ? ` · ${row.points} pts` : ''}\n` +
      `${row.html_url || ''}\n\nManaged by Academia — edits may be overwritten on next sync.`,
    start: { dateTime: start.toISOString() },
    end: { dateTime: end.toISOString() },
    reminders: { useDefault: true },
    extendedProperties: {
      private: { academiaSource: 'canvas', academiaAssignmentId: row.id },
    },
  };
}

/** Insert, or re-activate/patch when the deterministic id already exists. */
async function upsertEvent(calendar, userId, row) {
  const id = eventIdFor(userId, row.id);
  const requestBody = { ...toGoogleEvent(row), status: 'confirmed' };
  try {
    await calendar.events.insert({ calendarId: 'primary', requestBody: { id, ...requestBody } });
  } catch (err) {
    if ((err.code || err.status) !== 409) throw err;
    await calendar.events.patch({ calendarId: 'primary', eventId: id, requestBody });
  }
  return id;
}

async function deleteEvent(calendar, userId, assignmentId) {
  try {
    await calendar.events.delete({
      calendarId: 'primary',
      eventId: eventIdFor(userId, assignmentId),
    });
  } catch (err) {
    const code = err.code || err.status;
    if (code !== 404 && code !== 410) throw err; // already gone is fine
  }
}

module.exports = { eventIdFor, toGoogleEvent, upsertEvent, deleteEvent };
