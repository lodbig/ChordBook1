import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/tag.dart';
import '../../data/repositories/tag_repository.dart';
import '../library/library_providers.dart';
import '../shared/confirmation_dialog.dart';
import '../shared/tag_chip.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _tagRepoProvider = Provider((_) => TagRepository());

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class TagManagementScreen extends ConsumerWidget {
  const TagManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(allTagsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ניהול תגיות')),
      body: tagsAsync.when(
        data: (tags) => tags.isEmpty
            ? const Center(child: Text('אין תגיות עדיין'))
            : ListView.builder(
                itemCount: tags.length,
                itemBuilder: (_, i) => _TagTile(
                  tag: tags[i],
                  onDeleted: () => _deleteTag(context, ref, tags[i]),
                  onEdit: () => _editTag(context, ref, tags[i]),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('שגיאה: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createTag(context, ref),
        tooltip: 'הוסף תגית',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _createTag(BuildContext context, WidgetRef ref) async {
    final result = await _TagDialog.show(context);
    if (result == null) return;
    final repo = ref.read(_tagRepoProvider);
    await repo.save(Tag(id: const Uuid().v4(), name: result.name, color: result.color));
    ref.invalidate(allTagsProvider);
  }

  Future<void> _editTag(BuildContext context, WidgetRef ref, Tag tag) async {
    final result = await _TagDialog.show(context, existing: tag);
    if (result == null) return;
    final repo = ref.read(_tagRepoProvider);
    await repo.save(tag.copyWith(name: result.name, color: result.color));
    ref.invalidate(allTagsProvider);
  }

  Future<void> _deleteTag(BuildContext context, WidgetRef ref, Tag tag) async {
    final repo = ref.read(_tagRepoProvider);
    // Count songs with this tag
    final allSongs = await ref.read(songRepositoryProvider).getAll();
    final count = allSongs.where((s) => s.tags.contains(tag.id)).length;

    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'מחיקת תגית',
      message: count > 0
          ? 'פעולה זו תסיר את התגית "${tag.name}" מ-$count שירים.'
          : 'האם למחוק את התגית "${tag.name}"?',
      confirmLabel: 'מחק',
      isDestructive: true,
    );

    if (confirmed != true) return;

    await repo.removeFromAllSongs(tag.id);
    await repo.delete(tag.id);
    ref.invalidate(allTagsProvider);
  }
}

// ---------------------------------------------------------------------------
// Tag tile
// ---------------------------------------------------------------------------

class _TagTile extends StatelessWidget {
  const _TagTile({
    required this.tag,
    required this.onDeleted,
    required this.onEdit,
  });

  final Tag tag;
  final VoidCallback onDeleted;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final tagColor = tag.color != null && tag.color!.isNotEmpty
        ? Color(int.parse('FF${tag.color!.replaceFirst('#', '')}', radix: 16))
        : null;

    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: tagColor ?? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: tagColor == null
            ? const Icon(Icons.label_outline, size: 16)
            : null,
      ),
      title: Text(tag.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
            tooltip: 'ערוך',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: onDeleted,
            tooltip: 'מחק',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tag create/edit dialog
// ---------------------------------------------------------------------------

class _TagResult {
  final String name;
  final String? color;
  const _TagResult({required this.name, this.color});
}

class _TagDialog extends StatefulWidget {
  const _TagDialog({this.existing});
  final Tag? existing;

  static Future<_TagResult?> show(BuildContext context, {Tag? existing}) {
    return showDialog<_TagResult>(
      context: context,
      builder: (_) => _TagDialog(existing: existing),
    );
  }

  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  late final TextEditingController _nameCtrl;
  String? _selectedColor;

  // Preset colors for quick selection
  static const _presetColors = [
    '#E53935', '#D81B60', '#8E24AA', '#3949AB',
    '#1E88E5', '#00ACC1', '#43A047', '#F4511E',
    '#FB8C00', '#F9A825', '#6D4C41', '#546E7A',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _selectedColor = widget.existing?.color;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'תגית חדשה' : 'ערוך תגית'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'שם התגית',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          const Text('צבע (אופציונלי):'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // "No color" option
              GestureDetector(
                onTap: () => setState(() => _selectedColor = null),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedColor == null
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      width: _selectedColor == null ? 3 : 1,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.block, size: 18, color: Colors.grey),
                ),
              ),
              ..._presetColors.map((hex) {
                final color = Color(int.parse('FF${hex.substring(1)}', radix: 16));
                final isSelected = _selectedColor == hex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = hex),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ביטול'),
        ),
        TextButton(
          autofocus: true,
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(_TagResult(name: name, color: _selectedColor));
          },
          child: const Text('שמור'),
        ),
      ],
    );
  }
}
