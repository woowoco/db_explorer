import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Connection state — connection list, active connection.
class ConnectionState extends Equatable {
  const ConnectionState({
    this.connections = const [],
    this.activeConnectionId,
    this.lastError,
  });

  final List<DatabaseConnectionConfig> connections;
  final String? activeConnectionId;
  final String? lastError;

  bool get hasActive => activeConnectionId != null;

  DatabaseConnectionConfig? get activeConnection {
    if (activeConnectionId == null) return null;
    for (final c in connections) {
      if (c.id == activeConnectionId) return c;
    }
    return null;
  }

  ConnectionState copyWith({
    List<DatabaseConnectionConfig>? connections,
    String? activeConnectionId,
    String? lastError,
  }) {
    return ConnectionState(
      connections: connections ?? this.connections,
      activeConnectionId: activeConnectionId ?? this.activeConnectionId,
      lastError: lastError,
    );
  }

  @override
  List<Object?> get props => [connections, activeConnectionId, lastError];
}

class ConnectionCubit extends Cubit<ConnectionState> {
  ConnectionCubit() : super(const ConnectionState());

  void upsertConnection(DatabaseConnectionConfig profile) {
    final updated = <DatabaseConnectionConfig>[
      for (final c in state.connections)
        if (c.id != profile.id) c,
      profile,
    ];
    emit(state.copyWith(connections: updated));
  }

  void removeConnection(String id) {
    final updated = state.connections.where((c) => c.id != id).toList();
    final newActive = state.activeConnectionId == id
        ? null
        : state.activeConnectionId;
    emit(state.copyWith(connections: updated, activeConnectionId: newActive));
  }

  void setActive(String id) {
    emit(state.copyWith(activeConnectionId: id));
  }

  void reportError(String message) {
    emit(state.copyWith(lastError: message));
  }

  void clearError() {
    emit(ConnectionState(
      connections: state.connections,
      activeConnectionId: state.activeConnectionId,
    ));
  }
}
