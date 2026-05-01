
import '../../core/app_export.dart';
import './widgets/dashboard_assignments_widget.dart';
import './widgets/dashboard_chart_widget.dart';
import './widgets/dashboard_classes_widget.dart';
import './widgets/dashboard_header_widget.dart';
import './widgets/dashboard_metrics_widget.dart';
import './widgets/dashboard_tasks_widget.dart';
import './widgets/quick_add_sheet_widget.dart';

// TODO: Replace with Riverpod/Bloc for production state management
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // TODO: Replace with real sync service
  DateTime _lastSynced = DateTime.now().subtract(const Duration(minutes: 8));

  final List<Map<String, dynamic>> _classesMaps = [
    {
      'id': 'cls1',
      'courseName': 'Algorithms & Data Structures',
      'courseCode': 'CS 301',
      'startTime': '09:00',
      'endTime': '10:15',
      'location': 'Tech Hall 204',
      'color': 'primary',
      'instructor': 'Dr. Priya Nair',
    },
    {
      'id': 'cls2',
      'courseName': 'Linear Algebra',
      'courseCode': 'MATH 251',
      'startTime': '11:30',
      'endTime': '12:20',
      'location': 'Whitmore 110',
      'color': 'secondary',
      'instructor': 'Prof. Kwame Asante',
    },
    {
      'id': 'cls3',
      'courseName': 'Technical Writing',
      'courseCode': 'ENG 340',
      'startTime': '14:00',
      'endTime': '15:15',
      'location': 'Humanities 302',
      'color': 'teal',
      'instructor': 'Dr. Sofia Reyes',
    },
  ];

  final List<Map<String, dynamic>> _assignmentsMaps = [
    {
      'id': 'asgn1',
      'title': 'Binary Search Tree Implementation',
      'courseName': 'CS 301',
      'courseColor': 'primary',
      'dueDate': 'Today, 11:59 PM',
      'dueDateRaw': 'today',
      'status': 'due_soon',
      'points': 100,
      'submitted': false,
    },
    {
      'id': 'asgn2',
      'title': 'Problem Set 7 — Eigenvalues',
      'courseName': 'MATH 251',
      'courseColor': 'secondary',
      'dueDate': 'Tomorrow, 11:59 PM',
      'dueDateRaw': 'tomorrow',
      'status': 'upcoming',
      'points': 50,
      'submitted': false,
    },
    {
      'id': 'asgn3',
      'title': 'Research Paper Draft',
      'courseName': 'ENG 340',
      'courseColor': 'teal',
      'dueDate': 'May 3, 11:59 PM',
      'dueDateRaw': 'future',
      'status': 'upcoming',
      'points': 150,
      'submitted': false,
    },
    {
      'id': 'asgn4',
      'title': 'Graph Traversal Lab',
      'courseName': 'CS 301',
      'courseColor': 'primary',
      'dueDate': 'Apr 29, 11:59 PM',
      'dueDateRaw': 'past',
      'status': 'overdue',
      'points': 75,
      'submitted': false,
    },
  ];

  final List<Map<String, dynamic>> _tasksMaps = [
    {
      'id': 'task1',
      'title': 'Review lecture notes for midterm',
      'priority': 'high',
      'dueDate': 'Today',
      'completed': false,
      'source': 'personal',
    },
    {
      'id': 'task2',
      'title': 'Office hours — ask about Problem 4',
      'priority': 'medium',
      'dueDate': 'Today 2:00 PM',
      'completed': false,
      'source': 'personal',
    },
    {
      'id': 'task3',
      'title': 'Buy textbook for PHYS 202',
      'priority': 'low',
      'dueDate': 'This week',
      'completed': true,
      'source': 'personal',
    },
  ];

  final List<Map<String, dynamic>> _chartDataMaps = [
    {'day': 'Mon', 'completed': 3, 'total': 3},
    {'day': 'Tue', 'completed': 2, 'total': 4},
    {'day': 'Wed', 'completed': 4, 'total': 4},
    {'day': 'Thu', 'completed': 1, 'total': 3},
    {'day': 'Fri', 'completed': 3, 'total': 5},
    {'day': 'Sat', 'completed': 2, 'total': 2},
    {'day': 'Sun', 'completed': 0, 'total': 1},
  ];

  List<ClassItem> _classes = [];
  List<AssignmentItem> _assignments = [];
  List<TaskItem> _tasks = [];
  List<ChartDataItem> _chartData = [];

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );

    _loadData();
  }

  Future<void> _loadData() async {
    // TODO: Replace with real Canvas + Google Calendar API calls
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _classes = _classesMaps.map(ClassItem.fromMap).toList();
      _assignments = _assignmentsMaps.map(AssignmentItem.fromMap).toList();
      _tasks = _tasksMaps.map(TaskItem.fromMap).toList();
      _chartData = _chartDataMaps.map(ChartDataItem.fromMap).toList();
      _isLoading = false;
    });
    _entranceController.forward();
  }

  Future<void> _onRefresh() async {
    // TODO: Replace with real sync trigger
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _lastSynced = DateTime.now();
    });
  }

  void _onTaskToggle(String taskId) {
    // TODO: Replace with real local task repository
    setState(() {
      final idx = _tasks.indexWhere((t) => t.id == taskId);
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
        onTaskAdded: (task) {
          setState(() {
            _tasks.insert(0, task);
          });
        },
      ),
    );
  }

  int get _dueTodayCount =>
      _assignments.where((a) => a.dueDateRaw == 'today' && !a.submitted).length;
  int get _overdueCount =>
      _assignments.where((a) => a.status == 'overdue').length;

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return AppScaffold(
      currentIndex: 0,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showQuickAdd,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Quick Add',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const DashboardSkeletonWidget()
            : SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: theme.colorScheme.primary,
                    displacement: 20,
                    child: isTablet
                        ? _buildTabletLayout(theme)
                        : _buildPhoneLayout(theme),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildPhoneLayout(ThemeData theme) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: DashboardHeaderWidget(lastSynced: _lastSynced),
        ),
        SliverToBoxAdapter(
          child: DashboardMetricsWidget(
            dueTodayCount: _dueTodayCount,
            overdueCount: _overdueCount,
            completionRate: _calculateWeeklyRate(),
            classesRemaining: _classesRemainingToday(),
          ),
        ),
        SliverToBoxAdapter(child: DashboardClassesWidget(classes: _classes)),
        SliverToBoxAdapter(
          child: DashboardAssignmentsWidget(assignments: _assignments),
        ),
        SliverToBoxAdapter(
          child: DashboardTasksWidget(tasks: _tasks, onToggle: _onTaskToggle),
        ),
        SliverToBoxAdapter(child: DashboardChartWidget(chartData: _chartData)),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildTabletLayout(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: DashboardHeaderWidget(lastSynced: _lastSynced),
              ),
              SliverToBoxAdapter(
                child: DashboardMetricsWidget(
                  dueTodayCount: _dueTodayCount,
                  overdueCount: _overdueCount,
                  completionRate: _calculateWeeklyRate(),
                  classesRemaining: _classesRemainingToday(),
                ),
              ),
              SliverToBoxAdapter(
                child: DashboardClassesWidget(classes: _classes),
              ),
              SliverToBoxAdapter(
                child: DashboardChartWidget(chartData: _chartData),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
        VerticalDivider(
          width: 1,
          color: theme.colorScheme.outline.withAlpha(77),
        ),
        Expanded(
          flex: 4,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: DashboardAssignmentsWidget(assignments: _assignments),
              ),
              SliverToBoxAdapter(
                child: DashboardTasksWidget(
                  tasks: _tasks,
                  onToggle: _onTaskToggle,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ],
    );
  }

  double _calculateWeeklyRate() {
    int total = _chartData.fold(0, (s, d) => s + d.total);
    int completed = _chartData.fold(0, (s, d) => s + d.completed);
    if (total == 0) return 0;
    return (completed / total * 100).roundToDouble();
  }

  int _classesRemainingToday() {
    final now = TimeOfDay.now();
    return _classes.where((c) {
      final parts = c.endTime.split(':');
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      return hour > now.hour || (hour == now.hour && minute > now.minute);
    }).length;
  }
}

// Data models
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

  factory ClassItem.fromMap(Map<String, dynamic> m) => ClassItem(
    id: m['id'] as String,
    courseName: m['courseName'] as String,
    courseCode: m['courseCode'] as String,
    startTime: m['startTime'] as String,
    endTime: m['endTime'] as String,
    location: m['location'] as String,
    color: m['color'] as String,
    instructor: m['instructor'] as String,
  );
}

class AssignmentItem {
  final String id;
  final String title;
  final String courseName;
  final String courseColor;
  final String dueDate;
  final String dueDateRaw;
  final String status;
  final int points;
  final bool submitted;

  const AssignmentItem({
    required this.id,
    required this.title,
    required this.courseName,
    required this.courseColor,
    required this.dueDate,
    required this.dueDateRaw,
    required this.status,
    required this.points,
    required this.submitted,
  });

  factory AssignmentItem.fromMap(Map<String, dynamic> m) => AssignmentItem(
    id: m['id'] as String,
    title: m['title'] as String,
    courseName: m['courseName'] as String,
    courseColor: m['courseColor'] as String,
    dueDate: m['dueDate'] as String,
    dueDateRaw: m['dueDateRaw'] as String,
    status: m['status'] as String,
    points: m['points'] as int,
    submitted: m['submitted'] as bool,
  );

  AssignmentItem copyWith({bool? submitted}) => AssignmentItem(
    id: id,
    title: title,
    courseName: courseName,
    courseColor: courseColor,
    dueDate: dueDate,
    dueDateRaw: dueDateRaw,
    status: submitted == true ? 'submitted' : status,
    points: points,
    submitted: submitted ?? this.submitted,
  );
}

class TaskItem {
  final String id;
  final String title;
  final String priority;
  final String dueDate;
  final bool completed;
  final String source;

  const TaskItem({
    required this.id,
    required this.title,
    required this.priority,
    required this.dueDate,
    required this.completed,
    required this.source,
  });

  factory TaskItem.fromMap(Map<String, dynamic> m) => TaskItem(
    id: m['id'] as String,
    title: m['title'] as String,
    priority: m['priority'] as String,
    dueDate: m['dueDate'] as String,
    completed: m['completed'] as bool,
    source: m['source'] as String,
  );

  TaskItem copyWith({bool? completed}) => TaskItem(
    id: id,
    title: title,
    priority: priority,
    dueDate: dueDate,
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

  factory ChartDataItem.fromMap(Map<String, dynamic> m) => ChartDataItem(
    day: m['day'] as String,
    completed: m['completed'] as int,
    total: m['total'] as int,
  );
}
