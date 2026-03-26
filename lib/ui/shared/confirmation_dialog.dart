import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A reusable confirmation dialog with a title, optional message,
/// a confirm button (destructive by default), and a cancel button.
///
/// Returns `true` if the user confirms, `false` / `null` otherwise.
///
/// Usage:
/// ```dart
/// final confirmed = await ConfirmationDialog.show(
///   context,
///   title: 'מחיקת שיר',
///   message: 'האם אתה בטוח שברצונך למחוק את השיר?',
///   confirmLabel: 'מחק',
///   isDestructive: true,
/// );
/// if (confirmed == true) { ... }
/// ```
class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    super.key,
    required this.title,
    this.message,
    this.confirmLabel = 'אישור',
    this.cancelLabel = 'ביטול',
    this.isDestructive = false,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  /// Convenience static method to show the dialog and await the result.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'אישור',
    String cancelLabel = 'ביטול',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmColor =
        isDestructive ? colorScheme.error : colorScheme.primary;

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          Navigator.of(context).pop(true);
        }
      },
      child: AlertDialog(
        title: Text(title),
        content: message != null ? Text(message!) : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: confirmColor),
            child: Text(
              confirmLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
