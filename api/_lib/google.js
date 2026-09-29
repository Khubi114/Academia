// api/_lib/google.js
// Google OAuth helpers shared by every calendar endpoint.

const { google } = require('googleapis');
const { supabaseAdmin } = require('./supabase');
const { HttpError } = require('./http');

/** Scopes the app asks for. Must match the Flutter client (AppConfig.googleScopes). */
const REQUIRED_SCOPES = [
  'https://www.googleapis.com/auth/calendar.readonly',
  'https://www.googleapis.com/auth/calendar.events',
];

/** 'postmessage' is the redirect URI used by the server-auth-code flow. */
function newOAuthClient() {
  return new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    'postmessage'
  );
}

/** Returns an authenticated Calendar client for the user, or throws 401. */
async function calendarClientFor(userId) {
  const { data, error } = await supabaseAdmin
    .from('calendar_tokens')
    .select('refresh_token')
    .eq('user_id', userId)
    .maybeSingle();

  if (error) throw error;
  if (!data?.refresh_token) {
    throw new HttpError(401, 'User not connected to Google Calendar');
  }

  const auth = newOAuthClient();
  auth.setCredentials({ refresh_token: data.refresh_token });
  return google.calendar({ version: 'v3', auth });
}

module.exports = { REQUIRED_SCOPES, newOAuthClient, calendarClientFor };
