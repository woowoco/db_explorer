import 'package:db_explorer_app/infrastructure/storage/settings.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Uygulama seviyesi state — settings, AI mode, build version.
class AppState extends Equatable {
  const AppState({
    required this.aiMode,
    required this.aiLocalModelPath,
    required this.telemetryOptIn,
    required this.historyTtlDays,
    this.buildVersion = '0.8.0+8',
  });

  final AiMode aiMode;
  final String? aiLocalModelPath;
  final bool telemetryOptIn;
  final int historyTtlDays;
  final String buildVersion;

  static const AppState initial = AppState(
    aiMode: AiMode.disabled,
    aiLocalModelPath: null,
    telemetryOptIn: false,
    historyTtlDays: 30,
  );

  AppState copyWith({
    AiMode? aiMode,
    String? aiLocalModelPath,
    bool? telemetryOptIn,
    int? historyTtlDays,
  }) {
    return AppState(
      aiMode: aiMode ?? this.aiMode,
      aiLocalModelPath: aiLocalModelPath ?? this.aiLocalModelPath,
      telemetryOptIn: telemetryOptIn ?? this.telemetryOptIn,
      historyTtlDays: historyTtlDays ?? this.historyTtlDays,
      buildVersion: buildVersion,
    );
  }

  @override
  List<Object?> get props => [
    aiMode,
    aiLocalModelPath,
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

  Future<void> setTelemetryOptIn(bool enabled) async {
    await _settings.setTelemetryOptIn(enabled);
    emit(state.copyWith(telemetryOptIn: enabled));
  }

  Future<void> setHistoryTtlDays(int days) async {
    await _settings.setHistoryTtlDays(days);
    emit(state.copyWith(historyTtlDays: days));
  }
}