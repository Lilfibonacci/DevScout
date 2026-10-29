import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  final SharedPreferences sharedPreferences;
  static const String _themeKey = 'is_dark_mode';

  ThemeCubit({required this.sharedPreferences})
      : super(
          (sharedPreferences.getBool(_themeKey) ?? true)
              ? ThemeMode.dark
              : ThemeMode.light,
        );

  bool get isDarkMode => state == ThemeMode.dark;

  Future<void> setDarkMode(bool isDark) async {
    await sharedPreferences.setBool(_themeKey, isDark);
    emit(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> toggleTheme() async {
    await setDarkMode(!isDarkMode);
  }
}
