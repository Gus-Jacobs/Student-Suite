// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_teacher_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AITeacherSessionAdapter extends TypeAdapter<AITeacherSession> {
  @override
  final int typeId = 6;

  @override
  AITeacherSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AITeacherSession(
      id: fields[0] as String,
      topic: fields[1] as String,
      createdAt: fields[2] as DateTime,
      messages: (fields[3] as List).cast<HiveChatMessage>(),
    );
  }

  @override
  void write(BinaryWriter writer, AITeacherSession obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.topic)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.messages);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AITeacherSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
