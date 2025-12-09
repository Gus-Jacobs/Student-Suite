import 'package:hive/hive.dart';
import 'flashcard.dart';

part 'flashcard_deck.g.dart';

@HiveType(typeId: 2)
class FlashcardDeck extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  List<Flashcard> cards;

  FlashcardDeck({required this.id, required this.name, required this.cards});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cards': cards.map((c) => c.toJson()).toList(),
      };

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) => FlashcardDeck(
        id: json['id'],
        name: json['name'],
        cards:
            (json['cards'] as List).map((c) => Flashcard.fromJson(c)).toList(),
      );
}
