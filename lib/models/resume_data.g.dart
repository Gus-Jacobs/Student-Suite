// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resume_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ResumeDataAdapter extends TypeAdapter<ResumeData> {
  @override
  final int typeId = 12;

  @override
  ResumeData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ResumeData(
      contactInfo: fields[0] as ContactInfoData,
      skills: (fields[1] as List).cast<String>(),
      education: (fields[2] as List).cast<EducationData>(),
      experience: (fields[3] as List).cast<ExperienceData>(),
      certificates: (fields[4] as List).cast<CertificateData>(),
    );
  }

  @override
  void write(BinaryWriter writer, ResumeData obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.contactInfo)
      ..writeByte(1)
      ..write(obj.skills)
      ..writeByte(2)
      ..write(obj.education)
      ..writeByte(3)
      ..write(obj.experience)
      ..writeByte(4)
      ..write(obj.certificates);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResumeDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
