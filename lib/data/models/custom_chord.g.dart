// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_chord.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomChordAdapter extends TypeAdapter<CustomChord> {
  @override
  final int typeId = 3;

  @override
  CustomChord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomChord(
      id: fields[0] as String,
      name: fields[1] as String,
      order: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CustomChord obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.order);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomChordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
