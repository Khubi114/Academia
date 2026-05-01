import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class StatusBadgeWidget extends StatelessWidget {
  final String status;
  final String? customLabel;
  final double fontSize;

  const StatusBadgeWidget({
    super.key,
    required this.status,
    this.customLabel,
    this.fontSize = 11,
  });

  String get _label {
    if (customLabel != null) return customLabel!;
    switch (status) {
      case 'submitted':
        return 'Submitted';
      case 'graded':
        return 'Graded';
      case 'overdue':
        return 'Overdue';
      case 'due_soon':
        return 'Due Soon';
      case 'upcoming':
        return 'Upcoming';
      case 'completed':
        return 'Done';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return status;
    }
  }

  Color _backgroundColor(BuildContext context) {
    switch (status) {
      case 'submitted':
        return AppTheme.successContainer;
      case 'graded':
        return AppTheme.primaryContainer;
      case 'overdue':
        return AppTheme.errorContainer;
      case 'due_soon':
        return AppTheme.canvasAmberContainer;
      case 'upcoming':
        return Theme.of(context).colorScheme.surfaceContainerHighest;
      case 'completed':
        return AppTheme.successContainer;
      case 'high':
        return AppTheme.errorContainer;
      case 'medium':
        return AppTheme.canvasAmberContainer;
      case 'low':
        return AppTheme.successContainer;
      default:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
  }

  Color _textColor(BuildContext context) {
    switch (status) {
      case 'submitted':
        return AppTheme.success;
      case 'graded':
        return AppTheme.primary;
      case 'overdue':
        return AppTheme.errorRed;
      case 'due_soon':
        return AppTheme.canvasAmber;
      case 'upcoming':
        return Theme.of(context).colorScheme.onSurfaceVariant;
      case 'completed':
        return AppTheme.success;
      case 'high':
        return AppTheme.errorRed;
      case 'medium':
        return AppTheme.canvasAmber;
      case 'low':
        return AppTheme.success;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _backgroundColor(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _label,
        style: GoogleFonts.manrope(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: _textColor(context),
        ),
      ),
    );
  }
}
