import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/shortcut_definition.dart';
import 'shortcut_providers.dart';

class ShortcutsSettingsScreen extends ConsumerWidget {
  const ShortcutsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortcuts = ref.watch(shortcutsProvider);
    final fixedEntries = shortcuts.values.toList();
    final customShortcuts = ref.watch(dynamicCustomChordShortcutsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('קיצורי מקשים')),
      body: ListView(
        children: [
          // --- קיצורים קבועים ---
          ...List.generate(fixedEntries.length, (i) {
            final s = fixedEntries[i];
            return Column(
              children: [
                ListTile(
                  title: Text(s.label),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(label: Text(s.displayString)),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'שנה קיצור',
                        onPressed: () => _showCaptureDialog(context, ref, s),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
            );
          }),

          // --- קיצורים לאקורדים מותאמים ---
          if (customShortcuts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'אקורדים מותאמים',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            const Divider(height: 1),
            ...customShortcuts.map((s) {
              final isUnset = s.key == kNoKey;
              return Column(
                children: [
                  ListTile(
                    title: Text(s.label),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(isUnset ? 'לא מוגדר' : s.displayString),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'שנה קיצור',
                          onPressed: () =>
                              _showCaptureDialog(context, ref, s, isDynamic: true),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  Future<void> _showCaptureDialog(
    BuildContext context,
    WidgetRef ref,
    ShortcutDefinition current, {
    bool isDynamic = false,
  }) async {
    final result = await showDialog<_ShortcutResult>(
      context: context,
      builder: (_) => _ShortcutCaptureDialog(current: current, isDynamic: isDynamic),
    );
    if (result == null) return;

    if (result.isReset) {
      await ref.read(shortcutsProvider.notifier).reset(current.id);
      return;
    }

    final conflictId = await ref.read(shortcutsProvider.notifier).update(result.shortcut!);
    if (conflictId != null && context.mounted) {
      final shortcuts = ref.read(shortcutsProvider);
      final conflictLabel = shortcuts[conflictId]?.label ?? conflictId;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('הקיצור כבר בשימוש עבור: $conflictLabel'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

class _ShortcutResult {
  final ShortcutDefinition? shortcut;
  final bool isReset;
  const _ShortcutResult({this.shortcut, this.isReset = false});
}

// ---------------------------------------------------------------------------
// Capture dialog
// ---------------------------------------------------------------------------

class _ShortcutCaptureDialog extends StatefulWidget {
  const _ShortcutCaptureDialog({required this.current, this.isDynamic = false});
  final ShortcutDefinition current;
  final bool isDynamic;

  @override
  State<_ShortcutCaptureDialog> createState() => _ShortcutCaptureDialogState();
}

class _ShortcutCaptureDialogState extends State<_ShortcutCaptureDialog> {
  ShortcutDefinition? _captured;
  bool _listening = false;

  @override
  Widget build(BuildContext context) {
    final display = _captured ?? widget.current;
    final isUnset = display.key == kNoKey && _captured == null;

    return AlertDialog(
      title: Text('שנה קיצור: ${widget.current.label}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _listening ? 'לחץ על שילוב מקשים...' : 'קיצור נוכחי:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.control ||
                  event.logicalKey == LogicalKeyboardKey.controlLeft ||
                  event.logicalKey == LogicalKeyboardKey.controlRight ||
                  event.logicalKey == LogicalKeyboardKey.alt ||
                  event.logicalKey == LogicalKeyboardKey.altLeft ||
                  event.logicalKey == LogicalKeyboardKey.altRight ||
                  event.logicalKey == LogicalKeyboardKey.shift ||
                  event.logicalKey == LogicalKeyboardKey.shiftLeft ||
                  event.logicalKey == LogicalKeyboardKey.shiftRight) {
                return KeyEventResult.ignored;
              }
              final hw = HardwareKeyboard.instance;
              setState(() {
                _listening = false;
                _captured = widget.current.copyWith(
                  key: event.logicalKey,
                  ctrl: hw.isControlPressed,
                  alt: hw.isAltPressed,
                  shift: hw.isShiftPressed,
                );
              });
              return KeyEventResult.handled;
            },
            child: GestureDetector(
              onTap: () => setState(() => _listening = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _listening
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                    width: _listening ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isUnset ? 'לא מוגדר' : display.displayString,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
          ),
          if (_listening)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'לחץ על שילוב המקשים הרצוי',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ביטול'),
        ),
        // כפתור אפס: לקיצורים דינמיים – מוחק מה-repo; לקבועים – מחזיר לברירת מחדל
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(const _ShortcutResult(isReset: true));
          },
          child: Text(widget.isDynamic ? 'נקה' : 'אפס לברירת מחדל'),
        ),
        FilledButton(
          onPressed: _captured == null
              ? null
              : () => Navigator.of(context).pop(_ShortcutResult(shortcut: _captured)),
          child: const Text('שמור'),
        ),
      ],
    );
  }
}
