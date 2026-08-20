import 'package:db_explorer_app/infrastructure/storage/settings.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Uygulama seviyesi state — settings, AI mode, AI provider config, build version.
///
/// Phase 8'de tüm AI provider konfig alanları (her mode için: endpoint,
/// model, apiKey/bearerToken, temperature, timeout, maxTokens, vb.)
/// AppState'e alındı → AppCubit proxy olarak her alanı AppSettings'e
/// persist eder. SettingsPage bu state'i okur/yazar.
class AppState extends Equatable {
  const AppState({
    required this.aiMode,
    required this.aiLocalModelPath,
    required this.aiLocalContextSize,
    required this.aiLocalNGpuLayers,
    required this.aiLocalTemperature,
    required this.aiLocalMaxTokens,
    required this.aiOllamaEndpoint,
    required this.aiOllamaModel,
    required this.aiOllamaBearerToken,
    required this.aiOllamaTemperature,
    required this.aiOllamaTimeoutSeconds,
    required this.aiOpenaiEndpoint,
    required this.aiOpenaiModel,
    required this.aiOpenaiApiKey,
    required this.aiOpenaiTemperature,
    required this.aiOpenaiMaxTokens,
    required this.aiOpenaiTimeoutSeconds,
    required this.sensitiveFieldPatterns,
    required this.telemetryOptIn,
    required this.historyTtlDays,
    this.buildVersion = '0.9.0+9',
  });

  final AiMode aiMode;
  final String? aiLocalModelPath;
  final int aiLocalContextSize;
  final int aiLocalNGpuLayers;
  final double aiLocalTemperature;
  final int aiLocalMaxTokens;

  final String? aiOllamaEndpoint;
  final String? aiOllamaModel;
  final String? aiOllamaBearerToken;
  final double aiOllamaTemperature;
  final int aiOllamaTimeoutSeconds;

  final String? aiOpenaiEndpoint;
  final String? aiOpenaiModel;
  final String? aiOpenaiApiKey;
  final double aiOpenaiTemperature;
  final int aiOpenaiMaxTokens;
  final int aiOpenaiTimeoutSeconds;

  final List<String> sensitiveFieldPatterns;

  final bool telemetryOptIn;
  final int historyTtlDays;
  final String buildVersion;

  static const AppState initial = AppState(
    aiMode: AiMode.disabled,
    aiLocalModelPath: null,
    aiLocalContextSize: 2048,
    aiLocalNGpuLayers: 0,
    aiLocalTemperature: 0.2,
    aiLocalMaxTokens: 1024,
    aiOllamaEndpoint: null,
    aiOllamaModel: null,
    aiOllamaBearerToken: null,
    aiOllamaTemperature: 0.2,
    aiOllamaTimeoutSeconds: 120,
    aiOpenaiEndpoint: null,
    aiOpenaiModel: null,
    aiOpenaiApiKey: null,
    aiOpenaiTemperature: 0.2,
    aiOpenaiMaxTokens: 1024,
    aiOpenaiTimeoutSeconds: 60,
    sensitiveFieldPatterns: <String>[],
    telemetryOptIn: false,
    historyTtlDays: 30,
  );

  AppState copyWith({
    AiMode? aiMode,
    String? aiLocalModelPath,
    int? aiLocalContextSize,
    int? aiLocalNGpuLayers,
    double? aiLocalTemperature,
    int? aiLocalMaxTokens,
    String? aiOllamaEndpoint,
    String? aiOllamaModel,
    String? aiOllamaBearerToken,
    double? aiOllamaTemperature,
    int? aiOllamaTimeoutSeconds,
    String? aiOpenaiEndpoint,
    String? aiOpenaiModel,
    String? aiOpenaiApiKey,
    double? aiOpenaiTemperature,
    int? aiOpenaiMaxTokens,
    int? aiOpenaiTimeoutSeconds,
    List<String>? sensitiveFieldPatterns,
    bool? telemetryOptIn,
    int? historyTtlDays,
  }) {
    return AppState(
      aiMode: aiMode ?? this.aiMode,
      aiLocalModelPath: aiLocalModelPath ?? this.aiLocalModelPath,
      aiLocalContextSize: aiLocalContextSize ?? this.aiLocalContextSize,
      aiLocalNGpuLayers: aiLocalNGpuLayers ?? this.aiLocalNGpuLayers,
      aiLocalTemperature: aiLocalTemperature ?? this.aiLocalTemperature,
      aiLocalMaxTokens: aiLocalMaxTokens ?? this.aiLocalMaxTokens,
      aiOllamaEndpoint: aiOllamaEndpoint ?? this.aiOllamaEndpoint,
      aiOllamaModel: aiOllamaModel ?? this.aiOllamaModel,
      aiOllamaBearerToken: aiOllamaBearerToken ?? this.aiOllamaBearerToken,
      aiOllamaTemperature: aiOllamaTemperature ?? this.aiOllamaTemperature,
      aiOllamaTimeoutSeconds: aiOllamaTimeoutSeconds ?? this.aiOllamaTimeoutSeconds,
      aiOpenaiEndpoint: aiOpenaiEndpoint ?? this.aiOpenaiEndpoint,
      aiOpenaiModel: aiOpenaiModel ?? this.aiOpenaiModel,
      aiOpenaiApiKey: aiOpenaiApiKey ?? this.aiOpenaiApiKey,
      aiOpenaiTemperature: aiOpenaiTemperature ?? this.aiOpenaiTemperature,
      aiOpenaiMaxTokens: aiOpenaiMaxTokens ?? this.aiOpenaiMaxTokens,
      aiOpenaiTimeoutSeconds: aiOpenaiTimeoutSeconds ?? this.aiOpenaiTimeoutSeconds,
      sensitiveFieldPatterns: sensitiveFieldPatterns ?? this.sensitiveFieldPatterns,
      telemetryOptIn: telemetryOptIn ?? this.telemetryOptIn,
      historyTtlDays: historyTtlDays ?? this.historyTtlDays,
      buildVersion: buildVersion,
    );
  }

  @override
  List<Object?> get props => [
        aiMode,
        aiLocalModelPath,
        aiLocalContextSize,
        aiLocalNGpuLayers,
        aiLocalTemperature,
        aiLocalMaxTokens,
        aiOllamaEndpoint,
        aiOllamaModel,
        aiOllamaBearerToken,
        aiOllamaTemperature,
        aiOllamaTimeoutSeconds,
        aiOpenaiEndpoint,
        aiOpenaiModel,
        aiOpenaiApiKey,
        aiOpenaiTemperature,
        aiOpenaiMaxTokens,
        aiOpenaiTimeoutSeconds,
        sensitiveFieldPatterns,
        telemetryOptIn,
        historyTtlDays,
        buildVersion,
      ];
}

class AppCubit extends Cubit<AppState> {
  AppCubit(this._settings) : super(_initialState(_settings));

  final AppSettings _settings;

  static AppState _initialState(AppSettings settings) {
    return AppState(
      aiMode: settings.aiMode,
      aiLocalModelPath: settings.aiLocalModelPath,
      aiLocalContextSize: settings.aiLocalContextSize,
      aiLocalNGpuLayers: settings.aiLocalNGpuLayers,
      aiLocalTemperature: settings.aiLocalTemperature,
      aiLocalMaxTokens: settings.aiLocalMaxTokens,
      aiOllamaEndpoint: settings.aiOllamaEndpoint,
      aiOllamaModel: settings.aiOllamaModel,
      aiOllamaBearerToken: settings.aiOllamaBearerToken,
      aiOllamaTemperature: settings.aiOllamaTemperature,
      aiOllamaTimeoutSeconds: settings.aiOllamaTimeoutSeconds,
      aiOpenaiEndpoint: settings.aiOpenaiEndpoint,
      aiOpenaiModel: settings.aiOpenaiModel,
      aiOpenaiApiKey: settings.aiOpenaiApiKey,
      aiOpenaiTemperature: settings.aiOpenaiTemperature,
      aiOpenaiMaxTokens: settings.aiOpenaiMaxTokens,
      aiOpenaiTimeoutSeconds: settings.aiOpenaiTimeoutSeconds,
      sensitiveFieldPatterns: settings.sensitiveFieldPatterns,
      telemetryOptIn: settings.telemetryOptIn,
      historyTtlDays: settings.historyTtlDays,
    );
  }

  Future<void> setAiMode(AiMode mode) async {
    await _settings.setAiMode(mode);
    emit(state.copyWith(aiMode: mode));
  }

  Future<void> setAiLocalModelPath(String? path) async {
    if (path == null) return;
    await _settings.setAiLocalModelPath(path);
    emit(state.copyWith(aiLocalModelPath: path));
  }

  Future<void> setAiLocalContextSize(int size) async {
    await _settings.setAiLocalContextSize(size);
    emit(state.copyWith(aiLocalContextSize: size));
  }

  Future<void> setAiLocalNGpuLayers(int layers) async {
    await _settings.setAiLocalNGpuLayers(layers);
    emit(state.copyWith(aiLocalNGpuLayers: layers));
  }

  Future<void> setAiLocalTemperature(double temp) async {
    await _settings.setAiLocalTemperature(temp);
    emit(state.copyWith(aiLocalTemperature: temp));
  }

  Future<void> setAiLocalMaxTokens(int tokens) async {
    await _settings.setAiLocalMaxTokens(tokens);
    emit(state.copyWith(aiLocalMaxTokens: tokens));
  }

  Future<void> setAiOllamaEndpoint(String url) async {
    await _settings.setAiOllamaEndpoint(url);
    emit(state.copyWith(aiOllamaEndpoint: url));
  }

  Future<void> setAiOllamaModel(String model) async {
    await _settings.setAiOllamaModel(model);
    emit(state.copyWith(aiOllamaModel: model));
  }

  Future<void> setAiOllamaBearerToken(String token) async {
    await _settings.setAiOllamaBearerToken(token);
    emit(state.copyWith(aiOllamaBearerToken: token));
  }

  Future<void> setAiOllamaTemperature(double temp) async {
    await _settings.setAiOllamaTemperature(temp);
    emit(state.copyWith(aiOllamaTemperature: temp));
  }

  Future<void> setAiOllamaTimeoutSeconds(int seconds) async {
    await _settings.setAiOllamaTimeoutSeconds(seconds);
    emit(state.copyWith(aiOllamaTimeoutSeconds: seconds));
  }

  Future<void> setAiOpenaiEndpoint(String url) async {
    await _settings.setAiOpenaiEndpoint(url);
    emit(state.copyWith(aiOpenaiEndpoint: url));
  }

  Future<void> setAiOpenaiModel(String model) async {
    await _settings.setAiOpenaiModel(model);
    emit(state.copyWith(aiOpenaiModel: model));
  }

  Future<void> setAiOpenaiApiKey(String key) async {
    await _settings.setAiOpenaiApiKey(key);
    emit(state.copyWith(aiOpenaiApiKey: key));
  }

  Future<void> setAiOpenaiTemperature(double temp) async {
    await _settings.setAiOpenaiTemperature(temp);
    emit(state.copyWith(aiOpenaiTemperature: temp));
  }

  Future<void> setAiOpenaiMaxTokens(int tokens) async {
    await _settings.setAiOpenaiMaxTokens(tokens);
    emit(state.copyWith(aiOpenaiMaxTokens: tokens));
  }

  Future<void> setAiOpenaiTimeoutSeconds(int seconds) async {
    await _settings.setAiOpenaiTimeoutSeconds(seconds);
    emit(state.copyWith(aiOpenaiTimeoutSeconds: seconds));
  }

  Future<void> setSensitiveFieldPatterns(List<String> patterns) async {
    await _settings.setSensitiveFieldPatterns(patterns);
    emit(state.copyWith(sensitiveFieldPatterns: patterns));
  }

  Future<void> setTelemetryOptIn(bool enabled) async {
    await _settings.setTelemetryOptIn(enabled);
    emit(state.copyWith(telemetryOptIn: enabled));
  }

  Future<void> setHistoryTtlDays(int days) async {
    await _settings.setHistoryTtlDays(days);
    emit(state.copyWith(historyTtlDays: days));
  }
}
