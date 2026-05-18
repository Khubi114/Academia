import '../services/supabase_service.dart';
import '../presentation/dashboard_screen/dashboard_screen.dart'; // using TaskItem from here

class TaskRepository {
  static final TaskRepository instance = TaskRepository._internal();
  TaskRepository._internal();

  final _supabase = SupabaseService.instance.client;

  Future<List<TaskItem>> getTasks() async {
    try {
      final userId = SupabaseService.instance.userId;
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((task) => TaskItem(
        id: task['id'].toString(),
        title: task['title'],
        dueDate: task['due_date'],
        priority: task['priority'],
        completed: task['completed'],
        source: task['source'] ?? 'personal',
      )).toList();
    } catch (e) {
      print('Error fetching tasks: $e');
      return [];
    }
  }

  Future<void> addTask(TaskItem task) async {
    try {
      final userId = SupabaseService.instance.userId;
      await _supabase.from('tasks').insert({
        'user_id': userId,
        'title': task.title,
        'due_date': task.dueDate,
        'priority': task.priority,
        'completed': task.completed,
        'source': task.source,
      });
    } catch (e) {
      print('Error adding task: $e');
    }
  }

  Future<void> toggleTaskCompletion(String taskId, bool completed) async {
    try {
      await _supabase
          .from('tasks')
          .update({'completed': completed})
          .eq('id', taskId);
    } catch (e) {
      print('Error toggling task: $e');
    }
  }
}
