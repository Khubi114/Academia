// lib/models/sync_report.dart
//
// Result of one sync pass, used to tell the user what changed.

enum SyncSource { googleCalendar, canvas }

class SyncReport {
  final SyncSource source;
  final DateTime at;

  /// Calendar: events created/changed/removed upstream. Canvas: assignments.
  final int added;
  final int updated;
  final int removed;

  /// Human-readable titles of the newest changes (for the toast).
  final List<String> highlights;

  /// Set when the sync failed; the other fields are then zero.
  final String? error;

  const SyncReport({
    required this.source,
    required this.at,
    this.added = 0,
    this.updated = 0,
    this.removed = 0,
    this.highlights = const [],
    this.error,
  });

  bool get hasChanges => added + updated + removed > 0;
  bool get failed => error != null;

  String get sourceLabel =>
      source == SyncSource.canvas ? 'Canvas' : 'Google Calendar';

  /// e.g. "Canvas: 2 new, 1 updated".
  String get summary {
    final parts = <String>[
      if (added > 0) '$added new',
      if (updated > 0) '$updated updated',
      if (removed > 0) '$removed removed',
    ];
    return '$sourceLabel: ${parts.join(', ')}';
  }
}
