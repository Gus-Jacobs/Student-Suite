// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_info_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ContactInfoDataAdapter extends TypeAdapter<ContactInfoData> {
  @override
  final int typeId = 8;

  @override
  ContactInfoData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ContactInfoData(
      name: fields[0] as String,
      email: fields[1] as String,
      phone: fields[2] as String,
      linkedin: fields[3] as String,
      github: fields[4] as String,
      portfolio: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ContactInfoData obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.linkedin)
      ..writeByte(4)
      ..write(obj.github)
      ..writeByte(5)
      ..write(obj.portfolio);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactInfoDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
