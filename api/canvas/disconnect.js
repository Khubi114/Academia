// POST /api/canvas/disconnect
// Removes the stored Canvas token. Synced rows are kept so the app still
// shows history; the next connect reconciles them.

const { endpoint } = require('../_lib/http');
const { supabaseAdmin } = require('../_lib/supabase');

module.exports = endpoint(['POST'], async ({ userId }) => {
  const { error } = await supabaseAdmin
    .from('user_settings')
    .update({ canvas_token: null, updated_at: new Date().toISOString() })
    .eq('user_id', userId);
  if (error) throw error;
  return { connected: false };
});
