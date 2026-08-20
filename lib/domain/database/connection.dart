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
/// Phase 1: MongoDB genişletildi (authSource, replicaSet, ssl, directConnection).
/// Phase 5: PostgreSQL eklendi (password, sslMode, applicationName, connectTimeout).
/// Diğer provider'lar ilgili fazlarda eklenecek. sealed pattern sayesinde
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

/// PostgreSQL connection profile.
///
/// Postgres için tipik alanlar (RFC 3986 connection string parametreleri):
/// - host / port (default 5432)
/// - databaseName (zorunlu — Postgres "database" kavramı her connection için zorunlu)
/// - username + password (auth için; SCRAM-SHA-256 default)
/// - sslMode: disable / require / verifyFull (verify-full için securityContext ayrı)
/// - applicationName: pg_stat_activity'te görünür (debug için faydalı)
/// - connectTimeout: TCP bağlantı zaman aşımı
/// - statementTimeout: query başına max süre (saniye, 0 = sınırsız)
///
/// NOT: password RAM'de tutulur (MongoConnectionProfile ile aynı kalıp).
/// Persistent storage'da ayrı secure store'a yazılır.
class PostgresConnectionProfile extends DatabaseConnectionConfig {
  const PostgresConnectionProfile({
    required super.id,
    required super.label,
    required super.host,
    super.port = 5432,
    required super.databaseName,
    super.username,
    super.options,
    this.password,
    this.sslMode = PostgresSslMode.require,
    this.applicationName,
    this.connectTimeoutSeconds,
    this.statementTimeoutSeconds,
  });

  /// Şifre (RAM'de tutulur; persistent storage'da ayrı secure store).
  final String? password;

  /// TLS/SSL bağlantı politikası.
  final PostgresSslMode sslMode;

  /// `pg_stat_activity`'de görünen application_name.
  final String? applicationName;

  /// TCP bağlantı zaman aşımı (saniye). null = driver default (15s).
  final int? connectTimeoutSeconds;

  /// Statement-level timeout (saniye). 0 = sınırsız. null = driver default (5min).
  final int? statementTimeoutSeconds;

  @override
  DatabaseKind get kind => DatabaseKind.postgres;

  PostgresConnectionProfile copyWith({
    String? id,
    String? label,
    String? host,
    int? port,
    String? databaseName,
    String? username,
    Map<String, String>? options,
    String? password,
    PostgresSslMode? sslMode,
    String? applicationName,
    int? connectTimeoutSeconds,
    int? statementTimeoutSeconds,
  }) {
    return PostgresConnectionProfile(
      id: id ?? this.id,
      label: label ?? this.label,
      host: host ?? this.host,
      port: port ?? this.port,
      databaseName: databaseName ?? this.databaseName,
      username: username ?? this.username,
      options: options ?? this.options,
      password: password ?? this.password,
      sslMode: sslMode ?? this.sslMode,
      applicationName: applicationName ?? this.applicationName,
      connectTimeoutSeconds:
          connectTimeoutSeconds ?? this.connectTimeoutSeconds,
      statementTimeoutSeconds:
          statementTimeoutSeconds ?? this.statementTimeoutSeconds,
    );
  }
}

/// PostgreSQL SSL/TLS mode.
///
/// `postgres` paketinin `SslMode` enum'unu birebir yansıtır:
/// - `disable`: SSL yok (şifre plaintext gidebilir)
/// - `require`: SSL zorunlu ama sertifika doğrulanmaz (self-signed OK)
/// - `verifyFull`: SSL + CA + hostname doğrulama (production için tek güvenli mod)
///
///
/// `prefer` burada "require"a eşlenir çünkü Postgres default'u `prefer`'dır
/// ama bu paketin tercih ettiği davranış (modern Postgres'te SSL varsa kullan).
enum PostgresSslMode {
  disable,
  require,
  verifyFull;

  /// `postgres` paketinin `SslMode` enum'una map.
  ///
  /// Map'lenemeyen değerler için `prefer` olarak davranır.
  String get storageValue => switch (this) {
        PostgresSslMode.disable => 'disable',
        PostgresSslMode.require => 'require',
        PostgresSslMode.verifyFull => 'verify-full',
      };

  /// Human-readable label (UI dropdown'lar için).
  String get label => switch (this) {
        PostgresSslMode.disable => 'Disabled (plaintext)',
        PostgresSslMode.require => 'Required (no verification)',
        PostgresSslMode.verifyFull => 'Verify full (CA + hostname)',
      };
}

/// Redis connection profile.
///
/// Redis authentication modeli:
/// - Default: şifre yok (Redis 6 öncesi davranış)
/// - Redis 6+: ACL sistemi (username + password). Legacy `requirepass` desteği
///   için password tek başına yeterli — username null olursa legacy mode'a
///   geçer (`AUTH <password>`).
///
/// Veritabanı (dbIndex): 0-15 default. Cluster mode'da tüm node'lar aynı
/// dbIndex'i paylaşır (cluster-aware routing RedisDBProvider'da ileride).
class RedisConnectionProfile extends DatabaseConnectionConfig {
  const RedisConnectionProfile({
    required super.id,
    required super.label,
    required super.host,
    super.port = 6379,
    super.username,
    this.password,
    this.dbIndex = 0,
    this.useTls = false,
    this.connectTimeoutSeconds,
    super.options,
  });

  /// Şifre (legacy `requirepass` veya ACL password).
  final String? password;

  /// Default database index (0-15 default Redis'te; cluster'da tüm node'lar).
  final int dbIndex;

  /// TLS/SSL bağlantısı (redis:// vs rediss://).
  final bool useTls;

  /// TCP bağlantı zaman aşımı (saniye). null = driver default.
  final int? connectTimeoutSeconds;

  @override
  DatabaseKind get kind => DatabaseKind.redis;

  RedisConnectionProfile copyWith({
    String? id,
    String? label,
    String? host,
    int? port,
    String? username,
    String? password,
    int? dbIndex,
    bool? useTls,
    int? connectTimeoutSeconds,
    Map<String, String>? options,
  }) {
    return RedisConnectionProfile(
      id: id ?? this.id,
      label: label ?? this.label,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      dbIndex: dbIndex ?? this.dbIndex,
      useTls: useTls ?? this.useTls,
      connectTimeoutSeconds:
          connectTimeoutSeconds ?? this.connectTimeoutSeconds,
      options: options ?? this.options,
    );
  }
}

/// Elasticsearch connection profile.
///
/// Auth modeli (Phase 6):
/// - `username` + `password` (basic auth — default ES security)
/// - `apiKey` (base64 encoded "id:api_key") — REST API için önerilen
///
/// Eğer `apiKey` set edilirse `username`/`password` override edilir.
/// `scheme`: http (default dev) veya https (production).
///
/// `databaseName` ES'te "index" olarak kullanılır (UI'da gözükecek).
class ElasticsearchConnectionProfile extends DatabaseConnectionConfig {
  const ElasticsearchConnectionProfile({
    required super.id,
    required super.label,
    required super.host,
    super.port = 9200,
    this.scheme = 'http',
    super.username,
    this.password,
    this.apiKey,
    this.requestTimeoutSeconds,
    super.options,
  });

  /// http (default dev) veya https (production).
  final String scheme;

  /// Basic auth password.
  final String? password;

  /// API key (`base64(id:api_key)`). Set edilirse basic auth override.
  final String? apiKey;

  /// Per-request timeout (saniye). null = driver default (1 min).
  final int? requestTimeoutSeconds;

  @override
  DatabaseKind get kind => DatabaseKind.elasticsearch;

  ElasticsearchConnectionProfile copyWith({
    String? id,
    String? label,
    String? host,
    int? port,
    String? scheme,
    String? username,
    String? password,
    String? apiKey,
    int? requestTimeoutSeconds,
    Map<String, String>? options,
  }) {
    return ElasticsearchConnectionProfile(
      id: id ?? this.id,
      label: label ?? this.label,
      host: host ?? this.host,
      port: port ?? this.port,
      scheme: scheme ?? this.scheme,
      username: username ?? this.username,
      password: password ?? this.password,
      apiKey: apiKey ?? this.apiKey,
      requestTimeoutSeconds:
          requestTimeoutSeconds ?? this.requestTimeoutSeconds,
      options: options ?? this.options,
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