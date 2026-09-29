// api/_lib/calendarSync.js
// Incremental Google Calendar → Supabase sync using Google's `syncToken`.
//
// First run  : full download of a window (1 month back → 6 months ahead),
//              Google returns a `nextSyncToken` which we store.
// Later runs : we send the token and Google returns ONLY events that were
//              created / changed / deleted since — this is what makes
//              "new events in Google Calendar appear in the app" cheap.
// If Google answers 410 GONE the token expired: we wipe the cache and resync.

const { supabaseAdmin } = require('./supabase');
const { calendarClientFor } = require('./google');
const { partitionChanges } = require('./calendarEvents');

const CALENDAR_ID = 'primary';
const WINDOW_PAST_DAYS = 30;
const WINDOW_FUTURE_DAYS = 180;

async function loadSyncToken(userId) {
  const { data } = await supabaseAdmin
    .from('calendar_sync_state')
    .select('sync_token')
    .eq('user_id', userId)
    .maybeSingle();
  return data?.sync_token || null;
}

async function saveSyncToken(userId, token) {
  const { error } = await supabaseAdmin.from('calendar_sync_state').upsert(
    { user_id: userId, sync_token: token, synced_at: new Date().toISOString() },
    { onConflict: 'user_id' }
  );
  if (error) throw error;
}

/** Pages through events.list, returning every item plus the final sync token. */
async function listAll(calendar, params) {
  const items = [];
  let pageToken;
  let nextSyncToken;
  do {
    const { data } = await calendar.events.list({ ...params, pageToken });
    items.push(...(data.items || []));
    pageToken = data.nextPageToken;
    nextSyncToken = data.nextSyncToken || nextSyncToken;
  } while (pageToken);
  return { items, nextSyncToken };
}

function fullWindowParams() {
  const now = Date.now();
  return {
    calendarId: CALENDAR_ID,
    timeMin: new Date(now - WINDOW_PAST_DAYS * 864e5).toISOString(),
    timeMax: new Date(now + WINDOW_FUTURE_DAYS * 864e5).toISOString(),
    singleEvents: true,
    maxResults: 250,
    // NOTE: orderBy is not allowed together with syncToken, so we omit it.
  };
}

/**
 * Runs one sync pass for the user.
 * @returns {{mode:'full'|'incremental', upserted:number, deleted:number}}
 */
async function syncCalendar(userId) {
  const calendar = await calendarClientFor(userId);
  const startedAt = new Date().toISOString();
  const storedToken = await loadSyncToken(userId);

  let result;
  let mode = storedToken ? 'incremental' : 'full';

  try {
    result = await listAll(
      calendar,
      storedToken
        ? { calendarId: CALENDAR_ID, syncToken: storedToken, maxResults: 250 }
        : fullWindowParams()
    );
  } catch (err) {
    if (err.code !== 410 && err.status !== 410) throw err;
    // Token expired → fall back to a full resync (stale rows pruned below).
    mode = 'full';
    result = await listAll(calendar, fullWindowParams());
  }

  const { upserts, deletedIds } = partitionChanges(result.items, userId);

  if (upserts.length) {
    const { error } = await supabaseAdmin
      .from('calendar_events_cache')
      .upsert(upserts, { onConflict: 'id,user_id' });
    if (error) throw error;
  }
  if (mode === 'full') {
    // Every row written above carries cached_at >= startedAt, so anything
    // older no longer exists upstream. (Upsert-then-prune avoids an empty
    // cache window that a delete-then-insert would expose to readers.)
    const { error } = await supabaseAdmin
      .from('calendar_events_cache')
      .delete()
      .eq('user_id', userId)
      .lt('cached_at', startedAt);
    if (error) throw error;
  }
  if (deletedIds.length) {
    const { error } = await supabaseAdmin
      .from('calendar_events_cache')
      .delete()
      .eq('user_id', userId)
      .in('id', deletedIds);
    if (error) throw error;
  }

  if (result.nextSyncToken) await saveSyncToken(userId, result.nextSyncToken);

  return { mode, upserted: upserts.length, deleted: deletedIds.length };
}

module.exports = { syncCalendar };
