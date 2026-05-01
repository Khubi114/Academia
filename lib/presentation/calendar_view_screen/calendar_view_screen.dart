
import '../../core/app_export.dart';
import './widgets/add_event_sheet_widget.dart';
import './widgets/calendar_day_events_widget.dart';
import './widgets/calendar_legend_widget.dart';
import './widgets/calendar_month_widget.dart';

// TODO: Replace with Riverpod/Bloc for production state management
class CalendarViewScreen extends StatefulWidget {
  const CalendarViewScreen({super.key});

  @override
  State<CalendarViewScreen> createState() => _CalendarViewScreenState();
}

class _CalendarViewScreenState extends State<CalendarViewScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _focusedMonth;
  late DateTime _selectedDay;
  late AnimationController _entranceController;
  late Animation<double> _fadeAnim;

  final List<Map<String, dynamic>> _eventsMaps = [
    // Google Calendar events
    {
      'id': 'ev1',
      'title': 'CS 301 — Algorithms Lecture',
      'source': 'google_calendar',
      'date': '2026-05-01',
      'startTime': '09:00',
      'endTime': '10:15',
      'location': 'Tech Hall 204',
      'courseCode': 'CS 301',
      'description': 'Topic: Advanced tree algorithms and red-black trees.',
      'isAllDay': false,
    },
    {
      'id': 'ev2',
      'title': 'MATH 251 — Linear Algebra',
      'source': 'google_calendar',
      'date': '2026-05-01',
      'startTime': '11:30',
      'endTime': '12:20',
      'location': 'Whitmore 110',
      'courseCode': 'MATH 251',
      'description': 'Topic: Eigenvalue decomposition and applications.',
      'isAllDay': false,
    },
    {
      'id': 'ev3',
      'title': 'ENG 340 — Technical Writing',
      'source': 'google_calendar',
      'date': '2026-05-01',
      'startTime': '14:00',
      'endTime': '15:15',
      'location': 'Humanities 302',
      'courseCode': 'ENG 340',
      'description': 'Workshop: Peer review of research paper drafts.',
      'isAllDay': false,
    },
    // Canvas due dates
    {
      'id': 'ev4',
      'title': 'BST Implementation Due',
      'source': 'canvas',
      'date': '2026-05-01',
      'startTime': '23:59',
      'endTime': '23:59',
      'location': '',
      'courseCode': 'CS 301',
      'description': 'Binary Search Tree Implementation — 100 pts',
      'isAllDay': false,
    },
    {
      'id': 'ev5',
      'title': 'Problem Set 7 Due',
      'source': 'canvas',
      'date': '2026-05-02',
      'startTime': '23:59',
      'endTime': '23:59',
      'location': '',
      'courseCode': 'MATH 251',
      'description': 'Eigenvalues & Eigenvectors — 50 pts',
      'isAllDay': false,
    },
    {
      'id': 'ev6',
      'title': 'Research Paper Draft Due',
      'source': 'canvas',
      'date': '2026-05-03',
      'startTime': '23:59',
      'endTime': '23:59',
      'location': '',
      'courseCode': 'ENG 340',
      'description': 'Research Paper Draft — 150 pts',
      'isAllDay': false,
    },
    // Google Calendar — other events
    {
      'id': 'ev7',
      'title': 'CS 301 Lecture',
      'source': 'google_calendar',
      'date': '2026-05-04',
      'startTime': '09:00',
      'endTime': '10:15',
      'location': 'Tech Hall 204',
      'courseCode': 'CS 301',
      'description': 'Topic: Graph algorithms — Dijkstra\'s and A*.',
      'isAllDay': false,
    },
    {
      'id': 'ev8',
      'title': 'Study Group — Algorithms',
      'source': 'personal',
      'date': '2026-05-04',
      'startTime': '15:00',
      'endTime': '17:00',
      'location': 'Library Room 204',
      'courseCode': '',
      'description':
          'Study session for upcoming midterm with Amara, Tariq, and Ji-yeon.',
      'isAllDay': false,
    },
    {
      'id': 'ev9',
      'title': 'MATH 251 Lecture',
      'source': 'google_calendar',
      'date': '2026-05-06',
      'startTime': '11:30',
      'endTime': '12:20',
      'location': 'Whitmore 110',
      'courseCode': 'MATH 251',
      'description': 'Topic: Singular value decomposition.',
      'isAllDay': false,
    },
    {
      'id': 'ev10',
      'title': 'Office Hours — Dr. Nair',
      'source': 'personal',
      'date': '2026-05-06',
      'startTime': '13:00',
      'endTime': '14:00',
      'location': 'Tech Hall 310',
      'courseCode': 'CS 301',
      'description': 'Ask about problem 4 in dynamic programming set.',
      'isAllDay': false,
    },
    {
      'id': 'ev11',
      'title': 'Dynamic Programming Due',
      'source': 'canvas',
      'date': '2026-05-08',
      'startTime': '23:59',
      'endTime': '23:59',
      'location': '',
      'courseCode': 'CS 301',
      'description': 'Dynamic Programming Problems — 90 pts',
      'isAllDay': false,
    },
    {
      'id': 'ev12',
      'title': 'CS 301 Midterm Exam',
      'source': 'google_calendar',
      'date': '2026-05-12',
      'startTime': '09:00',
      'endTime': '11:00',
      'location': 'Tech Hall 204',
      'courseCode': 'CS 301',
      'description': 'Midterm covering chapters 1–8. Closed book.',
      'isAllDay': false,
    },
    {
      'id': 'ev13',
      'title': 'Campus Career Fair',
      'source': 'personal',
      'date': '2026-05-14',
      'startTime': '10:00',
      'endTime': '15:00',
      'location': 'Student Union Ballroom',
      'courseCode': '',
      'description':
          'Bring printed resumes. Tech companies recruiting for summer internships.',
      'isAllDay': false,
    },
    {
      'id': 'ev14',
      'title': 'ENG 340 Final Paper Due',
      'source': 'canvas',
      'date': '2026-05-15',
      'startTime': '23:59',
      'endTime': '23:59',
      'location': '',
      'courseCode': 'ENG 340',
      'description': 'Final Research Paper — 200 pts',
      'isAllDay': false,
    },
    {
      'id': 'ev15',
      'title': 'CS 301 Lecture',
      'source': 'google_calendar',
      'date': '2026-05-05',
      'startTime': '09:00',
      'endTime': '10:15',
      'location': 'Tech Hall 204',
      'courseCode': 'CS 301',
      'description': 'Topic: Heap data structures and priority queues.',
      'isAllDay': false,
    },
  ];

  List<CalendarEvent> _events = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime(2026, 5, 1);
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = now;
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _events = _eventsMaps.map(CalendarEvent.fromMap).toList();
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  List<CalendarEvent> _eventsForDay(DateTime day) {
    return _events.where((e) {
      return e.date.year == day.year &&
          e.date.month == day.month &&
          e.date.day == day.day;
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Map<DateTime, List<CalendarEvent>> get _eventsByDay {
    final map = <DateTime, List<CalendarEvent>>{};
    for (final e in _events) {
      final key = DateTime(e.date.year, e.date.month, e.date.day);
      map[key] = [...(map[key] ?? []), e];
    }
    return map;
  }

  void _onDaySelected(DateTime day) {
    setState(() => _selectedDay = day);
  }

  void _onMonthChanged(DateTime month) {
    setState(() => _focusedMonth = month);
  }

  void _showAddEvent() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEventSheetWidget(
        selectedDate: _selectedDay,
        onEventAdded: (event) {
          setState(() => _events.add(event));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final dayEvents = _eventsForDay(_selectedDay);

    return AppScaffold(
      currentIndex: 2,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEvent,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: isTablet
              ? _buildTabletLayout(theme, dayEvents)
              : _buildPhoneLayout(theme, dayEvents),
        ),
      ),
    );
  }

  Widget _buildPhoneLayout(ThemeData theme, List<CalendarEvent> dayEvents) {
    return Column(
      children: [
        _buildHeader(theme),
        Expanded(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: CalendarMonthWidget(
                  focusedMonth: _focusedMonth,
                  selectedDay: _selectedDay,
                  eventsByDay: _eventsByDay,
                  onDaySelected: _onDaySelected,
                  onMonthChanged: _onMonthChanged,
                ),
              ),
              SliverToBoxAdapter(child: CalendarLegendWidget()),
              SliverToBoxAdapter(
                child: _buildDayHeader(theme, dayEvents.length),
              ),
              dayEvents.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: EmptyStateWidget(
                          icon: Icons.event_available_outlined,
                          title: 'Nothing scheduled',
                          description:
                              'No classes, assignments, or events on this day.',
                          actionLabel: 'Add Event',
                          onAction: _showAddEvent,
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(
                                milliseconds: 180 + (index * 40).clamp(0, 280),
                              ),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, child) => Opacity(
                                opacity: v,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - v) * 12),
                                  child: child,
                                ),
                              ),
                              child: CalendarDayEventsWidget(
                                event: dayEvents[index],
                              ),
                            ),
                          ),
                          childCount: dayEvents.length,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(ThemeData theme, List<CalendarEvent> dayEvents) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _buildHeader(theme),
              CalendarMonthWidget(
                focusedMonth: _focusedMonth,
                selectedDay: _selectedDay,
                eventsByDay: _eventsByDay,
                onDaySelected: _onDaySelected,
                onMonthChanged: _onMonthChanged,
              ),
              CalendarLegendWidget(),
            ],
          ),
        ),
        VerticalDivider(
          width: 1,
          color: theme.colorScheme.outline.withAlpha(77),
        ),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDayHeader(theme, dayEvents.length),
              Expanded(
                child: dayEvents.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.event_available_outlined,
                        title: 'Nothing scheduled',
                        description: 'No events on this day.',
                        actionLabel: 'Add Event',
                        onAction: _showAddEvent,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: dayEvents.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            CalendarDayEventsWidget(event: dayEvents[i]),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text(
            'Calendar',
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                final now = DateTime(2026, 5, 1);
                _selectedDay = now;
                _focusedMonth = DateTime(now.year, now.month, 1);
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Today',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(ThemeData theme, int eventCount) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[_selectedDay.weekday - 1];
    final monthName = months[_selectedDay.month - 1];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Text(
            '$dayName, $monthName ${_selectedDay.day}',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$eventCount event${eventCount != 1 ? 's' : ''}',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Data model
class CalendarEvent {
  final String id;
  final String title;
  final String source;
  final DateTime date;
  final String startTime;
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

  factory CalendarEvent.fromMap(Map<String, dynamic> m) {
    final dateParts = (m['date'] as String).split('-');
    return CalendarEvent(
      id: m['id'] as String,
      title: m['title'] as String,
      source: m['source'] as String,
      date: DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      ),
      startTime: m['startTime'] as String,
      endTime: m['endTime'] as String,
      location: m['location'] as String,
      courseCode: m['courseCode'] as String,
      description: m['description'] as String,
      isAllDay: m['isAllDay'] as bool,
    );
  }
}
