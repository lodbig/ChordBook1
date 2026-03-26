import 'package:hive/hive.dart';

part 'song.g.dart';

@HiveType(typeId: 0)
class Song {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late String artist;

  @HiveField(3)
  late List<String> tags;

  @HiveField(4)
  late Map<String, String> versions;

  @HiveField(5)
  late String originalKey;

  @HiveField(6)
  late double scrollSpeed;

  @HiveField(7)
  late DateTime createdAt;

  @HiveField(8)
  late DateTime updatedAt;

  @HiveField(9)
  late Map<String, String> versionKeys; // version name → key (e.g. 'Am')

  Song({
    required this.id,
    required this.title,
    this.artist = '',
    List<String>? tags,
    Map<String, String>? versions,
    this.originalKey = '',
    this.scrollSpeed = 3.0,
    Map<String, String>? versionKeys,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : tags = tags ?? [],
        versions = versions ?? {'רגיל': ''},
        versionKeys = versionKeys ?? {},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    List<String>? tags,
    Map<String, String>? versions,
    String? originalKey,
    double? scrollSpeed,
    Map<String, String>? versionKeys,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      tags: tags ?? List.from(this.tags),
      versions: versions ?? Map.from(this.versions),
      originalKey: originalKey ?? this.originalKey,
      scrollSpeed: scrollSpeed ?? this.scrollSpeed,
      versionKeys: versionKeys ?? Map.from(this.versionKeys),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'tags': List<String>.from(tags),
        'versions': Map<String, String>.from(versions),
        'originalKey': originalKey,
        'scrollSpeed': scrollSpeed,
        'versionKeys': Map<String, String>.from(versionKeys),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String? ?? '',
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        versions: (json['versions'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as String)) ??
            {'רגיל': ''},
        originalKey: json['originalKey'] as String? ?? '',
        scrollSpeed: (json['scrollSpeed'] as num?)?.toDouble() ?? 3.0,
        versionKeys: (json['versionKeys'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as String)) ??
            {},
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
      );
}
