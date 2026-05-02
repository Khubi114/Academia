// ─────────────────────────────────────────────────────────────────────────────
// CHANGES TO: lib/presentation/dashboard_screen/dashboard_screen.dart
//
// Only the calendar/class-loading section changes.
// Tasks, assignments, and chart data are unchanged here.
// ─────────────────────────────────────────────────────────────────────────────


// ── CHANGE 1: Add import ──────────────────────────────────────────────────────

import '../../services/google_calendar_service.dart';


// ── CHANGE 2: Replace _loadData to fetch real classes from Google Calendar ────
// The dashboard shows today's classes (ClassItem list) which come from
// Google Calendar events. We filter events for today and map them.
//
// OLD (inside _loadData):
//   _classes = _classesMaps.map(ClassItem.fromMap).toList();
//
// NEW — replace the entire _loadData method:

  Future<void> _loadData() async {
    // Fetch today's calendar events from Google Calendar (via Vercel).
    // Falls back to an empty list if not connected — UI shows "No classes today".
    final today = DateTime.now();
    final calendarEvents = await GoogleCalendarService.instance.fetchEvents(
      start: today,
      end: today,
    );

    if (!mounted) return;
    setState(() {
      // Map Google Calendar events that look like classes to ClassItem.
      // A "class" event is one that has a defined end time (not all-day)
      // and is not a Canvas due-date event (end time != 23:59).
      _classes = calendarEvents
          .where((e) => !e.isAllDay && e.endTime != '23:59')
          .map((e) => ClassItem(
                id: e.id,
                courseName: e.title,
                courseCode: e.courseCode.isNotEmpty ? e.courseCode : _inferCourseCode(e.title),
                startTime: e.startTime,
                endTime: e.endTime,
                location: e.location,
                color: _colorForCourseCode(e.courseCode),
                instructor: '', // Google Calendar events don't carry instructor info
              ))
          .toList();

      // Keep using hardcoded demo data for assignments, tasks, and chart
      // until Canvas and Supabase integrations are added.
      _assignments = _assignmentsMaps.map(AssignmentItem.fromMap).toList();
      _tasks = _tasksMaps.map(TaskItem.fromMap).toList();
      _chartData = _chartDataMaps.map(ChartDataItem.fromMap).toList();

      _isLoading = false;
    });

    _entranceController.forward();
  }


// ── CHANGE 3: Add two small helper methods inside _DashboardScreenState ───────
// Add these anywhere inside the state class (e.g. after _classesRemainingToday):

  /// Tries to extract a course code (e.g. "CS 301") from an event title.
  /// Returns an empty string if none found.
  String _inferCourseCode(String title) {
    final match = RegExp(r'^([A-Z]{2,4}\s?\d{3})').firstMatch(title);
    return match?.group(0)?.trim() ?? '';
  }

  /// Returns a theme color key based on a course code prefix.
  /// You can expand this mapping to match your actual courses.
  String _colorForCourseCode(String courseCode) {
    if (courseCode.startsWith('CS') || courseCode.startsWith('CIS')) return 'primary';
    if (courseCode.startsWith('MATH') || courseCode.startsWith('MAT')) return 'secondary';
    return 'teal'; // default for all other departments
  }


// ── CHANGE 4: Remove the now-unused _classesMaps list ────────────────────────
// Delete the entire `final List<Map<String, dynamic>> _classesMaps = [ ... ];`
// block from _DashboardScreenState. It is no longer needed.


// ── NO OTHER CHANGES NEEDED ───────────────────────────────────────────────────
// All widgets, _onRefresh, _onTaskToggle, _showQuickAdd, build methods,
// and the data models at the bottom of the file stay exactly as-is.
