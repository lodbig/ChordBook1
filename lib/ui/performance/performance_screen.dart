import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/song.dart';
import '../../data/models/tag.dart';
import '../../domain/transpose_engine.dart';
import '../library/library_providers.dart';
import '../shared/confirmation_dialog.dart';
import '../shared/song_renderer_widget.dart';
import '../shared/tag_chip.dart';
import '../shared/theme_toggle.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _performanceSongProvider =
    Provider.family<Song?, String>((ref, id) {
  final songs = ref.watch(allSongsProvider).valueOrNull ?? [];
  try {
    return songs.firstWhere((s) => s.id == id);
  } catch (_) {
    return null;
  }
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class PerformanceScreen extends ConsumerStatefulWidget {
  const PerformanceScreen({
    super.key,
    required this.songId,
    this.songIds,
    this.currentIndex,
    this.isShuffleMode = false,
    this.autoStart = false,
  });
  final String songId;
  /// Optional ordered list of song IDs for prev/next navigation.
  final List<String>? songIds;
  /// Index of [songId] within [songIds].
  final int? currentIndex;
  /// Whether this session was started as a shuffle play.
  final bool isShuffleMode;
  /// Whether to auto-start scrolling when the screen loads.
  final bool autoStart;

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();

  // View-only state (does NOT mutate storage – Property 11)
  int _transposeSteps = 0;
  double _fontSize = 18.0;
  double _scrollSpeed = 3.0;
  double _scrollDelay = 3.0;
  bool _isScrolling = false;
  bool _toolbarVisible = true;
  String? _activeVersion;

  Ticker? _scrollTicker;
  double _scrollAccum = 0; // sub-pixel accumulator for smooth scroll

  static const double _minFontSize = 10.0;
  static const double _maxFontSize = 36.0;
  static const double _chordFontRatio = 0.85; // Property 12: constant ratio

  @override
  void dispose() {
    _scrollTicker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // אתחל מהירות והשהיה מה-providers מיד
    _scrollSpeed = ref.read(defaultScrollSpeedProvider);
    _scrollDelay = ref.read(globalScrollDelayProvider);
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final song = ref.read(_performanceSongProvider(widget.songId));
          if (song != null) _startScroll(song);
        }
      });
    }
  }

  // -------------------------------------------------------------------------
  // Auto-scroll
  // -------------------------------------------------------------------------

  void _toggleScroll(Song song) {
    if (_isScrolling) {
      _stopScroll();
    } else {
      _startScroll(song);
    }
  }

  void _startScroll(Song song) {
    setState(() { _isScrolling = true; _toolbarVisible = false; });
    Future.delayed(Duration(milliseconds: (_scrollDelay * 1000).round()), () {
      if (!mounted || !_isScrolling) return;
      _scrollAccum = 0;
      // px per second = _scrollSpeed * 10 (סקאלה 0.1-3.0 → 1-30 px/sec)
      _scrollTicker = createTicker((elapsed) {
        if (!_scrollController.hasClients) return;
        final max = _scrollController.position.maxScrollExtent;
        final current = _scrollController.offset;
        if (current >= max) {
          _stopScroll();
          final autoAdvance = ref.read(autoAdvanceProvider);
          if (autoAdvance && _hasNext) {
            final advanceDelay = ref.read(autoAdvanceDelayProvider);
            Future.delayed(
              Duration(milliseconds: (advanceDelay * 1000).round()),
              () {
                if (!mounted) return;
                final idx = widget.currentIndex! + 1;
                final id = widget.songIds![idx];
                context.pushReplacement(
                  '/performance/$id',
                  extra: {
                    'songIds': widget.songIds,
                    'currentIndex': idx,
                    'isShuffleMode': widget.isShuffleMode,
                    'autoStart': true,
                  },
                );
              },
            );
          }
          return;
        }
        // px per frame = speed * 10 / 60fps
        _scrollAccum += _scrollSpeed * 10 / 60;
        final pixels = _scrollAccum.floor();
        if (pixels > 0) {
          _scrollAccum -= pixels;
          _scrollController.jumpTo((current + pixels).clamp(0, max));
        }
      });
      _scrollTicker!.start();
    });
  }

  void _stopScroll() {
    _scrollTicker?.stop();
    _scrollTicker?.dispose();
    _scrollTicker = null;
    setState(() { _isScrolling = false; _toolbarVisible = true; });
  }

  // -------------------------------------------------------------------------
  // Song navigation
  // -------------------------------------------------------------------------

  bool get _hasPrev =>
      widget.songIds != null &&
      widget.currentIndex != null &&
      widget.currentIndex! > 0;

  bool get _hasNext =>
      widget.songIds != null &&
      widget.currentIndex != null &&
      widget.currentIndex! < widget.songIds!.length - 1;

  void _goToPrev() {
    if (!_hasPrev) return;
    final idx = widget.currentIndex! - 1;
    final id = widget.songIds![idx];
    context.pushReplacement(
      '/performance/$id',
      extra: {
        'songIds': widget.songIds,
        'currentIndex': idx,
        'isShuffleMode': widget.isShuffleMode,
        'autoStart': false,
      },
    );
  }

  void _goToNext() {
    if (!_hasNext) return;
    final idx = widget.currentIndex! + 1;
    final id = widget.songIds![idx];
    context.pushReplacement(
      '/performance/$id',
      extra: {
        'songIds': widget.songIds,
        'currentIndex': idx,
        'isShuffleMode': widget.isShuffleMode,
        'autoStart': false,
      },
    );
  }

  // -------------------------------------------------------------------------
  // Delete
  // -------------------------------------------------------------------------

  Future<void> _deleteSong(BuildContext context) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'מחיקת שיר',
      message: 'האם למחוק את השיר לצמיתות?',
      confirmLabel: 'מחק',
      isDestructive: true,
    );
    if (confirmed != true) return;
    await ref.read(songRepositoryProvider).delete(widget.songId);
    ref.invalidate(allSongsProvider);
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(_performanceSongProvider(widget.songId));

    if (song == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _activeVersion ??= song.versions.keys.first;
    return _buildScreen(song);
  }

  Widget _buildScreen(Song song) {
    final versions = song.versions.keys.toList();
    final activeVersion =
        versions.contains(_activeVersion) ? _activeVersion! : versions.first;
    final text = song.versions[activeVersion] ?? '';

    // Compute displayed key after transpose – use version-specific key if available
    final baseKey = song.versionKeys[activeVersion]?.isNotEmpty == true
        ? song.versionKeys[activeVersion]!
        : song.originalKey;
    final displayKey = baseKey.isNotEmpty && _transposeSteps != 0
        ? TransposeEngine.transposeChord(baseKey, _transposeSteps)
        : baseKey;

    // Resolve tag objects
    final tagMap = ref.watch(allTagsProvider).valueOrNull
            ?.fold<Map<String, Tag>>({}, (m, t) => m..[t.id] = t) ??
        {};
    final songTags = song.tags.map((id) => tagMap[id]).whereType<Tag>().toList();
    final fontFamily = ref.watch(fontFamilyProvider);

    return GestureDetector(
      onTap: () => _toggleScroll(song),
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.space) {
            _toggleScroll(song);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.backspace ||
              event.logicalKey == LogicalKeyboardKey.escape) {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
            return KeyEventResult.handled;
          }
          // חצים שמאל/ימין → שיר קודם/הבא
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _goToNext();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _goToPrev();
            return KeyEventResult.handled;
          }
          // חצים למעלה/למטה → גלילה ידנית
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                (_scrollController.offset + 80).clamp(
                    0, _scrollController.position.maxScrollExtent),
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
              );
            }
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                (_scrollController.offset - 80).clamp(
                    0, _scrollController.position.maxScrollExtent),
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
              );
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
        body: Stack(
          children: [
            // Main content
            Column(
              children: [
                // Header
                SafeArea(
                  child: _Header(
                    song: song,
                    displayKey: displayKey,
                    activeVersion: activeVersion,
                    versions: versions,
                    tags: songTags,
                    isShuffleMode: widget.isShuffleMode,
                    onVersionChanged: (v) =>
                        setState(() => _activeVersion = v),
                    onBack: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                    onDelete: () => _deleteSong(context),
                  ),
                ),
                // Song content
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: SongRendererWidget(
                      text: text,
                      transposeSteps: _transposeSteps,
                      fontSize: _fontSize,
                      chordFontSize: _fontSize * _chordFontRatio,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
                // Space for toolbar
                const SizedBox(height: 64),
              ],
            ),
            // Floating toolbar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _toolbarVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_toolbarVisible,
                  child: _FloatingToolbar(
                    isScrolling: _isScrolling,
                    scrollSpeed: _scrollSpeed,
                    scrollDelay: _scrollDelay,
                    fontSize: _fontSize,
                    transposeSteps: _transposeSteps,
                    onToggleScroll: () => _toggleScroll(song),
                    onSpeedChanged: (v) => setState(() => _scrollSpeed = v),
                    onDelayChanged: (v) => setState(() => _scrollDelay = v),
                    onTranspose: (steps) =>
                        setState(() => _transposeSteps += steps),
                    onFontChange: (delta) => setState(() {
                      _fontSize =
                          (_fontSize + delta).clamp(_minFontSize, _maxFontSize);
                    }),
                    onEdit: () => context.push('/editor/${widget.songId}'),
                    onBackToTop: () => _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
              ),
            ),
            // כפתורי ניווט שיר קודם/הבא
            if (_hasPrev)
              Positioned(
                left: 0,
                top: 0,
                bottom: 64,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _toolbarVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_toolbarVisible,
                      child: IconButton(
                        icon: const Icon(Icons.chevron_left, size: 36),
                        tooltip: 'שיר קודם',
                        onPressed: _goToPrev,
                      ),
                    ),
                  ),
                ),
              ),
            if (_hasNext)
              Positioned(
                right: 0,
                top: 0,
                bottom: 64,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _toolbarVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_toolbarVisible,
                      child: IconButton(
                        icon: const Icon(Icons.chevron_right, size: 36),
                        tooltip: 'שיר הבא',
                        onPressed: _goToNext,
                      ),
                    ),
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
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.song,
    required this.displayKey,
    required this.activeVersion,
    required this.versions,
    required this.tags,
    required this.isShuffleMode,
    required this.onVersionChanged,
    required this.onBack,
    required this.onDelete,
  });

  final Song song;
  final String displayKey;
  final String activeVersion;
  final List<String> versions;
  final List<Tag> tags;
  final bool isShuffleMode;
  final void Function(String) onVersionChanged;
  final VoidCallback onBack;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'חזור',
            onPressed: onBack,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (isShuffleMode)
                  Row(
                    children: [
                      Icon(Icons.shuffle,
                          size: 12,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'ניגון אקראי',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                if (song.artist.isNotEmpty || displayKey.isNotEmpty)
                  Text(
                    [
                      if (song.artist.isNotEmpty) song.artist,
                      if (displayKey.isNotEmpty) 'סולם: $displayKey',
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: tags
                          .map((t) => TagChip(tag: t, compact: true))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
          if (versions.length > 1)
            DropdownButton<String>(
              value: activeVersion,
              items: versions
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onVersionChanged(v);
              },
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'מחק שיר',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Floating toolbar
// ---------------------------------------------------------------------------

class _FloatingToolbar extends StatelessWidget {
  const _FloatingToolbar({
    required this.isScrolling,
    required this.scrollSpeed,
    required this.scrollDelay,
    required this.fontSize,
    required this.transposeSteps,
    required this.onToggleScroll,
    required this.onSpeedChanged,
    required this.onDelayChanged,
    required this.onTranspose,
    required this.onFontChange,
    required this.onEdit,
    required this.onBackToTop,
  });

  final bool isScrolling;
  final double scrollSpeed;
  final double scrollDelay;
  final double fontSize;
  final int transposeSteps;
  final VoidCallback onToggleScroll;
  final void Function(double) onSpeedChanged;
  final void Function(double) onDelayChanged;
  final void Function(int) onTranspose;
  final void Function(double) onFontChange;
  final VoidCallback onEdit;
  final VoidCallback onBackToTop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 56,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Play/Pause
          IconButton(
            icon: Icon(isScrolling ? Icons.pause : Icons.play_arrow),
            tooltip: isScrolling ? 'עצור גלילה' : 'גלילה אוטומטית',
            onPressed: onToggleScroll,
          ),
          // Speed slider
          const Icon(Icons.speed, size: 14),
          Expanded(
            flex: 3,
            child: Slider(
              value: scrollSpeed,
              min: 0.1,
              max: 3.0,
              divisions: 9,
              onChanged: onSpeedChanged,
            ),
          ),
          SizedBox(
            width: 26,
            child: Text(
              scrollSpeed.toStringAsFixed(1),
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ),
          // Delay slider
          const Icon(Icons.timer_outlined, size: 14),
          Expanded(
            flex: 3,
            child: Slider(
              value: scrollDelay,
              min: 0,
              max: 60,
              divisions: 60,
              onChanged: onDelayChanged,
            ),
          ),
          SizedBox(
            width: 26,
            child: Text(
              '${scrollDelay.toStringAsFixed(0)}s',
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ),
          // Transpose
          IconButton(
            icon: const Text('−½', style: TextStyle(fontSize: 12)),
            onPressed: () => onTranspose(-1),
            tooltip: 'הורד חצי טון',
          ),
          Text(
            transposeSteps == 0
                ? '♩'
                : (transposeSteps > 0 ? '+$transposeSteps' : '$transposeSteps'),
            style: const TextStyle(fontSize: 12),
          ),
          IconButton(
            icon: const Text('+½', style: TextStyle(fontSize: 12)),
            onPressed: () => onTranspose(1),
            tooltip: 'העלה חצי טון',
          ),
          // Font size
          IconButton(
            icon: const Icon(Icons.text_decrease),
            onPressed: () => onFontChange(-2),
            tooltip: 'הקטן גופן',
          ),
          IconButton(
            icon: const Icon(Icons.text_increase),
            onPressed: () => onFontChange(2),
            tooltip: 'הגדל גופן',
          ),
          // Back to top
          IconButton(
            icon: const Icon(Icons.vertical_align_top),
            onPressed: onBackToTop,
            tooltip: 'חזור לתחילה',
          ),
          // Edit
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
            tooltip: 'ערוך שיר',
          ),
        ],
      ),
    );
  }
}
