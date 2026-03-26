import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/custom_chord.dart';
import '../../data/repositories/custom_chord_repository.dart';
import '../library/library_providers.dart';

class CustomChordsScreen extends ConsumerWidget {
  const CustomChordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chordsAsync = ref.watch(allCustomChordsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('אקורדים מותאמים')),
      body: chordsAsync.when(
        data: (chords) => chords.isEmpty
            ? const Center(child: Text('אין אקורדים מותאמים. לחץ + להוספה.'))
            : ReorderableListView.builder(
                itemCount: chords.length,
                onReorder: (oldIndex, newIndex) async {
                  if (newIndex > oldIndex) newIndex--;
                  final updated = List<CustomChord>.from(chords);
                  final item = updated.removeAt(oldIndex);
                  updated.insert(newIndex, item);
                  await CustomChordRepository()
                      .reorder(updated.map((c) => c.id).toList());
                  ref.invalidate(allCustomChordsProvider);
                },
                itemBuilder: (_, i) {
                  final chord = chords[i];
                  return ListTile(
                    key: ValueKey(chord.id),
                    title: Text(chord.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              _editChord(context, ref, chord),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              _deleteChord(context, ref, chord),
                        ),
                        const Icon(Icons.drag_handle),
                      ],
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('שגיאה: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addChord(context, ref),
        tooltip: 'הוסף אקורד',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addChord(BuildContext context, WidgetRef ref) async {
    final name = await _showNameDialog(context, '');
    if (name == null || name.isEmpty) return;
    final chords = ref.read(allCustomChordsProvider).valueOrNull ?? [];
    final chord = CustomChord(
      id: const Uuid().v4(),
      name: name,
      order: chords.length,
    );
    await CustomChordRepository().save(chord);
    ref.invalidate(allCustomChordsProvider);
  }

  Future<void> _editChord(
      BuildContext context, WidgetRef ref, CustomChord chord) async {
    final name = await _showNameDialog(context, chord.name);
    if (name == null || name.isEmpty) return;
    await CustomChordRepository().save(chord.copyWith(name: name));
    ref.invalidate(allCustomChordsProvider);
  }

  Future<void> _deleteChord(
      BuildContext context, WidgetRef ref, CustomChord chord) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('מחיקת אקורד'),
        content: Text('למחוק את "${chord.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ביטול')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('מחק')),
        ],
      ),
    );
    if (confirmed != true) return;
    await CustomChordRepository().delete(chord.id);
    ref.invalidate(allCustomChordsProvider);
  }

  Future<String?> _showNameDialog(BuildContext context, String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('שם האקורד'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'למשל: Fsus4, C/E, Am7...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ביטול')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
              child: const Text('שמור')),
        ],
      ),
    );
  }
}
