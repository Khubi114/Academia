// api/calendar/events.js
// Vercel serverless function
// Called by Flutter whenever it needs calendar events for a date range.
// Uses the stored refresh_token to get a fresh access_token,
// fetches events from Google Calendar, caches them in Supabase,
// and returns them to Flutter.

const { createClient } = require('@supabase/supabase-js');
const { google } = require('googleapis');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

const oauth2Client = new google.auth.OAuth2(
  process.env.GOOGLE_CLIENT_ID,
  process.env.GOOGLE_CLIENT_SECRET,
  'postmessage'
);

// How old a cache entry can be before we re-fetch from Google (15 minutes)
const CACHE_TTL_MINUTES = 15;

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { user_id, time_min, time_max } = req.query;

  if (!user_id || !time_min || !time_max) {
    return res.status(400).json({ error: 'user_id, time_min, time_max are required' });
  }

  try {
    // ── 1. Check Supabase cache first ──────────────────────────────────────
    const cacheThreshold = new Date(Date.now() - CACHE_TTL_MINUTES * 60 * 1000).toISOString();

    const { data: cached } = await supabase
      .from('calendar_events_cache')
      .select('*')
      .eq('user_id', user_id)
      .gte('event_date', time_min.split('T')[0])
      .lte('event_date', time_max.split('T')[0])
      .gte('cached_at', cacheThreshold);

    if (cached && cached.length > 0) {
      return res.status(200).json({ source: 'cache', events: cached });
    }

    // ── 2. Cache miss — fetch refresh_token from Supabase ─────────────────
    const { data: tokenRow, error: tokenErr } = await supabase
      .from('calendar_tokens')
      .select('refresh_token')
      .eq('user_id', user_id)
      .single();

    if (tokenErr || !tokenRow?.refresh_token) {
      return res.status(401).json({ error: 'User not connected to Google Calendar' });
    }

    // ── 3. Use refresh_token to get a fresh access_token ──────────────────
    oauth2Client.setCredentials({ refresh_token: tokenRow.refresh_token });
    const { credentials } = await oauth2Client.refreshAccessToken();
    oauth2Client.setCredentials(credentials);

    // ── 4. Fetch events from Google Calendar API ───────────────────────────
    const calendar = google.calendar({ version: 'v3', auth: oauth2Client });

    const response = await calendar.events.list({
      calendarId: 'primary',
      timeMin: time_min,
      timeMax: time_max,
      singleEvents: true,
      orderBy: 'startTime',
      maxResults: 250,
    });

    const rawEvents = response.data.items || [];

    // ── 5. Normalise into the shape Flutter expects ────────────────────────
    const events = rawEvents
      .filter((e) => e.status !== 'cancelled')
      .map((e) => {
        const isAllDay = Boolean(e.start?.date && !e.start?.dateTime);
        const startDt = e.start?.dateTime || `${e.start?.date}T00:00:00`;
        const endDt = e.end?.dateTime || `${e.end?.date}T23:59:00`;

        const startDate = new Date(startDt);
        const endDate = new Date(endDt);

        // Try to extract a course code from the event title (e.g. "CS 301 — Lecture")
        const courseCodeMatch = e.summary?.match(/^([A-Z]{2,4}\s?\d{3})/);

        return {
          id: e.id,
          user_id,
          title: e.summary || 'Untitled',
          source: 'google_calendar',
          event_date: startDate.toISOString().split('T')[0],
          start_time: isAllDay
            ? '00:00'
            : `${String(startDate.getHours()).padStart(2, '0')}:${String(startDate.getMinutes()).padStart(2, '0')}`,
          end_time: isAllDay
            ? '23:59'
            : `${String(endDate.getHours()).padStart(2, '0')}:${String(endDate.getMinutes()).padStart(2, '0')}`,
          location: e.location || '',
          course_code: courseCodeMatch ? courseCodeMatch[0].trim() : '',
          description: e.description || '',
          is_all_day: isAllDay,
          cached_at: new Date().toISOString(),
        };
      });

    // ── 6. Write to Supabase cache (upsert by event id + user_id) ─────────
    if (events.length > 0) {
      const { error: cacheErr } = await supabase
        .from('calendar_events_cache')
        .upsert(events, { onConflict: 'id,user_id' });

      if (cacheErr) {
        // Non-fatal — still return events even if cache write fails
        console.warn('[events] cache write failed:', cacheErr.message);
      }
    }

    return res.status(200).json({ source: 'google', events });
  } catch (err) {
    console.error('[events] error:', err.message);
    return res.status(500).json({ error: 'Failed to fetch events', detail: err.message });
  }
};