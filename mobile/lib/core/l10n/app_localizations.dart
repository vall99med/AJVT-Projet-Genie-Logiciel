import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;
  late Map<String, String> _strings;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static String tr(BuildContext context, String key) =>
      of(context).translate(key);

  String translate(String key) => _strings[key] ?? key;

  Future<void> load() async {
    final jsonStr = await rootBundle
        .loadString('assets/translations/${locale.languageCode}.json');
    final map = json.decode(jsonStr) as Map<String, dynamic>;
    _strings = map.map((k, v) => MapEntry(k, v.toString()));
  }

  static const delegate = _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['ar', 'fr'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final l = AppLocalizations(locale);
    await l.load();
    return l;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
