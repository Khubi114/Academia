// POST /api/calendar/create
// Body: { title, date:'YYYY-MM-DD', start_time:'HH:mm', end_time:'HH:mm',
//         location?, description?, is_all_day?, utc_offset? ('+10:00') }
// Creates an event in the user's primary Google Calendar (calendar.events
// scope) and mirrors it into the cache so the UI shows it immediately.

const { endpoint, HttpError } = require('../_lib/http');
const { supabaseAdmin } = require('../_lib/supabase');
const { calendarClientFor } = require('../_lib/google');
const { normalizeEvent } = require('../_lib/calendarEvents');
const { buildGoogleEvent } = require('../_lib/eventBuilder');

module.exports = endpoint(['POST'], async ({ userId, body }) => {
  if (!body.title || !/^\d{4}-\d{2}-\d{2}$/.test(body.date || '')) {
    throw new HttpError(400, 'title and date (YYYY-MM-DD) are required');
  }

  const calendar = await calendarClientFor(userId);
  const { data } = await calendar.events.insert({
    calendarId: 'primary',
    requestBody: buildGoogleEvent(body),
  });

  const row = normalizeEvent(data, userId);
  if (row) {
    const { error } = await supabaseAdmin
      .from('calendar_events_cache')
      .upsert(row, { onConflict: 'id,user_id' });
    if (error) console.warn('[calendar/create] cache write failed:', error.message);
  }
  return { event: row };
});
