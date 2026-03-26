import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../library/library_providers.dart';
import '../shared/song_renderer_widget.dart';
import '../shared/theme_toggle.dart';
import 'playlist_providers.dart';

class SetlistPerformanceScreen extends ConsumerStatefulWidget {
  const SetlistPerformanceScreen({super.key, required this.playlistId});
  final String playlistId;

  @override
  ConsumerState<SetlistPerformanceScreen> createState() =>
      _SetlistPerformanceScreenState();
}

class _SetlistPerformanceScreenState
    extends ConsumerState<SetlistPerformanceScreen> {
  final _scrollController = ScrollController();
  final List<GlobalKey> _songKeys = [];

  Playlist? _playlist;
  List<Song> _songs = [];
  int _currentSongIndex = 0;
  bool _sidePanelOpen = false;
  bool _isScrolling = false;
  double _scrollSpeed = 0; // יאותחל מה-provider
  double _scrollDelay = 3.0;
  bool _speedInitialized = false;
  Timer? _scrollTimer;

  double _fontSize = 16.0;
  static const double _minFontSize = 10.0;
  static const double _maxFontSize = 36.0;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_updateCurrentSong);
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.removeListener(_updateCurrentSong);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final playlist =
        await ref.read(playlistRepositoryProvider).getById(widget.playlistId);
    if (playlist == null) return;
    final allSongs = await ref.read(songRepositoryProvider).getAll();
    final songs = playlist.songIds
        .map((id) => allSongs.firstWhere(
              (s) => s.id == id,
              orElse: () => Song(id: id, title: '(שיר לא נמצא)'),
            ))
        .toList();

    if (mounted) {
      setState(() {
        _playlist = playlist;
        _songs = songs;
        _songKeys.clear();
        _songKeys.addAll(List.generate(songs.length, (_) => GlobalKey()));
      });
    }
  }

  void _updateCurrentSong() {
    // Find which song is currently most visible
    for (int i = _songs.length - 1; i >= 0; i--) {
      final key = _songKeys[i];
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final pos = box.localToGlobal(Offset.zero);
      if (pos.dy <= MediaQuery.of(context).size.height / 2) {
        if (_currentSongIndex != i) {
          setState(() => _currentSongIndex = i);
        }
        break;
      }
    }
  }

  void _scrollToSong(int index) {
    final key = _songKeys[index];
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  void _toggleAutoScroll() {
    if (_isScrolling) {
      _scrollTimer?.cancel();
      setState(() => _isScrolling = false);
    } else {
      setState(() => _isScrolling = true);
      Future.delayed(Duration(milliseconds: (_scrollDelay * 1000).round()), () {
        if (!mounted || !_isScrolling) return;
        _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
          if (!_scrollController.hasClients) return;
          final max = _scrollController.position.maxScrollExtent;
          final current = _scrollController.offset;
          if (current >= max) {
            _scrollTimer?.cancel();
            setState(() => _isScrolling = false);
            return;
          }
          _scrollController.jumpTo(
            (current + _scrollSpeed * 0.5).clamp(0, max),
          );
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_playlist == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // אתחל מהירות מה-provider פעם אחת
    if (!_speedInitialized) {
      _scrollSpeed = ref.read(defaultScrollSpeedProvider);
      _speedInitialized = true;
    }

    final isAndroid = Platform.isAndroid;
    final fontFamily = ref.watch(fontFamilyProvider);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.space) {
          _toggleAutoScroll();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.backspace ||
            event.logicalKey == LogicalKeyboardKey.escape) {
          final router = GoRouter.of(context);
          if (router.canPop()) {
            router.pop();
          } else {
            router.go('/');
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: PopScope(
      canPop: isAndroid || !_sidePanelOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _sidePanelOpen && !isAndroid) {
          setState(() => _sidePanelOpen = false);
        }
      },
      child: Scaffold(
      body: Row(
        children: [
          // Side panel – Desktop only
          if (!isAndroid)
            ClipRect(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _sidePanelOpen ? 200 : 0,
                child: OverflowBox(
                  alignment: AlignmentDirectional.topStart,
                  minWidth: 200,
                  maxWidth: 200,
                  child: _SidePanel(
                    songs: _songs,
                    currentIndex: _currentSongIndex,
                    onTap: _scrollToSong,
                  ),
                ),
              ),
            ),
          // Main content
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _toggleAutoScroll,
              child: Column(
              children: [
                // AppBar area
                SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'חזור',
                        onPressed: () {
                          final router = GoRouter.of(context);
                          if (router.canPop()) {
                            router.pop();
                          } else {
                            router.go('/');
                          }
                        },
                      ),
                      if (isAndroid)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.music_note),
                        )
                      else
                        IconButton(
                          icon: Icon(_sidePanelOpen
                              ? Icons.menu_open
                              : Icons.menu),
                          onPressed: () =>
                              setState(() => _sidePanelOpen = !_sidePanelOpen),
                        ),
                      Expanded(
                        child: Text(
                          _playlist!.name,
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Auto-scroll controls
                      IconButton(
                        icon: Icon(_isScrolling ? Icons.pause : Icons.play_arrow),
                        onPressed: _toggleAutoScroll,
                      ),
                      SizedBox(
                        width: 80,
                        child: Slider(
                          value: _scrollSpeed,
                          min: 1,
                          max: 10,
                          onChanged: (v) => setState(() => _scrollSpeed = v),
                        ),
                      ),
                      // Delay slider
                      const Icon(Icons.timer_outlined, size: 16),
                      SizedBox(
                        width: 70,
                        child: Slider(
                          value: _scrollDelay,
                          min: 0,
                          max: 10,
                          divisions: 10,
                          onChanged: (v) => setState(() => _scrollDelay = v),
                        ),
                      ),
                      Text('${_scrollDelay.toStringAsFixed(0)}s',
                          style: const TextStyle(fontSize: 11)),
                      // Font size controls
                      IconButton(
                        icon: const Icon(Icons.text_decrease),
                        tooltip: 'הקטן גופן',
                        onPressed: () => setState(() {
                          _fontSize = (_fontSize - 2).clamp(_minFontSize, _maxFontSize);
                        }),
                      ),
                      IconButton(
                        icon: const Icon(Icons.text_increase),
                        tooltip: 'הגדל גופן',
                        onPressed: () => setState(() {
                          _fontSize = (_fontSize + 2).clamp(_minFontSize, _maxFontSize);
                        }),
                      ),
                    ],
                  ),
                ),
                // Song list
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _songs.length,
                    itemBuilder: (_, i) => _SongSection(
                      key: _songKeys[i],
                      song: _songs[i],
                      index: i,
                      isLast: i == _songs.length - 1,
                      fontSize: _fontSize,
                      fontFamily: fontFamily,
                      selectedVersion: _playlist!.songVersions[_songs[i].id],
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    ),
    ),
    );
  }
}

// ---------------------------------------------------------------------------
// Side panel
// ---------------------------------------------------------------------------

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.songs,
    required this.currentIndex,
    required this.onTap,
  });

  final List<Song> songs;
  final int currentIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          const SizedBox(height: 48), // align with AppBar
          Expanded(
            child: ListView.builder(
              itemCount: songs.length,
              itemBuilder: (_, i) {
                final isActive = i == currentIndex;
                return ListTile(
                  dense: true,
                  leading: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isActive ? colorScheme.primary : null,
                    ),
                  ),
                  title: Text(
                    songs[i].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? colorScheme.primary : null,
                      fontSize: 13,
                    ),
                  ),
                  onTap: () => onTap(i),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Song section with separator
// ---------------------------------------------------------------------------

class _SongSection extends StatelessWidget {
  const _SongSection({
    super.key,
    required this.song,
    required this.index,
    required this.isLast,
    required this.fontSize,
    this.fontFamily,
    this.selectedVersion,
  });

  final Song song;
  final int index;
  final bool isLast;
  final double fontSize;
  final String? fontFamily;
  final String? selectedVersion;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Song separator header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Divider(color: colorScheme.primary.withValues(alpha: 0.5)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.music_note, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${index + 1}. ${song.title}',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Divider(color: colorScheme.primary.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
        // Song content
        Center(
          child: SongRendererWidget(
            text: (selectedVersion != null && song.versions.containsKey(selectedVersion))
                ? song.versions[selectedVersion]!
                : song.versions.values.first,
            fontSize: fontSize,
            fontFamily: fontFamily,
          ),
        ),
        // End separator
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Divider(
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                    thickness: 2,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
