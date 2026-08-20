import 'dart:async';
import 'dart:io' show SocketException;

import 'package:db_explorer_app/core/utils/app_logger.dart';
import 'package:db_explorer_app/domain/database/capability.dart';
import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/domain/database/database_provider.dart';
import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/domain/database/schema.dart';
import 'package:db_explorer_app/infrastructure/database_providers/postgres/postgres_schema.dart';
import 'package:postgres/postgres.dart';

// ignore_for_file: prefer_single_quotes
// SQL string'leri çoğunlukla tek-tırnak literal içerir (örn. 'public',
// 'BASE TABLE'); çift tırnak kullanımı kasıtlı.

/// Gerçek PostgreSQL provider — `postgres` paketini kullanır.
///
/// Phase 5.3 sürümü:
/// - connect: TCP bağlantısı + SCRAM-SHA-256 auth
/// - schema discovery: information_schema + pg_catalog sorguları
/// - execute: SQL execute (RETURNING yoksa affectedRows; varsa result rows)
/// - explain: `EXPLAIN (FORMAT JSON) <sql>` — Postgres native JSON format
/// - completion: keyword listesi (schema-aware autocomplete Phase 8+ için)
///
/// Hata yönetimi:
/// - Bağlantı hatası → `ErrorConnection` (retryable: true, code: PG_CONNECTION_REFUSED vs.)
/// - Query hatası → exception throw (provider contract; UI handle eder)
/// - `closed` future tamamlandığında `DisconnectedConnection` (auto-reconnect hint'ı yok)
///
/// NOT: Bu provider `DatabaseProvider` interface'inin **gerçek** implementasyonudur.
/// Mock'un aksine external resource (network) gerektirir — CI'da test edilmez,
/// yalnızca Phase 8 integration test'lerinde bir test container'a karşı çalışır.
class RealPostgresProvider implements DatabaseProvider {
  RealPostgresProvider();

  final _log = getLogger('RealPostgresProvider');

  // Provider, oluşturulan connection handle'larını saklar.
  // Her DatabaseConnection.sessionId → Connection handle map'i.
  final Map<String, Connection> _connections = {};
  final Map<String, PostgresConnectionProfile> _profiles = {};

  // ─── Provider identity ────────────────────────────────────────────
  @override
  String get id => 'postgres';

  @override
  DatabaseKind get kind => DatabaseKind.postgres;

  @override
  DatabaseCapabilities get capabilities => const DatabaseCapabilities({
    DatabaseCapability.schemaHierarchy,
    DatabaseCapability.schemaIntrospection,
    DatabaseCapability.indexIntrospection,
    DatabaseCapability.relationalJoins,
    DatabaseCapability.fullTextSearch,
    DatabaseCapability.geospatial,
    DatabaseCapability.transactions,
    DatabaseCapability.streaming,
    DatabaseCapability.indexManagement,
    DatabaseCapability.explainPlan,
    DatabaseCapability.completion,
    DatabaseCapability.insert,
    DatabaseCapability.update,
    DatabaseCapability.delete,
    DatabaseCapability.bulkWrite,
    DatabaseCapability.createDatabase,
    DatabaseCapability.createCollection,
    DatabaseCapability.dropCollection,
    DatabaseCapability.schemaValidation,
    DatabaseCapability.serverInfo,
    DatabaseCapability.liveStats,
    DatabaseCapability.backup,
    DatabaseCapability.userManagement,
    DatabaseCapability.tlsSupport,
    DatabaseCapability.sshTunnelSupport,
  });

  // ─── Connection lifecycle ─────────────────────────────────────────
  @override
  Future<DatabaseConnection> connect(DatabaseConnectionConfig config) async {
    if (config is! PostgresConnectionProfile) {
      throw ArgumentError(
        'RealPostgresProvider requires PostgresConnectionProfile, '
        'got ${config.runtimeType}',
      );
    }

    final dbConn = DatabaseConnection(profile: config, providerId: id);
    dbConn.state = const ConnectingConnection(message: 'Resolving host...');

    final endpoint = Endpoint(
      host: config.host,
      port: config.port,
      database: config.databaseName ?? 'postgres',
      username: config.username,
      password: config.password,
    );

    final settings = ConnectionSettings(
      applicationName: config.applicationName ?? 'db_explorer_app',
      sslMode: _mapSslMode(config.sslMode),
      connectTimeout: config.connectTimeoutSeconds != null
          ? Duration(seconds: config.connectTimeoutSeconds!)
          : const Duration(seconds: 15),
    );

    try {
      dbConn.state = const ConnectingConnection(
        progress: 0.5,
        message: 'Authenticating (SCRAM-SHA-256)...',
      );
      final conn = await Connection.open(endpoint, settings: settings);
      final sessionId =
          'pg-sess-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';

      _connections[sessionId] = conn;
      _profiles[sessionId] = config;

      final serverInfo = await _readServerInfo(conn);
      dbConn.state = ConnectedConnection(
        sessionId: sessionId,
        at: DateTime.now(),
        serverVersion: serverInfo.$1,
        latencyMs: serverInfo.$2,
        uptimeSeconds: serverInfo.$3,
        extra: {
          'protocol': 'postgres-v3',
          'mode': 'real-driver',
          'database': config.databaseName ?? 'postgres',
        },
      );

      // Auto-disconnect hook — server kapattığında state'i düşür.
      // ignore: unawaited_futures
      conn.closed.then((_) {
        if (_connections.containsKey(sessionId)) {
          _connections.remove(sessionId);
          _profiles.remove(sessionId);
          dbConn.state = const DisconnectedConnection(reason: 'server-closed');
        }
      });

      _log.i('Connect OK: $sessionId (${config.label}, '
          'server=${serverInfo.$1})');
      return dbConn;
    } on ServerException catch (e) {
      // Server-side hata (PG SQLSTATE ile döner; örn. 28P01 invalid_password).
      dbConn.state = ErrorConnection(
        message: e.message,
        code: e.code != null ? 'PG_${e.code}' : 'PG_SERVER_ERROR',
        cause: e,
        // ServerException Fatal/Panic ise retry anlamsız; aksi halde auth hatası
        // tekrar denenebilir (ör. şifre değişmiş olabilir).
        isRetryable: e.severity != Severity.fatal &&
            e.severity != Severity.panic,
      );
      _log.w('Connect failed (server): ${e.message}');
      rethrow;
    } on PgException catch (e) {
      // Client-side hata (parser, codec, vs.).
      dbConn.state = ErrorConnection(
        message: e.message,
        code: 'PG_CLIENT_ERROR',
        cause: e,
      );
      _log.w('Connect failed (client): ${e.message}');
      rethrow;
    } on SocketException catch (e) {
      dbConn.state = ErrorConnection(
        message: 'Could not reach ${config.host}:${config.port}',
        code: 'PG_CONNECTION_REFUSED',
        cause: e,
      );
      rethrow;
    } catch (e) {
      dbConn.state = ErrorConnection(
        message: e.toString(),
        cause: e,
      );
      rethrow;
    }
  }

  @override
  Future<void> disconnect(DatabaseConnection connection) async {
    final state = connection.state;
    if (state is! ConnectedConnection) return;
    final conn = _connections.remove(state.sessionId);
    _profiles.remove(state.sessionId);
    if (conn != null && conn.isOpen) {
      await conn.close();
    }
    connection.state = const DisconnectedConnection(reason: 'user-request');
    _log.i('Disconnect: ${connection.profile.label}');
  }

  @override
  Future<bool> ping(DatabaseConnection connection) async {
    final conn = _requireConn(connection);
    try {
      final result = await conn.execute('SELECT 1');
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ─── Schema discovery ─────────────────────────────────────────────
  @override
  Future<List<DatabaseNode>> listDatabases(
    DatabaseConnection connection,
  ) async {
    final conn = _requireConn(connection);
    final result = await conn.execute(
      'SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname',
    );
    return result
        .map((row) => PostgresDatabase(name: row[0]! as String))
        .toList(growable: false);
  }

  @override
  Future<List<CollectionNode>> listCollections(
    DatabaseConnection connection,
    String database,
  ) async {
    final conn = _requireConn(connection);

    // information_schema.tables — sadece gerçek tablolar (VIEW'lar opsiyonel).
    // Phase 5'te sadece tables; views/sequences ileride eklenebilir.
    final tablesResult = await conn.execute(
      "SELECT table_name FROM information_schema.tables "
      "WHERE table_schema = 'public' AND table_type = 'BASE TABLE' "
      "ORDER BY table_name",
    );

    final tables = <PostgresTable>[];
    for (final row in tablesResult) {
      final tableName = row[0]! as String;
      final fields = await _readColumns(conn, tableName);
      final stats = await _readTableStats(conn, tableName);
      tables.add(PostgresTable(
        name: tableName,
        fields: fields,
        rowEstimate: stats.$1,
        totalSizeBytes: stats.$2,
      ));
    }
    return tables;
  }

  // ─── Query execution ──────────────────────────────────────────────
  @override
  Future<QueryResult> execute(
    DatabaseConnection connection,
    QueryRequest request,
  ) async {
    final conn = _requireConn(connection);
    if (request.language != QueryLanguage.sql) {
      throw ArgumentError(
        'Postgres provider only supports SQL, got ${request.language}',
      );
    }

    final started = DateTime.now();
    try {
      // Statement timeout — saniyeden millisecond'a çevir.
      if (request.timeout != null) {
        await conn.execute(
          "SET statement_timeout = ${request.timeout!.inMilliseconds}",
        );
      }

      // pageSize/pageOffset için SQL'e eklemiyoruz — kullanıcı kendi
      // LIMIT/OFFSET'ini yazsın (Postgres dünyasında doğal kalıp).
      // Ama UI için toplam satır sayısını tracking için kullanabiliriz.

      final result = await conn.execute(request.text);
      final rows = result
          .map((r) => DataRow(_rowToMap(r, result.schema)))
          .toList(growable: false);

      return QueryResult(
        columns: result.schema.columns
            .where((c) => c.columnName != null)
            .map((c) => c.columnName!)
            .toList(growable: false),
        rows: rows,
        affectedRows: result.affectedRows > 0 ? result.affectedRows : null,
        executionTime: DateTime.now().difference(started),
        totalCount: rows.length,
      );
    } on PgException catch (e) {
      throw FormatException('Postgres error: ${e.message}', e);
    }
  }

  // ─── Explain ──────────────────────────────────────────────────────
  @override
  Future<String> explain(
    DatabaseConnection connection,
    QueryRequest request,
  ) async {
    final conn = _requireConn(connection);
    // JSON formatı programatik parse için uygun; UI prettified gösterebilir.
    final result = await conn.execute(
      'EXPLAIN (FORMAT JSON) ${request.text}',
    );
    return result
        .map((r) => r[0]?.toString() ?? '{}')
        .join('\n');
  }

  // ─── Completion ───────────────────────────────────────────────────
  @override
  Future<List<CompletionItem>> complete(
    DatabaseConnection connection,
    CompletionContext context,
  ) async {
    // Phase 5: sadece SQL keyword'leri. Schema-aware autocomplete Phase 8+
    // (cubit'in connection scope'una göre table/column önerisi).
    return const [
      CompletionItem(label: 'SELECT', kind: 'keyword'),
      CompletionItem(label: 'FROM', kind: 'keyword'),
      CompletionItem(label: 'WHERE', kind: 'keyword'),
      CompletionItem(label: 'LIMIT', kind: 'keyword'),
      CompletionItem(label: 'OFFSET', kind: 'keyword'),
      CompletionItem(label: 'ORDER BY', kind: 'keyword'),
      CompletionItem(label: 'GROUP BY', kind: 'keyword'),
      CompletionItem(label: 'HAVING', kind: 'keyword'),
      CompletionItem(label: 'JOIN', kind: 'keyword'),
      CompletionItem(label: 'LEFT JOIN', kind: 'keyword'),
      CompletionItem(label: 'INNER JOIN', kind: 'keyword'),
      CompletionItem(label: 'INSERT INTO', kind: 'keyword'),
      CompletionItem(label: 'VALUES', kind: 'keyword'),
      CompletionItem(label: 'UPDATE', kind: 'keyword'),
      CompletionItem(label: 'SET', kind: 'keyword'),
      CompletionItem(label: 'DELETE FROM', kind: 'keyword'),
      CompletionItem(label: 'CREATE TABLE', kind: 'keyword'),
      CompletionItem(label: 'DROP TABLE', kind: 'keyword'),
      CompletionItem(label: 'ALTER TABLE', kind: 'keyword'),
      CompletionItem(label: 'BEGIN', kind: 'keyword'),
      CompletionItem(label: 'COMMIT', kind: 'keyword'),
      CompletionItem(label: 'ROLLBACK', kind: 'keyword'),
      CompletionItem(label: 'count(*)', kind: 'function', detail: 'Aggregate'),
      CompletionItem(label: 'sum()', kind: 'function', detail: 'Aggregate'),
      CompletionItem(label: 'avg()', kind: 'function', detail: 'Aggregate'),
      CompletionItem(label: 'now()', kind: 'function', detail: 'Current timestamp'),
      CompletionItem(label: 'COALESCE', kind: 'function'),
    ];
  }

  // ─── Internal helpers ─────────────────────────────────────────────
  Connection _requireConn(DatabaseConnection connection) {
    final state = connection.state;
    if (state is! ConnectedConnection) {
      throw StateError(
        'Operation called on inactive connection '
        '(state=${state.runtimeType})',
      );
    }
    final conn = _connections[state.sessionId];
    if (conn == null) {
      throw StateError(
        'Connection handle for session ${state.sessionId} is gone '
        '(auto-disconnect?)',
      );
    }
    return conn;
  }

  Future<(String, int, int)> _readServerInfo(Connection conn) async {
    final t0 = DateTime.now();
    final versionResult = await conn.execute('SHOW server_version');
    final version = versionResult.isNotEmpty
        ? versionResult.first[0]?.toString() ?? 'unknown'
        : 'unknown';
    final latency = DateTime.now().difference(t0).inMilliseconds;

    // Uptime pg_postmaster_start_time'dan hesaplanır (opsiyonel).
    int uptime = 0;
    try {
      final uptimeResult = await conn.execute(
        "SELECT EXTRACT(EPOCH FROM (now() - pg_postmaster_start_time()))::int",
      );
      if (uptimeResult.isNotEmpty) {
        uptime = (uptimeResult.first[0] as int?) ?? 0;
      }
    } catch (_) {
      // pg_postmaster_start_time erişim izni yoksa 0 bırak.
    }
    return (version, latency, uptime);
  }

  Future<List<PostgresColumn>> _readColumns(
    Connection conn,
    String tableName,
  ) async {
    // Phase 5'te Sql.named yerine doğrudan string interpolation kullanıyoruz —
    // tableName güvenli bir identifier (validate edilmemiş olsa da SQL injection
    // riski regclass cast ile sınırlı). Phase 8'de Sql.named + parameters
    // kalıbına geçilecek.
    final safeTable = _escapeIdentifier(tableName);
    final result = await conn.execute(
      'SELECT column_name, data_type, is_nullable, column_default '
      "FROM information_schema.columns "
      "WHERE table_schema = 'public' AND table_name = '$safeTable' "
      'ORDER BY ordinal_position',
    );

    // Primary key kolonlarını bir seferde oku.
    final pkResult = await conn.execute(
      'SELECT a.attname FROM pg_index i '
      'JOIN pg_attribute a ON a.attrelid = i.indrelid '
      'AND a.attnum = ANY(i.indkey) '
      "WHERE i.indrelid = '$safeTable'::regclass AND i.indisprimary",
    );
    final pkColumns = pkResult
        .map((r) => r[0] as String)
        .toSet();

    // Indexed kolonları (PK + unique + non-unique).
    final idxResult = await conn.execute(
      'SELECT a.attname FROM pg_index i '
      'JOIN pg_attribute a ON a.attrelid = i.indrelid '
      'AND a.attnum = ANY(i.indkey) '
      "WHERE i.indrelid = '$safeTable'::regclass AND NOT i.indisprimary",
    );
    final indexedCols = idxResult
        .map((r) => r[0] as String)
        .toSet();

    return result
        .map((row) {
          final name = row[0]! as String;
          final dataType = row[1]! as String;
          final isNullable = (row[2] as String?) == 'YES';
          final defaultValue = row[3]?.toString();
          final isPk = pkColumns.contains(name);
          return PostgresColumn(
            name: name,
            dataType: dataType,
            isNullable: isNullable,
            isIndexed: isPk || indexedCols.contains(name),
            columnDefault: defaultValue,
            isPrimaryKey: isPk,
          );
        })
        .toList(growable: false);
  }

  Future<(int?, int?)> _readTableStats(
    Connection conn,
    String tableName,
  ) async {
    final safeTable = _escapeIdentifier(tableName);
    try {
      final result = await conn.execute(
        'SELECT c.reltuples::bigint AS row_estimate, '
        'pg_relation_size(c.oid) AS data_bytes '
        'FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace '
        "WHERE c.relname = '$safeTable' AND n.nspname = 'public'",
      );
      if (result.isEmpty) return (null, null);
      final row = result.first;
      final rows = row[0] as int?;
      final size = row[1] as int?;
      return (rows, size);
    } catch (_) {
      return (null, null);
    }
  }

  /// SQL identifier (table name) escape — phase 5 sürümü basit:
  /// sadece alfanumerik + underscore kontrolü. Tehlikeli karakterler reject.
  String _escapeIdentifier(String id) {
    final ok = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
    if (!ok.hasMatch(id)) {
      throw ArgumentError('Invalid SQL identifier: $id');
    }
    return id;
  }

  Map<String, Object?> _rowToMap(ResultRow row, ResultSchema schema) {
    final map = <String, Object?>{};
    for (var i = 0; i < schema.columns.length; i++) {
      final col = schema.columns[i];
      final name = col.columnName;
      if (name == null || name.isEmpty) continue;
      final value = i < row.length ? row[i] : null;
      map[name] = value;
    }
    return map;
  }

  dynamic _mapSslMode(PostgresSslMode mode) {
    // `postgres` paketinin SslMode enum'una map.
    return switch (mode) {
      PostgresSslMode.disable => SslMode.disable,
      PostgresSslMode.require => SslMode.require,
      PostgresSslMode.verifyFull => SslMode.verifyFull,
    };
  }
}

/// RealPostgresProvider factory.
///
/// Phase 5'te default değil — feature flag ile Phase 8'de wiring yapılacak.
/// Şimdiden factory tanımlı; registry'de mock default kalır.
class RealPostgresProviderFactory implements DatabaseProviderFactory {
  const RealPostgresProviderFactory();

  @override
  DatabaseProvider create() => RealPostgresProvider();

  @override
  DatabaseKind get kind => DatabaseKind.postgres;
}
