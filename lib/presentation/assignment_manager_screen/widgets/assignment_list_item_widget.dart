import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/status_badge_widget.dart';
import '../assignment_manager_screen.dart';

class AssignmentListItemWidget extends StatefulWidget {
  final AssignmentManagerItem assignment;
  final VoidCallback onTap;
  final VoidCallback onReminderToggle;
  final VoidCallback onMarkSubmitted;

  const AssignmentListItemWidget({
    super.key,
    required this.assignment,
    required this.onTap,
    required this.onReminderToggle,
    required this.onMarkSubmitted,
  });

  @override
  State<AssignmentListItemWidget> createState() =>
      _AssignmentListItemWidgetState();
}

class _AssignmentListItemWidgetState extends State<AssignmentListItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Color get _courseColor {
    switch (widget.assignment.courseColor) {
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

  Color get _courseContainerColor {
    switch (widget.assignment.courseColor) {
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
    final isOverdue = widget.assignment.status == 'overdue';
    final isCompleted = widget.assignment.submitted;

    return Dismissible(
      key: Key('asgn_${widget.assignment.id}'),
      background: _buildSwipeBackground(
        alignment: Alignment.centerLeft,
        color: AppTheme.canvasAmber,
        icon: widget.assignment.reminderSet
            ? Icons.notifications_off_outlined
            : Icons.notifications_outlined,
        label: widget.assignment.reminderSet
            ? 'Remove Reminder'
            : 'Set Reminder',
      ),
      secondaryBackground: _buildSwipeBackground(
        alignment: Alignment.centerRight,
        color: AppTheme.success,
        icon: Icons.check_circle_outline_rounded,
        label: 'Mark Submitted',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          widget.onReminderToggle();
        } else {
          if (!widget.assignment.submitted) {
            widget.onMarkSubmitted();
          }
        }
        return false;
      },
      child: ScaleTransition(
        scale: _scaleAnim,
        child: GestureDetector(
          onTapDown: (_) => _scaleController.forward(),
          onTapUp: (_) {
            _scaleController.reverse();
            widget.onTap();
          },
          onTapCancel: () => _scaleController.reverse(),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  color: isOverdue
                      ? AppTheme.errorRed
                      : isCompleted
                      ? AppTheme.success
                      : _courseColor,
                  width: 3,
                ),
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? AppTheme.errorContainer
                          : isCompleted
                          ? AppTheme.successContainer
                          : _courseContainerColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.assignment_outlined,
                      size: 20,
                      color: isOverdue
                          ? AppTheme.errorRed
                          : isCompleted
                          ? AppTheme.success
                          : _courseColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.assignment.title,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isCompleted
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.onSurface,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
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
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                widget.assignment.courseCode,
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _courseColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                widget.assignment.courseName,
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
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: isOverdue
                                  ? AppTheme.errorRed
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.assignment.dueDate} · ${widget.assignment.dueTime}',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
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
                      StatusBadgeWidget(status: widget.assignment.status),
                      const SizedBox(height: 6),
                      Text(
                        widget.assignment.pointsEarned != null
                            ? '${widget.assignment.pointsEarned}/${widget.assignment.points}'
                            : '${widget.assignment.points} pts',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.assignment.pointsEarned != null
                              ? AppTheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (widget.assignment.reminderSet) ...[
                        const SizedBox(height: 6),
                        Icon(
                          Icons.notifications_active_rounded,
                          size: 14,
                          color: AppTheme.canvasAmber,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeBackground({
    required AlignmentGeometry alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
