// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'education_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EducationDataAdapter extends TypeAdapter<EducationData> {
  @override
  final int typeId = 9;

  @override
  EducationData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EducationData(
      school: fields[0] as String,
      degree: fields[1] as String,
      gradDate: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, EducationData obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.school)
      ..writeByte(1)
      ..write(obj.degree)
      ..writeByte(2)
      ..write(obj.gradDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EducationDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
