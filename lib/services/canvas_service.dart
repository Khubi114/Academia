// lib/services/canvas_service.dart
//
// Canvas LMS integration (client side).
//
// Data flow
// ─────────
//   Canvas API ──(device, personal access token)──► [fetchAssignments]  rich UI data
//   Canvas API ──(Vercel, same token)─────────────► /api/canvas/sync     Supabase tables
//                                                    + optional Google Calendar mirror
//
// [sync] runs both, compares the result with the snapshot saved on the device
// after the previous run, and returns a [SyncReport] describing what changed
// (new / updated / removed assignments). The last result is cached locally so
// the UI can paint instantly and work offline.
//
// SECURITY: the access token is stored only in the OS keychain
// (flutter_secure_storage) and in the user's own `user_settings` row on the
// server (needed for background sync). It is never hard-coded.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import '../models/assignment_item.dart';
import '../models/canvas_module.dart';
import '../models/sync_report.dart';
import 'api_client.dart';
import 'change_detector.dart';

class CanvasService extends ChangeNotifier {
  CanvasService._();
  static final CanvasService instance = CanvasService._();

  static const String _baseUrlKey = 'canvas_base_url';
  static const String _tokenKey = 'canvas_api_token';
  static const String _snapshotKey = 'canvas_snapshot_v1';
  static const String _cacheKey = 'canvas_assignments_v1';

  /// Courses fetched in parallel — polite to Canvas' rate limiter.
  static const int _concurrency = 4;

  final _storage = const FlutterSecureStorage();
  final _api = ApiClient.instance;
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  String? _baseUrl;
  String? _token;
  bool _isConnected = false;
  bool _mirrorToCalendar = false;
  DateTime? _lastSynced;

  bool get isConnected => _isConnected;
  bool get mirrorToCalendar => _mirrorToCalendar;
  DateTime? get lastSynced => _lastSynced;
  String? get baseUrl => _baseUrl;

  // ── Connection management ───────────────────────────────────────────────────

  /// Loads saved credentials from secure storage. Call once at app start.
  Future<void> loadCredentials() async {
    _baseUrl = await _storage.read(key: _baseUrlKey);
    _token = await _storage.read(key: _tokenKey);
    _isConnected = (_token ?? '').isNotEmpty && (_baseUrl ?? '').isNotEmpty;
    if (_isConnected) await _loadMirrorSetting();
    notifyListeners();
  }

  /// Validates the token (server-side), stores it and marks Canvas connected.
  ///
  /// Returns `null` on success, otherwise a user-facing error message.
  Future<String?> connect(String baseUrl, String token) async {
    final cleanUrl = _normaliseUrl(baseUrl);
    final cleanToken = token.trim();
    if (cleanUrl.isEmpty || cleanToken.isEmpty) {
      return 'Enter your Canvas address and access token.';
    }

    try {
      // The backend checks the domain is a genuine Canvas host and that the
      // token works, then saves it for background syncs.
      await _api.post('/api/canvas/connect', body: {
        'domain': Uri.parse(cleanUrl).host,
        'token': cleanToken,
      });
    } on ApiException catch (e) {
      return e.message;
    }

    await _storage.write(key: _baseUrlKey, value: cleanUrl);
    await _storage.write(key: _tokenKey, value: cleanToken);
    _baseUrl = cleanUrl;
    _token = cleanToken;
    _isConnected = true;
    await _loadMirrorSetting();
    notifyListeners();
    return null;
  }

  /// Removes credentials (device + server) and the local cache.
  Future<void> disconnect() async {
    try {
      await _api.post('/api/canvas/disconnect');
    } on ApiException catch (e) {
      debugPrint('[Canvas] server disconnect failed: $e');
    }
    await _storage.delete(key: _baseUrlKey);
    await _storage.delete(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_snapshotKey);
    await prefs.remove(_cacheKey);
    _baseUrl = null;
    _token = null;
    _isConnected = false;
    _lastSynced = null;
    notifyListeners();
  }

  /// Opt-in: mirror Canvas due dates into Google Calendar during sync.
  Future<void> setMirrorToCalendar(bool enabled) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    await Supabase.instance.client.from('user_settings').upsert({
      'user_id': userId,
      'canvas_calendar_sync': enabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
    _mirrorToCalendar = enabled;
    notifyListeners();
  }

  Future<void> _loadMirrorSetting() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('user_settings')
          .select('canvas_calendar_sync')
          .eq('user_id', userId)
          .maybeSingle();
      _mirrorToCalendar = row?['canvas_calendar_sync'] as bool? ?? false;
    } catch (e) {
      debugPrint('[Canvas] could not load settings: $e');
    }
  }

  String _normaliseUrl(String input) {
    var url = input.trim().replaceAll(RegExp(r'/+$'), '');
    if (url.isEmpty) return '';
    if (!url.startsWith('http')) url = 'https://$url';
    return url;
  }

  // ── Sync (fetch + diff + backend + cache) ───────────────────────────────────

  /// Full sync. Returns the fresh assignments and a report of what changed
  /// since the previous sync on this device.
  Future<({List<AssignmentManagerItem> items, SyncReport report})> sync() async {
    await _ensureCredentials();
    if (!_isConnected) {
      return (
        items: <AssignmentManagerItem>[],
        report: SyncReport(
          source: SyncSource.canvas,
          at: DateTime.now(),
          error: 'not_connected',
        ),
      );
    }

    try {
      final fetched = await _fetchAll();
      final prefs = await SharedPreferences.getInstance();

      // 1. Detect what changed since last time.
      final previous = decodeSnapshot(prefs.getString(_snapshotKey));
      final current = <String, SnapshotEntry>{
        for (final a in fetched.items)
          a.id: SnapshotEntry(
            signature: a.signature,
            title: a.title,
            group: fetched.courseOf[a.id] ?? '',
          ),
      };
      // Keep entries of courses that failed to load, or they'd look "removed"
      // now and "added" again on the next successful sync.
      previous?.forEach((id, entry) {
        if (fetched.failedCourses.contains(entry.group)) {
          current.putIfAbsent(id, () => entry);
        }
      });
      // No previous snapshot = first sync: nothing is "news".
      final changes = previous == null
          ? const ChangeSet()
          : detectChanges(
              previous: previous,
              current: current,
              failedGroups: fetched.failedCourses,
            );

      // 2. Persist snapshot + cache for instant / offline start-up.
      await prefs.setString(_snapshotKey, encodeSnapshot(current));
      await prefs.setString(
        _cacheKey,
        jsonEncode(fetched.items.map((a) => a.toMap()).toList()),
      );
      _lastSynced = DateTime.now();

      // 3. Let the backend update Supabase (+ Google Calendar). A backend
      //    hiccup must not hide data we already fetched successfully.
      await _pushToBackend();

      notifyListeners();
      return (
        items: fetched.items,
        report: SyncReport(
          source: SyncSource.canvas,
          at: _lastSynced!,
          added: changes.added.length,
          updated: changes.updated.length,
          removed: changes.removed.length,
          highlights: [...changes.added, ...changes.updated].take(3).toList(),
        ),
      );
    } on DioException catch (e) {
      _handleAuthError(e);
      return (
        items: await loadCached(),
        report: SyncReport(
          source: SyncSource.canvas,
          at: DateTime.now(),
          error: e.response?.statusCode == 401
              ? 'Canvas token expired — reconnect in Settings.'
              : 'Could not reach Canvas.',
        ),
      );
    } catch (e) {
      debugPrint('[Canvas] sync unexpected: $e');
      return (
        items: await loadCached(),
        report: SyncReport(
          source: SyncSource.canvas,
          at: DateTime.now(),
          error: 'Sync failed.',
        ),
      );
    }
  }

  Future<void> _pushToBackend() async {
    try {
      await _api.post('/api/canvas/sync');
    } on ApiException catch (e) {
      debugPrint('[Canvas] backend sync failed: $e');
    }
  }

  /// Last successful result from disk (empty when never synced).
  Future<List<AssignmentManagerItem>> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return [];
      return (jsonDecode(raw) as List<dynamic>)
          .map((m) => AssignmentManagerItem.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Modular Canvas API ──────────────────────────────────────────────────────

  /// Follows Canvas Link-header pagination, collecting every page.
  Future<List<dynamic>> _getPaginated(String path) async {
    final results = <dynamic>[];
    String? url = '$_apiBase$path';

    while (url != null) {
      final response = await _dio.get<dynamic>(
        url,
        options: Options(headers: {'Authorization': 'Bearer $_token'}),
      );
      if (response.data is List) results.addAll(response.data as List);
      url = _parseNextLink(response.headers.value('link'));
    }
    return results;
  }

  String get _apiBase => '${_baseUrl ?? AppConfig.canvasDefaultBaseUrl}/api/v1';

  String? _parseNextLink(String? linkHeader) {
    if (linkHeader == null) return null;
    for (final part in linkHeader.split(',')) {
      if (part.contains('rel="next"')) {
        return RegExp(r'<([^>]+)>').firstMatch(part)?.group(1);
      }
    }
    return null;
  }

  /// Active courses ("subjects") the user is enrolled in.
  Future<List<Map<String, dynamic>>> fetchCourses() async {
    await _ensureCredentials();
    final raw = await _getPaginated(
      '/courses?enrollment_state=active&per_page=50',
    );
    return raw.cast<Map<String, dynamic>>();
  }

  /// Modules of one course.
  Future<List<CanvasModule>> fetchModules(String courseId) async {
    await _ensureCredentials();
    try {
      final raw = await _getPaginated('/courses/$courseId/modules?per_page=50');
      return raw
          .map((m) => CanvasModule.fromCanvas(m as Map<String, dynamic>, courseId))
          .toList();
    } on DioException catch (e) {
      // Course admins can disable modules → Canvas answers 404/403.
      debugPrint('[Canvas] modules for $courseId: ${e.message}');
      return [];
    }
  }

  /// Assignments (with submission state and due dates) across all courses.
  Future<List<AssignmentManagerItem>> fetchAssignments() async {
    await _ensureCredentials();
    if (!_isConnected) return [];
    try {
      return (await _fetchAll()).items;
    } on DioException catch (e) {
      _handleAuthError(e);
      return loadCached();
    }
  }

  Future<_Fetched> _fetchAll() async {
    final courses = await fetchCourses();
    final items = <AssignmentManagerItem>[];
    final courseOf = <String, String>{};
    final failed = <String>{};

    for (var i = 0; i < courses.length; i += _concurrency) {
      final batch = courses.skip(i).take(_concurrency);
      final results = await Future.wait(batch.map((course) async {
        final courseId = course['id'].toString();
        try {
          final raw = await _getPaginated(
            '/courses/$courseId/assignments'
            '?per_page=50&include[]=submission&order_by=due_at',
          );
          return (course: course, raw: raw, failed: false);
        } on DioException catch (e) {
          if (e.response?.statusCode == 401) rethrow; // token problem: abort
          debugPrint('[Canvas] course $courseId failed: ${e.message}');
          return (course: course, raw: <dynamic>[], failed: true);
        }
      }));

      for (final r in results) {
        final courseId = r.course['id'].toString();
        if (r.failed) {
          failed.add(courseId);
          continue;
        }
        final name = r.course['name'] as String? ?? 'Unknown Course';
        final code = r.course['course_code'] as String? ?? '';
        for (final a in r.raw) {
          final item = _mapAssignment(
            a as Map<String, dynamic>,
            courseName: name,
            courseCode: code,
            courseColorKey: _colorForCourse(code),
          );
          if (item == null) continue;
          items.add(item);
          courseOf[item.id] = courseId;
        }
      }
    }

    items.sort((a, b) => _statusOrder(a.status).compareTo(_statusOrder(b.status)));
    return _Fetched(items, courseOf, failed);
  }

  // ── Mapping ─────────────────────────────────────────────────────────────────

  AssignmentManagerItem? _mapAssignment(
    Map<String, dynamic> a, {
    required String courseName,
    required String courseCode,
    required String courseColorKey,
  }) {
    final dueUtc = DateTime.tryParse(a['due_at'] as String? ?? '');
    final due = dueUtc?.toLocal(); // show the user's own local date/time

    final submission = a['submission'] as Map<String, dynamic>?;
    final workflow = submission?['workflow_state'];
    final submitted = submission != null &&
        (submission['submitted_at'] != null ||
            workflow == 'submitted' ||
            workflow == 'graded');
    final graded =
        submission != null && workflow == 'graded' && submission['score'] != null;

    // Undated work that is already graded is just history.
    if (due == null && graded) return null;

    return AssignmentManagerItem(
      id: a['id']?.toString() ?? '',
      title: a['name'] as String? ?? 'Untitled',
      courseName: courseName,
      courseCode: courseCode,
      courseColor: courseColorKey,
      dueDate: _formatDueDate(due),
      dueTime: due == null ? '' : _formatTime(due),
      dueDateRaw: _classifyDueDate(due),
      status: _resolveStatus(due: due, submitted: submitted, graded: graded),
      points: (a['points_possible'] as num?)?.toInt() ?? 0,
      pointsEarned: graded ? (submission['score'] as num?)?.toInt() : null,
      submitted: submitted,
      description: _stripHtml(a['description'] as String? ?? ''),
      submissionType: _formatSubmissionType(
        (a['submission_types'] as List<dynamic>?)?.cast<String>() ?? [],
      ),
      reminderSet: false,
    );
  }

  String _resolveStatus({
    required DateTime? due,
    required bool submitted,
    required bool graded,
  }) {
    if (graded) return 'graded';
    if (submitted) return 'submitted';
    if (due == null) return 'upcoming';
    final now = DateTime.now();
    if (due.isBefore(now)) return 'overdue';
    return due.difference(now).inHours <= 48 ? 'due_soon' : 'upcoming';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDueDate(DateTime? d) =>
      d == null ? 'No due date' : '${_months[d.month - 1]} ${d.day}, ${d.year}';

  String _formatTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  String _classifyDueDate(DateTime? date) {
    if (date == null) return 'future';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(date.year, date.month, date.day).difference(today).inDays;
    if (diff < 0) return 'past';
    if (diff == 0) return 'today';
    if (diff == 1) return 'tomorrow';
    return 'future';
  }

  String _formatSubmissionType(List<String> types) {
    if (types.isEmpty) return 'Canvas';
    const names = {
      'online_upload': 'File Upload',
      'online_text_entry': 'Text Entry',
      'online_url': 'Website URL',
      'media_recording': 'Media Recording',
      'online_quiz': 'Online Quiz',
      'discussion_topic': 'Discussion',
      'external_tool': 'External Tool',
      'none': 'No Submission',
      'not_graded': 'Not Graded',
    };
    return types.map((t) => names[t] ?? t).join(' / ');
  }

  String _stripHtml(String html) => html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .trim();

  String _colorForCourse(String courseCode) {
    final upper = courseCode.toUpperCase();
    const tech = ['COS', 'TNE', 'INF', 'SWE', 'CIS', 'CS'];
    const math = ['MAT', 'STA', 'PHY'];
    if (tech.any(upper.contains)) return 'primary';
    if (math.any(upper.contains)) return 'secondary';
    return 'teal';
  }

  int _statusOrder(String status) {
    const order = ['overdue', 'due_soon', 'upcoming', 'submitted', 'graded'];
    final i = order.indexOf(status);
    return i == -1 ? order.length : i;
  }

  Future<void> _ensureCredentials() async {
    if (_token == null) await loadCredentials();
  }

  void _handleAuthError(DioException e) {
    if (e.response?.statusCode == 401) {
      _isConnected = false;
      notifyListeners();
      debugPrint('[Canvas] 401 — token invalid or expired');
    }
  }
}

class _Fetched {
  final List<AssignmentManagerItem> items;
  final Map<String, String> courseOf; // assignment id → course id
  final Set<String> failedCourses;
  const _Fetched(this.items, this.courseOf, this.failedCourses);
}
