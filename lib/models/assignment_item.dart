// lib/models/assignment_item.dart
//
// A Canvas assignment as shown in the Assignments screen.

class AssignmentManagerItem {
  final String id;
  final String title;
  final String courseName;
  final String courseCode;
  final String courseColor;
  final String dueDate;
  final String dueTime;
  final String dueDateRaw;
  final String status;
  final int points;
  final int? pointsEarned;
  final bool submitted;
  final String description;
  final String submissionType;
  final bool reminderSet;

  const AssignmentManagerItem({
    required this.id,
    required this.title,
    required this.courseName,
    required this.courseCode,
    required this.courseColor,
    required this.dueDate,
    required this.dueTime,
    required this.dueDateRaw,
    required this.status,
    required this.points,
    this.pointsEarned,
    required this.submitted,
    required this.description,
    required this.submissionType,
    required this.reminderSet,
  });

  factory AssignmentManagerItem.fromMap(Map<String, dynamic> m) =>
      AssignmentManagerItem(
        id: m['id'] as String,
        title: m['title'] as String,
        courseName: m['courseName'] as String,
        courseCode: m['courseCode'] as String,
        courseColor: m['courseColor'] as String,
        dueDate: m['dueDate'] as String,
        dueTime: m['dueTime'] as String,
        dueDateRaw: m['dueDateRaw'] as String,
        status: m['status'] as String,
        points: m['points'] as int,
        pointsEarned: m['pointsEarned'] as int?,
        submitted: m['submitted'] as bool,
        description: m['description'] as String,
        submissionType: m['submissionType'] as String,
        reminderSet: m['reminderSet'] as bool,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'courseName': courseName,
        'courseCode': courseCode,
        'courseColor': courseColor,
        'dueDate': dueDate,
        'dueTime': dueTime,
        'dueDateRaw': dueDateRaw,
        'status': status,
        'points': points,
        'pointsEarned': pointsEarned,
        'submitted': submitted,
        'description': description,
        'submissionType': submissionType,
        'reminderSet': reminderSet,
      };

  /// Fields that matter for change detection. `status` and `dueDateRaw` are
  /// excluded on purpose: they drift with the clock ("due soon" → "overdue")
  /// without anything having changed in Canvas.
  String get signature => [
        title,
        courseCode,
        dueDate,
        points,
        pointsEarned,
        submitted,
        description,
      ].join('\u0001');

  AssignmentManagerItem copyWith({
    bool? submitted,
    String? status,
    bool? reminderSet,
  }) => AssignmentManagerItem(
    id: id,
    title: title,
    courseName: courseName,
    courseCode: courseCode,
    courseColor: courseColor,
    dueDate: dueDate,
    dueTime: dueTime,
    dueDateRaw: dueDateRaw,
    status: status ?? this.status,
    points: points,
    pointsEarned: pointsEarned,
    submitted: submitted ?? this.submitted,
    description: description,
    submissionType: submissionType,
    reminderSet: reminderSet ?? this.reminderSet,
  );
}
