import 'package:go_router/go_router.dart';

import '../ui/custom_chords/custom_chords_screen.dart';
import '../ui/editor/song_editor_screen.dart';
import '../ui/library/library_screen.dart';
import '../ui/performance/performance_screen.dart';
import '../ui/playlists/playlist_detail_screen.dart';
import '../ui/playlists/playlist_list_screen.dart';
import '../ui/playlists/setlist_performance_screen.dart';
import '../ui/settings/settings_screen.dart';
import '../ui/settings/shortcuts_settings_screen.dart';
import '../ui/tags/tag_management_screen.dart';
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LibraryScreen(),
    ),
    GoRoute(
      path: '/editor/:id',
      builder: (context, state) =>
          SongEditorScreen(songId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/performance/:id',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final songIds = extra?['songIds'] as List<String>?;
        final currentIndex = extra?['currentIndex'] as int?;
        final isShuffleMode = extra?['isShuffleMode'] as bool? ?? false;
        final autoStart = extra?['autoStart'] as bool? ?? false;
        return PerformanceScreen(
          songId: state.pathParameters['id']!,
          songIds: songIds,
          currentIndex: currentIndex,
          isShuffleMode: isShuffleMode,
          autoStart: autoStart,
        );
      },
    ),
    GoRoute(
      path: '/playlists',
      builder: (context, state) => const PlaylistListScreen(),
    ),
    GoRoute(
      path: '/playlists/:id',
      builder: (context, state) =>
          PlaylistDetailScreen(playlistId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/playlists/:id/perform',
      builder: (context, state) =>
          SetlistPerformanceScreen(playlistId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/tags',
      builder: (context, state) => const TagManagementScreen(),
    ),
    GoRoute(
      path: '/custom-chords',
      builder: (context, state) => const CustomChordsScreen(),
    ),
    GoRoute(
      path: '/shortcuts',
      builder: (context, state) => const ShortcutsSettingsScreen(),
    ),
  ],
);
