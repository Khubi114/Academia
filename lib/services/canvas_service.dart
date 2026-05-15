// lib/services/canvas_service.dart
//
// Talks directly to the Swinburne Canvas REST API.
// Token is stored securely on-device (OS keychain via flutter_secure_storage).
// No server proxy needed — Canvas tokens are long-lived personal access tokens.

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../presentation/assignment_manager_screen/assignment_manager_screen.dart';

class CanvasService {
  CanvasService._();
  static final CanvasService instance = CanvasService._();

  static const String _baseUrlKey = 'canvas_base_url';
  static const String _tokenKey = 'canvas_api_token';

  // Hardcoded defaults from env.json — overridden by saved credentials
  static const String _defaultBaseUrl = 'https://swinburne.instructure.com';
  static const String _defaultToken =
      '10633~kMvyA3GNRc4tk2h4Y7DCBwYEDyGxF4eMwPvHXTD8huWXTeEZkCLRRW2BnHVmfGU8';

  final _storage = const FlutterSecureStorage();
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  String? _baseUrl;
  String? _token;
  bool _isConnected = false;
  DateTime? _lastSynced;

  bool get isConnected => _isConnected;
  DateTime? get lastSynced => _lastSynced;

  // ── Credential management ───────────────────────────────────────────────────

  /// Loads saved credentials from secure storage (or falls back to defaults).
  /// Call this once at app start.
  Future<void> loadCredentials() async {
    _baseUrl = await _storage.read(key: _baseUrlKey) ?? _defaultBaseUrl;
    _token = await _storage.read(key: _tokenKey) ?? _defaultToken;

    if (_token != null && _token!.isNotEmpty) {
      _isConnected = true;
    }
  }

  /// Saves new credentials and marks as connected.
  Future<void> saveCredentials(String baseUrl, String token) async {
    final cleanUrl = baseUrl.trimRight().replaceAll(RegExp(r'/$'), '');
    await _storage.write(key: _baseUrlKey, value: cleanUrl);
    await _storage.write(key: _tokenKey, value: token);
    _baseUrl = cleanUrl;
    _token = token;
    _isConnected = true;
  }

  /// Removes saved credentials and disconnects.
  Future<void> disconnect() async {
    await _storage.delete(key: _baseUrlKey);
    await _storage.delete(key: _tokenKey);
    _baseUrl = null;
    _token = null;
    _isConnected = false;
    _lastSynced = null;
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  Options get _authOptions => Options(
        headers: {'Authorization': 'Bearer $_token'},
      );

  String get _apiBase => '${_baseUrl ?? _defaultBaseUrl}/api/v1';

  /// Follows Canvas Link header pagination, collecting all pages.
  Future<List<dynamic>> _getPaginated(String path) async {
    final results = <dynamic>[];
    String? url = '$_apiBase$path';

    while (url != null) {
      final response = await _dio.get<dynamic>(url, options: _authOptions);
      final data = response.data;
      if (data is List) results.addAll(data);

      // Parse Link header for next page
      final linkHeader = response.headers.value('link');
      url = _parseNextLink(linkHeader);
    }
    return results;
  }

  String? _parseNextLink(String? linkHeader) {
    if (linkHeader == null) return null;
    for (final part in linkHeader.split(',')) {
      final trimmed = part.trim();
      if (trimmed.contains('rel="next"')) {
        final urlMatch = RegExp(r'<([^>]+)>').firstMatch(trimmed);
        return urlMatch?.group(1);
      }
    }
    return null;
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Fetches all active courses the user is enrolled in.
  Future<List<Map<String, dynamic>>> fetchCourses() async {
    await _ensureCredentials();
    try {
      final raw = await _getPaginated(
        '/courses?enrollment_state=active&per_page=50',
      );
      return raw.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      debugPrint('[Canvas] fetchCourses error: ${e.message}');
      _handleAuthError(e);
      return [];
    }
  }

  /// Fetches all assignments across all active courses.
  /// Returns a list of [AssignmentManagerItem] ready for the UI.
  Future<List<AssignmentManagerItem>> fetchAssignments() async {
    await _ensureCredentials();
    if (!_isConnected) return [];

    try {
      final courses = await fetchCourses();
      final allAssignments = <AssignmentManagerItem>[];

      for (final course in courses) {
        final courseId = course['id'];
        final courseName = (course['name'] as String? ?? 'Unknown Course');
        final courseCode = (course['course_code'] as String? ?? '');

        final raw = await _getPaginated(
          '/courses/$courseId/assignments'
          '?per_page=50'
          '&include[]=submission'
          '&order_by=due_at',
        );

        for (final a in raw) {
          final item = _mapAssignment(
            a as Map<String, dynamic>,
            courseName: courseName,
            courseCode: courseCode,
            courseColorKey: _colorForCourse(courseCode),
          );
          if (item != null) allAssignments.add(item);
        }
      }

      // Sort: overdue first, then due_soon, then upcoming, then submitted/graded
      allAssignments.sort((a, b) => _statusOrder(a.status)
          .compareTo(_statusOrder(b.status)));

      _lastSynced = DateTime.now();
      return allAssignments;
    } on DioException catch (e) {
      debugPrint('[Canvas] fetchAssignments error: ${e.message}');
      _handleAuthError(e);
      return [];
    } catch (e) {
      debugPrint('[Canvas] fetchAssignments unexpected: $e');
      return [];
    }
  }

  // ── Mapping ─────────────────────────────────────────────────────────────────

  AssignmentManagerItem? _mapAssignment(
    Map<String, dynamic> a, {
    required String courseName,
    required String courseCode,
    required String courseColorKey,
  }) {
    final id = a['id']?.toString() ?? '';
    final title = a['name'] as String? ?? 'Untitled';
    final pointsPossible = (a['points_possible'] as num?)?.toInt() ?? 0;
    final description = _stripHtml(a['description'] as String? ?? '');
    final submissionTypes =
        (a['submission_types'] as List<dynamic>?)?.cast<String>() ?? [];
    final submissionType = _formatSubmissionType(submissionTypes);

    // Parse due date
    final dueDateStr = a['due_at'] as String?;
    final dueDate = dueDateStr != null ? DateTime.tryParse(dueDateStr) : null;
    final dueDateFormatted = _formatDueDate(dueDate);
    final dueDateRaw = _classifyDueDate(dueDate);

    // Parse submission status
    final submission = a['submission'] as Map<String, dynamic>?;
    final submitted = submission != null &&
        (submission['submitted_at'] != null ||
            submission['workflow_state'] == 'submitted' ||
            submission['workflow_state'] == 'graded');
    final graded = submission != null &&
        submission['workflow_state'] == 'graded' &&
        submission['score'] != null;
    final pointsEarned =
        graded ? (submission?['score'] as num?)?.toInt() : null;

    final status = _resolveStatus(
      dueDate: dueDate,
      submitted: submitted,
      graded: graded,
    );

    // Skip assignments with no due date that are already graded
    if (dueDate == null && graded) return null;

    return AssignmentManagerItem(
      id: id,
      title: title,
      courseName: courseName,
      courseCode: courseCode,
      courseColor: courseColorKey,
      dueDate: dueDateFormatted,
      dueTime: '11:59 PM',
      dueDateRaw: dueDateRaw,
      status: status,
      points: pointsPossible,
      pointsEarned: pointsEarned,
      submitted: submitted,
      description: description,
      submissionType: submissionType,
      reminderSet: false,
    );
  }

  String _resolveStatus({
    required DateTime? dueDate,
    required bool submitted,
    required bool graded,
  }) {
    if (graded) return 'graded';
    if (submitted) return 'submitted';
    if (dueDate == null) return 'upcoming';
    final now = DateTime.now();
    if (dueDate.isBefore(now)) return 'overdue';
    final diff = dueDate.difference(now);
    if (diff.inHours <= 48) return 'due_soon';
    return 'upcoming';
  }

  String _formatDueDate(DateTime? date) {
    if (date == null) return 'No due date';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _classifyDueDate(DateTime? date) {
    if (date == null) return 'future';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(date.year, date.month, date.day);
    final diff = dueDay.difference(today).inDays;
    if (diff < 0) return 'past';
    if (diff == 0) return 'today';
    if (diff == 1) return 'tomorrow';
    return 'future';
  }

  String _formatSubmissionType(List<String> types) {
    if (types.isEmpty) return 'Canvas';
    final map = {
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
    return types.map((t) => map[t] ?? t).join(' / ');
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .trim();
  }

  String _colorForCourse(String courseCode) {
    final upper = courseCode.toUpperCase();
    if (upper.contains('COS') || upper.contains('TNE') ||
        upper.contains('INF') || upper.contains('SWE') ||
        upper.contains('CIS') || upper.contains('CS')) {
      return 'primary';
    }
    if (upper.contains('MAT') || upper.contains('STA') ||
        upper.contains('PHY')) {
      return 'secondary';
    }
    return 'teal';
  }

  int _statusOrder(String status) {
    switch (status) {
      case 'overdue':
        return 0;
      case 'due_soon':
        return 1;
      case 'upcoming':
        return 2;
      case 'submitted':
        return 3;
      case 'graded':
        return 4;
      default:
        return 5;
    }
  }

  Future<void> _ensureCredentials() async {
    if (_token == null) await loadCredentials();
  }

  void _handleAuthError(DioException e) {
    if (e.response?.statusCode == 401) {
      _isConnected = false;
      debugPrint('[Canvas] 401 — token invalid or expired');
    }
  }
}
