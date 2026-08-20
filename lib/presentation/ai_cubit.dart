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
/// Phase 0'da stub: default olarak 'disabled' provider loaded olarak
/// işaretlenir. Phase 7'de registry'den available provider'lar probe
/// edilir.
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
}
