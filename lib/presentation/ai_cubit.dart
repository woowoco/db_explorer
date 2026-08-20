import 'package:db_explorer_app/infrastructure/registry/ai_provider_registry.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum AiStatus { unknown, loaded, unavailable, error }

class AiState extends Equatable {
  const AiState({
    required this.status,
    this.activeProviderId,
    this.lastError,
  });

  final AiStatus status;
  final String? activeProviderId;
  final String? lastError;

  static const AiState initial = AiState(status: AiStatus.unknown);

  AiState copyWith({
    AiStatus? status,
    String? activeProviderId,
    String? lastError,
  }) {
    return AiState(
      status: status ?? this.status,
      activeProviderId: activeProviderId ?? this.activeProviderId,
      lastError: lastError,
    );
  }

  @override
  List<Object?> get props => [status, activeProviderId, lastError];
}

/// AI provider availability durumunu tutan cubit.
///
/// Phase 8'de `AiProviderRegistry` ile bağlandı: `refresh()` çağrıldığında
/// registry'de bulunan `defaultProvider()` (ilk available provider)
/// probe edilir ve state güncellenir. `AppBootstrap.fullInitialize()`
/// tarafından bir kez çağrılır; kullanıcı Settings'te `aiMode`'u
/// değiştirdiğinde tekrar çağrılabilir.
class AiCubit extends Cubit<AiState> {
  AiCubit() : super(AiState.initial);

  void markLoaded(String providerId) {
    emit(AiState(
      status: AiStatus.loaded,
      activeProviderId: providerId,
    ));
  }

  void markUnavailable() {
    emit(const AiState(status: AiStatus.unavailable));
  }

  void markError(String message) {
    emit(AiState(status: AiStatus.error, lastError: message));
  }

  /// Registry'yi probe et → ilk available provider'ı yansıt.
  ///
  /// Async IO olabilir (network ping vs.); hata durumunda state `error`
  /// emit eder, uygulama çökmez.
  Future<void> refresh(AiProviderRegistry registry) async {
    try {
      final provider = await registry.defaultProvider();
      if (provider == null) {
        markUnavailable();
      } else {
        markLoaded(provider.id);
      }
    } catch (e) {
      markError('AI probe failed: $e');
    }
  }
}
