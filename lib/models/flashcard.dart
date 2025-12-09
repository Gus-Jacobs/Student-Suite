import 'package:hive/hive.dart';

part 'flashcard.g.dart';

@HiveType(typeId: 4)
class Flashcard extends HiveObject {
  @HiveField(0)
  final String question;
  @HiveField(1)
  final String answer;

  Flashcard({required this.question, required this.answer});

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
      };

  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
        question: json['question'],
        answer: json['answer'],
      );
}
