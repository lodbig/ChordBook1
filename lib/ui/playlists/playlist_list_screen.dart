import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/playlist.dart';
import '../shared/confirmation_dialog.dart';
import 'playlist_providers.dart';

class PlaylistListScreen extends ConsumerWidget {
  const PlaylistListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(allPlaylistsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('רשימות השמעה')),
      body: playlistsAsync.when(
        data: (playlists) => playlists.isEmpty
            ? const Center(child: Text('אין רשימות השמעה עדיין'))
            : ListView.builder(
                itemCount: playlists.length,
                itemBuilder: (_, i) => _PlaylistTile(
                  playlist: playlists[i],
                  onTap: () => context.push('/playlists/${playlists[i].id}'),
                  onDelete: () => _delete(context, ref, playlists[i]),
                  onRename: () => _rename(context, ref, playlists[i]),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('שגיאה: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _create(context, ref),
        tooltip: 'רשימה חדשה',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await _nameDialog(context, title: 'רשימה חדשה');
    if (name == null || name.isEmpty) return;
    final repo = ref.read(playlistRepositoryProvider);
    await repo.save(Playlist(
      id: const Uuid().v4(),
      name: name,
      songIds: [],
    ));
    ref.invalidate(allPlaylistsProvider);
  }

  Future<void> _rename(
      BuildContext context, WidgetRef ref, Playlist playlist) async {
    final name =
        await _nameDialog(context, title: 'שנה שם', initial: playlist.name);
    if (name == null || name.isEmpty) return;
    final repo = ref.read(playlistRepositoryProvider);
    await repo.save(playlist.copyWith(name: name));
    ref.invalidate(allPlaylistsProvider);
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Playlist playlist) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'מחיקת רשימה',
      message: 'האם למחוק את "${playlist.name}"?',
      confirmLabel: 'מחק',
      isDestructive: true,
    );
    if (confirmed != true) return;
    await ref.read(playlistRepositoryProvider).delete(playlist.id);
    ref.invalidate(allPlaylistsProvider);
  }

  static Future<String?> _nameDialog(BuildContext context,
      {required String title, String initial = ''}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'שם הרשימה'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('שמור'),
          ),
        ],
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.queue_music),
      title: Text(playlist.name),
      subtitle: Text('${playlist.songIds.length} שירים'),
      onTap: onTap,
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'rename') onRename();
          if (v == 'delete') onDelete();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'rename', child: Text('שנה שם')),
          PopupMenuItem(value: 'delete', child: Text('מחק')),
        ],
      ),
    );
  }
}
