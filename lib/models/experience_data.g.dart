// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'experience_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExperienceDataAdapter extends TypeAdapter<ExperienceData> {
  @override
  final int typeId = 10;

  @override
  ExperienceData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExperienceData(
      company: fields[0] as String,
      title: fields[1] as String,
      dates: fields[2] as String,
      responsibilities: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ExperienceData obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.company)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.dates)
      ..writeByte(3)
      ..write(obj.responsibilities);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExperienceDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
