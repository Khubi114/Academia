import '../../core/app_export.dart';
import '../../services/google_calendar_service.dart';
import './widgets/add_event_sheet_widget.dart';
import './widgets/calendar_day_events_widget.dart';
import './widgets/calendar_legend_widget.dart';
import './widgets/calendar_month_widget.dart';

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

  List<CalendarEvent> _events = [];
  bool _calendarLoading = true;
  bool _calendarConnected = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
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
    _loadCalendarEvents(_focusedMonth);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _loadCalendarEvents(DateTime month) async {
    setState(() => _calendarLoading = true);

    final events =
        await GoogleCalendarService.instance.fetchMonthEvents(month);

    if (!mounted) return;
    setState(() {
      _events = events;
      _calendarConnected = GoogleCalendarService.instance.isConnected;
      _calendarLoading = false;
    });

    if (!_entranceController.isAnimating && !_entranceController.isCompleted) {
      _entranceController.forward();
    }
  }

  Future<void> _connectGoogle() async {
    setState(() => _isConnecting = true);
    try {
      final error = await GoogleCalendarService.instance.signIn();
      if (error == null) {
        // Success
        await _loadCalendarEvents(_focusedMonth);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully connected to Google Calendar!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (error == 'cancelled') {
        // User dismissed — no message needed
      } else {
        if (mounted) {
          final message = _friendlyError(error);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 10),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  String _friendlyError(String code) {
    if (code == 'no_auth_code') {
      return 'Sign-in failed: no server auth code received. '
          'Make sure the OAuth Client ID in your app is the '
          '"Web application" type (not Android/iOS).';
    }
    if (code == 'no_supabase_user') {
      return 'Could not create a session. Check your Supabase URL and anon key.';
    }
    if (code.startsWith('exchange_failed_500')) {
      return 'The Vercel backend returned an error. Check that '
          'GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, SUPABASE_URL and '
          'SUPABASE_SERVICE_ROLE_KEY are set in your Vercel project settings.';
    }
    if (code.startsWith('exchange_failed_')) {
      return 'Token exchange failed ($code). Check Vercel function logs for details.';
    }
    if (code.startsWith('network_error')) {
      return 'Network error reaching Vercel backend. '
          'Check your internet connection and that the deployment is live.\n$code';
    }
    return 'Connection failed: $code';
  }

  // ── Event helpers ─────────────────────────────────────────────────────────────

  Map<DateTime, List<CalendarEvent>> get _eventsByDay {
    final map = <DateTime, List<CalendarEvent>>{};
    for (final e in _events) {
      final key = DateTime(e.date.year, e.date.month, e.date.day);
      (map[key] ??= []).add(e);
    }
    return map;
  }

  List<CalendarEvent> _eventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    final evts = _eventsByDay[key] ?? [];
    evts.sort((a, b) => a.startTime.compareTo(b.startTime));
    return evts;
  }

  void _onMonthChanged(DateTime month) {
    setState(() => _focusedMonth = month);
    _loadCalendarEvents(month);
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

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      currentIndex: 2,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            if (!_calendarConnected && !_calendarLoading)
              _buildConnectBanner(theme),
            CalendarMonthWidget(
              focusedMonth: _focusedMonth,
              selectedDay: _selectedDay,
              eventsByDay: _eventsByDay,
              onDaySelected: (day) => setState(() => _selectedDay = day),
              onMonthChanged: _onMonthChanged,
            ),
            const CalendarLegendWidget(),
            Expanded(
              child: _calendarLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : FadeTransition(
                      opacity: _fadeAnim,
                      child: _buildDayEvents(theme),
                    ),
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
                  'Calendar',
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  _calendarConnected
                      ? 'Google Calendar · Synced'
                      : 'Connect Google Calendar to see events',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: _calendarConnected
                        ? theme.colorScheme.onSurfaceVariant
                        : AppTheme.canvasAmber,
                  ),
                ),
              ],
            ),
          ),
          // Today button
          TextButton(
            onPressed: () {
              final now = DateTime.now();
              final newMonth = DateTime(now.year, now.month, 1);
              setState(() {
                _selectedDay = now;
                if (_focusedMonth != newMonth) {
                  _focusedMonth = newMonth;
                  _loadCalendarEvents(newMonth);
                }
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            child: Text(
              'Today',
              style: GoogleFonts.manrope(
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          // Add event button
          IconButton(
            onPressed: _showAddEvent,
            icon: Icon(
              Icons.add_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectBanner(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: AppTheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _isConnecting ? null : _connectGoogle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.event_available_rounded,
                    size: 18, color: AppTheme.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tap to connect your Google Calendar',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondary,
                    ),
                  ),
                ),
                if (_isConnecting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.secondary,
                    ),
                  )
                else
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: AppTheme.secondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayEvents(ThemeData theme) {
    final dayEvents = _eventsForDay(_selectedDay);
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weekdays[_selectedDay.weekday - 1],
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    '${months[_selectedDay.month - 1]} ${_selectedDay.day}',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: dayEvents.isEmpty
                      ? theme.colorScheme.surfaceContainerHighest
                      : AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dayEvents.isEmpty
                      ? 'No events'
                      : '${dayEvents.length} event${dayEvents.length == 1 ? '' : 's'}',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: dayEvents.isEmpty
                        ? theme.colorScheme.onSurfaceVariant
                        : AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: dayEvents.isEmpty
              ? _buildEmptyDay(theme)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: dayEvents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      CalendarDayEventsWidget(event: dayEvents[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyDay(ThemeData theme) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.event_available_outlined,
                  size: 26,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Nothing scheduled',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _calendarConnected
                    ? 'Free day — enjoy it!'
                    : 'Connect Google Calendar to see your events',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (!_calendarConnected) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isConnecting ? null : _connectGoogle,
                  icon: _isConnecting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_rounded, size: 16),
                  label: Text(
                    _isConnecting ? 'Connecting…' : 'Connect Google Calendar',
                    style: GoogleFonts.manrope(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── CalendarEvent model ───────────────────────────────────────────────────────

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
}
