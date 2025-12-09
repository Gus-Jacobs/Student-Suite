import 'package:hive/hive.dart';

part 'saved_document.g.dart';

@HiveType(typeId: 20)
class SavedDocument extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title; // e.g., "Google - Software Engineer"

  @HiveField(2)
  String type; // 'resume' or 'cover_letter'

  @HiveField(3)
  DateTime lastModified;

  @HiveField(4)
  Map<String, dynamic> content; // The raw data map from the editor

  SavedDocument({
    required this.id,
    required this.title,
    required this.type,
    required this.lastModified,
    required this.content,
  });
}
