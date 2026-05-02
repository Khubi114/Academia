# ─────────────────────────────────────────────────────────────────────────────
# PUBSPEC.YAML — add these two packages under `dependencies:`
# ─────────────────────────────────────────────────────────────────────────────

  google_sign_in: ^6.2.1       # Google OAuth — gets the server auth code
  supabase_flutter: ^2.5.0     # Supabase client — reads cached events + auth


# ─────────────────────────────────────────────────────────────────────────────
# MAIN.DART — add Supabase init before runApp
# ─────────────────────────────────────────────────────────────────────────────
#
# In lib/main.dart, inside main(), before runApp(MyApp()):
#
#   await Supabase.initialize(
#     url: const String.fromEnvironment('SUPABASE_URL'),
#     anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
#   );
#
# Then build/run with:
#   flutter run \
#     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
#     --dart-define=SUPABASE_ANON_KEY=eyJ... \
#     --dart-define=GOOGLE_WEB_CLIENT_ID=123456.apps.googleusercontent.com \
#     --dart-define=VERCEL_BASE_URL=https://your-app.vercel.app


# ─────────────────────────────────────────────────────────────────────────────
# VERCEL — environment variables to set in the Vercel dashboard
# (Project → Settings → Environment Variables)
# ─────────────────────────────────────────────────────────────────────────────

SUPABASE_URL                = https://xxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY   = eyJ...   # Settings → API → service_role key
GOOGLE_CLIENT_ID            = 123456.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET        = GOCSPX-...


# ─────────────────────────────────────────────────────────────────────────────
# VERCEL — package.json for the api/ folder
# Create api/package.json with:
# ─────────────────────────────────────────────────────────────────────────────
#
# {
#   "dependencies": {
#     "@supabase/supabase-js": "^2.43.0",
#     "googleapis": "^140.0.0"
#   }
# }


# ─────────────────────────────────────────────────────────────────────────────
# GOOGLE CLOUD CONSOLE — one-time setup (all free)
# ─────────────────────────────────────────────────────────────────────────────
#
# 1. Create a project at console.cloud.google.com
# 2. Enable "Google Calendar API"
# 3. OAuth consent screen → External → add your email as test user
# 4. Credentials → Create OAuth 2.0 Client ID:
#    - Type: Web application
#    - Authorized redirect URIs: (leave blank for server auth code flow)
#    → This gives you GOOGLE_CLIENT_ID + GOOGLE_CLIENT_SECRET for Vercel
# 5. Credentials → Create OAuth 2.0 Client ID:
#    - Type: Android (use your app's package name from AndroidManifest.xml)
#    - Type: iOS (use your bundle ID from Info.plist)
#    → These are needed by google_sign_in on device (no secret needed for mobile)
#
# The "Web application" client ID is what goes in GOOGLE_WEB_CLIENT_ID
# (dart-define) AND serverClientId in GoogleCalendarService.


# ─────────────────────────────────────────────────────────────────────────────
# ANDROID — add to android/app/src/main/res/values/strings.xml
# ─────────────────────────────────────────────────────────────────────────────
#
# <resources>
#   <string name="default_web_client_id">YOUR_WEB_CLIENT_ID</string>
# </resources>
#
# Also add to android/app/build.gradle.kts inside defaultConfig:
#   manifestPlaceholders["appAuthRedirectScheme"] = "com.example.studysync"


# ─────────────────────────────────────────────────────────────────────────────
# IOS — add to ios/Runner/Info.plist
# ─────────────────────────────────────────────────────────────────────────────
#
# <key>CFBundleURLTypes</key>
# <array>
#   <dict>
#     <key>CFBundleURLSchemes</key>
#     <array>
#       <!-- Reversed iOS client ID from Google Cloud Console -->
#       <string>com.googleusercontent.apps.YOUR_IOS_CLIENT_ID</string>
#     </array>
#   </dict>
# </array>
