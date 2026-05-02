// ─────────────────────────────────────────────────────────────────────────────
// CHANGES TO: lib/presentation/calendar_view_screen/calendar_view_screen.dart
//
// Apply each block below using str_replace. The rest of the file is unchanged.
// ─────────────────────────────────────────────────────────────────────────────


// ── CHANGE 1: Add import at the top of the file ───────────────────────────────
// Add after the existing import block:

import '../../../services/google_calendar_service.dart';


// ── CHANGE 2: Inside _CalendarViewScreenState — add new state fields ──────────
// Add these two lines alongside the existing state declarations
// (near _focusedMonth, _selectedDay, etc.):

bool _calendarLoading = true;
bool _calendarConnected = false;


// ── CHANGE 3: Replace the entire initState method ────────────────────────────
// OLD:
//   @override
//   void initState() {
//     super.initState();
//     final now = DateTime(2026, 5, 1);
//     _focusedMonth = DateTime(now.year, now.month, 1);
//     _selectedDay = now;
//     _entranceController = AnimationController( ... );
//     _fadeAnim = CurvedAnimation( ... );
//     _events = _eventsMaps.map(CalendarEvent.fromMap).toList();  // ← REMOVE THIS LINE
//     _entranceController.forward();
//   }
//
// NEW — replace _events assignment with a real fetch:

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


// ── CHANGE 4: Replace _onMonthChanged to also refetch events ─────────────────
// OLD:
//   void _onMonthChanged(DateTime month) {
//     setState(() => _focusedMonth = month);
//   }
//
// NEW:

  void _onMonthChanged(DateTime month) {
    setState(() => _focusedMonth = month);
    _loadCalendarEvents(month);
  }


// ── CHANGE 5: Add new _loadCalendarEvents method ──────────────────────────────
// Add this method anywhere inside _CalendarViewScreenState,
// e.g. right after _onMonthChanged:

  Future<void> _loadCalendarEvents(DateTime month) async {
    setState(() => _calendarLoading = true);

    final events = await GoogleCalendarService.instance.fetchMonthEvents(month);

    if (!mounted) return;
    setState(() {
      _events = events;
      _calendarConnected = GoogleCalendarService.instance.isConnected;
      _calendarLoading = false;
    });

    // Only start the entrance animation once we have data.
    if (!_entranceController.isAnimating && !_entranceController.isCompleted) {
      _entranceController.forward();
    }
  }


// ── CHANGE 6: Add a connect-to-Google button in _buildHeader ─────────────────
// Add inside the Row in _buildHeader, before the closing bracket,
// alongside the existing 'Today' TextButton:

              if (!_calendarConnected)
                TextButton.icon(
                  onPressed: () async {
                    final ok = await GoogleCalendarService.instance.signIn();
                    if (ok) _loadCalendarEvents(_focusedMonth);
                  },
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(
                    'Connect Google',
                    style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),


// ── CHANGE 7: Remove the now-unused _eventsMaps list ─────────────────────────
// Delete the entire `final List<Map<String, dynamic>> _eventsMaps = [ ... ];`
// block from _CalendarViewScreenState. It is no longer needed.
// The _events list is now populated by _loadCalendarEvents above.


// ── NO OTHER CHANGES NEEDED ───────────────────────────────────────────────────
// Everything else in the file — CalendarEvent model, widgets, _eventsForDay,
// _eventsByDay, _showAddEvent, build methods — stays exactly as-is.
