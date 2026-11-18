import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// App preferences, saved separately from class data.
class SettingsStore extends ChangeNotifier {
  SettingsStore({this.persist = true});

  /// Tests can turn off disk writes.
  final bool persist;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> init() async {
    if (!persist) return;
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final mode = data['themeMode'] as String?;
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == mode,
        orElse: () => ThemeMode.system,
      );
    } on Object {
      // A broken settings file should never stop the app from opening.
      _themeMode = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    if (!persist) return;
    final file = await _file();
    await file.writeAsString(jsonEncode({'themeMode': mode.name}));
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/recitro_settings.json');
  }
}
