import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/custom_chord.dart';
import '../../data/models/song.dart';
import '../../data/models/tag.dart';
import '../../data/repositories/custom_chord_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../domain/transpose_engine.dart';
import '../library/library_providers.dart';
import '../shared/confirmation_dialog.dart';
import '../shared/song_renderer_widget.dart';
import '../shared/theme_toggle.dart';
import 'editor_keyboard_handler.dart';
import 'editor_providers.dart';

class SongEditorScreen extends ConsumerStatefulWidget {
  const SongEditorScreen({super.key, required this.songId});
  final String songId;

  @override
  ConsumerState<SongEditorScreen> createState() => _SongEditorScreenState();
}

class _SongEditorScreenState extends ConsumerState<SongEditorScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  // version name → controller; rebuilt when version list changes
  final Map<String, TextEditingController> _versionControllers = {};
  List<String> _knownVersions =[];
  int _lastCursorOffset = -1;
  int? _pendingNudge;
  int? _pendingChordIndex;

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _versionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Called every build with the latest song.
  /// - Rebuilds TabController only when the version list changes.
  /// - Creates controllers for new versions.
  /// - Updates controller text when the stored text differs from what's shown
  ///   (e.g. after a transpose or external save) WITHOUT disturbing the cursor
  ///   if the user is actively typing.
  void _syncControllers(Song song) {
    final versions = song.versions.keys.toList();

    // Rebuild TabController if version list changed
    if (!_listEquals(versions, _knownVersions)) {
      final prevIndex = _tabController.index;
      _tabController.dispose();
      _tabController = TabController(
        length: versions.length,
        vsync: this,
        initialIndex: prevIndex.clamp(0, versions.length - 1),
      );
      _tabController.addListener(() => setState(() {}));
      _knownVersions = List.from(versions);
    }

    // Create controllers for new versions only – do NOT overwrite existing ones
    // (text sync for active version is handled by _RawEditorState.didUpdateWidget)
    for (final v in versions) {
      if (!_versionControllers.containsKey(v)) {
        final stored = song.versions[v] ?? '';
        _versionControllers[v] = ChordHighlightingTextEditingController(text: stored);
      }
    }

    // Remove controllers for deleted versions
    _versionControllers.removeWhere((k, ctrl) {
      if (!versions.contains(k)) {
        ctrl.dispose();
        return true;
      }
      return false;
    });
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _tabController.addListener(() => setState(() {}));
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
    final repo = ref.read(songRepositoryProvider);
    await repo.delete(widget.songId);
    ref.invalidate(allSongsProvider);
    if (mounted) context.go('/');
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final songAsync = ref.watch(currentSongProvider(widget.songId));

    if (songAsync == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _syncControllers(songAsync);
    final versions = songAsync.versions.keys.toList();
    final activeVersion = versions.isNotEmpty
        ? versions[_tabController.index.clamp(0, versions.length - 1)]
        : null;

    final isWindows = Platform.isWindows;

    return Scaffold(
      appBar: AppBar(
        title: Text(songAsync.title.isEmpty ? 'שיר חדש' : songAsync.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'חזור',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions:[
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'מחק שיר',
            onPressed: () => _deleteSong(context),
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'שמור',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: EditorKeyboardHandler(
        onNudgeLeft: () => setState(() => _pendingNudge = 1),
        onNudgeRight: () => setState(() => _pendingNudge = -1),
        onChordAtIndex: (i) => setState(() => _pendingChordIndex = i),
        onCustomChordById: (chordId) {
          final customChords =
              ref.read(allCustomChordsProvider).valueOrNull ?? [];
          final chord = customChords.firstWhere(
            (c) => c.id == chordId,
            orElse: () => customChords.isEmpty ? customChords.first : customChords.first,
          );
          // Find index in custom chords list and use pendingChordIndex offset
          final diatonicCount = () {
            final song = ref.read(currentSongProvider(widget.songId));
            if (song == null) return 0;
            final versions = song.versions.keys.toList();
            final activeVersion = versions.isNotEmpty
                ? versions[_tabController.index.clamp(0, versions.length - 1)]
                : null;
            final key = activeVersion != null
                ? (song.versionKeys[activeVersion]?.isNotEmpty == true
                    ? song.versionKeys[activeVersion]!
                    : song.originalKey)
                : song.originalKey;
            return key.isNotEmpty
                ? TransposeEngine.getDiatonicChords(key).length
                : 0;
          }();
          final idx = customChords.indexWhere((c) => c.id == chordId);
          if (idx >= 0) {
            setState(() => _pendingChordIndex = diatonicCount + idx);
          }
        },
        child: Column(
          children:[
            // Header area
            _HeaderArea(song: songAsync, songId: widget.songId, activeVersion: activeVersion),
            // Version tabs
            _VersionTabBar(
              song: songAsync,
              songId: widget.songId,
              tabController: _tabController,
            ),
            // Split editor
            Expanded(
              child: isWindows
                  ? _VerticalSplit(
                      song: songAsync,
                      songId: widget.songId,
                      activeVersion: activeVersion,
                      versionControllers: _versionControllers,
                      onCursorOffsetChanged: (offset) =>
                          setState(() => _lastCursorOffset = offset),
                    )
                  : _HorizontalSplit(
                      song: songAsync,
                      songId: widget.songId,
                      activeVersion: activeVersion,
                      versionControllers: _versionControllers,
                      onCursorOffsetChanged: (offset) =>
                          setState(() => _lastCursorOffset = offset),
                    ),
            ),
            // Chord bar
            if (activeVersion != null)
              _ChordBar(
                song: songAsync,
                songId: widget.songId,
                activeVersion: activeVersion,
                controller: _versionControllers[activeVersion],
                lastCursorOffset: _lastCursorOffset,
                onCursorOffsetChanged: (offset) =>
                    setState(() => _lastCursorOffset = offset),
                pendingNudge: _pendingNudge,
                pendingChordIndex: _pendingChordIndex,
                onPendingConsumed: () => setState(() {
                  _pendingNudge = null;
                  _pendingChordIndex = null;
                }),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header area
// ---------------------------------------------------------------------------

class _HeaderArea extends ConsumerStatefulWidget {
  const _HeaderArea({required this.song, required this.songId, required this.activeVersion});
  final Song song;
  final String songId;
  final String? activeVersion;

  @override
  ConsumerState<_HeaderArea> createState() => _HeaderAreaState();
}

class _HeaderAreaState extends ConsumerState<_HeaderArea> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _artistCtrl;

  static const _keys =[
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
    'Cm', 'C#m', 'Dm', 'D#m', 'Em', 'Fm', 'F#m', 'Gm', 'G#m', 'Am', 'A#m', 'Bm',
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.song.title);
    _artistCtrl = TextEditingController(text: widget.song.artist);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(currentSongProvider(widget.songId).notifier);
    final tagsAsync = ref.watch(allTagsProvider);
    final allTags = tagsAsync.valueOrNull ??[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          Row(
            children:[
              Expanded(
                child: TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'שם השיר',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => notifier.updateField(title: v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _artistCtrl,
                  decoration: const InputDecoration(
                    labelText: 'אמן',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => notifier.updateField(artist: v),
                ),
              ),
              const SizedBox(width: 8),
              // Key dropdown - per version
              DropdownButton<String>(
                value: () {
                  final v = widget.activeVersion;
                  if (v == null) return null;
                  final k = widget.song.versionKeys[v] ?? widget.song.originalKey;
                  return _keys.contains(k) ? k : null;
                }(),
                hint: const Text('סולם'),
                items: _keys
                    .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                    .toList(),
                onChanged: (v) {
                  final activeV = widget.activeVersion;
                  if (activeV == null) return;
                  final newKeys = Map<String, String>.from(widget.song.versionKeys)
                    ..[activeV] = v ?? '';
                  notifier.updateField(versionKeys: newKeys);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children:[
              // Tags multi-select
              Expanded(
                child: _TagsSelector(
                  allTags: allTags,
                  selectedTagIds: widget.song.tags,
                  onChanged: (ids) => notifier.updateField(tags: ids),
                  onTagCreated: (_) => ref.invalidate(allTagsProvider),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tags multi-select
// ---------------------------------------------------------------------------

class _TagsSelector extends StatelessWidget {
  const _TagsSelector({
    required this.allTags,
    required this.selectedTagIds,
    required this.onChanged,
    required this.onTagCreated,
  });

  final List<Tag> allTags;
  final List<String> selectedTagIds;
  final void Function(List<String>) onChanged;
  final void Function(Tag) onTagCreated;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'תגיות',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        child: Wrap(
          spacing: 4,
          children: selectedTagIds.isEmpty
              ?[const Text('בחר תגיות...', style: TextStyle(color: Colors.grey))]
              : selectedTagIds.map((id) {
                  final tag = allTags.firstWhere(
                    (t) => t.id == id,
                    orElse: () => Tag(id: id, name: id),
                  );
                  return Chip(
                    label: Text(tag.name),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  );
                }).toList(),
        ),
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final selected = Set<String>.from(selectedTagIds);
    // Use a ValueNotifier so the dialog can react to new tags being added
    final tagsNotifier = ValueNotifier<List<Tag>>(List.from(allTags));

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Row(
            children:[
              const Expanded(child: Text('בחר תגיות')),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'תגית חדשה',
                onPressed: () async {
                  final newTag = await _createNewTag(ctx, tagsNotifier.value);
                  if (newTag != null) {
                    tagsNotifier.value = [...tagsNotifier.value, newTag];
                    selected.add(newTag.id);
                    setState(() {});
                    onTagCreated(newTag);
                  }
                },
              ),
            ],
          ),
          content: SizedBox(
            width: 300,
            child: ValueListenableBuilder<List<Tag>>(
              valueListenable: tagsNotifier,
              builder: (_, tags, __) => ListView(
                shrinkWrap: true,
                children: tags.map((t) {
                  return CheckboxListTile(
                    title: Text(t.name),
                    value: selected.contains(t.id),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          selected.add(t.id);
                        } else {
                          selected.remove(t.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          actions:[
            TextButton(
              onPressed: () {
                onChanged(selected.toList());
                Navigator.of(ctx).pop();
              },
              child: const Text('אישור'),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a simple "new tag" dialog and saves to repo. Returns the created tag.
  Future<Tag?> _createNewTag(BuildContext context, List<Tag> existing) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('תגית חדשה'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'שם התגית',
            border: OutlineInputBorder(),
          ),
        ),
        actions:[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('צור'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return null;
    if (existing.any((t) => t.name == name)) return null; // duplicate
    final tag = Tag(id: const Uuid().v4(), name: name);
    await TagRepository().save(tag);
    return tag;
  }
}

// ---------------------------------------------------------------------------
// Version tab bar
// ---------------------------------------------------------------------------

class _VersionTabBar extends ConsumerWidget {
  const _VersionTabBar({
    required this.song,
    required this.songId,
    required this.tabController,
  });

  final Song song;
  final String songId;
  final TabController tabController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versions = song.versions.keys.toList();
    final notifier = ref.read(currentSongProvider(songId).notifier);

    return Row(
      children:[
        Expanded(
          child: TabBar(
            controller: tabController,
            isScrollable: true,
            tabs: versions.map((v) => GestureDetector(
              onLongPress: () => _renameVersion(context, notifier, versions, v),
              child: Tab(text: v),
            )).toList(),
          ),
        ),
        // Add version button
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'הוסף גרסה',
          onPressed: () => _addVersion(context, notifier, versions),
        ),
        // Delete version button (disabled if only one version)
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'מחק גרסה',
          onPressed: versions.length <= 1
              ? null
              : () => _deleteVersion(context, notifier, versions, tabController.index),
        ),
      ],
    );
  }

  Future<void> _addVersion(
    BuildContext context,
    CurrentSongNotifier notifier,
    List<String> existing,
  ) async {
    final nameCtrl = TextEditingController();
    String? copyFrom;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('הוסף גרסה'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children:[
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'שם הגרסה',
                  hintText: 'למשל: קל, מקורי...',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: copyFrom,
                decoration: const InputDecoration(
                  labelText: 'העתק מגרסה קיימת (אופציונלי)',
                  border: OutlineInputBorder(),
                ),
                items:[
                  const DropdownMenuItem(value: null, child: Text('ריק')),
                  ...existing.map((v) => DropdownMenuItem(value: v, child: Text(v))),
                ],
                onChanged: (v) => setState(() => copyFrom = v),
              ),
            ],
          ),
          actions:[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ביטול'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop({
                'name': nameCtrl.text.trim(),
                'copyFrom': copyFrom,
              }),
              child: const Text('הוסף'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    final name = result['name'] as String;
    if (name.isEmpty || existing.contains(name)) return;
    // קרא את ה-state הנוכחי כדי לא לאבד שינויים שהמשתמש הקליד
    final currentSong = notifier.getCurrentSong();
    if (currentSong == null) return;
    final sourceText = copyFrom != null ? (currentSong.versions[copyFrom] ?? '') : '';
    final newVersions = Map<String, String>.from(currentSong.versions)..[name] = sourceText;
    await notifier.updateField(versions: newVersions);
  }

  Future<void> _renameVersion(
    BuildContext context,
    CurrentSongNotifier notifier,
    List<String> versions,
    String currentName,
  ) async {
    final ctrl = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('שנה שם גרסה'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions:[
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
    if (newName == null || newName.isEmpty || newName == currentName) return;
    if (versions.contains(newName)) return; // duplicate
    final currentSong = notifier.getCurrentSong();
    if (currentSong == null) return;
    // Rebuild versions map preserving order
    final newVersions = <String, String>{};
    for (final v in versions) {
      newVersions[v == currentName ? newName : v] = currentSong.versions[v] ?? '';
    }
    // Rebuild versionKeys map
    final newVersionKeys = <String, String>{};
    for (final entry in currentSong.versionKeys.entries) {
      newVersionKeys[entry.key == currentName ? newName : entry.key] = entry.value;
    }
    await notifier.updateField(versions: newVersions, versionKeys: newVersionKeys);
  }

  Future<void> _deleteVersion(
    BuildContext context,
    CurrentSongNotifier notifier,
    List<String> versions,
    int index,
  ) async {
    final versionName = versions[index];
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'מחיקת גרסה',
      message: 'האם למחוק את הגרסה "$versionName"?',
      confirmLabel: 'מחק',
      isDestructive: true,
    );
    if (confirmed != true) return;
    final currentSong = notifier.getCurrentSong();
    if (currentSong == null) return;
    final newVersions = Map<String, String>.from(currentSong.versions)..remove(versionName);
    final newVersionKeys = Map<String, String>.from(currentSong.versionKeys)..remove(versionName);
    await notifier.updateField(versions: newVersions, versionKeys: newVersionKeys);
  }
}

// ---------------------------------------------------------------------------
// Split layouts
// ---------------------------------------------------------------------------

class _VerticalSplit extends ConsumerWidget {
  const _VerticalSplit({
    required this.song,
    required this.songId,
    required this.activeVersion,
    required this.versionControllers,
    required this.onCursorOffsetChanged,
  });

  final Song song;
  final String songId;
  final String? activeVersion;
  final Map<String, TextEditingController> versionControllers;
  final void Function(int) onCursorOffsetChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (activeVersion == null) return const SizedBox();
    final ctrl = versionControllers[activeVersion!];
    if (ctrl == null) return const SizedBox();
    final fontFamily = ref.watch(fontFamilyProvider);

    return Row(
      children:[
        Expanded(child: _RawEditor(ctrl: ctrl, song: song, songId: songId, version: activeVersion!, onCursorOffsetChanged: onCursorOffsetChanged)),
        const VerticalDivider(width: 1),
        Expanded(child: _LivePreview(controller: ctrl, fontFamily: fontFamily)),
      ],
    );
  }
}

class _HorizontalSplit extends ConsumerWidget {
  const _HorizontalSplit({
    required this.song,
    required this.songId,
    required this.activeVersion,
    required this.versionControllers,
    required this.onCursorOffsetChanged,
  });

  final Song song;
  final String songId;
  final String? activeVersion;
  final Map<String, TextEditingController> versionControllers;
  final void Function(int) onCursorOffsetChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (activeVersion == null) return const SizedBox();
    final ctrl = versionControllers[activeVersion!];
    if (ctrl == null) return const SizedBox();
    final fontFamily = ref.watch(fontFamilyProvider);

    return Column(
      children:[
        Expanded(child: _RawEditor(ctrl: ctrl, song: song, songId: songId, version: activeVersion!, onCursorOffsetChanged: onCursorOffsetChanged)),
        const Divider(height: 1),
        Expanded(child: _LivePreview(controller: ctrl, fontFamily: fontFamily)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Raw editor panel
// ---------------------------------------------------------------------------

class _RawEditor extends ConsumerStatefulWidget {
  const _RawEditor({
    required this.ctrl,
    required this.song,
    required this.songId,
    required this.version,
    required this.onCursorOffsetChanged,
  });

  final TextEditingController ctrl;
  final Song song;
  final String songId;
  final String version;
  final void Function(int) onCursorOffsetChanged;

  @override
  ConsumerState<_RawEditor> createState() => _RawEditorState();
}

class _RawEditorState extends ConsumerState<_RawEditor> {
  bool _suppressSync = false;

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(_RawEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ctrl != widget.ctrl) {
      oldWidget.ctrl.removeListener(_onControllerChanged);
      widget.ctrl.addListener(_onControllerChanged);
    }
    // אם הטקסט השתנה מבחוץ (למשל transpose או הוספת גרסה), עדכן בלי להפעיל sync
    final stored = ref.read(currentSongProvider(widget.songId))
        ?.versions[widget.version] ?? '';
    if (widget.ctrl.text != stored) {
      _suppressSync = true;
      widget.ctrl.value = TextEditingValue(
        text: stored,
        selection: TextSelection.collapsed(offset: stored.length),
      );
      _suppressSync = false;
    }
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (_suppressSync) return;
    // Report cursor position to parent so chord bar can insert at correct spot
    final sel = widget.ctrl.selection;
    if (sel.isValid) {
      widget.onCursorOffsetChanged(sel.baseOffset);
    }
    // Sync text to Riverpod state – read current state to avoid stale versions map
    final notifier = ref.read(currentSongProvider(widget.songId).notifier);
    final currentSong = ref.read(currentSongProvider(widget.songId));
    if (currentSong == null) return;
    final newVersions = Map<String, String>.from(currentSong.versions)
      ..[widget.version] = widget.ctrl.text;
    notifier.updateField(versions: newVersions);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          final isLeft = event.logicalKey == LogicalKeyboardKey.arrowLeft;
          final isRight = event.logicalKey == LogicalKeyboardKey.arrowRight;
          if (!isLeft && !isRight) return KeyEventResult.ignored;

          // אם Ctrl לחוץ – זה קיצור מקלדת להזזת אקורד, לא לטפל כאן
          final isCtrl = HardwareKeyboard.instance.isControlPressed;
          if (isCtrl) return KeyEventResult.ignored;

          final ctrl = widget.ctrl;
          final text = ctrl.text;
          final sel = ctrl.selection;
          if (!sel.isValid) return KeyEventResult.ignored;

          // RTL: arrowLeft → move right (+1), arrowRight → move left (-1)
          final delta = isLeft ? 1 : -1;
          final newOffset = (sel.baseOffset + delta).clamp(0, text.length);
          ctrl.selection = TextSelection.collapsed(offset: newOffset);
          return KeyEventResult.handled;
        },
        child: TextField(
          controller: widget.ctrl,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: TextStyle(
            fontFamily: ref.watch(fontFamilyProvider) ?? 'monospace',
            fontSize: 14,
          ),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'הכנס טקסט עם[אקורדים]...',
            contentPadding: EdgeInsets.all(12),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live preview panel
// ---------------------------------------------------------------------------

class _LivePreview extends StatefulWidget {
  const _LivePreview({required this.controller, this.fontFamily});
  final TextEditingController controller;
  final String? fontFamily;

  @override
  State<_LivePreview> createState() => _LivePreviewState();
}

class _LivePreviewState extends State<_LivePreview> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(_LivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SongRendererWidget(
        text: widget.controller.text,
        fontFamily: widget.fontFamily,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chord bar
// ---------------------------------------------------------------------------

class _ChordBar extends ConsumerWidget {
  const _ChordBar({
    required this.song,
    required this.songId,
    required this.activeVersion,
    required this.controller,
    required this.lastCursorOffset,
    required this.onCursorOffsetChanged,
    this.pendingNudge,
    this.pendingChordIndex,
    this.onPendingConsumed,
  });

  final Song song;
  final String songId;
  final String activeVersion;
  final TextEditingController? controller;
  final int lastCursorOffset;
  final void Function(int) onCursorOffsetChanged;
  final int? pendingNudge;
  final int? pendingChordIndex;
  final VoidCallback? onPendingConsumed;

  /// Inserts [chord] at the last known cursor position.
  void _insertChord(WidgetRef ref, String chord) {
    final ctrl = controller;
    if (ctrl == null) return;

    final text = ctrl.text;
    final insertPos = (lastCursorOffset >= 0 && lastCursorOffset <= text.length)
        ? lastCursorOffset
        : text.length;
    final inserted = '[$chord]';
    final newText = text.substring(0, insertPos) + inserted + text.substring(insertPos);
    final newOffset = insertPos + inserted.length;
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    onCursorOffsetChanged(newOffset);
    // Use current Riverpod state to avoid stale versions map
    final notifier = ref.read(currentSongProvider(songId).notifier);
    final currentSong = ref.read(currentSongProvider(songId));
    if (currentSong == null) return;
    final newVersions = Map<String, String>.from(currentSong.versions)
      ..[activeVersion] = newText;
    notifier.updateField(versions: newVersions);
  }

  void _transpose(WidgetRef ref, int steps) {
    final ctrl = controller;
    final notifier = ref.read(currentSongProvider(songId).notifier);
    final currentSong = ref.read(currentSongProvider(songId));
    if (currentSong == null) return;
    final current = currentSong.versions[activeVersion] ?? '';
    final transposed = TransposeEngine.transposeText(current, steps);
    final newVersions = Map<String, String>.from(currentSong.versions)
      ..[activeVersion] = transposed;
    // Update the key for this version
    final currentKey = currentSong.versionKeys[activeVersion]?.isNotEmpty == true
        ? currentSong.versionKeys[activeVersion]!
        : currentSong.originalKey;
    final newKey = currentKey.isNotEmpty
        ? TransposeEngine.transposeChord(currentKey, steps)
        : '';
    final newVersionKeys = Map<String, String>.from(currentSong.versionKeys)
      ..[activeVersion] = newKey;
    notifier.updateField(versions: newVersions, versionKeys: newVersionKeys);
    if (ctrl != null) {
      ctrl.value = TextEditingValue(
        text: transposed,
        selection: TextSelection.collapsed(offset: transposed.length),
      );
    }
  }

  /// Nudge the chord right or left
  void _nudgeChord(WidgetRef ref, int direction) {
    final ctrl = controller;
    if (ctrl == null) return;

    final text = ctrl.text;
    final cursor = lastCursorOffset;
    if (cursor < 0 || cursor > text.length) return;

    // חיפוש האקורד שהסמן נמצא בתוכו או צמוד אליו
    final RegExp chordRegExp = RegExp(r'\[.*?\]');
    final matches = chordRegExp.allMatches(text);
    
    RegExpMatch? targetMatch;
    for (final m in matches) {
      if (cursor >= m.start && cursor <= m.end) {
        targetMatch = m;
        break;
      }
    }

    if (targetMatch == null) return;

    final chordText = targetMatch.group(0)!;
    String newText = text;
    int newCursor = cursor;

    if (direction == -1) {
      // הזזה למיקום מוקדם יותר במחרוזת (מזיז ימינה ויזואלית בעברית RTL)
      if (targetMatch.start > 0) {
        final charBefore = text.substring(targetMatch.start - 1, targetMatch.start);
        newText = text.substring(0, targetMatch.start - 1) +
                  chordText +
                  charBefore +
                  text.substring(targetMatch.end);
        newCursor = cursor - 1;
      }
    } else {
      // הזזה למיקום מאוחר במחרוזת (מזיז שמאלה ויזואלית בעברית RTL)
      if (targetMatch.end < text.length) {
        final charAfter = text.substring(targetMatch.end, targetMatch.end + 1);
        newText = text.substring(0, targetMatch.start) +
                  charAfter +
                  chordText +
                  text.substring(targetMatch.end + 1);
        newCursor = cursor + 1;
      }
    }

    if (newText != text) {
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
      onCursorOffsetChanged(newCursor);
      // _onControllerChanged ב-_RawEditor יסנכרן את הטקסט ל-Riverpod
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Handle pending keyboard shortcut actions
    if (pendingNudge != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _nudgeChord(ref, pendingNudge!);
        onPendingConsumed?.call();
      });
    }
    if (pendingChordIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final diatonicNow = () {
          final key = song.versionKeys[activeVersion]?.isNotEmpty == true
              ? song.versionKeys[activeVersion]!
              : song.originalKey;
          return key.isNotEmpty ? TransposeEngine.getDiatonicChords(key) : <String>[];
        }();
        final customChordsNow = ref.read(allCustomChordsProvider).valueOrNull ?? [];
        final allChords = [...diatonicNow, ...customChordsNow.map((c) => c.name)];
        final idx = pendingChordIndex!;
        if (idx >= 0 && idx < allChords.length) {
          _insertChord(ref, allChords[idx]);
        }
        onPendingConsumed?.call();
      });
    }

    final diatonic = () {
      final v = activeVersion;
      final key = v != null
          ? (song.versionKeys[v]?.isNotEmpty == true
              ? song.versionKeys[v]!
              : song.originalKey)
          : song.originalKey;
      return key.isNotEmpty ? TransposeEngine.getDiatonicChords(key) : <String>[];
    }();
    final customChordsAsync = ref.watch(allCustomChordsProvider);
    final customChords = customChordsAsync.valueOrNull ??[];

    return Container(
      height: 52,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children:[
          // Diatonic chords
          ...diatonic.map((c) => _ChordButton(
                chord: c,
                onTap: () => _insertChord(ref, c),
              )),
          if (diatonic.isNotEmpty) const _Divider(),
          
          // Custom chords
          ...customChords.map((c) => _ChordButton(
                chord: c.name,
                onTap: () => _insertChord(ref, c.name),
                isCustom: true,
              )),
          if (customChords.isNotEmpty) const _Divider(),

          // כפתורי הזזה (Nudge)
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'הזז אקורד ימינה',
            onPressed: () => _nudgeChord(ref, -1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'הזז אקורד שמאלה',
            onPressed: () => _nudgeChord(ref, 1),
          ),
          const _Divider(),

          // Transpose
          _TransposeButton(label: '−½', onTap: () => _transpose(ref, -1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                () {
                  final k = song.versionKeys[activeVersion]?.isNotEmpty == true
                      ? song.versionKeys[activeVersion]!
                      : song.originalKey;
                  return k.isEmpty ? '?' : k;
                }(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          _TransposeButton(label: '+½', onTap: () => _transpose(ref, 1)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const VerticalDivider(width: 16, indent: 8, endIndent: 8);
}

class _ChordButton extends StatelessWidget {
  const _ChordButton({required this.chord, required this.onTap, this.isCustom = false});
  final String chord;
  final VoidCallback onTap;
  final bool isCustom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: isCustom
              ? BorderSide(color: Theme.of(context).colorScheme.tertiary)
              : null,
        ),
        child: Text(chord, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

class _TransposeButton extends StatelessWidget {
  const _TransposeButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom Controller for Syntax Highlighting Chords
// ---------------------------------------------------------------------------

class ChordHighlightingTextEditingController extends TextEditingController {
  ChordHighlightingTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final String sourceText = text;
    if (sourceText.isEmpty) {
      return TextSpan(style: style, text: sourceText);
    }

    // מזהה כל טקסט שבתוך סוגריים מרובעים
    final RegExp chordRegExp = RegExp(r'\[.*?\]');
    final Iterable<RegExpMatch> matches = chordRegExp.allMatches(sourceText);

    if (matches.isEmpty) {
      return TextSpan(style: style, text: sourceText);
    }

    final List<TextSpan> spans =[];
    int currentIndex = 0;

    // עיצוב שמבליט את האקורד כמו "בלוק"
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chordStyle = style?.copyWith(
      color: isDark ? Colors.lightBlueAccent : Colors.blue[800],
      fontWeight: FontWeight.bold,
      backgroundColor: isDark 
          ? Colors.lightBlueAccent.withValues(alpha: 0.2)
          : Colors.blue.withValues(alpha: 0.15),
    );

    for (final RegExpMatch match in matches) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: sourceText.substring(currentIndex, match.start),
          style: style,
        ));
      }

      // האקורד המודגש עצמו
      spans.add(TextSpan(
        text: sourceText.substring(match.start, match.end),
        style: chordStyle,
      ));

      currentIndex = match.end;
    }

    if (currentIndex < sourceText.length) {
      spans.add(TextSpan(
        text: sourceText.substring(currentIndex),
        style: style,
      ));
    }

    return TextSpan(style: style, children: spans);
  }
}