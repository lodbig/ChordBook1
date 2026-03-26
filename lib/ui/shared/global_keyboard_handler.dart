import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// עוטף את כל האפליקציה ומטפל בקיצורי מקלדת גלובליים:
/// - Backspace מחוץ לשדה טקסט → חזרה למסך הקודם
/// - Enter → מועבר ל-Flutter לטיפול רגיל (מאשר דיאלוגים)
class GlobalKeyboardHandler extends StatelessWidget {
  const GlobalKeyboardHandler({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: false,
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final focused = FocusManager.instance.primaryFocus;
        // בדוק אם הפוקוס נמצא בתוך שדה טקסט
        final isInTextField = focused?.context?.widget is EditableText;

        if (event.logicalKey == LogicalKeyboardKey.backspace && !isInTextField) {
          // השתמש ב-GoRouter לניווט חזרה
          final router = GoRouter.maybeOf(context);
          if (router != null && router.canPop()) {
            router.pop();
            return KeyEventResult.handled;
          }
        }

        // Enter ושאר מקשים – מועברים ל-Flutter לטיפול רגיל
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
