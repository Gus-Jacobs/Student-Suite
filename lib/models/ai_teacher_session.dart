import 'package:hive/hive.dart';
import 'package:student_suite/models/hive_chat_message.dart';
import 'package:uuid/uuid.dart';

part 'ai_teacher_session.g.dart';

@HiveType(typeId: 6)
class AITeacherSession extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String topic;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  List<HiveChatMessage> messages;

  AITeacherSession(
      {required this.id,
      required this.topic,
      required this.createdAt,
      required this.messages});

  factory AITeacherSession.create({required String topic}) {
    return AITeacherSession(
      id: const Uuid().v4(),
      topic: topic,
      createdAt: DateTime.now(),
      messages: [],
    );
  }
}
