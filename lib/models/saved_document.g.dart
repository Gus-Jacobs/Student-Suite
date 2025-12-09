// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_document.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SavedDocumentAdapter extends TypeAdapter<SavedDocument> {
  @override
  final int typeId = 20;

  @override
  SavedDocument read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedDocument(
      id: fields[0] as String,
      title: fields[1] as String,
      type: fields[2] as String,
      lastModified: fields[3] as DateTime,
      content: (fields[4] as Map).cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, SavedDocument obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.lastModified)
      ..writeByte(4)
      ..write(obj.content);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedDocumentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
