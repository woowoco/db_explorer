/// Veritabanı türü enum'u.
enum DatabaseKind {
  /// MongoDB (Phase 3 MVP)
  mongodb,

  /// PostgreSQL (Phase 5+)
  postgres,

  /// Redis (Phase 6+)
  redis,

  /// Elasticsearch (Phase 6+)
  elasticsearch,
}

/// DatabaseKind human-readable label.
extension DatabaseKindLabel on DatabaseKind {
  String get label => switch (this) {
    DatabaseKind.mongodb => 'MongoDB',
    DatabaseKind.postgres => 'PostgreSQL',
    DatabaseKind.redis => 'Redis',
    DatabaseKind.elasticsearch => 'Elasticsearch',
  };
}

/// Connection profile (sealed) — provider'a göre farklı alanlar.
///
/// Phase 0'da sadece MongoDBConnectionProfile var; diğerleri sonraki
/// fazlarda eklenecek. sealed pattern sayesinde derleyici
/// `switch` exhaustiveness kontrolü yapar.
sealed class DatabaseConnectionConfig {
  const DatabaseConnectionConfig({
    required this.id,
    required this.label,
    required this.host,
    required this.port,
    this.databaseName,
    this.username,
    this.options = const {},
  });

  /// Benzersiz kimlik (UUID v4).
  final String id;

  /// Kullanıcı dostu etiket ("Local Mongo", "Production Mongo Cluster").
  final String label;

  final String host;
  final int port;

  /// Default database (MongoDB'de `authSource`, Postgres'te default db).
  final String? databaseName;

  /// Kullanıcı adı (MongoDB'de optional — auth aktifse).
  final String? username;

  /// Provider'a özel ek ayarlar (replicaSet, sslMode, vs.).
  final Map<String, String> options;

  DatabaseKind get kind;
}

/// MongoDB connection profile.
class MongoConnectionProfile extends DatabaseConnectionConfig {
  const MongoConnectionProfile({
    required super.id,
    required super.label,
    required super.host,
    required super.port,
    super.databaseName,
    super.username,
    super.options,
    this.password,
    this.authSource,
  });

  /// Şifre (RAM'de tutulur; persistent storage'da ayrı secure store).
  final String? password;

  /// MongoDB auth source database.
  final String? authSource;

  @override
  DatabaseKind get kind => DatabaseKind.mongodb;
}

/// Sealed connection state — provider implementasyonu emit eder.
sealed class DatabaseConnectionState {
  const DatabaseConnectionState();
}

class IdleConnection extends DatabaseConnectionState {
  const IdleConnection();
}

class ConnectingConnection extends DatabaseConnectionState {
  const ConnectingConnection();
}

class ConnectedConnection extends DatabaseConnectionState {
  const ConnectedConnection({required this.sessionId, required this.at});
  final String sessionId;
  final DateTime at;
}

class ErrorConnection extends DatabaseConnectionState {
  const ErrorConnection(this.message, {this.cause});
  final String message;
  final Object? cause;
}

class DisconnectedConnection extends DatabaseConnectionState {
  const DisconnectedConnection();
}

/// Connection wrapper — provider'dan gelen handle + state.
class DatabaseConnection {
  DatabaseConnection({
    required this.profile,
    required this.providerId,
    this.state = const IdleConnection(),
  });

  final DatabaseConnectionConfig profile;
  final String providerId;
  DatabaseConnectionState state;

  bool get isConnected => state is ConnectedConnection;
  bool get isConnecting => state is ConnectingConnection;
  bool get isIdle => state is IdleConnection;
  bool get isError => state is ErrorConnection;
  bool get isDisconnected => state is DisconnectedConnection;
}
