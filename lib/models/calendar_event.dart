// lib/models/calendar_event.dart
//
// A single entry on the calendar, regardless of where it came from
// (Google Calendar, Canvas due date, or created inside the app).

class CalendarEvent {
  final String id;
  final String title;
  final String source; // 'google_calendar' | 'canvas' | 'personal'
  final DateTime date;
  final String startTime; // 'HH:mm'
  final String endTime;
  final String location;
  final String courseCode;
  final String description;
  final bool isAllDay;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.source,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.courseCode,
    required this.description,
    required this.isAllDay,
  });

  /// Builds an event from a row of `calendar_events_cache` as returned by
  /// `/api/calendar/events` and `/api/calendar/create`.
  factory CalendarEvent.fromRow(Map<String, dynamic> row) {
    final parts = (row['event_date'] as String).split('-');
    return CalendarEvent(
      id: row['id'] as String,
      title: row['title'] as String,
      source: row['source'] as String? ?? 'google_calendar',
      date: DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ),
      startTime: row['start_time'] as String,
      endTime: row['end_time'] as String,
      location: row['location'] as String? ?? '',
      courseCode: row['course_code'] as String? ?? '',
      description: row['description'] as String? ?? '',
      isAllDay: row['is_all_day'] as bool? ?? false,
    );
  }
}
