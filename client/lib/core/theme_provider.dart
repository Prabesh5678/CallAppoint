import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const _themeKey = 'theme_mode';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await _storage.read(key: _themeKey);
    if (saved == 'light') state = ThemeMode.light;
    if (saved == 'dark') state = ThemeMode.dark;
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    await _storage.write(
      key: _themeKey,
      value: next == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _storage.write(
      key: _themeKey,
      value: mode == ThemeMode.dark
          ? 'dark'
          : (mode == ThemeMode.light ? 'light' : 'system'),
    );
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier();
});
