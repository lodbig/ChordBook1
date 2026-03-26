import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/database/database_manager.dart';
import '../library/library_providers.dart';
import '../shared/confirmation_dialog.dart';
import '../shared/theme_toggle.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final fontScale = ref.watch(fontScaleProvider);
    final isDark = mode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('הגדרות')),
      body: ListView(
        children: [
          // Theme
          ListTile(
            leading: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            title: const Text('מצב תצוגה'),
            subtitle: Text(isDark ? 'כהה' : 'בהיר'),
            trailing: Switch(
              value: isDark,
              onChanged: (_) =>
                  ref.read(themeModeProvider.notifier).toggle(),
            ),
          ),
          const Divider(),
          // Font scale
          ListTile(
            leading: const Icon(Icons.format_size_outlined),
            title: const Text('גודל טקסט'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.text_fields, size: 14),
                    Expanded(
                      child: Slider(
                        value: fontScale,
                        min: 0.8,
                        max: 1.4,
                        divisions: 6,
                        label: fontScale.toStringAsFixed(1),
                        onChanged: (v) =>
                            ref.read(fontScaleProvider.notifier).setScale(v),
                      ),
                    ),
                    const Icon(Icons.text_fields, size: 20),
                  ],
                ),
                Text(
                  'גודל נוכחי: ${fontScale.toStringAsFixed(1)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            trailing: TextButton(
              onPressed: () =>
                  ref.read(fontScaleProvider.notifier).reset(),
              child: const Text('אפס'),
            ),
          ),
          const Divider(),
          // Font family
          _FontFamilyTile(),
          const Divider(),
          // Default scroll speed
          _DefaultScrollSpeedTile(),
          const Divider(),
          // Auto-advance
          _AutoAdvanceTile(),
          const Divider(),
          // Tag management
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('ניהול תגיות'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/tags'),
          ),
          // Custom chords
          ListTile(
            leading: const Icon(Icons.piano_outlined),
            title: const Text('אקורדים מותאמים'),
            subtitle: const Text('הוסף אקורדים לסרגל העורך'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/custom-chords'),
          ),
          // Keyboard shortcuts
          ListTile(
            leading: const Icon(Icons.keyboard_outlined),
            title: const Text('קיצורי מקשים'),
            subtitle: const Text('התאם אישית קיצורי מקשים לעורך'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/shortcuts'),
          ),
          const Divider(),
          // Database export
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('ייצוא מסד נתונים'),
            subtitle: const Text('שמור עותק של כל הנתונים'),
            onTap: () => _exportDatabase(context),
          ),
          // Database import
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('ייבוא מסד נתונים'),
            subtitle: const Text('שחזר נתונים מקובץ גיבוי'),
            onTap: () => _importDatabase(context, ref),
          ),
          const Divider(),
          // About
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('אודות ChordBook'),
            subtitle: const Text('גרסה 1.0.0'),
            onTap: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('ChordBook'),
                content: const Text('גרסה 1.0.0\n© 2024'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('סגור'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportDatabase(BuildContext context) async {
    try {
      final dbPath = await DatabaseManager.getDatabasePath();
      final dbDir = Directory(dbPath);
      if (!await dbDir.exists()) {
        _showSnack(context, 'לא נמצא מסד נתונים לייצוא');
        return;
      }

      final files = dbDir.listSync().whereType<File>().toList();
      if (files.isEmpty) {
        _showSnack(context, 'אין נתונים לייצוא');
        return;
      }

      if (Platform.isWindows) {
        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: 'שמור גיבוי מסד נתונים',
          fileName: 'chordbook_backup',
          type: FileType.any,
        );
        if (savePath == null) return;
        final backupDir = Directory(savePath);
        await backupDir.create(recursive: true);
        for (final file in files) {
          await file.copy('${backupDir.path}/${file.uri.pathSegments.last}');
        }
        _showSnack(context, 'הגיבוי נשמר ב: ${backupDir.path}');
      } else {
        // Android: copy to temp dir and share
        final tempDir = await getTemporaryDirectory();
        final backupDir = Directory('${tempDir.path}/chordbook_backup');
        if (await backupDir.exists()) await backupDir.delete(recursive: true);
        await backupDir.create(recursive: true);
        final xFiles = <XFile>[];
        for (final file in files) {
          final dest = await file.copy('${backupDir.path}/${file.uri.pathSegments.last}');
          xFiles.add(XFile(dest.path));
        }
        await Share.shareXFiles(xFiles, subject: 'ChordBook גיבוי');
      }
    } catch (e) {
      _showSnack(context, 'שגיאה בייצוא: $e');
    }
  }

  Future<void> _importDatabase(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'ייבוא מסד נתונים',
      message: 'פעולה זו תחליף את כל הנתונים הקיימים. האם להמשיך?',
      confirmLabel: 'ייבא',
      isDestructive: true,
    );
    if (confirmed != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'בחר קבצי .hive לייבוא',
        type: FileType.any,
        withData: false,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      final dbPath = await DatabaseManager.getDatabasePath();
      await DatabaseManager.closeAll();

      int copied = 0;
      for (final picked in result.files) {
        if (picked.path == null) continue;
        final src = File(picked.path!);
        final dest = File('$dbPath/${picked.name}');
        await src.copy(dest.path);
        copied++;
      }

      // Invalidate all providers so UI refreshes
      ref.invalidate(allSongsProvider);
      ref.invalidate(allTagsProvider);
      ref.invalidate(allCustomChordsProvider);

      if (context.mounted) {
        _showSnack(context, 'יובאו $copied קבצים. הפעל מחדש את האפליקציה.');
      }
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, 'שגיאה בייבוא: $e');
      }
    }
  }

  void _showSnack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

// ---------------------------------------------------------------------------
// Font family tile – built-in + custom fonts
// ---------------------------------------------------------------------------

class _FontFamilyTile extends ConsumerWidget {
  const _FontFamilyTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontFamily = ref.watch(fontFamilyProvider);
    final customFonts = ref.watch(customFontsProvider);
    final systemFonts = getSystemFonts();
    final allFonts = [...systemFonts, ...customFonts];

    if (allFonts.isEmpty && customFonts.isEmpty) return const SizedBox.shrink();
    // Always show on any platform so user can add custom fonts

    // Ensure selected value is still valid
    final selectedValue = (fontFamily != null && allFonts.contains(fontFamily))
        ? fontFamily
        : null;

    // Use a sentinel for "default" since DropdownButton<String> can't have null value
    const kDefault = '__default__';

    return ListTile(
      leading: const Icon(Icons.font_download_outlined),
      title: const Text('גופן'),
      subtitle: Text(selectedValue ?? 'ברירת מחדל'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<String>(
            value: selectedValue ?? kDefault,
            items: [
              const DropdownMenuItem<String>(
                value: kDefault,
                child: Text('ברירת מחדל'),
              ),
              ...systemFonts.map((f) => DropdownMenuItem<String>(
                    value: f,
                    child: Text(f, style: TextStyle(fontFamily: f)),
                  )),
              ...customFonts.map((f) => DropdownMenuItem<String>(
                    value: f,
                    child: Row(
                      children: [
                        Text(f, style: TextStyle(fontFamily: f)),
                        const SizedBox(width: 4),
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                      ],
                    ),
                  )),
            ],
            onChanged: (v) => ref
                .read(fontFamilyProvider.notifier)
                .setFamily(v == kDefault ? null : v),
          ),
          const SizedBox(width: 4),
          // Add custom font button
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 20),
            tooltip: 'הוסף פונט מותאם',
            onPressed: () => _addCustomFont(context, ref, customFonts),
          ),
          // Remove custom font button (only if a custom font is selected)
          if (selectedValue != null && customFonts.contains(selectedValue))
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              tooltip: 'הסר פונט מותאם',
              onPressed: () async {
                await ref
                    .read(customFontsProvider.notifier)
                    .removeFont(selectedValue);
                // Reset selection if removed font was active
                await ref
                    .read(fontFamilyProvider.notifier)
                    .validateAgainst([...systemFonts, ...ref.read(customFontsProvider)]);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _addCustomFont(
    BuildContext context,
    WidgetRef ref,
    List<String> existing,
  ) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('הוסף פונט מותאם'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'שם הפונט',
                hintText: 'למשל: Rubik, Assistant...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'הכנס שם מדויק של פונט המותקן במחשב.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('הוסף'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (existing.contains(name)) return;
    await ref.read(customFontsProvider.notifier).addFont(name);
  }
}

// ---------------------------------------------------------------------------
// Default scroll speed tile
// ---------------------------------------------------------------------------

class _DefaultScrollSpeedTile extends ConsumerWidget {
  const _DefaultScrollSpeedTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(defaultScrollSpeedProvider);
    return ListTile(
      leading: const Icon(Icons.speed_outlined),
      title: const Text('מהירות גלילה ברירת מחדל'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.slow_motion_video, size: 14),
              Expanded(
                child: Slider(
                  value: speed,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: speed.toStringAsFixed(0),
                  onChanged: (v) =>
                      ref.read(defaultScrollSpeedProvider.notifier).setValue(v),
                ),
              ),
              const Icon(Icons.fast_forward, size: 14),
            ],
          ),
          Text(
            'מהירות נוכחית: ${speed.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Auto-advance tile + delay settings
// ---------------------------------------------------------------------------

class _AutoAdvanceTile extends ConsumerWidget {
  const _AutoAdvanceTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoAdvance = ref.watch(autoAdvanceProvider);
    final advanceDelay = ref.watch(autoAdvanceDelayProvider);
    final globalScrollDelay = ref.watch(globalScrollDelayProvider);
    final hasGlobalDelay = globalScrollDelay != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Toggle
        ListTile(
          leading: const Icon(Icons.skip_next_outlined),
          title: const Text('מעבר אוטומטי לשיר הבא'),
          subtitle: const Text('בסיום גלילה אוטומטית, עבור לשיר הבא'),
          trailing: Switch(
            value: autoAdvance,
            onChanged: (_) => ref.read(autoAdvanceProvider.notifier).toggle(),
          ),
        ),
        // השהיה לפני מעבר לשיר הבא
        if (autoAdvance)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'השהיה לפני מעבר לשיר הבא: ${advanceDelay.toStringAsFixed(0)}ש׳',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Row(
                  children: [
                    const Icon(Icons.hourglass_empty, size: 16),
                    Expanded(
                      child: Slider(
                        value: advanceDelay,
                        min: 0,
                        max: 30,
                        divisions: 30,
                        label: '${advanceDelay.toStringAsFixed(0)}ש׳',
                        onChanged: (v) => ref
                            .read(autoAdvanceDelayProvider.notifier)
                            .setValue(v),
                      ),
                    ),
                    const Icon(Icons.hourglass_full, size: 16),
                  ],
                ),
              ],
            ),
          ),
        // השהיה גלובלית לפני תחילת גלילה
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'השהיה גלובלית לפני גלילה',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Switch(
                    value: hasGlobalDelay,
                    onChanged: (v) => ref
                        .read(globalScrollDelayProvider.notifier)
                        .setValue(v ? 3.0 : null),
                  ),
                ],
              ),
              Text(
                hasGlobalDelay
                    ? 'גובר על הגדרת ההשהיה המקומית בכל שיר'
                    : 'כבוי – כל שיר משתמש בהגדרה המקומית שלו',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (hasGlobalDelay) ...[
                const SizedBox(height: 4),
                Text(
                  'השהיה: ${globalScrollDelay.toStringAsFixed(0)}ש׳',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 16),
                    Expanded(
                      child: Slider(
                        value: globalScrollDelay,
                        min: 0,
                        max: 30,
                        divisions: 30,
                        label: '${globalScrollDelay.toStringAsFixed(0)}ש׳',
                        onChanged: (v) => ref
                            .read(globalScrollDelayProvider.notifier)
                            .setValue(v),
                      ),
                    ),
                    const Icon(Icons.timer, size: 16),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
