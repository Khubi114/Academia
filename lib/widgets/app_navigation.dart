import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../routes/app_routes.dart';
import '../theme/design_tokens.dart';

class AppNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<_NavItem> _items = [
    _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Dashboard',
      route: AppRoutes.dashboardScreen,
    ),
    _NavItem(
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment_rounded,
      label: 'Assignments',
      route: AppRoutes.assignmentManagerScreen,
    ),
    _NavItem(
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
      label: 'Calendar',
      route: AppRoutes.calendarViewScreen,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    if (isTablet) {
      return _TabletRail(
        currentIndex: currentIndex,
        onTap: onTap,
        items: _items,
      );
    }
    return _PhoneBottomNav(
      currentIndex: currentIndex,
      onTap: onTap,
      items: _items,
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}

class _PhoneBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<_NavItem> items;

  const _PhoneBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isActive = currentIndex == index;
              final color = isActive ? scheme.primary : scheme.onSurfaceVariant;

              return Expanded(
                child: Semantics(
                  button: true,
                  selected: isActive,
                  label: item.label,
                  child: InkResponse(
                    onTap: () => onTap(index),
                    highlightShape: BoxShape.rectangle,
                    borderRadius: AppRadius.control,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Pill that grows behind the active icon.
                        AnimatedContainer(
                          duration: AppMotion.base,
                          curve: AppMotion.enter,
                          width: isActive ? 56 : 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isActive
                                ? scheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            isActive ? item.activeIcon : item.icon,
                            size: 22,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        AnimatedDefaultTextStyle(
                          duration: AppMotion.base,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w500,
                            color: color,
                          ),
                          child: Text(item.label),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TabletRail extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<_NavItem> items;

  const _TabletRail({
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      backgroundColor: theme.colorScheme.surface,
      indicatorColor: theme.colorScheme.primaryContainer,
      labelType: NavigationRailLabelType.selected,
      selectedLabelTextStyle: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.primary,
      ),
      unselectedLabelTextStyle: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      destinations: items
          .map(
            (item) => NavigationRailDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.activeIcon),
              label: Text(item.label),
            ),
          )
          .toList(),
    );
  }
}

class AppScaffold extends StatefulWidget {
  final Widget body;
  final int currentIndex;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  const AppScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  // Tabs replace each other (no back stack); the fade-through page transition
  // in AppTheme keeps switching smooth.
  void _onNavTap(int index) {
    if (index == widget.currentIndex) return;
    const routes = [
      AppRoutes.dashboardScreen,
      AppRoutes.assignmentManagerScreen,
      AppRoutes.calendarViewScreen,
    ];
    Navigator.pushNamedAndRemoveUntil(context, routes[index], (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    if (isTablet) {
      return Scaffold(
        body: Row(
          children: [
            AppNavigation(currentIndex: widget.currentIndex, onTap: _onNavTap),
            VerticalDivider(
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(child: widget.body),
          ],
        ),
        floatingActionButton: widget.floatingActionButton,
        floatingActionButtonLocation: widget.floatingActionButtonLocation,
      );
    }

    return Scaffold(
      body: widget.body,
      bottomNavigationBar: AppNavigation(
        currentIndex: widget.currentIndex,
        onTap: _onNavTap,
      ),
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
    );
  }
}
