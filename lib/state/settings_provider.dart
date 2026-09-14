import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/ai_provider.dart';

/// Theme preference.
enum ThemeModeSetting { system, light, dark }

ThemeMode themeModeOf(ThemeModeSetting s) => switch (s) {
      ThemeModeSetting.system => ThemeMode.system,
      ThemeModeSetting.light => ThemeMode.light,
      ThemeModeSetting.dark => ThemeMode.dark,
    };

/// User settings: appearance + AI provider configuration. Everything is local
/// (SharedPreferences); nothing syncs anywhere.
class SettingsProvider extends ChangeNotifier {
  static const _kThemeMode = 'settings.themeMode';
  static const _kProviderId = 'settings.ai.providerId';
  static const _kModel = 'settings.ai.model';
  static const _kApiKey = 'settings.ai.apiKey';
  static const _kBaseUrl = 'settings.ai.baseUrl';

  final SharedPreferences _prefs;

  ThemeModeSetting _themeMode = ThemeModeSetting.system;
  AiConfig _aiConfig = const AiConfig(providerId: 'gemini', model: 'gemini-2.0-flash');

  SettingsProvider(this._prefs) {
    _load();
  }

  ThemeModeSetting get themeMode => _themeMode;
  AiConfig get aiConfig => _aiConfig;

  bool get cloudAiEnabled =>
      _aiConfig.providerId != 'ollama' &&
      (_aiConfig.apiKey?.isNotEmpty == true);

  void _load() {
    _themeMode = ThemeModeSetting.values.asNameMap()[
            _prefs.getString(_kThemeMode)] ??
        ThemeModeSetting.system;

    _aiConfig = AiConfig(
      providerId: _prefs.getString(_kProviderId) ?? 'gemini',
      model: _prefs.getString(_kModel) ?? 'gemini-2.0-flash',
      apiKey: _prefs.getString(_kApiKey),
      baseUrl: _prefs.getString(_kBaseUrl),
    );
  }

  Future<void> setThemeMode(ThemeModeSetting mode) async {
    _themeMode = mode;
    await _prefs.setString(_kThemeMode, mode.name);
    notifyListeners();
  }

  Future<void> updateAiConfig(AiConfig config) async {
    _aiConfig = config;
    await _prefs.setString(_kProviderId, config.providerId);
    await _prefs.setString(_kModel, config.model);
    if (config.apiKey == null) {
      await _prefs.remove(_kApiKey);
    } else {
      await _prefs.setString(_kApiKey, config.apiKey!);
    }
    if (config.baseUrl == null) {
      await _prefs.remove(_kBaseUrl);
    } else {
      await _prefs.setString(_kBaseUrl, config.baseUrl!);
    }
    notifyListeners();
  }

  /// Exports settings as JSON (for the privacy page "what is stored" view).
  String describeAiConfig() {
    return jsonEncode({
      'provider': _aiConfig.providerId,
      'model': _aiConfig.model,
      'hasApiKey': _aiConfig.apiKey?.isNotEmpty == true,
      'baseUrl': _aiConfig.baseUrl,
    });
  }
}
