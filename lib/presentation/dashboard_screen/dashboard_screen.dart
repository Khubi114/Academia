import '../../core/app_export.dart';
import '../../services/google_calendar_service.dart';
import '../../services/canvas_service.dart';
import '../calendar_view_screen/calendar_view_screen.dart';
import '../assignment_manager_screen/assignment_manager_screen.dart';
import './widgets/dashboard_assignments_widget.dart';
import './widgets/dashboard_chart_widget.dart';
import './widgets/dashboard_classes_widget.dart';
import './widgets/dashboard_header_widget.dart';
import './widgets/dashboard_metrics_widget.dart';
import './widgets/dashboard_tasks_widget.dart';
import './widgets/quick_add_sheet_widget.dart';

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

  // Hardcoded tasks (local only — no backend needed for personal tasks)
  final List<Map<String, dynamic>> _tasksMaps = [
    {
      'id': 't1',
      'title': 'Review lecture notes from yesterday',
      'dueDate': 'Today',
      'priority': 'high',
      'completed': false,
      'source': 'personal',
    },
    {
      'id': 't2',
      'title': 'Book library study room for group project',
      'dueDate': 'Today',
      'priority': 'medium',
      'completed': false,
      'source': 'personal',
    },
    {
      'id': 't3',
      'title': 'Email tutor about assignment extension',
      'dueDate': 'Tomorrow',
      'priority': 'high',
      'completed': false,
      'source': 'personal',
    },
  ];

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
    _tasks = _tasksMaps.map(TaskItem.fromMap).toList();
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
    ]);

    if (!mounted) return;
    setState(() {
      _classes = results[0] as List<ClassItem>;
      _assignments = results[1] as List<AssignmentItem>;
      _chartData = _buildChartData(_assignments);
      _lastSynced = DateTime.now();
      _isLoading = false;
    });

    _entranceController.forward();
  }

  Future<List<ClassItem>> _loadClasses() async {
    try {
      final today = DateTime.now();
      final calendarEvents = await GoogleCalendarService.instance.fetchEvents(
        start: today,
        end: today,
      );

      return calendarEvents
          .where((e) => !e.isAllDay && e.endTime != '23:59')
          .map((e) => ClassItem(
                id: e.id,
                courseName: e.title,
                courseCode: e.courseCode.isNotEmpty
                    ? e.courseCode
                    : _inferCourseCode(e.title),
                startTime: e.startTime,
                endTime: e.endTime,
                location: e.location,
                color: _colorForCourseCode(e.courseCode),
                instructor: '',
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AssignmentItem>> _loadAssignments() async {
    try {
      final canvasItems = await CanvasService.instance.fetchAssignments();

      // Convert AssignmentManagerItem → AssignmentItem (dashboard view)
      return canvasItems.take(8).map((a) {
        return AssignmentItem(
          id: a.id,
          title: a.title,
          courseName: a.courseName,
          courseCode: a.courseCode,
          courseColor: a.courseColor,
          dueDate: a.dueDate,
          status: a.status,
          points: a.points,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isLoading = true);
    await _loadData();
  }

  // ── Metric helpers ─────────────────────────────────────────────────────────

  String get _syncSubtitle {
    if (!CanvasService.instance.isConnected) return 'Canvas LMS · Not connected';
    if (_lastSynced == null) return 'Canvas LMS · Syncing…';
    final diff = DateTime.now().difference(_lastSynced!);
    if (diff.inMinutes < 1) return 'Canvas LMS · Just synced';
    if (diff.inMinutes < 60) return 'Canvas LMS · Synced ${diff.inMinutes}m ago';
    return 'Canvas LMS · Synced ${diff.inHours}h ago';
  }

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

  String _inferCourseCode(String title) {
    final match = RegExp(r'^([A-Z]{2,4}\s?\d{3})').firstMatch(title);
    return match?.group(0)?.trim() ?? '';
  }

  String _colorForCourseCode(String courseCode) {
    final upper = courseCode.toUpperCase();
    if (upper.startsWith('COS') ||
        upper.startsWith('TNE') ||
        upper.startsWith('SWE') ||
        upper.startsWith('CS') ||
        upper.startsWith('INF')) return 'primary';
    if (upper.startsWith('MAT') ||
        upper.startsWith('STA') ||
        upper.startsWith('PHY')) return 'secondary';
    return 'teal';
  }

  void _onTaskToggle(String id) {
    setState(() {
      final idx = _tasks.indexWhere((t) => t.id == id);
      if (idx != -1) {
        _tasks[idx] = _tasks[idx].copyWith(completed: !_tasks[idx].completed);
      }
    });
  }

  void _showQuickAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickAddSheetWidget(
        onTaskAdded: (task) => setState(() => _tasks.insert(0, task)),
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
