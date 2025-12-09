// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flashcard_deck.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FlashcardDeckAdapter extends TypeAdapter<FlashcardDeck> {
  @override
  final int typeId = 2;

  @override
  FlashcardDeck read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FlashcardDeck(
      id: fields[0] as String,
      name: fields[1] as String,
      cards: (fields[2] as List).cast<Flashcard>(),
    );
  }

  @override
  void write(BinaryWriter writer, FlashcardDeck obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.cards);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlashcardDeckAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
