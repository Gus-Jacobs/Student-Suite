// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'certificate_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CertificateDataAdapter extends TypeAdapter<CertificateData> {
  @override
  final int typeId = 11;

  @override
  CertificateData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CertificateData(
      name: fields[0] as String,
      organization: fields[1] as String,
      date: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CertificateData obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.organization)
      ..writeByte(2)
      ..write(obj.date);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CertificateDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
