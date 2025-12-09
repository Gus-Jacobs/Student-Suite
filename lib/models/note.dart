import 'package:hive/hive.dart';

part 'note.g.dart';

@HiveType(typeId: 3)
class Note extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String content;

  @HiveField(2)
  double posX;

  @HiveField(3)
  double posY;

  @HiveField(4)
  bool isAiGenerated;

  Note({
    required this.id,
    required this.content,
    this.isAiGenerated = false,
    this.posX = 0,
    this.posY = 0,
  });

  factory Note.create({required String content, bool isAiGenerated = false}) {
    return Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isAiGenerated: isAiGenerated,
      posX: 0,
      posY: 0,
    );
  }
}
