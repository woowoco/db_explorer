import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// db_explorer_app settings — `SharedPreferences` wrapper.
///
/// Settings keys (kebab-case, dot-separated namespace):
/// - theme_mode: light | dark | system
/// - ai_mode: local | ollama | openai | disabled
/// - ai_local_model_path, ai_local_context_size, ai_local_n_gpu_layers,
///   ai_local_temperature, ai_local_max_tokens
/// - ai_ollama_endpoint, ai_ollama_model, ai_ollama_bearer_token,
///   ai_ollama_temperature, ai_ollama_timeout_seconds
/// - ai_openai_endpoint, ai_openai_model, ai_openai_api_key,
///   ai_openai_temperature, ai_openai_max_tokens, ai_openai_timeout_seconds
/// - sensitive_field_patterns: newline-separated regex sources
/// - telemetry_opt_in: bool
/// - history_ttl_days: int
///
/// Hassas bilgi (connection password vs.) burada DEĞİL —
/// `SecureConnectionStore`'da saklanır. API key burada shared prefs'de
/// plain-text durur; ileride `flutter_secure_storage`'a taşınabilir
/// (Phase 9 backlog).
enum AiMode {
  /// Local llama.cpp model (Phase 7+).
  local,

  /// Ollama remote server.
  ollamaRemote,

  /// OpenAI-compatible HTTP API (OpenAI, Azure, Together, Groq, LM Studio...).
  openaiCompatible,

  /// AI kapalı (sadece manual query editor).
  disabled,
}

extension AiModeLabel on AiMode {
  String get label => switch (this) {
        AiMode.local => 'Local (llama.cpp)',
        AiMode.ollamaRemote => 'Ollama (remote)',
        AiMode.openaiCompatible => 'OpenAI-compatible',
        AiMode.disabled => 'Disabled',
      };
}

class AppSettings {
  AppSettings(this._prefs);

  final SharedPreferences _prefs;

  // --- key constants ---
  static const _kThemeMode = 'theme_mode';
  static const _kAiMode = 'ai_mode';

  // Local (llama.cpp)
  static const _kAiLocalModelPath = 'ai_local_model_path';
  static const _kAiLocalContextSize = 'ai_local_context_size';
  static const _kAiLocalNGpuLayers = 'ai_local_n_gpu_layers';
  static const _kAiLocalTemperature = 'ai_local_temperature';
  static const _kAiLocalMaxTokens = 'ai_local_max_tokens';

  // Ollama (remote)
  static const _kAiOllamaEndpoint = 'ai_ollama_endpoint';
  static const _kAiOllamaModel = 'ai_ollama_model';
  static const _kAiOllamaBearerToken = 'ai_ollama_bearer_token';
  static const _kAiOllamaTemperature = 'ai_ollama_temperature';
  static const _kAiOllamaTimeoutSeconds = 'ai_ollama_timeout_seconds';

  // OpenAI-compatible
  static const _kAiOpenaiEndpoint = 'ai_openai_endpoint';
  static const _kAiOpenaiModel = 'ai_openai_model';
  static const _kAiOpenaiApiKey = 'ai_openai_api_key';
  static const _kAiOpenaiTemperature = 'ai_openai_temperature';
  static const _kAiOpenaiMaxTokens = 'ai_openai_max_tokens';
  static const _kAiOpenaiTimeoutSeconds = 'ai_openai_timeout_seconds';

  // Misc
  static const _kSensitiveFieldPatterns = 'sensitive_field_patterns';
  static const _kTelemetryOptIn = 'telemetry_opt_in';
  static const _kHistoryTtlDays = 'history_ttl_days';

  // ==================== Theme ====================

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

  // ==================== AI mode ====================

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

  // ==================== Local (llama.cpp) ====================

  String? get aiLocalModelPath => _prefs.getString(_kAiLocalModelPath);
  Future<void> setAiLocalModelPath(String path) =>
      _prefs.setString(_kAiLocalModelPath, path);

  int get aiLocalContextSize => _prefs.getInt(_kAiLocalContextSize) ?? 2048;
  Future<void> setAiLocalContextSize(int size) =>
      _prefs.setInt(_kAiLocalContextSize, size);

  int get aiLocalNGpuLayers => _prefs.getInt(_kAiLocalNGpuLayers) ?? 0;
  Future<void> setAiLocalNGpuLayers(int layers) =>
      _prefs.setInt(_kAiLocalNGpuLayers, layers);

  double get aiLocalTemperature =>
      _prefs.getDouble(_kAiLocalTemperature) ?? 0.2;
  Future<void> setAiLocalTemperature(double temp) =>
      _prefs.setDouble(_kAiLocalTemperature, temp);

  int get aiLocalMaxTokens => _prefs.getInt(_kAiLocalMaxTokens) ?? 1024;
  Future<void> setAiLocalMaxTokens(int tokens) =>
      _prefs.setInt(_kAiLocalMaxTokens, tokens);

  // ==================== Ollama (remote) ====================

  String? get aiOllamaEndpoint => _prefs.getString(_kAiOllamaEndpoint);
  Future<void> setAiOllamaEndpoint(String url) =>
      _prefs.setString(_kAiOllamaEndpoint, url);

  String? get aiOllamaModel => _prefs.getString(_kAiOllamaModel);
  Future<void> setAiOllamaModel(String model) =>
      _prefs.setString(_kAiOllamaModel, model);

  String? get aiOllamaBearerToken => _prefs.getString(_kAiOllamaBearerToken);
  Future<void> setAiOllamaBearerToken(String token) =>
      _prefs.setString(_kAiOllamaBearerToken, token);

  double get aiOllamaTemperature =>
      _prefs.getDouble(_kAiOllamaTemperature) ?? 0.2;
  Future<void> setAiOllamaTemperature(double temp) =>
      _prefs.setDouble(_kAiOllamaTemperature, temp);

  int get aiOllamaTimeoutSeconds =>
      _prefs.getInt(_kAiOllamaTimeoutSeconds) ?? 120;
  Future<void> setAiOllamaTimeoutSeconds(int seconds) =>
      _prefs.setInt(_kAiOllamaTimeoutSeconds, seconds);

  // ==================== OpenAI-compatible ====================

  String? get aiOpenaiEndpoint => _prefs.getString(_kAiOpenaiEndpoint);
  Future<void> setAiOpenaiEndpoint(String url) =>
      _prefs.setString(_kAiOpenaiEndpoint, url);

  String? get aiOpenaiModel => _prefs.getString(_kAiOpenaiModel);
  Future<void> setAiOpenaiModel(String model) =>
      _prefs.setString(_kAiOpenaiModel, model);

  String? get aiOpenaiApiKey => _prefs.getString(_kAiOpenaiApiKey);
  Future<void> setAiOpenaiApiKey(String key) =>
      _prefs.setString(_kAiOpenaiApiKey, key);

  double get aiOpenaiTemperature =>
      _prefs.getDouble(_kAiOpenaiTemperature) ?? 0.2;
  Future<void> setAiOpenaiTemperature(double temp) =>
      _prefs.setDouble(_kAiOpenaiTemperature, temp);

  int get aiOpenaiMaxTokens => _prefs.getInt(_kAiOpenaiMaxTokens) ?? 1024;
  Future<void> setAiOpenaiMaxTokens(int tokens) =>
      _prefs.setInt(_kAiOpenaiMaxTokens, tokens);

  int get aiOpenaiTimeoutSeconds =>
      _prefs.getInt(_kAiOpenaiTimeoutSeconds) ?? 60;
  Future<void> setAiOpenaiTimeoutSeconds(int seconds) =>
      _prefs.setInt(_kAiOpenaiTimeoutSeconds, seconds);

  // ==================== Sensitive patterns ====================

  /// Newline-separated regex source list. Default empty (no masking).
  List<String> get sensitiveFieldPatterns {
    final raw = _prefs.getString(_kSensitiveFieldPatterns);
    if (raw == null || raw.isEmpty) return const [];
    return raw.split('\n').where((s) => s.trim().isNotEmpty).toList();
  }

  Future<void> setSensitiveFieldPatterns(List<String> patterns) async {
    final cleaned = patterns
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    await _prefs.setString(
      _kSensitiveFieldPatterns,
      cleaned.join('\n'),
    );
  }

  // ==================== Misc ====================

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