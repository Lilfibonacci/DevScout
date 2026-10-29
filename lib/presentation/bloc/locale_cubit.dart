import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleCubit extends Cubit<Locale> {
  final SharedPreferences sharedPreferences;
  static const String _langCodeKey = 'app_language_code';

  LocaleCubit({required this.sharedPreferences})
      : super(_loadInitialLocale(sharedPreferences));

  static Locale _loadInitialLocale(SharedPreferences prefs) {
    final code = prefs.getString(_langCodeKey) ?? 'fa';
    return code == 'en'
        ? const Locale('en', 'US')
        : const Locale('fa', 'IR');
  }

  bool get isPersian => state.languageCode == 'fa';

  Future<void> setLanguage(String languageCode) async {
    await sharedPreferences.setString(_langCodeKey, languageCode);
    final nextLocale = languageCode == 'en'
        ? const Locale('en', 'US')
        : const Locale('fa', 'IR');
    emit(nextLocale);
  }

  Future<void> toggleLanguage() async {
    final nextCode = isPersian ? 'en' : 'fa';
    await setLanguage(nextCode);
  }
}
