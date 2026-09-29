// api/_lib/supabase.js
// Shared Supabase admin client (service-role key — server only, bypasses RLS).
// Folders starting with "_" are not deployed as Vercel functions.

const { createClient } = require('@supabase/supabase-js');

const supabaseAdmin = createClient(
  process.env.SUPABASE_URL || 'http://localhost',
  process.env.SUPABASE_SERVICE_ROLE_KEY || 'missing-service-role-key',
  { auth: { persistSession: false, autoRefreshToken: false } }
);

module.exports = { supabaseAdmin };
