import 'package:hive/hive.dart';

part 'custom_chord.g.dart';

@HiveType(typeId: 3)
class CustomChord {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name; // "C/E", "Fsus4", etc.

  @HiveField(2)
  late int order;

  CustomChord({
    required this.id,
    required this.name,
    required this.order,
  });

  CustomChord copyWith({
    String? id,
    String? name,
    int? order,
  }) {
    return CustomChord(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
    );
  }
}
