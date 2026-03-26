import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/song.dart';
import '../../data/models/tag.dart';
import '../playlists/playlist_providers.dart';
import '../shared/confirmation_dialog.dart';
import '../shared/song_card.dart';
import '../shared/theme_toggle.dart';
import 'library_providers.dart';
import 'song_import_export.dart';
import '../../window_helper_stub.dart'
    if (dart.library.io) '../../window_helper_io.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  Future<void> _createNewSong() async {
    final repo = ref.read(songRepositoryProvider);
    final newSong = Song(
      id: const Uuid().v4(),
      title: 'שיר חדש',
    );
    await repo.save(newSong);
    ref.invalidate(allSongsProvider);
    if (mounted) context.push('/editor/${newSong.id}');
  }

  void _playRandom(BuildContext context) {
    final songs = ref.read(filteredSongsProvider).valueOrNull ?? [];
    if (songs.isEmpty) return;
    final shuffled = List.of(songs)..shuffle();
    final ids = shuffled.map((s) => s.id).toList();
    context.push(
      '/performance/${ids.first}',
      extra: {
        'songIds': ids,
        'currentIndex': 0,
        'isShuffleMode': true,
        'autoStart': true,
      },
    );
  }

  void _clearSelection() {
    ref.read(selectedSongIdsProvider.notifier).state = const {};
  }

  void _toggleSelect(String id) {
    final current = ref.read(selectedSongIdsProvider);
    final updated = Set<String>.from(current);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    ref.read(selectedSongIdsProvider.notifier).state = updated;
  }

  void _toggleSelectAll() {
    final selectedIds = ref.read(selectedSongIdsProvider);
    final filteredSongs = ref.read(filteredSongsProvider).valueOrNull ?? [];
    final allSelected =
        selectedIds.length == filteredSongs.length && filteredSongs.isNotEmpty;
    if (allSelected) {
      ref.read(selectedSongIdsProvider.notifier).state = const {};
    } else {
      ref.read(selectedSongIdsProvider.notifier).state =
          filteredSongs.map((s) => s.id).toSet();
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final selectedIds = ref.watch(selectedSongIdsProvider);
    final isSelectionMode = selectedIds.isNotEmpty;

    return Scaffold(
      appBar: _buildAppBar(isSelectionMode, selectedIds),
      body: Column(
        children: [
          _SearchBar(controller: _searchController),
          _FilterRow(),
          Expanded(child: _SongList(
            onTap: (song) {
              if (isSelectionMode) {
                _toggleSelect(song.id);
              } else {
                final songs = ref.read(filteredSongsProvider).valueOrNull ?? [];
                final ids = songs.map((s) => s.id).toList();
                final idx = ids.indexOf(song.id);
                context.push(
                  '/performance/${song.id}',
                  extra: {'songIds': ids, 'currentIndex': idx < 0 ? 0 : idx},
                );
              }
            },
            onLongPress: (song) => _toggleSelect(song.id),
          )),
        ],
      ),
      floatingActionButton: isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: _createNewSong,
              tooltip: 'הוסף שיר',
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar:
          isSelectionMode ? _SelectionBar(onClear: _clearSelection) : null,
    );
  }

  AppBar _buildAppBar(bool isSelectionMode, Set<String> selectedIds) {
    if (isSelectionMode) {
      final filteredSongs =
          ref.read(filteredSongsProvider).valueOrNull ?? [];
      final allSelected =
          selectedIds.length == filteredSongs.length && filteredSongs.isNotEmpty;
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
        ),
        title: Text('${selectedIds.length} נבחרו'),
        actions: [
          IconButton(
            icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
            tooltip: allSelected ? 'בטל בחירת הכל' : 'בחר הכל',
            onPressed: _toggleSelectAll,
          ),
        ],
      );
    }
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/CHORDBOOK_ICON.png',
            width: 28,
            height: 28,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          const Text('ChordBook'),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.queue_music_outlined),
          tooltip: 'רשימות ניגון',
          onPressed: () => context.push('/playlists'),
        ),
        IconButton(
          icon: const Icon(Icons.shuffle),
          tooltip: 'ניגון אקראי',
          onPressed: () => _playRandom(context),
        ),
        IconButton(
          icon: const Icon(Icons.download_outlined),
          tooltip: 'ייבוא שירים',
          onPressed: () => _importSongs(),
        ),
        const ThemeToggle(),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'הגדרות',
          onPressed: () => context.push('/settings'),
        ),
// --- כפתור מסך מלא - Windows בלבד ---
        if (Platform.isWindows)
          IconButton(
            icon: const Icon(Icons.fullscreen_outlined),
            tooltip: 'מסך מלא (F11)',
            onPressed: () => onF11Pressed(),
          ),
        if (Platform.isWindows)
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'יציאה (Ctrl+Q)',
            onPressed: () => confirmAndExit(context),
          ),
        // -----------------------
      const SizedBox(width: 8), // רווח קטן כדי שלא ייצמד לקצה המסך
      ],
    );
  }

  Future<void> _importSongs() async {
    final repo = ref.read(songRepositoryProvider);
    await importSongsFromJson(context, repo, () {
      ref.invalidate(allSongsProvider);
      ref.invalidate(allTagsProvider);
    });
  }
}

// ---------------------------------------------------------------------------
// Search bar
// ---------------------------------------------------------------------------

class _SearchBar extends ConsumerWidget {
  const _SearchBar({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'חפש שיר, אמן או תגית...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    ref.read(searchQueryProvider.notifier).state = '';
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        onChanged: (v) =>
            ref.read(searchQueryProvider.notifier).state = v,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter row (tags + sort)
// ---------------------------------------------------------------------------

class _FilterRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(allTagsProvider);
    final selectedTag = ref.watch(selectedTagFilterProvider);
    final sort = ref.watch(sortModeProvider);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // Sort dropdown
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: DropdownButton<SortMode>(
              value: sort,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(
                    value: SortMode.title, child: Text('א-ב')),
                DropdownMenuItem(
                    value: SortMode.artist, child: Text('לפי אמן')),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref.read(sortModeProvider.notifier).state = v;
                }
              },
            ),
          ),
          // Tag filter chips
          tagsAsync.when(
            data: (tags) => Row(
              children: tags
                  .map((t) => Padding(
                        padding:
                            const EdgeInsetsDirectional.only(end: 6),
                        child: FilterChip(
                          label: Text(t.name),
                          selected: selectedTag == t.id,
                          onSelected: (_) {
                            ref
                                .read(selectedTagFilterProvider.notifier)
                                .state = selectedTag == t.id ? null : t.id;
                          },
                        ),
                      ))
                  .toList(),
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Song list
// ---------------------------------------------------------------------------

class _SongList extends ConsumerWidget {
  const _SongList({required this.onTap, required this.onLongPress});
  final void Function(Song) onTap;
  final void Function(Song) onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(filteredSongsProvider);
    final tagsAsync = ref.watch(allTagsProvider);
    final selectedIds = ref.watch(selectedSongIdsProvider);
    final query = ref.watch(searchQueryProvider);

    final tagMap = tagsAsync.valueOrNull
            ?.fold<Map<String, Tag>>({}, (m, t) => m..[t.id] = t) ??
        {};

    return songsAsync.when(
      data: (songs) {
        if (songs.isEmpty) {
          return _EmptyState(query: query);
        }
        return ListView.builder(
          itemCount: songs.length,
          itemBuilder: (_, i) {
            final song = songs[i];
            final songTags =
                song.tags.map((id) => tagMap[id]).whereType<Tag>().toList();
            return SongCard(
              song: song,
              tags: songTags,
              isSelected: selectedIds.contains(song.id),
              isSelectionMode: selectedIds.isNotEmpty,
              onTap: () => onTap(song),
              onLongPress: () => onLongPress(song),
            );
          },
        );
      },
      loading: () => const _LoadingShimmer(),
      error: (e, _) => Center(child: Text('שגיאה: $e')),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty / loading states
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_note_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            query.isEmpty
                ? 'אין שירים עדיין. לחץ + להוספה'
                : 'לא נמצאו שירים עבור "$query"',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Multi-select bottom bar
// ---------------------------------------------------------------------------

class _SelectionBar extends ConsumerWidget {
  const _SelectionBar({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Container(
        height: 56,
        color: Theme.of(context).colorScheme.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.label_outline),
              label: const Text('תייג'),
              onPressed: () => _tagSelected(context, ref),
            ),
            TextButton.icon(
              icon: const Icon(Icons.playlist_add),
              label: const Text('הוסף לרשימה'),
              onPressed: () => _addToPlaylist(context, ref),
            ),
            TextButton.icon(
              icon: const Icon(Icons.upload_outlined),
              label: const Text('ייצא'),
              onPressed: () => _exportSelected(context, ref),
            ),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('מחק', style: TextStyle(color: Colors.red)),
              onPressed: () => _deleteSelected(context, ref),
            ),
            TextButton.icon(
              icon: const Icon(Icons.close),
              label: const Text('בטל'),
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportSelected(BuildContext context, WidgetRef ref) async {
    final selectedIds = ref.read(selectedSongIdsProvider);
    final allSongs = ref.read(allSongsProvider).valueOrNull ?? [];
    final selected = allSongs.where((s) => selectedIds.contains(s.id)).toList();
    if (selected.isEmpty) return;
    await exportSongsToJson(context, selected);
  }

  Future<void> _deleteSelected(BuildContext context, WidgetRef ref) async {
    final selectedIds = ref.read(selectedSongIdsProvider);
    if (selectedIds.isEmpty) return;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'מחיקת שירים',
      message: 'האם למחוק ${selectedIds.length} שירים לצמיתות?',
      confirmLabel: 'מחק',
      isDestructive: true,
    );
    if (confirmed != true) return;
    final repo = ref.read(songRepositoryProvider);
    for (final id in selectedIds) {
      await repo.delete(id);
    }
    ref.read(selectedSongIdsProvider.notifier).state = const {};
    ref.invalidate(allSongsProvider);
  }

  Future<void> _tagSelected(BuildContext context, WidgetRef ref) async {
    final selectedIds = ref.read(selectedSongIdsProvider);
    if (selectedIds.isEmpty) return;
    final allTags = ref.read(allTagsProvider).valueOrNull ?? [];
    if (allTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('אין תגיות. צור תגיות בהגדרות.')),
      );
      return;
    }
    final allSongs = ref.read(allSongsProvider).valueOrNull ?? [];
    final selectedSongs =
        allSongs.where((s) => selectedIds.contains(s.id)).toList();

    // חשב אילו תגיות משותפות לכל השירים הנבחרים
    final commonTagIds = allTags
        .map((t) => t.id)
        .where((id) => selectedSongs.every((s) => s.tags.contains(id)))
        .toSet();

    // null = ביטול, Map<tagId, bool> = מה לשנות
    final result = await showDialog<Map<String, bool>>(
      context: context,
      builder: (_) {
        // true = הוסף, false = הסר, null = לא שונה
        final sel = <String, bool>{
          for (final id in commonTagIds) id: true,
        };
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('ניהול תגיות'),
            content: SizedBox(
              width: 300,
              child: ListView(
                shrinkWrap: true,
                children: allTags.map((t) {
                  final isChecked = sel[t.id] ?? false;
                  return CheckboxListTile(
                    title: Text(t.name),
                    value: isChecked,
                    onChanged: (v) =>
                        setState(() => sel[t.id] = v ?? false),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('ביטול'),
              ),
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.of(ctx).pop(sel),
                child: const Text('החל'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    final repo = ref.read(songRepositoryProvider);
    for (final song in selectedSongs) {
      var tags = List<String>.from(song.tags);
      for (final entry in result.entries) {
        if (entry.value) {
          if (!tags.contains(entry.key)) tags.add(entry.key);
        } else {
          tags.remove(entry.key);
        }
      }
      await repo.save(song.copyWith(tags: tags));
    }
    ref.invalidate(allSongsProvider);
  }

  Future<void> _addToPlaylist(BuildContext context, WidgetRef ref) async {
    final selectedIds = ref.read(selectedSongIdsProvider);
    if (selectedIds.isEmpty) return;
    final playlists = ref.read(allPlaylistsProvider).valueOrNull ?? [];
    if (playlists.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('אין רשימות ניגון. צור רשימה תחילה.')),
        );
      }
      return;
    }
    final chosen = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('הוסף לרשימת ניגון'),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: playlists.map((p) => ListTile(
              title: Text(p.name),
              subtitle: Text('${p.songIds.length} שירים'),
              onTap: () => Navigator.of(context).pop(p.id),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ביטול'),
          ),
        ],
      ),
    );
    if (chosen == null) return;
    final repo = ref.read(playlistRepositoryProvider);
    final playlist = playlists.firstWhere((p) => p.id == chosen);
    final newIds = [
      ...playlist.songIds,
      ...selectedIds.where((id) => !playlist.songIds.contains(id)),
    ];
    await repo.save(playlist.copyWith(songIds: newIds));
    ref.invalidate(allPlaylistsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selectedIds.length} שירים נוספו לרשימה')),
      );
    }
  }
}
