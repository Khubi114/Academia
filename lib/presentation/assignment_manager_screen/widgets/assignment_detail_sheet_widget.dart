import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/status_badge_widget.dart';
import '../assignment_manager_screen.dart';

class AssignmentDetailSheetWidget extends StatelessWidget {
  final AssignmentManagerItem assignment;

  const AssignmentDetailSheetWidget({super.key, required this.assignment});

  Color get _courseColor {
    switch (assignment.courseColor) {
      case 'primary':
        return AppTheme.primary;
      case 'secondary':
        return AppTheme.secondary;
      case 'teal':
        return AppTheme.personalTeal;
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
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
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _courseColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${assignment.courseCode} · ${assignment.courseName}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _courseColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              assignment.title,
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      StatusBadgeWidget(
                        status: assignment.status,
                        fontSize: 12,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _InfoRow(
                    icon: Icons.schedule_rounded,
                    label: 'Due',
                    value: '${assignment.dueDate} at ${assignment.dueTime}',
                    valueColor: assignment.status == 'overdue'
                        ? AppTheme.errorRed
                        : theme.colorScheme.onSurface,
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.star_outline_rounded,
                    label: 'Points',
                    value: assignment.pointsEarned != null
                        ? '${assignment.pointsEarned} / ${assignment.points} pts'
                        : '${assignment.points} pts possible',
                    valueColor: assignment.pointsEarned != null
                        ? AppTheme.primary
                        : theme.colorScheme.onSurface,
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.upload_file_outlined,
                    label: 'Submission',
                    value: assignment.submissionType,
                    valueColor: theme.colorScheme.onSurface,
                    theme: theme,
                  ),
                  const SizedBox(height: 20),
                  Divider(color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'Description',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    assignment.description,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (!assignment.submitted)
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        assignment.reminderSet
                            ? Icons.notifications_off_outlined
                            : Icons.notifications_outlined,
                        size: 18,
                        color: AppTheme.canvasAmber,
                      ),
                      label: Text(
                        assignment.reminderSet
                            ? 'Remove Reminder'
                            : 'Set Reminder',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.canvasAmber,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.canvasAmber),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  if (!assignment.submitted) const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      assignment.submitted
                          ? Icons.check_circle_rounded
                          : Icons.open_in_new_rounded,
                      size: 18,
                    ),
                    label: Text(
                      assignment.submitted ? 'Submitted' : 'Open in Canvas',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: assignment.submitted
                          ? AppTheme.success
                          : theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final ThemeData theme;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
