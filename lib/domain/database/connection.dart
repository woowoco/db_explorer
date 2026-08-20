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

  /// Bu kind için storage key prefix (secure store'da ayrım için).
  String get storageKeyPrefix => switch (this) {
    DatabaseKind.mongodb => 'dbx_conn_mongo_',
    DatabaseKind.postgres => 'dbx_conn_pg_',
    DatabaseKind.redis => 'dbx_conn_redis_',
    DatabaseKind.elasticsearch => 'dbx_conn_es_',
  };
}

/// Connection profile (sealed) — provider'a göre farklı alanlar.
///
/// Phase 1'de MongoDB genişletildi (authSource, replicaSet, ssl, directConnection);
/// diğer provider'lar ilgili fazlarda eklenecek. sealed pattern sayesinde
/// derleyici `switch` exhaustiveness kontrolü yapar.
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
    this.replicaSet,
    this.ssl = false,
    this.directConnection = false,
    this.serverSelectionTimeoutMs,
  });

  /// Şifre (RAM'de tutulur; persistent storage'da ayrı secure store).
  final String? password;

  /// MongoDB auth source database (genelde "admin").
  final String? authSource;

  /// Replica set adı (varsa).
  final String? replicaSet;

  /// TLS/SSL bağlantısı kullan.
  final bool ssl;

  /// Direct connection (replica set bypass).
  final bool directConnection;

  /// Server selection timeout (ms). null = driver default.
  final int? serverSelectionTimeoutMs;

  @override
  DatabaseKind get kind => DatabaseKind.mongodb;

  MongoConnectionProfile copyWith({
    String? id,
    String? label,
    String? host,
    int? port,
    String? databaseName,
    String? username,
    Map<String, String>? options,
    String? password,
    String? authSource,
    String? replicaSet,
    bool? ssl,
    bool? directConnection,
    int? serverSelectionTimeoutMs,
  }) {
    return MongoConnectionProfile(
      id: id ?? this.id,
      label: label ?? this.label,
      host: host ?? this.host,
      port: port ?? this.port,
      databaseName: databaseName ?? this.databaseName,
      username: username ?? this.username,
      options: options ?? this.options,
      password: password ?? this.password,
      authSource: authSource ?? this.authSource,
      replicaSet: replicaSet ?? this.replicaSet,
      ssl: ssl ?? this.ssl,
      directConnection: directConnection ?? this.directConnection,
      serverSelectionTimeoutMs:
          serverSelectionTimeoutMs ?? this.serverSelectionTimeoutMs,
    );
  }
}

/// Sealed connection state — provider implementasyonu emit eder.
///
/// Her alt sınıf, UI'ın connection panelinde gösterebileceği structured
/// data taşır (latency, server version, error code, vs.).
sealed class DatabaseConnectionState {
  const DatabaseConnectionState();
}

/// Henüz denenmedi (initial state).
class IdleConnection extends DatabaseConnectionState {
  const IdleConnection();
}

/// Bağlantı deneniyor — progress yüzdesi opsiyonel.
class ConnectingConnection extends DatabaseConnectionState {
  const ConnectingConnection({this.progress = 0.0, this.message});
  final double progress; // 0.0..1.0
  final String? message;
}

/// Bağlantı kuruldu — server bilgisi + latency taşır.
class ConnectedConnection extends DatabaseConnectionState {
  const ConnectedConnection({
    required this.sessionId,
    required this.at,
    this.serverVersion,
    this.latencyMs,
    this.uptimeSeconds,
    this.extra = const {},
  });
  final String sessionId;
  final DateTime at;

  /// Sunucu versiyonu (örn. "7.0.5" MongoDB, "16.3" Postgres).
  final String? serverVersion;

  /// Handshake latency (ms).
  final int? latencyMs;

  /// Server uptime (seconds).
  final int? uptimeSeconds;

  /// Provider'a özel ekstra bilgi (replica set name, db list, vs.).
  final Map<String, String> extra;
}

/// Bağlantı hatası — kodlanmış kategori + insan-okur mesaj.
class ErrorConnection extends DatabaseConnectionState {
  const ErrorConnection({
    required this.message,
    this.code,
    this.cause,
    this.isRetryable = true,
  });

  final String message;

  /// Hata kodu (provider'a özel: MongoAuthFailure, PostgresConnectionRefused, vs.).
  final String? code;

  /// Underlying exception (debug/log için).
  final Object? cause;

  /// Yeniden denenebilir mi? UI'da "Retry" butonu gösterimi için.
  final bool isRetryable;
}

/// Kullanıcı tarafından kesildi (logout / app pause).
class DisconnectedConnection extends DatabaseConnectionState {
  const DisconnectedConnection({this.reason});
  final String? reason;
}

/// Connection wrapper — provider'dan gelen handle + state.
///
/// `state` mutable (lifecycle update); geri kalan alanlar immutable.
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

  /// Şu anda aktif bir state'te mi? (Connecting / Connected)
  bool get isActive => isConnecting || isConnected;

  /// Connected ise serverVersion'a cast edip döner.
  String? get serverVersion {
    final s = state;
    return s is ConnectedConnection ? s.serverVersion : null;
  }
}