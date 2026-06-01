import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/biometric_service.dart' show sharedPrefsProvider;

const _kThemeModeKey = 'theme_mode';

/// The user's Light / Dark / System choice, persisted to SharedPreferences.
/// Defaults to [ThemeMode.system] until they pick otherwise. `main()` preloads
/// and overrides [sharedPrefsProvider], so the stored value is available
/// synchronously on the first frame — no flash of the wrong theme.
final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPrefsProvider).valueOrNull;
    return _decode(prefs?.getString(_kThemeModeKey));
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = ref.read(sharedPrefsProvider).valueOrNull;
    await prefs?.setString(_kThemeModeKey, mode.name);
  }

  static ThemeMode _decode(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
