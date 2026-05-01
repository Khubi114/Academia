import 'package:flutter/material.dart';

import '../presentation/assignment_manager_screen/assignment_manager_screen.dart';
import '../presentation/calendar_view_screen/calendar_view_screen.dart';
import '../presentation/dashboard_screen/dashboard_screen.dart';

class AppRoutes {
  static const String initial = '/';
  static const String dashboardScreen = '/dashboard-screen';
  static const String assignmentManagerScreen = '/assignment-manager-screen';
  static const String calendarViewScreen = '/calendar-view-screen';

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const DashboardScreen(),
    dashboardScreen: (context) => const DashboardScreen(),
    assignmentManagerScreen: (context) => const AssignmentManagerScreen(),
    calendarViewScreen: (context) => const CalendarViewScreen(),
  };
}
