# Academia — setup, migration & testing

## Architecture

```
Flutter app ──Bearer <Supabase JWT>──► Vercel functions (api/) ──► Google Calendar API
    │                                        │ ├─────────────────► Canvas REST API
    │ (reads own rows via RLS)               ▼
    └────────────────────────────────► Supabase (Postgres + auth)
```

| Concern | Where |
|---|---|
| Build-time config | `lib/core/app_config.dart` |
| Authenticated backend calls | `lib/services/api_client.dart` |
| Google Calendar (sign-in, read, create) | `lib/services/google_calendar_service.dart` |
| Canvas (connect, fetch, diff) | `lib/services/canvas_service.dart`, `change_detector.dart` |
| Periodic + on-resume sync, change toasts | `lib/services/sync_service.dart` |
| Connect / disconnect UI | `lib/widgets/integrations_sheet.dart` |
| Design tokens & theme | `lib/theme/` |
| Backend endpoints | `api/calendar/*`, `api/canvas/*` |
| Backend logic (unit-tested) | `api/_lib/*` |

### How sync works
* **Google Calendar** — first sync downloads −30/+180 days and stores Google's
  `syncToken`. Every later sync sends the token and receives *only* events that
  were created, edited or deleted (`api/_lib/calendarSync.js`). The app syncs
  every 5 min and whenever it returns to the foreground.
* **Canvas** — every 15 min / on resume. Courses, assignments and modules are
  fetched, hashed and compared with the stored rows; only differences are
  written (`api/canvas/sync.js`). The app also diffs against a snapshot kept on
  the device and shows a toast such as *"Canvas: 2 new, 1 updated"*.
* **Canvas → Google Calendar** (opt-in switch in *Connections*): each assignment
  becomes a 30-min event ending at its deadline. Event ids are derived from the
  assignment id, so retries can never create duplicates; changed due dates
  patch the same event, removed assignments delete it.

### Security changes
* Every endpoint now verifies the caller's Supabase JWT; the user id is never
  taken from the request body (before, anyone knowing a UUID could read that
  user's events).
* `api/auth/google/callback.js` was **deleted** — it returned Google tokens to
  the client and nothing used it.
* Canvas domains are restricted to `*.instructure.com` (+ `CANVAS_ALLOWED_DOMAINS`)
  so the server can't be used to reach internal hosts.
* The Canvas token that was hard-coded in `canvas_service.dart` is gone.
  **It is still in git history — revoke it in Canvas (Account → Settings →
  Approved Integrations) and create a new one from inside the app.**

## Migration (replace old → new)

1. `git pull` this branch, then `flutter pub get`.
2. **Supabase SQL editor**: run `supabase_migration_002_sync.sql`
   (idempotent; `supabase_migration.sql` must already have been run).
3. **Vercel** env vars (Project → Settings → Environment Variables):
   `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `GOOGLE_CLIENT_ID`,
   `GOOGLE_CLIENT_SECRET`; optional `CANVAS_ALLOWED_DOMAINS`
   (comma-separated, e.g. `canvas.myuni.edu`).
   Deploy from the repo root (`vercel.json` sets a 60 s function limit).
4. **Google Cloud Console** → OAuth consent screen → add scopes
   `…/auth/calendar.readonly` and `…/auth/calendar.events`
   (add yourself as a test user while the app is unverified).
5. Run the app: `flutter run --dart-define-from-file=env.json`
   (`env.json` keys: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `VERCEL_BASE_URL`,
   `GOOGLE_WEB_CLIENT_ID`, `CANVAS_BASE_URL`). Do **not** put a Canvas token in it.
6. Users who connected Google Calendar before this update only granted
   read access; the *Connections* sheet shows "Reconnect to allow adding
   events" until they reconnect once.

Dependencies: no new Flutter packages. The API needs Node ≥ 18
(`cd api && npm install`).

## Android: Google sign-in (error 10)

Google only allows sign-in from apps whose signing key is registered. Every
build here is signed with `android/app/academia-test.keystore` (a committed
TEST key), so the fingerprint never changes:

    SHA-1: 6B:B2:BE:EA:1D:B6:3C:38:2B:B9:B2:8E:B8:11:3C:24:A6:8C:E7:A1

Google Cloud Console → APIs & Services → Credentials → Create credentials →
OAuth client ID → **Android**, package name `com.example.academia`, paste the
SHA-1. (Keep the existing *Web application* client; the app still uses it as
`GOOGLE_WEB_CLIENT_ID`.) It can take a few minutes to take effect. Replace the
keystore with a private one before publishing to the Play Store.

## Testing

Automated:
```bash
cd api && npm install && npm test     # 12 backend tests (mapping, diff, scopes, event ids…)
flutter test                          # change-detection tests
flutter analyze
```

Manual — Google Calendar
1. Open **Dashboard → ⇄ (top right)** → *Connect Google Calendar*; tick **both**
   permission boxes. Status turns to "Connected".
2. Open **Calendar**: your events appear. In Google Calendar (web/phone) add an
   event for today; within 5 min (or tap *Sync now*) it appears in the app with a toast.
3. Edit its title / delete it in Google Calendar → the app follows on the next sync.
4. In the app tap **+**, choose *Google Calendar*, save → the event appears in Google Calendar.
5. Untick a permission on the consent screen → the app shows the "needs permission" message.

Manual — Canvas
1. **Assignments** (or *Connections*) → paste your Canvas address and a new access token → *Connect*.
   A wrong token shows "Canvas token is invalid or expired".
2. Assignments load; the Dashboard fills after the first sync (it reads Supabase).
3. In Canvas change a due date or publish a new assignment → *Sync now* → toast
   "Canvas: 1 new" / "1 updated" and the list updates.
4. Turn on *Add due dates to Google Calendar* → events named `COURSE: title`
   appear in Google Calendar. Move the due date in Canvas and sync: the same
   event moves (no duplicate). Submit an assignment: its event gets a ✓.
5. *Disconnect* clears the token from the device and the server.

Known limits: sync runs while the app is open (no OS background scheduler yet);
dark theme exists but the app stays in light mode because several widgets still
use light-only container colors.
