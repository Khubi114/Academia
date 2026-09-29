// POST /api/calendar/sync
// Pulls new / changed / deleted Google Calendar events into the cache.
// Cheap thanks to incremental sync tokens, so the app calls it every few
// minutes and whenever it returns to the foreground.

const { endpoint } = require('../_lib/http');
const { syncCalendar } = require('../_lib/calendarSync');

module.exports = endpoint(['POST'], async ({ userId }) => {
  const sync = await syncCalendar(userId);
  return { success: true, ...sync };
});
