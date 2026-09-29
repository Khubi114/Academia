// GET /api/calendar/events?time_min=…&time_max=…
// Returns cached events for a date range, refreshing the cache first when the
// last sync is older than STALE_AFTER_MS.

const { endpoint, HttpError } = require('../_lib/http');
const { supabaseAdmin } = require('../_lib/supabase');
const { syncCalendar } = require('../_lib/calendarSync');

const STALE_AFTER_MS = 5 * 60 * 1000;

module.exports = endpoint(['GET'], async ({ userId, query }) => {
  const { time_min, time_max } = query;
  if (!time_min || !time_max) {
    throw new HttpError(400, 'time_min and time_max are required');
  }

  const { data: state } = await supabaseAdmin
    .from('calendar_sync_state')
    .select('synced_at')
    .eq('user_id', userId)
    .maybeSingle();

  const fresh = state && Date.now() - new Date(state.synced_at).getTime() < STALE_AFTER_MS;
  let source = 'cache';
  if (!fresh) {
    await syncCalendar(userId); // throws 401 if the user never connected
    source = 'google';
  }

  const { data, error } = await supabaseAdmin
    .from('calendar_events_cache')
    .select('*')
    .eq('user_id', userId)
    .gte('event_date', time_min.split('T')[0])
    .lte('event_date', time_max.split('T')[0])
    .order('event_date')
    .order('start_time');
  if (error) throw error;

  return { source, events: data };
});
