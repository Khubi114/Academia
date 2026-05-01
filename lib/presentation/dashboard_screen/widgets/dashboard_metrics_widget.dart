import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class DashboardMetricsWidget extends StatelessWidget {
  final int dueTodayCount;
  final int overdueCount;
  final double completionRate;
  final int classesRemaining;

  const DashboardMetricsWidget({
    super.key,
    required this.dueTodayCount,
    required this.overdueCount,
    required this.completionRate,
    required this.classesRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: _MetricCard(
              label: 'Due Today',
              value: '$dueTodayCount',
              icon: Icons.assignment_late_outlined,
              color: dueTodayCount > 0
                  ? AppTheme.canvasAmber
                  : AppTheme.success,
              containerColor: dueTodayCount > 0
                  ? AppTheme.canvasAmberContainer
                  : AppTheme.successContainer,
              theme: theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              label: 'Overdue',
              value: '$overdueCount',
              icon: Icons.warning_amber_rounded,
              color: overdueCount > 0 ? AppTheme.errorRed : AppTheme.success,
              containerColor: overdueCount > 0
                  ? AppTheme.errorContainer
                  : AppTheme.successContainer,
              theme: theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              label: '7-Day Rate',
              value: '${completionRate.toInt()}%',
              icon: Icons.trending_up_rounded,
              color: AppTheme.primary,
              containerColor: AppTheme.primaryContainer,
              theme: theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              label: 'Classes Left',
              value: '$classesRemaining',
              icon: Icons.school_outlined,
              color: AppTheme.secondary,
              containerColor: AppTheme.secondaryContainer,
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color containerColor;
  final ThemeData theme;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.containerColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
