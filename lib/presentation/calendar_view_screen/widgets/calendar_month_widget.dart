import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../calendar_view_screen.dart';

class CalendarMonthWidget extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final Map<DateTime, List<CalendarEvent>> eventsByDay;
  final Function(DateTime) onDaySelected;
  final Function(DateTime) onMonthChanged;

  const CalendarMonthWidget({
    super.key,
    required this.focusedMonth,
    required this.selectedDay,
    required this.eventsByDay,
    required this.onDaySelected,
    required this.onMonthChanged,
  });

  static const List<String> _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const List<String> _months = [
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

  int _daysInMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 0).day;

  int _firstWeekdayOfMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    return first.weekday; // 1=Mon, 7=Sun
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysInMonth = _daysInMonth(focusedMonth);
    final firstWeekday = _firstWeekdayOfMonth(focusedMonth);
    final today = DateTime(2026, 5, 1);

    final totalCells = firstWeekday - 1 + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          children: [
            // Month header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  Text(
                    '${_months[focusedMonth.month - 1]} ${focusedMonth.year}',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => onMonthChanged(
                      DateTime(focusedMonth.year, focusedMonth.month - 1, 1),
                    ),
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    iconSize: 22,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                  IconButton(
                    onPressed: () => onMonthChanged(
                      DateTime(focusedMonth.year, focusedMonth.month + 1, 1),
                    ),
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    iconSize: 22,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ],
              ),
            ),
            // Weekday headers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: _weekdays
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 6),
            // Calendar grid
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Column(
                children: List.generate(rows, (rowIndex) {
                  return Row(
                    children: List.generate(7, (colIndex) {
                      final cellIndex = rowIndex * 7 + colIndex;
                      final dayNumber = cellIndex - (firstWeekday - 1) + 1;

                      if (dayNumber < 1 || dayNumber > daysInMonth) {
                        return const Expanded(child: SizedBox(height: 40));
                      }

                      final day = DateTime(
                        focusedMonth.year,
                        focusedMonth.month,
                        dayNumber,
                      );
                      final isSelected =
                          day.year == selectedDay.year &&
                          day.month == selectedDay.month &&
                          day.day == selectedDay.day;
                      final isToday =
                          day.year == today.year &&
                          day.month == today.month &&
                          day.day == today.day;
                      final dayKey = DateTime(day.year, day.month, day.day);
                      final dayEvents = eventsByDay[dayKey] ?? [];

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => onDaySelected(day),
                          child: Container(
                            height: 40,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 1,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary
                                  : isToday
                                  ? AppTheme.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$dayNumber',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: isSelected || isToday
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? Colors.white
                                        : isToday
                                        ? AppTheme.primary
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                                if (dayEvents.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  _EventDots(
                                    events: dayEvents,
                                    isSelected: isSelected,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventDots extends StatelessWidget {
  final List<CalendarEvent> events;
  final bool isSelected;

  const _EventDots({required this.events, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final sources = events.map((e) => e.source).toSet().toList();
    final displaySources = sources.take(3).toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: displaySources.map((source) {
        Color dotColor;
        if (isSelected) {
          dotColor = Colors.white.withAlpha(204);
        } else {
          dotColor = AppTheme.sourceColor(source);
        }
        return Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        );
      }).toList(),
    );
  }
}
