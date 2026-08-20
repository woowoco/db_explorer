import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// db_explorer_app settings — `SharedPreferences` wrapper.
///
/// Phase 0'da sadece themeMode + aiMode + aiModelPath + telemetry opt-in.
/// Hassas bilgi (connection password vs.) burada DEĞİL —
/// `SecureConnectionStore`'da saklanır.
enum AiMode {
  /// Local llama.cpp model (Phase 7+)
  local,

  /// Ollama remote server
  ollamaRemote,

  /// OpenAI-compatible HTTP API
  openaiCompatible,

  /// AI kapalı (sadece manual query editor)
  disabled,
}

class AppSettings {
  AppSettings(this._prefs);

  final SharedPreferences _prefs;

  static const _kThemeMode = 'theme_mode';
  static const _kAiMode = 'ai_mode';
  static const _kAiModelPath = 'ai_model_path';
  static const _kTelemetryOptIn = 'telemetry_opt_in';
  static const _kHistoryTtlDays = 'history_ttl_days';

  ThemeMode get themeMode {
    final raw = _prefs.getString(_kThemeMode);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _prefs.setString(_kThemeMode, value);
  }

  AiMode get aiMode {
    final raw = _prefs.getString(_kAiMode);
    return switch (raw) {
      'local' => AiMode.local,
      'ollama' => AiMode.ollamaRemote,
      'openai' => AiMode.openaiCompatible,
      _ => AiMode.disabled,
    };
  }

  Future<void> setAiMode(AiMode mode) async {
    final value = switch (mode) {
      AiMode.local => 'local',
      AiMode.ollamaRemote => 'ollama',
      AiMode.openaiCompatible => 'openai',
      AiMode.disabled => 'disabled',
    };
    await _prefs.setString(_kAiMode, value);
  }

  String? get aiModelPath => _prefs.getString(_kAiModelPath);

  Future<void> setAiModelPath(String path) async {
    await _prefs.setString(_kAiModelPath, path);
  }

  bool get telemetryOptIn => _prefs.getBool(_kTelemetryOptIn) ?? false;

  Future<void> setTelemetryOptIn(bool enabled) async {
    await _prefs.setBool(_kTelemetryOptIn, enabled);
  }

  int get historyTtlDays => _prefs.getInt(_kHistoryTtlDays) ?? 30;

  Future<void> setHistoryTtlDays(int days) async {
    await _prefs.setInt(_kHistoryTtlDays, days);
  }

  /// Smoke test.
  Future<bool> ping() async {
    try {
      await _prefs.setString('dbx_settings_smoke', 'ok');
      final read = _prefs.getString('dbx_settings_smoke');
      await _prefs.remove('dbx_settings_smoke');
      return read == 'ok';
    } catch (_) {
      return false;
    }
  }
}
