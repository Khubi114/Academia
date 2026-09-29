// lib/models/canvas_module.dart
//
// A Canvas course module (a "unit" of content inside a course).

class CanvasModule {
  final String id;
  final String courseId;
  final String name;
  final int position;
  final String state; // 'locked' | 'unlocked' | 'started' | 'completed' | ''
  final int itemsCount;

  const CanvasModule({
    required this.id,
    required this.courseId,
    required this.name,
    required this.position,
    required this.state,
    required this.itemsCount,
  });

  factory CanvasModule.fromCanvas(Map<String, dynamic> json, String courseId) =>
      CanvasModule(
        id: json['id'].toString(),
        courseId: courseId,
        name: json['name'] as String? ?? 'Module',
        position: (json['position'] as num?)?.toInt() ?? 0,
        state: json['state'] as String? ?? '',
        itemsCount: (json['items_count'] as num?)?.toInt() ?? 0,
      );
}
