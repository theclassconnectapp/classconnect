import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/local_storage_service.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit({required LocalStorageService storage})
    : _storage = storage,
      super(ThemeMode.system) {
    _init();
  }

  final LocalStorageService _storage;

  Future<void> _init() async {
    final String? saved = await _storage.getThemeMode();
    if (saved != null) emit(_fromString(saved));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _storage.setThemeMode(_toString(mode));
    emit(mode);
  }

  String _toString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  ThemeMode _fromString(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
