// lib/services/google_calendar_service.dart
//
// Google Calendar integration (client side).
//
// How the pieces fit together
// ───────────────────────────
//   1. [signIn] opens Google's consent screen (Google Identity Services on web,
//      the native picker on mobile) asking for calendar.readonly and
//      calendar.events, and receives a one-time *server auth code*.
//   2. The code goes to POST /api/calendar/exchange; the server swaps it for a
//      refresh token, checks BOTH scopes were granted and stores the token in
//      Supabase. The app never sees the refresh token.
//   3. [fetchEvents] / [syncNow] read events through the backend, which
//      keeps a cache in sync with Google using incremental sync tokens —
//      events added, edited or deleted in Google Calendar flow into the app
//      the next time we sync (every few minutes, see SyncService).
//   4. [createEvent] writes an event back to Google Calendar
//      (calendar.events scope).

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import '../models/calendar_event.dart';
import '../models/sync_report.dart';
import 'api_client.dart';

class GoogleCalendarService extends ChangeNotifier {
  GoogleCalendarService._();
  static final GoogleCalendarService instance = GoogleCalendarService._();

  final ApiClient _api = ApiClient.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: AppConfig.googleScopes,
    serverClientId: AppConfig.googleWebClientId,
    // Android: always return a fresh auth code so a refresh token is issued.
    forceCodeForRefreshToken: true,
  );

  bool _isConnected = false;
  bool _needsReconnect = false;
  DateTime? _lastSynced;

  bool get isConnected => _isConnected;

  /// True when the stored grant predates the calendar.events scope, so we can
  /// read but not write. The user must reconnect once to upgrade it.
  bool get needsReconnect => _needsReconnect;
  DateTime? get lastSynced => _lastSynced;

  void _setState({bool? connected, bool? needsReconnect}) {
    _isConnected = connected ?? _isConnected;
    _needsReconnect = needsReconnect ?? _needsReconnect;
    notifyListeners();
  }

  // ── Auth ────────────────────────────────────────────────────────────────────

  /// Restores connection state on app launch by checking whether the server
  /// already holds a token (and with which scopes) for this user.
  Future<void> checkExistingConnection() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final row = await Supabase.instance.client
          .from('calendar_tokens')
          .select('scope')
          .eq('user_id', userId)
          .maybeSingle();

      final scope = (row?['scope'] as String?) ?? '';
      _setState(
        connected: row != null,
        needsReconnect:
            row != null && !scope.contains(AppConfig.googleEventsScope),
      );
    } catch (e) {
      debugPrint('[GCal] checkExistingConnection: $e');
    }
  }

  /// Signs in with Google and hands the server auth code to the backend.
  ///
  /// Returns `null` on success, otherwise a short error code:
  /// `cancelled`, `no_auth_code`, `missing_scopes`, `exchange_failed_<status>`,
  /// `network_error: …`.
  Future<String?> signIn() async {
    try {
      // Must be the first await: browsers only allow the sign-in popup while
      // the user's click is still "fresh".
      final account = await _googleSignIn.signIn();
      if (account == null) return 'cancelled';

      // Scopes the user unticked on the consent screen are caught by the
      // server (403 → 'missing_scopes'), which sees the scopes Google granted.
      final code = account.serverAuthCode;
      if (code == null) {
        debugPrint('[GCal] serverAuthCode is null — is GOOGLE_WEB_CLIENT_ID a '
            '"Web application" client id?');
        return 'no_auth_code';
      }

      await _api.post('/api/calendar/exchange', body: {'server_auth_code': code});
      _lastSynced = DateTime.now();
      _setState(connected: true, needsReconnect: false);
      return null;
    } on ApiException catch (e) {
      debugPrint('[GCal] signIn failed: $e');
      if (e.status == 403) return 'missing_scopes';
      if (e.status == null) return 'network_error: ${e.message}';
      return 'exchange_failed_${e.status}: ${e.message}';
    } catch (e) {
      debugPrint('[GCal] signIn unexpected: $e');
      return 'unexpected: $e';
    }
  }

  /// Signs out of Google on this device. The server keeps its token so
  /// background sync continues; use the backend to revoke fully.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _setState(connected: false);
  }

  /// Turns a [signIn] error code into a message a student can act on.
  static String describeError(String code) {
    if (code == 'missing_scopes') {
      return 'Academia needs permission to view AND edit calendar events. '
          'Please reconnect and leave both boxes ticked.';
    }
    if (code == 'no_auth_code') {
      return 'Google did not return a server auth code. Check that '
          'GOOGLE_WEB_CLIENT_ID is a "Web application" client id.';
    }
    if (code.startsWith('exchange_failed_5')) {
      return 'The Academia server hit an error. Check that the Google and '
          'Supabase keys are set in the Vercel project.';
    }
    if (code.startsWith('exchange_failed_')) {
      return 'Could not finish connecting ($code).';
    }
    if (code.startsWith('network_error')) {
      return 'Could not reach the Academia server. Check your connection.';
    }
    return 'Connection failed: $code';
  }

  // ── Reading ─────────────────────────────────────────────────────────────────

  /// Events between [start] and [end] (inclusive dates).
  /// The backend refreshes its cache first when it is older than 5 minutes.
  Future<List<CalendarEvent>> fetchEvents({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final json = await _api.get('/api/calendar/events', query: {
        'time_min': '${_ymd(start)}T00:00:00Z',
        'time_max': '${_ymd(end)}T23:59:59Z',
      });
      _lastSynced = DateTime.now();
      _setState(connected: true);

      return (json['events'] as List<dynamic>? ?? [])
          .map((row) => CalendarEvent.fromRow(row as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      debugPrint('[GCal] fetchEvents: $e');
      if (e.isUnauthorized) _setState(connected: false);
      return [];
    } catch (e) {
      debugPrint('[GCal] fetchEvents unexpected: $e');
      return [];
    }
  }

  /// A month plus a one-week buffer either side (for the month grid).
  Future<List<CalendarEvent>> fetchMonthEvents(DateTime month) {
    final start =
        DateTime(month.year, month.month, 1).subtract(const Duration(days: 7));
    final end = DateTime(month.year, month.month + 1, 0)
        .add(const Duration(days: 7));
    return fetchEvents(start: start, end: end);
  }

  /// Forces the backend to pull the latest changes from Google right now.
  Future<SyncReport> syncNow() async {
    if (!_isConnected) {
      return SyncReport(
        source: SyncSource.googleCalendar,
        at: DateTime.now(),
        error: 'not_connected',
      );
    }
    try {
      final json = await _api.post('/api/calendar/sync');
      _lastSynced = DateTime.now();
      notifyListeners();

      // The first (full) sync is not "news" — only report incremental changes.
      final incremental = json['mode'] == 'incremental';
      return SyncReport(
        source: SyncSource.googleCalendar,
        at: _lastSynced!,
        updated: incremental ? (json['upserted'] as int? ?? 0) : 0,
        removed: incremental ? (json['deleted'] as int? ?? 0) : 0,
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) _setState(connected: false);
      return SyncReport(
        source: SyncSource.googleCalendar,
        at: DateTime.now(),
        error: e.message,
      );
    }
  }

  // ── Writing ─────────────────────────────────────────────────────────────────

  /// Creates an event in the user's primary Google Calendar.
  /// Returns the stored event, or `null` if it could not be created.
  Future<CalendarEvent?> createEvent({
    required String title,
    required DateTime date,
    String startTime = '09:00',
    String endTime = '10:00',
    String location = '',
    String description = '',
    bool isAllDay = false,
  }) async {
    if (!_isConnected || _needsReconnect) return null;
    try {
      final json = await _api.post('/api/calendar/create', body: {
        'title': title,
        'date': _ymd(date),
        'start_time': startTime,
        'end_time': endTime,
        'location': location,
        'description': description,
        'is_all_day': isAllDay,
        'utc_offset': _utcOffset(date),
      });
      final row = json['event'];
      return row is Map<String, dynamic> ? CalendarEvent.fromRow(row) : null;
    } on ApiException catch (e) {
      debugPrint('[GCal] createEvent: $e');
      return null;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Device UTC offset on [date] as `+10:00` (Google needs an offset because
  /// Dart cannot supply an IANA zone name).
  String _utcOffset(DateTime date) {
    final o = DateTime(date.year, date.month, date.day, 12).timeZoneOffset;
    final sign = o.isNegative ? '-' : '+';
    final abs = o.abs();
    final hh = abs.inHours.toString().padLeft(2, '0');
    final mm = (abs.inMinutes % 60).toString().padLeft(2, '0');
    return '$sign$hh:$mm';
  }
}
