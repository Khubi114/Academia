// lib/services/change_detector.dart
//
// Pure change detection between two snapshots of synced items (no Flutter or
// network imports, so it is trivially unit-testable).
//
// A snapshot maps item id → [SnapshotEntry]. Comparing the previous snapshot
// with a fresh one tells us what was added, updated or removed since the last
// sync — which drives the "2 new assignments" toast and the local cache.

import 'dart:convert';

class SnapshotEntry {
  /// Hash-like string of the fields that matter (see
  /// `AssignmentManagerItem.signature`).
  final String signature;
  final String title;

  /// Grouping key (Canvas course id). Used to avoid reporting items as
  /// "removed" when the group they belong to failed to load this time.
  final String group;

  const SnapshotEntry({
    required this.signature,
    required this.title,
    required this.group,
  });

  Map<String, dynamic> toJson() =>
      {'s': signature, 't': title, 'g': group};

  factory SnapshotEntry.fromJson(Map<String, dynamic> json) => SnapshotEntry(
        signature: json['s'] as String? ?? '',
        title: json['t'] as String? ?? '',
        group: json['g'] as String? ?? '',
      );
}

class ChangeSet {
  final List<String> added;
  final List<String> updated;
  final List<String> removed;

  const ChangeSet({
    this.added = const [],
    this.updated = const [],
    this.removed = const [],
  });

  bool get isEmpty => added.isEmpty && updated.isEmpty && removed.isEmpty;
}

/// Titles of items that were added / updated / removed between [previous] and
/// [current]. Items whose group is in [failedGroups] are never "removed".
ChangeSet detectChanges({
  required Map<String, SnapshotEntry> previous,
  required Map<String, SnapshotEntry> current,
  Set<String> failedGroups = const {},
}) {
  final added = <String>[];
  final updated = <String>[];
  final removed = <String>[];

  current.forEach((id, entry) {
    final old = previous[id];
    if (old == null) {
      added.add(entry.title);
    } else if (old.signature != entry.signature) {
      updated.add(entry.title);
    }
  });

  previous.forEach((id, entry) {
    if (!current.containsKey(id) && !failedGroups.contains(entry.group)) {
      removed.add(entry.title);
    }
  });

  return ChangeSet(added: added, updated: updated, removed: removed);
}

// ── (De)serialisation for SharedPreferences ────────────────────────────────

String encodeSnapshot(Map<String, SnapshotEntry> snapshot) =>
    jsonEncode(snapshot.map((id, e) => MapEntry(id, e.toJson())));

Map<String, SnapshotEntry>? decodeSnapshot(String? raw) {
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (id, e) => MapEntry(id, SnapshotEntry.fromJson(e as Map<String, dynamic>)),
    );
  } catch (_) {
    return null; // corrupt cache → behave like a first sync
  }
}
