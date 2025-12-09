class CanvasCourse {
  final String id;
  final String name;

  CanvasCourse({required this.id, required this.name});

  factory CanvasCourse.fromJson(Map<String, dynamic> json) {
    return CanvasCourse(
      id: json['id'].toString(),
      name: json['name'] ?? 'Untitled Course',
    );
  }
}

class CanvasAssignment {
  final String id;
  final String name;
  final DateTime dueDate;

  CanvasAssignment(
      {required this.id, required this.name, required this.dueDate});

  factory CanvasAssignment.fromJson(Map<String, dynamic> json) {
    return CanvasAssignment(
      id: json['id'].toString(),
      name: json['name'] ?? 'Untitled Assignment',
      // Handle null due dates gracefully
      dueDate: json['due_at'] != null
          ? DateTime.parse(json['due_at'])
          : DateTime.now().add(const Duration(days: 365)), // Fallback
    );
  }
}
