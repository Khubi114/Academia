
import '../../core/app_export.dart';
import '../../services/canvas_service.dart';
import './widgets/assignment_detail_sheet_widget.dart';
import './widgets/assignment_filter_bar_widget.dart';
import './widgets/assignment_list_item_widget.dart';

// TODO: Replace with Riverpod/Bloc for production state management
class AssignmentManagerScreen extends StatefulWidget {
  const AssignmentManagerScreen({super.key});

  @override
  State<AssignmentManagerScreen> createState() =>
      _AssignmentManagerScreenState();
}

class _AssignmentManagerScreenState extends State<AssignmentManagerScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isSyncing = false;
  String _activeFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _listController;
  bool _showSearch = false;
  DateTime? _lastSynced;

  // No hardcoded data — assignments come from Canvas LMS

  List<AssignmentManagerItem> _assignments = [];

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    await CanvasService.instance.loadCredentials();
    final items = await CanvasService.instance.fetchAssignments();
    if (!mounted) return;
    setState(() {
      _assignments = items;
      _lastSynced = CanvasService.instance.lastSynced;
      _isLoading = false;
    });
    _listController.forward();
  }

  Future<void> _onRefresh() async {
    setState(() => _isSyncing = true);
    final items = await CanvasService.instance.fetchAssignments();
    if (!mounted) return;
    setState(() {
      _assignments = items;
      _lastSynced = CanvasService.instance.lastSynced;
      _isSyncing = false;
    });
  }

  List<AssignmentManagerItem> get _filteredAssignments {
    List<AssignmentManagerItem> result = _assignments;

    if (_activeFilter != 'all') {
      result = result.where((a) {
        switch (_activeFilter) {
          case 'due_soon':
            return a.status == 'due_soon' || a.dueDateRaw == 'tomorrow';
          case 'overdue':
            return a.status == 'overdue';
          case 'completed':
            return a.submitted;
          default:
            return true;
        }
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where(
            (a) =>
                a.title.toLowerCase().contains(q) ||
                a.courseName.toLowerCase().contains(q) ||
                a.courseCode.toLowerCase().contains(q),
          )
          .toList();
    }

    return result;
  }

  void _openDetail(AssignmentManagerItem assignment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssignmentDetailSheetWidget(assignment: assignment),
    );
  }

  void _toggleReminder(String id) {
    // TODO: Replace with real notification service
    setState(() {
      final idx = _assignments.indexWhere((a) => a.id == id);
      if (idx != -1) {
        _assignments[idx] = _assignments[idx].copyWith(
          reminderSet: !_assignments[idx].reminderSet,
        );
      }
    });
  }

  void _markSubmitted(String id) {
    // TODO: Replace with Canvas submission API
    setState(() {
      final idx = _assignments.indexWhere((a) => a.id == id);
      if (idx != -1) {
        _assignments[idx] = _assignments[idx].copyWith(
          submitted: true,
          status: 'submitted',
        );
      }
    });
  }

  @override
  void dispose() {
    _listController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _syncSubtitle {
    if (!CanvasService.instance.isConnected) return 'Canvas LMS · Not connected';
    if (_lastSynced == null) return 'Canvas LMS · Syncing…';
    final diff = DateTime.now().difference(_lastSynced!);
    if (diff.inMinutes < 1) return 'Canvas LMS · Just synced';
    if (diff.inMinutes < 60) return 'Canvas LMS · Synced ${diff.inMinutes}m ago';
    return 'Canvas LMS · Synced ${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return AppScaffold(
      currentIndex: 1,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(theme),
            if (_showSearch) _buildSearchBar(theme),
            AssignmentFilterBarWidget(
              activeFilter: _activeFilter,
              onFilterChanged: (f) => setState(() => _activeFilter = f),
              counts: _getFilterCounts(),
            ),
            Expanded(
              child: _isLoading
                  ? const ListSkeletonWidget(itemCount: 7)
                  : _buildBody(theme, isTablet),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assignments',
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  _syncSubtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: CanvasService.instance.isConnected
                        ? theme.colorScheme.onSurfaceVariant
                        : AppTheme.canvasAmber,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchQuery = '';
                _searchController.clear();
              }
            }),
            icon: Icon(
              _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            onPressed: _isSyncing ? null : _onRefresh,
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.sync_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w400),
        decoration: InputDecoration(
          hintText: 'Search assignments, courses…',
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  }),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, bool isTablet) {
    final filtered = _filteredAssignments;
    if (filtered.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.assignment_outlined,
        title: 'No assignments found',
        description: _searchQuery.isNotEmpty
            ? 'No assignments match "$_searchQuery". Try a different search.'
            : 'No assignments in this category right now.',
        actionLabel: _searchQuery.isNotEmpty ? null : 'Refresh Canvas',
        onAction: _searchQuery.isNotEmpty ? null : _onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: theme.colorScheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final assignment = filtered[index];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 200 + (index * 40).clamp(0, 320)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 16),
                child: child,
              ),
            ),
            child: AssignmentListItemWidget(
              assignment: assignment,
              onTap: () => _openDetail(assignment),
              onReminderToggle: () => _toggleReminder(assignment.id),
              onMarkSubmitted: () => _markSubmitted(assignment.id),
            ),
          );
        },
      ),
    );
  }

  Map<String, int> _getFilterCounts() {
    return {
      'all': _assignments.length,
      'due_soon': _assignments
          .where((a) => a.status == 'due_soon' || a.dueDateRaw == 'tomorrow')
          .length,
      'overdue': _assignments.where((a) => a.status == 'overdue').length,
      'completed': _assignments.where((a) => a.submitted).length,
    };
  }
}

// Data model
class AssignmentManagerItem {
  final String id;
  final String title;
  final String courseName;
  final String courseCode;
  final String courseColor;
  final String dueDate;
  final String dueTime;
  final String dueDateRaw;
  final String status;
  final int points;
  final int? pointsEarned;
  final bool submitted;
  final String description;
  final String submissionType;
  final bool reminderSet;

  const AssignmentManagerItem({
    required this.id,
    required this.title,
    required this.courseName,
    required this.courseCode,
    required this.courseColor,
    required this.dueDate,
    required this.dueTime,
    required this.dueDateRaw,
    required this.status,
    required this.points,
    this.pointsEarned,
    required this.submitted,
    required this.description,
    required this.submissionType,
    required this.reminderSet,
  });

  factory AssignmentManagerItem.fromMap(Map<String, dynamic> m) =>
      AssignmentManagerItem(
        id: m['id'] as String,
        title: m['title'] as String,
        courseName: m['courseName'] as String,
        courseCode: m['courseCode'] as String,
        courseColor: m['courseColor'] as String,
        dueDate: m['dueDate'] as String,
        dueTime: m['dueTime'] as String,
        dueDateRaw: m['dueDateRaw'] as String,
        status: m['status'] as String,
        points: m['points'] as int,
        pointsEarned: m['pointsEarned'] as int?,
        submitted: m['submitted'] as bool,
        description: m['description'] as String,
        submissionType: m['submissionType'] as String,
        reminderSet: m['reminderSet'] as bool,
      );

  AssignmentManagerItem copyWith({
    bool? submitted,
    String? status,
    bool? reminderSet,
  }) => AssignmentManagerItem(
    id: id,
    title: title,
    courseName: courseName,
    courseCode: courseCode,
    courseColor: courseColor,
    dueDate: dueDate,
    dueTime: dueTime,
    dueDateRaw: dueDateRaw,
    status: status ?? this.status,
    points: points,
    pointsEarned: pointsEarned,
    submitted: submitted ?? this.submitted,
    description: description,
    submissionType: submissionType,
    reminderSet: reminderSet ?? this.reminderSet,
  );
}
