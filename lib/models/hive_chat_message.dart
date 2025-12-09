import 'package:hive/hive.dart';

part 'hive_chat_message.g.dart';

@HiveType(typeId: 5)
class HiveChatMessage {
  @HiveField(0)
  final String role; // 'user' or 'model'

  @HiveField(1)
  String content;

  HiveChatMessage({required this.role, required this.content});
}
