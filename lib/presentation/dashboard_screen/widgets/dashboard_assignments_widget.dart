import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/status_badge_widget.dart';
import '../../../routes/app_routes.dart';
import '../dashboard_screen.dart';

class DashboardAssignmentsWidget extends StatelessWidget {
  final List<AssignmentItem> assignments;

  const DashboardAssignmentsWidget({super.key, required this.assignments});

  Color _courseColor(String colorKey) {
    switch (colorKey) {
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

  Color _courseContainerColor(String colorKey) {
    switch (colorKey) {
      case 'primary':
        return AppTheme.primaryContainer;
      case 'secondary':
        return AppTheme.secondaryContainer;
      case 'teal':
        return AppTheme.personalTealContainer;
      default:
        return AppTheme.primaryContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayAssignments = assignments.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Text(
                'Upcoming Assignments',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.assignmentManagerScreen,
                ),
                child: Text(
                  'See all',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: displayAssignments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final a = displayAssignments[index];
            final color = _courseColor(a.courseColor);
            final containerColor = _courseContainerColor(a.courseColor);
            return _AssignmentCard(
              assignment: a,
              color: color,
              containerColor: containerColor,
              theme: theme,
            );
          },
        ),
      ],
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final AssignmentItem assignment;
  final Color color;
  final Color containerColor;
  final ThemeData theme;

  const _AssignmentCard({
    required this.assignment,
    required this.color,
    required this.containerColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = assignment.status == 'overdue';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            Navigator.pushNamed(context, AppRoutes.assignmentManagerScreen),
        borderRadius: BorderRadius.circular(12),
        splashColor: color.withAlpha(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: isOverdue ? AppTheme.errorRed : color,
                width: 3,
              ),
              top: BorderSide(color: theme.colorScheme.outline, width: 1),
              right: BorderSide(color: theme.colorScheme.outline, width: 1),
              bottom: BorderSide(color: theme.colorScheme.outline, width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isOverdue ? AppTheme.errorContainer : containerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.assignment_outlined,
                  size: 18,
                  color: isOverdue ? AppTheme.errorRed : color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.title,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          assignment.courseName,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '·',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          assignment.dueDate,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: isOverdue
                                ? AppTheme.errorRed
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadgeWidget(status: assignment.status),
                  const SizedBox(height: 4),
                  Text(
                    '${assignment.points} pts',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
