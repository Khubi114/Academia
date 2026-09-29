// POST /api/calendar/exchange
// Body: { server_auth_code }
// Called once after the user signs in with Google in the app. Exchanges the
// one-time server auth code for tokens, verifies the user granted BOTH calendar
// scopes, stores the refresh token, and kicks off the first sync.

const { endpoint, HttpError } = require('../_lib/http');
const { supabaseAdmin } = require('../_lib/supabase');
const { newOAuthClient, REQUIRED_SCOPES } = require('../_lib/google');
const { syncCalendar } = require('../_lib/calendarSync');

module.exports = endpoint(['POST'], async ({ userId, body }) => {
  const code = body.server_auth_code;
  if (!code) throw new HttpError(400, 'server_auth_code is required');

  const { tokens } = await newOAuthClient().getToken(code);

  // Users can untick scopes on Google's consent screen — refuse partial grants.
  const granted = (tokens.scope || '').split(' ');
  const missing = REQUIRED_SCOPES.filter((s) => !granted.includes(s));
  if (missing.length) {
    throw new HttpError(403, 'Missing Google Calendar permissions', { missing });
  }

  if (tokens.refresh_token) {
    const { error } = await supabaseAdmin.from('calendar_tokens').upsert(
      {
        user_id: userId,
        refresh_token: tokens.refresh_token,
        scope: tokens.scope,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'user_id' }
    );
    if (error) throw error;
  } else {
    // Google only sends a refresh token on first consent. Fine if we have one.
    const { data } = await supabaseAdmin
      .from('calendar_tokens')
      .select('user_id')
      .eq('user_id', userId)
      .maybeSingle();
    if (!data) {
      throw new HttpError(
        400,
        'No refresh token returned and none stored. Remove Academia at ' +
          'myaccount.google.com/permissions and sign in again.'
      );
    }
  }

  const sync = await syncCalendar(userId);
  return { status: 'connected', sync };
});
