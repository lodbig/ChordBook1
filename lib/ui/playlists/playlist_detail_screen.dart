import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../library/library_providers.dart';
import 'playlist_providers.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});
  final String playlistId;

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  Playlist? _playlist;
  List<Song> _allSongs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(playlistRepositoryProvider);
    final songRepo = ref.read(songRepositoryProvider);
    final playlist = await repo.getById(widget.playlistId);
    final songs = await songRepo.getAll();
    if (mounted) {
      setState(() {
        _playlist = playlist;
        _allSongs = songs;
      });
    }
  }

  List<Song> get _playlistSongs {
    if (_playlist == null) return [];
    return _playlist!.songIds
        .map((id) => _allSongs.firstWhere(
              (s) => s.id == id,
              orElse: () => Song(id: id, title: '(שיר לא נמצא)'),
            ))
        .toList();
  }

  Future<void> _save(Playlist updated) async {
    await ref.read(playlistRepositoryProvider).save(updated);
    ref.invalidate(allPlaylistsProvider);
    setState(() => _playlist = updated);
  }

  Future<void> _addSongs() async {
    if (_playlist == null) return;
    final existing = Set<String>.from(_playlist!.songIds);
    final selected = Set<String>.from(existing);
    final searchCtrl = TextEditingController();
    var query = '';

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) {
          final filtered = query.isEmpty
              ? _allSongs
              : _allSongs.where((s) {
                  final q = query.toLowerCase();
                  return s.title.toLowerCase().contains(q) ||
                      s.artist.toLowerCase().contains(q);
                }).toList();

          void confirm() {
            Navigator.of(ctx).pop();
            final newIds = [
              ..._playlist!.songIds,
              ...selected.where((id) => !existing.contains(id)),
            ];
            _save(_playlist!.copyWith(songIds: newIds));
          }

          return KeyboardListener(
            focusNode: FocusNode(),
            autofocus: false,
            onKeyEvent: (event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.enter) {
                confirm();
              }
            },
            child: AlertDialog(
              title: const Text('הוסף שירים'),
              content: SizedBox(
                width: 320,
                height: 460,
                child: Column(
                  children: [
                    TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'חפש שיר או אמן...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  searchCtrl.clear();
                                  setState(() => query = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => query = v),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: filtered.map((s) {
                          return CheckboxListTile(
                            title: Text(s.title),
                            subtitle:
                                s.artist.isNotEmpty ? Text(s.artist) : null,
                            value: selected.contains(s.id),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  selected.add(s.id);
                                } else {
                                  selected.remove(s.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('ביטול'),
                ),
                TextButton(
                  autofocus: false,
                  onPressed: confirm,
                  child: const Text('הוסף'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _removeSong(String songId) {
    if (_playlist == null) return;
    final newIds = List<String>.from(_playlist!.songIds)..remove(songId);
    _save(_playlist!.copyWith(songIds: newIds));
  }

  void _reorder(int oldIndex, int newIndex) {
    if (_playlist == null) return;
    final ids = List<String>.from(_playlist!.songIds);
    if (newIndex > oldIndex) newIndex--;
    final item = ids.removeAt(oldIndex);
    ids.insert(newIndex, item);
    _save(_playlist!.copyWith(songIds: ids));
  }

  @override
  Widget build(BuildContext context) {
    if (_playlist == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final songs = _playlistSongs;

    return Scaffold(
      appBar: AppBar(
        title: Text(_playlist!.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'הפעל רשימת השמעה',
            onPressed: () =>
                context.push('/playlists/${widget.playlistId}/perform'),
          ),
          const SizedBox(width: 8), // רווח קטן כדי שלא ייצמד לקצה המסך
        ],
      ),
      body: songs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('הרשימה ריקה'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('הוסף שירים'),
                    onPressed: _addSongs,
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              itemCount: songs.length,
              onReorder: _reorder,
              itemBuilder: (_, i) {
                final song = songs[i];
                return ListTile(
                  key: ValueKey(song.id),
                  leading: Text('${i + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  title: Text(song.title),
                  subtitle:
                      song.artist.isNotEmpty ? Text(song.artist) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (song.versions.length > 1)
                        DropdownButton<String>(
                          value: _playlist!.songVersions[song.id] ??
                              song.versions.keys.first,
                          isDense: true,
                          underline: const SizedBox.shrink(),
                          items: song.versions.keys
                              .map((v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(v),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            _save(_playlist!.copyWith(
                              songVersions: Map.from(_playlist!.songVersions)
                                ..[song.id] = v,
                            ));
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => _removeSong(song.id),
                        tooltip: 'הסר מהרשימה',
                      ),
                      const Icon(Icons.drag_handle),
                    ],
                  ),
                  onTap: () => context.push('/performance/${song.id}'),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSongs,
        tooltip: 'הוסף שירים',
        child: const Icon(Icons.add),
      ),
    );
  }
}
