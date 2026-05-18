const { google } = require('googleapis');
const { supabaseAdmin } = require('../../utils/supabase');

module.exports = async (req, res) => {
  if (req.method === 'OPTIONS') return res.status(200).end();

  try {
    const { code, userId } = req.body || {};
    
    if (!code || !userId) {
      return res.status(400).json({ error: 'Missing code or userId' });
    }

    const oauth2Client = new google.auth.OAuth2(
      process.env.GOOGLE_CLIENT_ID,
      process.env.GOOGLE_CLIENT_SECRET,
      process.env.GOOGLE_REDIRECT_URI
    );

    const { tokens } = await oauth2Client.getToken(code);
    
    if (tokens.refresh_token) {
      const { error } = await supabaseAdmin
        .from('calendar_tokens')
        .upsert({ user_id: userId, refresh_token: tokens.refresh_token, updated_at: new Date().toISOString() });
        
      if (error) throw error;
    }

    return res.status(200).json({ success: true, tokens });
  } catch (error) {
    console.error('Google Auth Error:', error);
    return res.status(500).json({ error: error.message });
  }
};
