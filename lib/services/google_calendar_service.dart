// lib/services/google_calendar_service.dart
//
// Responsibilities:
//   1. Sign the user in with Google and send the server auth code to Vercel.
//   2. Fetch calendar events for a date range from the Vercel endpoint.
//   3. Map raw JSON → CalendarEvent objects (the model already used in
//      calendar_view_screen.dart — no model changes needed).
//
// Dependencies to add to pubspec.yaml:
//   google_sign_in: ^6.2.1
//   supabase_flutter: ^2.5.0
//
// Environment variables (add to your .env / build config):
//   VERCEL_BASE_URL  — e.g. https://your-app.vercel.app

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import the CalendarEvent model from the screen file.
// It lives at the bottom of calendar_view_screen.dart already.
import '../presentation/calendar_view_screen/calendar_view_screen.dart';

class GoogleCalendarService {
  GoogleCalendarService._();
  static final GoogleCalendarService instance = GoogleCalendarService._();

  // ── Configuration ──────────────────────────────────────────────────────────
  // Replace with your actual Vercel deployment URL.
  // Store this in a constants file or from dart-define in production.
  static const String _vercelBaseUrl =
      String.fromEnvironment('VERCEL_BASE_URL', defaultValue: 'https://your-app.vercel.app');

  // The Web OAuth 2.0 Client ID from Google Cloud Console.
  // Used so google_sign_in can return a server auth code instead of
  // an access token — the server code is what Vercel exchanges for tokens.
  static const String _serverClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');

  // ── Internal state ─────────────────────────────────────────────────────────
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Calendar read-only is free and covers all event data we need.
    scopes: ['https://www.googleapis.com/auth/calendar.readonly'],
    // serverClientId is required to get a serverAuthCode back.
    serverClientId: _serverClientId,
  );

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // ── Auth ───────────────────────────────────────────────────────────────────

  /// Signs the user in with Google and sends the server auth code to Vercel
  /// so a refresh_token can be stored in Supabase.
  ///
  /// Returns true on success, false if the user cancels or an error occurs.
  Future<bool> signIn() async {
    try {
      // 1. Trigger Google sign-in flow (shows the account picker).
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return false; // user cancelled

      // 2. The serverAuthCode is what Vercel needs — not the access token.
      final String? serverAuthCode = account.serverAuthCode;
      if (serverAuthCode == null) {
        debugPrint('[GCalService] No serverAuthCode returned. '
            'Make sure serverClientId is set and the scope is correct.');
        return false;
      }

      // 3. Get the Supabase user id to associate the token with.
      final String? userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('[GCalService] No Supabase user — sign into the app first.');
        return false;
      }

      // 4. Send the server auth code to Vercel for token exchange.
      final response = await _dio.post(
        '$_vercelBaseUrl/api/calendar/exchange',
        data: {'server_auth_code': serverAuthCode, 'user_id': userId},
      );

      if (response.statusCode == 200) {
        _isConnected = true;
        return true;
      }

      debugPrint('[GCalService] Exchange failed: ${response.data}');
      return false;
    } on DioException catch (e) {
      debugPrint('[GCalService] signIn DioException: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[GCalService] signIn error: $e');
      return false;
    }
  }

  /// Signs the user out of Google (does NOT delete the Supabase token).
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _isConnected = false;
  }

  // ── Events ─────────────────────────────────────────────────────────────────

  /// Fetches all calendar events between [start] and [end] (inclusive).
  ///
  /// The Vercel function serves cached data when possible (15-minute TTL),
  /// so calling this for every screen load is safe and free-tier friendly.
  ///
  /// Returns an empty list if the user is not connected or on any error.
  Future<List<CalendarEvent>> fetchEvents({
    required DateTime start,
    required DateTime end,
  }) async {
    final String? userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[GCalService] fetchEvents: no Supabase user');
      return [];
    }

    try {
      final String timeMin = '${start.toIso8601String().split('T')[0]}T00:00:00Z';
      final String timeMax = '${end.toIso8601String().split('T')[0]}T23:59:59Z';

      final response = await _dio.get(
        '$_vercelBaseUrl/api/calendar/events',
        queryParameters: {
          'user_id': userId,
          'time_min': timeMin,
          'time_max': timeMax,
        },
      );

      if (response.statusCode != 200) {
        debugPrint('[GCalService] fetchEvents non-200: ${response.statusCode}');
        return [];
      }

      final List<dynamic> rawEvents =
          (response.data as Map<String, dynamic>)['events'] as List<dynamic>;

      _isConnected = true;
      return rawEvents
          .map((json) => _mapToCalendarEvent(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Token missing — user needs to re-connect.
        _isConnected = false;
      }
      debugPrint('[GCalService] fetchEvents DioException: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('[GCalService] fetchEvents error: $e');
      return [];
    }
  }

  /// Convenience: fetch events for a full calendar month plus a small buffer
  /// so adjacent-month days (shown greyed out) also have dot indicators.
  Future<List<CalendarEvent>> fetchMonthEvents(DateTime month) {
    final start = DateTime(month.year, month.month, 1).subtract(const Duration(days: 7));
    final end = DateTime(month.year, month.month + 1, 0).add(const Duration(days: 7));
    return fetchEvents(start: start, end: end);
  }

  // ── Mapping ────────────────────────────────────────────────────────────────

  /// Maps a JSON row (from either Vercel or Supabase) to the [CalendarEvent]
  /// model that already exists in calendar_view_screen.dart.
  /// No changes to the model are needed.
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
