const { google } = require('googleapis');
const { supabaseAdmin } = require('../../utils/supabase');

module.exports = async (req, res) => {
  if (req.method === 'OPTIONS') return res.status(200).end();

  try {
    const { userId } = req.body || {};
    if (!userId) return res.status(400).json({ error: 'Missing userId' });

    const { data: tokenData, error: tokenError } = await supabaseAdmin
      .from('calendar_tokens')
      .select('refresh_token')
      .eq('user_id', userId)
      .single();

    if (tokenError || !tokenData?.refresh_token) {
      return res.status(401).json({ error: 'No calendar connection found' });
    }

    const oauth2Client = new google.auth.OAuth2(
      process.env.GOOGLE_CLIENT_ID,
      process.env.GOOGLE_CLIENT_SECRET
    );
    oauth2Client.setCredentials({ refresh_token: tokenData.refresh_token });

    const calendar = google.calendar({ version: 'v3', auth: oauth2Client });
    const timeMin = new Date();
    timeMin.setMonth(timeMin.getMonth() - 1);
    
    const response = await calendar.events.list({
      calendarId: 'primary',
      timeMin: timeMin.toISOString(),
      maxResults: 100,
      singleEvents: true,
      orderBy: 'startTime',
    });

    const events = response.data.items || [];
    const formattedEvents = events.map(event => {
      const start = event.start.dateTime || event.start.date;
      const end = event.end.dateTime || event.end.date;
      const isAllDay = !event.start.dateTime;
      
      return {
        id: event.id,
        user_id: userId,
        title: event.summary || 'Untitled Event',
        source: 'google_calendar',
        event_date: start.split('T')[0],
        start_time: isAllDay ? '00:00' : start.split('T')[1].substring(0, 5),
        end_time: isAllDay ? '23:59' : end.split('T')[1].substring(0, 5),
        location: event.location || '',
        description: event.description || '',
        is_all_day: isAllDay,
        cached_at: new Date().toISOString()
      };
    });

    if (formattedEvents.length > 0) {
      const { error: upsertError } = await supabaseAdmin
        .from('calendar_events_cache')
        .upsert(formattedEvents, { onConflict: 'id,user_id' });
      if (upsertError) throw upsertError;
    }

    return res.status(200).json({ success: true, count: formattedEvents.length });
  } catch (error) {
    console.error('Calendar Sync Error:', error);
    return res.status(500).json({ error: error.message });
  }
};
