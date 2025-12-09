import 'package:hive/hive.dart';
import 'package:student_suite/models/hive_chat_message.dart';
import 'package:uuid/uuid.dart';

part 'ai_interview_session.g.dart';

@HiveType(typeId: 13)
class AIInterviewSession extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String jobDescription;

  @HiveField(2)
  final String? resumeText;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  List<HiveChatMessage> messages;

  @HiveField(5)
  String? feedback;

  AIInterviewSession({
    required this.id,
    required this.jobDescription,
    this.resumeText,
    required this.createdAt,
    required this.messages,
    this.feedback,
  });

  factory AIInterviewSession.create(
      {required String jobDescription, String? resumeText}) {
    return AIInterviewSession(
        id: const Uuid().v4(),
        jobDescription: jobDescription,
        resumeText: resumeText,
        createdAt: DateTime.now(),
        messages: []);
  }
}
