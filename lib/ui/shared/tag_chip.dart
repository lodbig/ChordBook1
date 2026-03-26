import 'package:flutter/material.dart';

import '../../data/models/tag.dart';

/// A chip displaying a [Tag] name with its optional hex color as background.
///
/// [compact] reduces padding for use inside [SongCard].
/// [onDeleted] shows a delete icon (used in tag management / editor).
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.tag,
    this.compact = false,
    this.onDeleted,
    this.onTap,
  });

  final Tag tag;
  final bool compact;
  final VoidCallback? onDeleted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tagColor = _parseColor(tag.color);
    final colorScheme = Theme.of(context).colorScheme;

    final bgColor = tagColor ?? colorScheme.primary.withValues(alpha: 0.15);
    final fgColor = tagColor != null
        ? _contrastColor(tagColor)
        : colorScheme.primary;

    if (compact) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            tag.name,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      );
    }

    return InputChip(
      label: Text(tag.name),
      labelStyle: TextStyle(color: fgColor, fontWeight: FontWeight.w600),
      backgroundColor: bgColor,
      deleteIconColor: fgColor.withValues(alpha: 0.7),
      onDeleted: onDeleted,
      onPressed: onTap,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  static Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final clean = hex.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return null;
    }
  }

  /// Returns black or white depending on background luminance.
  static Color _contrastColor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.4 ? Colors.black87 : Colors.white;
  }
}
