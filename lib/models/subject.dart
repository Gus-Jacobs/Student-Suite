import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'subject.g.dart';

@HiveType(typeId: 7)
class Subject extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String content;

  @HiveField(3)
  DateTime lastUpdated;

  @HiveField(4)
  List<String> filePaths;

  Subject({
    required this.id,
    required this.name,
    required this.content,
    required this.lastUpdated,
    this.filePaths = const [],
  });

  factory Subject.create({required String name, String content = ''}) {
    return Subject(
      id: const Uuid().v4(),
      name: name,
      content: content,
      lastUpdated: DateTime.now(),
      filePaths: [],
    );
  }
}
