import '../services/supabase_service.dart';
import '../presentation/dashboard_screen/dashboard_screen.dart';

class CalendarRepository {
  static final CalendarRepository instance = CalendarRepository._internal();
  CalendarRepository._internal();

  final _supabase = SupabaseService.instance.client;

  Future<List<ClassItem>> getClasses() async {
    try {
      final userId = SupabaseService.instance.userId;
      final response = await _supabase
          .from('classes')
          .select()
          .eq('user_id', userId)
          .order('start_time', ascending: true);

      return (response as List).map((c) => ClassItem(
        id: c['id'].toString(),
        courseName: c['course_name'],
        courseCode: c['course_code'],
        startTime: c['start_time'],
        endTime: c['end_time'],
        location: c['location'],
        color: c['color'],
        instructor: c['instructor'],
      )).toList();
    } catch (e) {
      print('Error fetching classes: $e');
      return [];
    }
  }

  Future<void> syncCalendar() async {
    // This would call our Vercel API endpoint `/api/calendar/sync`
  }
}
