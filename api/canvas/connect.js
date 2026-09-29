// POST /api/canvas/connect   Body: { domain, token }
// Validates the personal access token against Canvas, then stores it
// server-side so background syncs can use it.

const { endpoint, HttpError } = require('../_lib/http');
const { supabaseAdmin } = require('../_lib/supabase');
const { CanvasClient } = require('../_lib/canvasApi');

module.exports = endpoint(['POST'], async ({ userId, body }) => {
  const token = String(body.token || '').trim();
  if (!token) throw new HttpError(400, 'token is required');

  const client = new CanvasClient(body.domain, token); // validates the domain
  const me = await client.self(); // throws 401 if the token is bad

  const { error } = await supabaseAdmin.from('user_settings').upsert(
    {
      user_id: userId,
      canvas_token: token,
      canvas_domain: client.domain,
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'user_id' }
  );
  if (error) throw error;

  return { connected: true, domain: client.domain, name: me.name || '' };
});
