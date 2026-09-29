// lib/services/sync_service.dart
//
// Keeps everything up to date without the user pressing anything.
//
//   • Google Calendar: incremental sync every [AppConfig.calendarSyncInterval]
//   • Canvas:          full diff-sync every  [AppConfig.canvasSyncInterval]
//   • Both again whenever the app returns to the foreground.
//
// Screens subscribe to [reports] to reload when something changed, and to
// [assignments] for the latest Canvas data. The app shell shows a toast for
// every report that has changes (see main.dart).
//
// Note: timers only run while the app is open. True background sync would
// need a platform scheduler (WorkManager / BGTaskScheduler) — out of scope.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/app_config.dart';
import '../models/assignment_item.dart';
import '../models/sync_report.dart';
import 'canvas_service.dart';
import 'google_calendar_service.dart';

class SyncService with WidgetsBindingObserver {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _reportController = StreamController<SyncReport>.broadcast();

  /// Emits after every sync attempt (successful or not).
  Stream<SyncReport> get reports => _reportController.stream;

  /// Latest Canvas assignments (cached copy first, then fresh after a sync).
  final ValueNotifier<List<AssignmentManagerItem>> assignments =
      ValueNotifier(const []);

  /// True while a Canvas sync is running (drives spinners).
  final ValueNotifier<bool> canvasSyncing = ValueNotifier(false);

  Timer? _calendarTimer;
  Timer? _canvasTimer;
  DateTime? _lastCalendar;
  DateTime? _lastCanvas;
  Future<SyncReport?>? _calendarRun;
  Future<SyncReport?>? _canvasRun;
  bool _started = false;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  /// Starts periodic + resume-triggered syncing. Safe to call repeatedly.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);

    _calendarTimer =
        Timer.periodic(AppConfig.calendarSyncInterval, (_) => syncCalendar());
    _canvasTimer =
        Timer.periodic(AppConfig.canvasSyncInterval, (_) => syncCanvas());

    // Paint the cached copy immediately, then refresh from the network.
    await CanvasService.instance.loadCredentials();
    await GoogleCalendarService.instance.checkExistingConnection();
    assignments.value = await CanvasService.instance.loadCached();
    unawaited(syncAll(force: true));
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _calendarTimer?.cancel();
    _canvasTimer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) syncAll();
  }

  // ── Sync entry points ───────────────────────────────────────────────────────

  Future<void> syncAll({bool force = false}) async {
    await Future.wait([syncCalendar(force: force), syncCanvas(force: force)]);
  }

  bool _tooSoon(DateTime? last, bool force) =>
      !force &&
      last != null &&
      DateTime.now().difference(last) < AppConfig.minSyncGap;

  /// Pulls new/changed/deleted Google Calendar events. Concurrent callers
  /// share one run.
  Future<SyncReport?> syncCalendar({bool force = false}) {
    if (!GoogleCalendarService.instance.isConnected) return Future.value(null);
    if (_calendarRun != null) return _calendarRun!;
    if (_tooSoon(_lastCalendar, force)) return Future.value(null);

    return _calendarRun = () async {
      try {
        final report = await GoogleCalendarService.instance.syncNow();
        _lastCalendar = DateTime.now();
        _reportController.add(report);
        return report;
      } finally {
        _calendarRun = null;
      }
    }();
  }

  /// Diff-syncs Canvas, updates [assignments] and (server side) the database
  /// and Google Calendar mirror.
  Future<SyncReport?> syncCanvas({bool force = false}) {
    if (!CanvasService.instance.isConnected) return Future.value(null);
    if (_canvasRun != null) return _canvasRun!;
    if (_tooSoon(_lastCanvas, force)) return Future.value(null);

    return _canvasRun = () async {
      canvasSyncing.value = true;
      try {
        final result = await CanvasService.instance.sync();
        _lastCanvas = DateTime.now();
        if (!result.report.failed || result.items.isNotEmpty) {
          assignments.value = result.items;
        }
        _reportController.add(result.report);
        return result.report;
      } finally {
        canvasSyncing.value = false;
        _canvasRun = null;
      }
    }();
  }
}
