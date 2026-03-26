import 'package:hive/hive.dart';

part 'playlist.g.dart';

@HiveType(typeId: 1)
class Playlist {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late List<String> songIds;

  @HiveField(3)
  late DateTime createdAt;

  @HiveField(4)
  late Map<String, String> songVersions;

  Playlist({
    required this.id,
    required this.name,
    List<String>? songIds,
    DateTime? createdAt,
    Map<String, String>? songVersions,
  })  : songIds = songIds ?? [],
        createdAt = createdAt ?? DateTime.now(),
        songVersions = songVersions ?? {};

  Playlist copyWith({
    String? id,
    String? name,
    List<String>? songIds,
    DateTime? createdAt,
    Map<String, String>? songVersions,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songIds: songIds ?? List.from(this.songIds),
      createdAt: createdAt ?? this.createdAt,
      songVersions: songVersions ?? Map.from(this.songVersions),
    );
  }
}
