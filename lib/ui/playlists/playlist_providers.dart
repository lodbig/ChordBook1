import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/playlist.dart';
import '../../data/repositories/playlist_repository.dart';

final playlistRepositoryProvider = Provider((_) => PlaylistRepository());

final allPlaylistsProvider = FutureProvider<List<Playlist>>((ref) {
  return ref.watch(playlistRepositoryProvider).getAll();
});
