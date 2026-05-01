import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../calendar_view_screen.dart';

class CalendarDayEventsWidget extends StatelessWidget {
  final CalendarEvent event;

  const CalendarDayEventsWidget({super.key, required this.event});

  Color get _sourceColor => AppTheme.sourceColor(event.source);
  Color get _sourceContainerColor =>
      AppTheme.sourceContainerColor(event.source);

  String get _sourceLabel {
    switch (event.source) {
      case 'google_calendar':
        return 'Google Cal';
      case 'canvas':
        return 'Canvas';
      case 'personal':
        return 'Personal';
      default:
        return event.source;
    }
  }

  IconData get _sourceIcon {
    switch (event.source) {
      case 'google_calendar':
        return Icons.event_rounded;
      case 'canvas':
        return Icons.assignment_outlined;
      case 'personal':
        return Icons.bookmark_outline_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  bool get _isDueDate => event.startTime == '23:59';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showEventDetail(context),
        borderRadius: BorderRadius.circular(12),
        splashColor: _sourceColor.withAlpha(20),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: _sourceColor, width: 3),
              top: BorderSide(color: theme.colorScheme.outline, width: 1),
              right: BorderSide(color: theme.colorScheme.outline, width: 1),
              bottom: BorderSide(color: theme.colorScheme.outline, width: 1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _sourceContainerColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_sourceIcon, size: 18, color: _sourceColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isDueDate
                                ? 'Due at 11:59 PM'
                                : '${event.startTime} – ${event.endTime}',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _isDueDate
                                  ? AppTheme.canvasAmber
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (event.location.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                event.location,
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (event.courseCode.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _sourceContainerColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            event.courseCode,
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _sourceColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _sourceContainerColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _sourceLabel,
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _sourceColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEventDetail(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _sourceContainerColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_sourceIcon, size: 20, color: _sourceColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    event.title,
                    style: GoogleFonts.manrope(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (!_isDueDate)
              _DetailRow(
                icon: Icons.access_time_rounded,
                text: '${event.startTime} – ${event.endTime}',
                theme: theme,
              ),
            if (_isDueDate)
              _DetailRow(
                icon: Icons.warning_amber_rounded,
                text: 'Due at 11:59 PM',
                color: AppTheme.canvasAmber,
                theme: theme,
              ),
            if (event.location.isNotEmpty) ...[
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.location_on_outlined,
                text: event.location,
                theme: theme,
              ),
            ],
            if (event.courseCode.isNotEmpty) ...[
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.school_outlined,
                text: event.courseCode,
                color: _sourceColor,
                theme: theme,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              event.description,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.colorScheme.outline),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final ThemeData theme;

  const _DetailRow({
    required this.icon,
    required this.text,
    this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: c,
          ),
        ),
      ],
    );
  }
}
