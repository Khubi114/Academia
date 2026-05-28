// lib/services/google_calendar_service.dart
//
// Responsibilities:
//   1. Sign the user in with Google and send the server auth code to Vercel.
//   2. Fetch calendar events for a date range from the Vercel endpoint.
//   3. Map raw JSON → CalendarEvent objects used across the app.
//
// Vercel endpoints:
//   POST /api/calendar/exchange  — stores refresh_token in Supabase
//   GET  /api/calendar/events    — returns events for a date range

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../presentation/calendar_view_screen/calendar_view_screen.dart';

class GoogleCalendarService {
  GoogleCalendarService._();
  static final GoogleCalendarService instance = GoogleCalendarService._();

  // ── Configuration ───────────────────────────────────────────────────────────
  static const String _vercelBaseUrl = String.fromEnvironment(
    'VERCEL_BASE_URL',
    defaultValue: 'https://academia-plum.vercel.app',
  );

  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '821856499544-pro3mv21j1dkrqiiqf4b0ssbiie3u3u9.apps.googleusercontent.com',
  );

  // ── Internal state ──────────────────────────────────────────────────────────
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/calendar.readonly'],
    serverClientId: _serverClientId,
  );

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // ── Auth ────────────────────────────────────────────────────────────────────

  /// Checks if this user already has a token in Supabase (restore on app launch).
  Future<void> checkExistingConnection() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final result = await Supabase.instance.client
          .from('calendar_tokens')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      _isConnected = result != null;
    } catch (_) {
      _isConnected = false;
    }
  }

  /// Signs the user in with Google (shows account picker) and sends the
  /// server auth code to Vercel to exchange for a refresh token.
  ///
  /// Returns `null` on success, or a human-readable error string on failure.
  Future<String?> signIn() async {
    try {
      // 1. Trigger Google sign-in (account picker) immediately to avoid browser popup blockers.
      // Modern browsers require popups to be opened synchronously from user gestures;
      // putting any asynchronous call (like Supabase init) first will break the user gesture chain.
      debugPrint('[GCalService] Starting Google sign-in…');
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        debugPrint('[GCalService] User cancelled sign-in');
        return 'cancelled';
      }
      debugPrint('[GCalService] Signed in as ${account.email}');

      // 2. Get server auth code — requires a valid Web Application OAuth client ID
      final String? serverAuthCode = account.serverAuthCode;
      if (serverAuthCode == null) {
        debugPrint(
          '[GCalService] serverAuthCode is null.\n'
          '  → Make sure serverClientId is your Web Application OAuth 2.0 client ID\n'
          '  → NOT the Android or iOS client ID.\n'
          '  → Current value: $_serverClientId',
        );
        return 'no_auth_code';
      }
      debugPrint('[GCalService] Got serverAuthCode (length: ${serverAuthCode.length})');

      // 3. Sign in anonymously to Supabase (now safe to do asynchronously)
      final supabase = Supabase.instance.client;
      if (supabase.auth.currentUser == null) {
        debugPrint('[GCalService] No Supabase session — signing in anonymously…');
        await supabase.auth.signInAnonymously();
      }

      final String? userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('[GCalService] Could not get Supabase user ID');
        return 'no_supabase_user';
      }
      debugPrint('[GCalService] Supabase user ID: $userId');

      // 4. Send to Vercel for token exchange
      debugPrint('[GCalService] Calling $_vercelBaseUrl/api/calendar/exchange…');
      final response = await _dio.post(
        '$_vercelBaseUrl/api/calendar/exchange',
        data: {'server_auth_code': serverAuthCode, 'user_id': userId},
      );

      if (response.statusCode == 200) {
        _isConnected = true;
        debugPrint('[GCalService] Connected successfully: ${response.data}');
        return null; // success
      }

      debugPrint('[GCalService] Exchange failed (${response.statusCode}): ${response.data}');
      return 'exchange_failed_${response.statusCode}';
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      debugPrint('[GCalService] signIn DioException ($status): ${e.message}\nBody: $body');
      return 'network_error: ${e.message} (status: $status, body: $body)';
    } catch (e) {
      debugPrint('[GCalService] signIn unexpected error: $e');
      return 'unexpected: $e';
    }
  }

  /// Signs out of Google. Does NOT delete the Supabase refresh token,
  /// so the server can still fetch events in the background.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _isConnected = false;
  }

  // ── Events ──────────────────────────────────────────────────────────────────

  /// Fetches events for [start]–[end] from Vercel (which caches in Supabase).
  Future<List<CalendarEvent>> fetchEvents({
    required DateTime start,
    required DateTime end,
  }) async {
    // Ensure we have a Supabase session
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentUser == null) {
      try {
        await supabase.auth.signInAnonymously();
      } catch (_) {}
    }

    final String? userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final String timeMin =
          '${start.toIso8601String().split('T')[0]}T00:00:00Z';
      final String timeMax =
          '${end.toIso8601String().split('T')[0]}T23:59:59Z';

      final response = await _dio.get(
        '$_vercelBaseUrl/api/calendar/events',
        queryParameters: {
          'user_id': userId,
          'time_min': timeMin,
          'time_max': timeMax,
        },
      );

      if (response.statusCode != 200) return [];

      final List<dynamic> rawEvents =
          (response.data as Map<String, dynamic>)['events'] as List<dynamic>;

      _isConnected = true;
      return rawEvents
          .map((json) => _mapToCalendarEvent(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) _isConnected = false;
      debugPrint('[GCalService] fetchEvents: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('[GCalService] fetchEvents error: $e');
      return [];
    }
  }

  /// Convenience: fetch a full month plus one-week buffer on each side.
  Future<List<CalendarEvent>> fetchMonthEvents(DateTime month) {
    final start =
        DateTime(month.year, month.month, 1).subtract(const Duration(days: 7));
    final end = DateTime(month.year, month.month + 1, 0)
        .add(const Duration(days: 7));
    return fetchEvents(start: start, end: end);
  }

  // ── Mapping ─────────────────────────────────────────────────────────────────

  CalendarEvent _mapToCalendarEvent(Map<String, dynamic> json) {
    final String dateStr = json['event_date'] as String;
    final parts = dateStr.split('-');

    return CalendarEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      source: json['source'] as String? ?? 'google_calendar',
      date: DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      location: json['location'] as String? ?? '',
      courseCode: json['course_code'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isAllDay: json['is_all_day'] as bool? ?? false,
    );
  }
}
