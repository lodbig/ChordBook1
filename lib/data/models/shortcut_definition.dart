import 'package:flutter/services.dart';

/// מייצג "ללא מקש" – משמש לקיצורים שטרם הוגדרו.
const kNoKey = LogicalKeyboardKey(0);

class ShortcutDefinition {
  final String id;
  final String label;
  final LogicalKeyboardKey key;
  final bool ctrl;
  final bool alt;
  final bool shift;

  const ShortcutDefinition({
    required this.id,
    required this.label,
    required this.key,
    this.ctrl = false,
    this.alt = false,
    this.shift = false,
  });

  String get displayString {
    final parts = <String>[];
    if (ctrl) parts.add('Ctrl');
    if (alt) parts.add('Alt');
    if (shift) parts.add('Shift');
    parts.add(key.keyLabel);
    return parts.join('+');
  }

  ShortcutDefinition copyWith({
    String? id,
    String? label,
    LogicalKeyboardKey? key,
    bool? ctrl,
    bool? alt,
    bool? shift,
  }) {
    return ShortcutDefinition(
      id: id ?? this.id,
      label: label ?? this.label,
      key: key ?? this.key,
      ctrl: ctrl ?? this.ctrl,
      alt: alt ?? this.alt,
      shift: shift ?? this.shift,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'keyId': key.keyId,
        'ctrl': ctrl,
        'alt': alt,
        'shift': shift,
      };

  factory ShortcutDefinition.fromJson(Map<String, dynamic> json) {
    return ShortcutDefinition(
      id: json['id'] as String,
      label: json['label'] as String,
      key: LogicalKeyboardKey(json['keyId'] as int),
      ctrl: json['ctrl'] as bool? ?? false,
      alt: json['alt'] as bool? ?? false,
      shift: json['shift'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ShortcutDefinition &&
      other.key == key &&
      other.ctrl == ctrl &&
      other.alt == alt &&
      other.shift == shift;

  @override
  int get hashCode => Object.hash(key, ctrl, alt, shift);
}
