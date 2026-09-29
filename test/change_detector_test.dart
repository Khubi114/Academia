import 'package:Academia/models/assignment_item.dart';
import 'package:Academia/services/change_detector.dart';
import 'package:flutter_test/flutter_test.dart';

SnapshotEntry entry(String sig, String title, [String group = 'c1']) =>
    SnapshotEntry(signature: sig, title: title, group: group);

AssignmentManagerItem item({String title = 'Essay', String status = 'upcoming'}) =>
    AssignmentManagerItem(
      id: '1',
      title: title,
      courseName: 'Systems',
      courseCode: 'COS10004',
      courseColor: 'primary',
      dueDate: 'Oct 5, 2026',
      dueTime: '11:59 PM',
      dueDateRaw: 'future',
      status: status,
      points: 20,
      submitted: false,
      description: '',
      submissionType: 'File Upload',
      reminderSet: false,
    );

void main() {
  group('detectChanges', () {
    test('reports added, updated and removed items', () {
      final result = detectChanges(
        previous: {
          '1': entry('a', 'Same'),
          '2': entry('b', 'Old title'),
          '3': entry('c', 'Deleted'),
        },
        current: {
          '1': entry('a', 'Same'),
          '2': entry('b2', 'New title'),
          '4': entry('d', 'Brand new'),
        },
      );
      expect(result.added, ['Brand new']);
      expect(result.updated, ['New title']);
      expect(result.removed, ['Deleted']);
    });

    test('does not report items of a failed course as removed', () {
      final result = detectChanges(
        previous: {'1': entry('a', 'Kept', 'c9')},
        current: const {},
        failedGroups: {'c9'},
      );
      expect(result.isEmpty, isTrue);
    });
  });

  group('snapshot encoding', () {
    test('round-trips', () {
      final original = {'1': entry('sig', 'Title', 'g')};
      final decoded = decodeSnapshot(encodeSnapshot(original))!;
      expect(decoded['1']!.signature, 'sig');
      expect(decoded['1']!.title, 'Title');
      expect(decoded['1']!.group, 'g');
    });

    test('corrupt or missing data decodes to null (treated as first sync)', () {
      expect(decodeSnapshot(null), isNull);
      expect(decodeSnapshot('{not json'), isNull);
    });
  });

  group('AssignmentManagerItem', () {
    test('signature ignores clock-driven status but tracks real edits', () {
      expect(item(status: 'upcoming').signature, item(status: 'overdue').signature);
      expect(item().signature, isNot(item(title: 'Renamed').signature));
    });

    test('toMap / fromMap round-trip', () {
      final copy = AssignmentManagerItem.fromMap(item().toMap());
      expect(copy.signature, item().signature);
    });
  });
}
