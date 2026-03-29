import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ---------------------------------------------------------------------------
// Persistence helpers
// ---------------------------------------------------------------------------

const _settingsBox = 'settings';
const _themeModeKey = 'themeMode';

Future<Box> _openSettingsBox() async {
  if (Hive.isBoxOpen(_settingsBox)) return Hive.box(_settingsBox);
  return Hive.openBox(_settingsBox);
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

/// Reads the persisted theme mode from Hive.
/// Falls back to [ThemeMode.dark] if nothing is stored.
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    final box = await _openSettingsBox();
    final stored = box.get(_themeModeKey, defaultValue: 'light') as String;
    state = stored == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() async {
    final next =
        state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    final box = await _openSettingsBox();
    await box.put(_themeModeKey, next == ThemeMode.light ? 'light' : 'dark');
  }
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// An [IconButton] that toggles between dark and light theme.
/// Reads and writes the persisted preference via [themeModeProvider].
class ThemeToggle extends ConsumerWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isDark = mode == ThemeMode.dark;

    return IconButton(
      tooltip: isDark ? 'עבור למצב בהיר' : 'עבור למצב כהה',
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
    );
  }
}

// ---------------------------------------------------------------------------
// Font scale provider
// ---------------------------------------------------------------------------

const _fontScaleKey = 'fontScale';
const double _defaultFontScale = 1.0;
const double _minFontScale = 0.8;
const double _maxFontScale = 1.4;

final fontScaleProvider =
    StateNotifierProvider<FontScaleNotifier, double>((ref) {
  return FontScaleNotifier();
});

class FontScaleNotifier extends StateNotifier<double> {
  FontScaleNotifier() : super(_defaultFontScale) {
    _load();
  }

  Future<void> _load() async {
    final box = await _openSettingsBox();
    final stored = box.get(_fontScaleKey, defaultValue: _defaultFontScale);
    state = (stored as double).clamp(_minFontScale, _maxFontScale);
  }

  Future<void> setScale(double scale) async {
    final clamped = scale.clamp(_minFontScale, _maxFontScale);
    state = clamped;
    final box = await _openSettingsBox();
    await box.put(_fontScaleKey, clamped);
  }

  Future<void> reset() => setScale(_defaultFontScale);
}

// ---------------------------------------------------------------------------
// Font family provider
// ---------------------------------------------------------------------------

const _fontFamilyKey = 'fontFamily';
const _customFontsKey = 'customFonts';

final fontFamilyProvider =
    StateNotifierProvider<FontFamilyNotifier, String?>((ref) {
  return FontFamilyNotifier();
});

/// Provider for the list of custom (user-added) font names.
final customFontsProvider =
    StateNotifierProvider<CustomFontsNotifier, List<String>>((ref) {
  return CustomFontsNotifier();
});

class FontFamilyNotifier extends StateNotifier<String?> {
  FontFamilyNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final box = await _openSettingsBox();
    final stored = box.get(_fontFamilyKey) as String?;
    // Validate that the stored font still exists in the available list
    if (stored != null) {
      final builtIn = getSystemFonts();
      final customRaw = box.get(_customFontsKey);
      final custom = customRaw is List
          ? List<String>.from(customRaw)
          : <String>[];
      final allFonts = [...builtIn, ...custom];
      state = allFonts.contains(stored) ? stored : null;
      if (state == null && stored != null) {
        // Font no longer exists – clear persisted value
        await box.delete(_fontFamilyKey);
      }
    } else {
      state = null;
    }
  }

  Future<void> setFamily(String? family) async {
    state = family;
    final box = await _openSettingsBox();
    if (family == null) {
      await box.delete(_fontFamilyKey);
    } else {
      await box.put(_fontFamilyKey, family);
    }
  }

  /// Called when a custom font is removed – resets to default if it was selected.
  Future<void> validateAgainst(List<String> availableFonts) async {
    if (state != null && !availableFonts.contains(state)) {
      await setFamily(null);
    }
  }
}

class CustomFontsNotifier extends StateNotifier<List<String>> {
  CustomFontsNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final box = await _openSettingsBox();
    final raw = box.get(_customFontsKey);
    state = raw is List ? List<String>.from(raw) : [];
  }

  Future<void> addFont(String name) async {
    if (state.contains(name)) return;
    state = [...state, name];
    final box = await _openSettingsBox();
    await box.put(_customFontsKey, state);
  }

  Future<void> removeFont(String name) async {
    state = state.where((f) => f != name).toList();
    final box = await _openSettingsBox();
    await box.put(_customFontsKey, state);
  }
}

/// Returns a list of available system font families on Windows.
/// On other platforms returns an empty list.
List<String> getSystemFonts() {
  if (!Platform.isWindows) return [];
  // רשימה של פונטים נפוצים ב-Windows
  return const [
    'Arial',
    'Arial Black',
    'Calibri',
    'Cambria',
    'Comic Sans MS',
    'Consolas',
    'Courier New',
    'David',
    'Frank Ruehl',
    'Georgia',
    'Impact',
    'Lucida Console',
    'Miriam',
    'Narkisim',
    'Segoe UI',
    'Tahoma',
    'Times New Roman',
    'Trebuchet MS',
    'Verdana',
  ];
}

// ---------------------------------------------------------------------------
// Auto-advance provider (move to next song when auto-scroll ends)
// ---------------------------------------------------------------------------

const _autoAdvanceKey = 'autoAdvance';

final autoAdvanceProvider =
    StateNotifierProvider<AutoAdvanceNotifier, bool>((ref) {
  return AutoAdvanceNotifier();
});

class AutoAdvanceNotifier extends StateNotifier<bool> {
  AutoAdvanceNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final box = await _openSettingsBox();
    state = box.get(_autoAdvanceKey, defaultValue: false) as bool;
  }

  Future<void> toggle() async {
    state = !state;
    final box = await _openSettingsBox();
    await box.put(_autoAdvanceKey, state);
  }

  Future<void> setValue(bool value) async {
    state = value;
    final box = await _openSettingsBox();
    await box.put(_autoAdvanceKey, value);
  }
}

// ---------------------------------------------------------------------------
// Auto-advance delay provider (seconds before moving to next song)
// ---------------------------------------------------------------------------

const _autoAdvanceDelayKey = 'autoAdvanceDelay';
const double _defaultAutoAdvanceDelay = 3.0;

final autoAdvanceDelayProvider =
    StateNotifierProvider<AutoAdvanceDelayNotifier, double>((ref) {
  return AutoAdvanceDelayNotifier();
});

class AutoAdvanceDelayNotifier extends StateNotifier<double> {
  AutoAdvanceDelayNotifier() : super(_defaultAutoAdvanceDelay) {
    _load();
  }

  Future<void> _load() async {
    final box = await _openSettingsBox();
    state = (box.get(_autoAdvanceDelayKey,
            defaultValue: _defaultAutoAdvanceDelay) as double)
        .clamp(0.0, 30.0);
  }

  Future<void> setValue(double value) async {
    state = value.clamp(0.0, 30.0);
    final box = await _openSettingsBox();
    await box.put(_autoAdvanceDelayKey, state);
  }
}

// ---------------------------------------------------------------------------
// Default scroll delay provider (0-60 seconds, replaces per-song local setting)
// ---------------------------------------------------------------------------

const _globalScrollDelayKey = 'globalScrollDelay';
const double _defaultGlobalScrollDelay = 3.0;

final globalScrollDelayProvider =
    StateNotifierProvider<GlobalScrollDelayNotifier, double>((ref) {
  return GlobalScrollDelayNotifier();
});

class GlobalScrollDelayNotifier extends StateNotifier<double> {
  GlobalScrollDelayNotifier() : super(_defaultGlobalScrollDelay) {
    _load();
  }

  Future<void> _load() async {
    final box = await _openSettingsBox();
    final raw = box.get(_globalScrollDelayKey, defaultValue: _defaultGlobalScrollDelay);
    state = (raw as double).clamp(0.0, 60.0);
  }

  Future<void> setValue(double value) async {
    state = value.clamp(0.0, 60.0);
    final box = await _openSettingsBox();
    await box.put(_globalScrollDelayKey, state);
  }
}

// ---------------------------------------------------------------------------
// Default scroll speed provider
// ---------------------------------------------------------------------------

const _defaultScrollSpeedKey = 'defaultScrollSpeed';
const double _defaultScrollSpeedValue = 1.5;

final defaultScrollSpeedProvider =
    StateNotifierProvider<DefaultScrollSpeedNotifier, double>((ref) {
  return DefaultScrollSpeedNotifier();
});

class DefaultScrollSpeedNotifier extends StateNotifier<double> {
  DefaultScrollSpeedNotifier() : super(_defaultScrollSpeedValue) {
    _load();
  }

  Future<void> _load() async {
    final box = await _openSettingsBox();
    state = (box.get(_defaultScrollSpeedKey,
            defaultValue: _defaultScrollSpeedValue) as double)
        .clamp(0.1, 3.0);
  }

  Future<void> setValue(double value) async {
    state = value.clamp(0.1, 3.0);
    final box = await _openSettingsBox();
    await box.put(_defaultScrollSpeedKey, state);
  }
}
