// api/calendar/exchange.js
// Vercel serverless function
// Called once after user signs in with Google on the Flutter app.
// Receives the server auth code, exchanges it for tokens,
// and stores the refresh_token in Supabase for future use.

const { createClient } = require('@supabase/supabase-js');
const { google } = require('googleapis');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY // service role — never exposed to client
);

const oauth2Client = new google.auth.OAuth2(
  process.env.GOOGLE_CLIENT_ID,
  process.env.GOOGLE_CLIENT_SECRET,
  'postmessage' // Flutter uses server auth code flow — no redirect URI needed
);

module.exports = async function handler(req, res) {
  // Only allow POST
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { server_auth_code, user_id } = req.body;

  if (!server_auth_code || !user_id) {
    return res.status(400).json({ error: 'server_auth_code and user_id are required' });
  }

  try {
    // Exchange the auth code for access + refresh tokens
    const { tokens } = await oauth2Client.getToken(server_auth_code);

    if (!tokens.refresh_token) {
      // refresh_token is only returned on first auth. If missing, the user
      // already granted access before — fetch existing token from Supabase.
      const { data: existing } = await supabase
        .from('calendar_tokens')
        .select('refresh_token')
        .eq('user_id', user_id)
        .single();

      if (!existing?.refresh_token) {
        return res.status(400).json({
          error: 'No refresh token returned and none stored. Ask user to re-authenticate.',
        });
      }

      return res.status(200).json({ status: 'already_connected' });
    }

    // Upsert the refresh token — one row per user
    const { error: dbError } = await supabase
      .from('calendar_tokens')
      .upsert(
        { user_id, refresh_token: tokens.refresh_token, updated_at: new Date().toISOString() },
        { onConflict: 'user_id' }
      );

    if (dbError) throw dbError;

    return res.status(200).json({ status: 'connected' });
  } catch (err) {
    console.error('[exchange] error:', err.message);
    return res.status(500).json({ error: 'Token exchange failed', detail: err.message });
  }
};