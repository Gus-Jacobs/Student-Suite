// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_interview_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AIInterviewSessionAdapter extends TypeAdapter<AIInterviewSession> {
  @override
  final int typeId = 13;

  @override
  AIInterviewSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AIInterviewSession(
      id: fields[0] as String,
      jobDescription: fields[1] as String,
      resumeText: fields[2] as String?,
      createdAt: fields[3] as DateTime,
      messages: (fields[4] as List).cast<HiveChatMessage>(),
      feedback: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AIInterviewSession obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.jobDescription)
      ..writeByte(2)
      ..write(obj.resumeText)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.messages)
      ..writeByte(5)
      ..write(obj.feedback);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIInterviewSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
