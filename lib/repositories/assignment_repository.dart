import '../services/supabase_service.dart';
import '../presentation/dashboard_screen/dashboard_screen.dart';

class AssignmentRepository {
  static final AssignmentRepository instance = AssignmentRepository._internal();
  AssignmentRepository._internal();

  final _supabase = SupabaseService.instance.client;

  Future<List<AssignmentItem>> getAssignments() async {
    try {
      final userId = SupabaseService.instance.userId;
      final response = await _supabase
          .from('assignments')
          .select()
          .eq('user_id', userId)
          .order('due_date', ascending: true);

      return (response as List).map((a) => AssignmentItem(
        id: a['id'].toString(),
        title: a['title'],
        courseName: a['course_name'],
        courseCode: a['course_code'],
        courseColor: a['course_color'],
        dueDate: a['due_date'],
        status: a['status'],
        points: a['points'] ?? 0,
      )).toList();
    } catch (e) {
      print('Error fetching assignments: $e');
      return [];
    }
  }

  Future<void> syncAssignments() async {
    // This would call our Vercel API endpoint `/api/canvas/sync`
    // In a real implementation we'd use `http` package to post to it
    // Example:
    // await http.post(Uri.parse('https://academia-api.vercel.app/api/canvas/sync'), body: {'userId': SupabaseService.instance.userId});
  }
}
