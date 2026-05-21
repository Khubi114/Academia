import '../../core/app_export.dart';
import '../../services/google_calendar_service.dart';
import '../../services/canvas_service.dart';
import './widgets/dashboard_assignments_widget.dart';
import './widgets/dashboard_chart_widget.dart';
import './widgets/dashboard_classes_widget.dart';
import './widgets/dashboard_header_widget.dart';
import './widgets/dashboard_metrics_widget.dart';
import './widgets/dashboard_tasks_widget.dart';
import './widgets/quick_add_sheet_widget.dart';
import '../../repositories/task_repository.dart';
import '../../repositories/assignment_repository.dart';
import '../../repositories/calendar_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _entranceController;
  late Animation<double> _fadeAnim;

  List<ClassItem> _classes = [];
  List<AssignmentItem> _assignments = [];
  List<TaskItem> _tasks = [];
  List<ChartDataItem> _chartData = [];
  DateTime _lastSynced = DateTime.now();

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    // Load Canvas credentials into memory (reads from secure storage)
    await CanvasService.instance.loadCredentials();

    // Restore Google Calendar connection state
    await GoogleCalendarService.instance.checkExistingConnection();

    // Run both fetches concurrently
    final results = await Future.wait([
      _loadClasses(),
      _loadAssignments(),
      _loadTasks(),
    ]);

    if (!mounted) return;
    setState(() {
      _classes = results[0] as List<ClassItem>;
      _assignments = results[1] as List<AssignmentItem>;
      _tasks = results[2] as List<TaskItem>;
      _chartData = _buildChartData(_assignments);
      _lastSynced = DateTime.now();
      _isLoading = false;
    });

    _entranceController.forward();
  }

  Future<List<ClassItem>> _loadClasses() async {
    return await CalendarRepository.instance.getClasses();
  }

  Future<List<AssignmentItem>> _loadAssignments() async {
    return await AssignmentRepository.instance.getAssignments();
  }

  Future<List<TaskItem>> _loadTasks() async {
    return await TaskRepository.instance.getTasks();
  }

  Future<void> _onRefresh() async {
    setState(() => _isLoading = true);
    await _loadData();
  }

  // ── Metric helpers ─────────────────────────────────────────────────────────

  int get _dueTodayCount {
    final today = DateTime.now();
    return _assignments
        .where((a) =>
            a.status == 'due_soon' &&
            (a.dueDate.toLowerCase().contains('today') ||
                a.dueDate.toLowerCase().contains(
                    '${today.day}')))
        .length;
  }

  int get _overdueCount =>
      _assignments.where((a) => a.status == 'overdue').length;

  double get _completionRate {
    final submitted =
        _assignments.where((a) => a.status == 'submitted' || a.status == 'graded')
            .length;
    if (_assignments.isEmpty) return 0;
    return (submitted / _assignments.length) * 100;
  }

  int _classesRemainingToday() {
    final now = DateTime.now();
    final nowStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return _classes.where((c) => c.endTime.compareTo(nowStr) > 0).length;
  }

  List<ChartDataItem> _buildChartData(List<AssignmentItem> assignments) {
    final now = DateTime.now();
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final dayLabel = dayLabels[day.weekday - 1];
      // Approximate completion data from assignment statuses
      final total = (assignments.length / 7).ceil().clamp(1, 6);
      final completed = i < 5 ? (total * 0.6 + i * 0.1).round().clamp(0, total) : 0;
      return ChartDataItem(day: dayLabel, completed: completed, total: total);
    });
  }

  void _onTaskToggle(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final newStatus = !_tasks[idx].completed;
      setState(() {
        _tasks[idx] = _tasks[idx].copyWith(completed: newStatus);
      });
      await TaskRepository.instance.toggleTaskCompletion(id, newStatus);
    }
  }

  void _showQuickAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickAddSheetWidget(
        onTaskAdded: (task) async {
          setState(() => _tasks.insert(0, task));
          await TaskRepository.instance.addTask(task);
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 0,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : RefreshIndicator(
                onRefresh: _onRefresh,
                color: AppTheme.primary,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      DashboardHeaderWidget(lastSynced: _lastSynced),
                      DashboardMetricsWidget(
                        dueTodayCount: _dueTodayCount,
                        overdueCount: _overdueCount,
                        completionRate: _completionRate,
                        classesRemaining: _classesRemainingToday(),
                      ),
                      DashboardClassesWidget(classes: _classes),
                      DashboardAssignmentsWidget(assignments: _assignments),
                      DashboardTasksWidget(
                        tasks: _tasks,
                        onToggle: _onTaskToggle,
                      ),
                      DashboardChartWidget(chartData: _chartData),
                    ],
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickAdd,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 26),
      ),
    );
  }
}

// ── Data models ────────────────────────────────────────────────────────────────

class ClassItem {
  final String id;
  final String courseName;
  final String courseCode;
  final String startTime;
  final String endTime;
  final String location;
  final String color;
  final String instructor;

  const ClassItem({
    required this.id,
    required this.courseName,
    required this.courseCode,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.color,
    required this.instructor,
  });
}

class AssignmentItem {
  final String id;
  final String title;
  final String courseName;
  final String courseCode;
  final String courseColor;
  final String dueDate;
  final String status;
  final int points;

  const AssignmentItem({
    required this.id,
    required this.title,
    required this.courseName,
    required this.courseCode,
    required this.courseColor,
    required this.dueDate,
    required this.status,
    required this.points,
  });
}

class TaskItem {
  final String id;
  final String title;
  final String dueDate;
  final String priority;
  final bool completed;
  final String source;

  const TaskItem({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.priority,
    required this.completed,
    this.source = 'personal',
  });

  factory TaskItem.fromMap(Map<String, dynamic> m) => TaskItem(
        id: m['id'] as String,
        title: m['title'] as String,
        dueDate: m['dueDate'] as String,
        priority: m['priority'] as String,
        completed: m['completed'] as bool,
        source: m['source'] as String? ?? 'personal',
      );

  TaskItem copyWith({bool? completed}) => TaskItem(
        id: id,
        title: title,
        dueDate: dueDate,
        priority: priority,
        completed: completed ?? this.completed,
        source: source,
      );
}

class ChartDataItem {
  final String day;
  final int completed;
  final int total;

  const ChartDataItem({
    required this.day,
    required this.completed,
    required this.total,
  });
}
