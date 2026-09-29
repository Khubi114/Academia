// lib/core/app_config.dart
//
// Single home for build-time configuration. Values come from
// `--dart-define` / `--dart-define-from-file=env.json`; the defaults are the
// public (non-secret) identifiers of the deployed project.
//
// NEVER add secrets here (Canvas tokens, Google client secret, Supabase
// service-role key). Those live on the device keychain or on Vercel.

class AppConfig {
  AppConfig._();

  // ── Backend ────────────────────────────────────────────────────────────────
  static const String vercelBaseUrl = String.fromEnvironment(
    'VERCEL_BASE_URL',
    defaultValue: 'https://academia-plum.vercel.app',
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ktfimwhkkbspkizazjvr.supabase.co',
  );

  /// The anon key is public by design (row-level security protects the data).
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt0Zmltd2hra2JzcGtpemF6anZyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg3OTgzMzksImV4cCI6MjA5NDM3NDMzOX0.PM2ZFnZs0uPpVJMixvYMB9LrAyvMu7RN8jsraxEYiq0',
  );

  // ── Google ─────────────────────────────────────────────────────────────────
  /// Must be the *Web application* OAuth client id (not Android / iOS).
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '821856499544-pro3mv21j1dkrqiiqf4b0ssbiie3u3u9.apps.googleusercontent.com',
  );

  static const String googleReadScope =
      'https://www.googleapis.com/auth/calendar.readonly';
  static const String googleEventsScope =
      'https://www.googleapis.com/auth/calendar.events';

  /// Must stay in sync with REQUIRED_SCOPES in api/_lib/google.js.
  static const List<String> googleScopes = [googleReadScope, googleEventsScope];

  // ── Canvas ─────────────────────────────────────────────────────────────────
  /// Pre-fills the connect form. Not a secret.
  static const String canvasDefaultBaseUrl = String.fromEnvironment(
    'CANVAS_BASE_URL',
    defaultValue: 'https://swinburne.instructure.com',
  );

  // ── Sync cadence ───────────────────────────────────────────────────────────
  static const Duration calendarSyncInterval = Duration(minutes: 5);
  static const Duration canvasSyncInterval = Duration(minutes: 15);

  /// A sync triggered by returning to the app is skipped if the last one is
  /// younger than this (avoids hammering the APIs on quick app switches).
  static const Duration minSyncGap = Duration(minutes: 1);
}
