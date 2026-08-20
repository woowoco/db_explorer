import 'dart:async';
import 'dart:io' show SocketException;

import 'package:db_explorer_app/core/utils/app_logger.dart';
import 'package:db_explorer_app/domain/database/capability.dart';
import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/domain/database/database_provider.dart';
import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/domain/database/schema.dart';
import 'package:db_explorer_app/infrastructure/database_providers/redis/redis_schema.dart';
import 'package:redis/redis.dart';

/// Gerçek Redis provider — `redis` paketini kullanır.
///
/// Phase 6.3 sürümü:
/// - connect: TCP bağlantısı + (opsiyonel) AUTH + SELECT dbIndex
/// - listDatabases: CONFIG GET databases ile okunur (default 16; override mümkün)
/// - listCollections: SCAN ile key listesi (KEYS değil — production'da KEYS
///   O(N) blocking'dir, SCAN cursor-based güvenli)
/// - execute: komut parser — Redis protocol üzerinden arbitrary `send_object`
/// - complete: Redis command listesi
///
/// Hata yönetimi:
/// - Bağlantı hatası → `ErrorConnection` (retryable: true, code: REDIS_REFUSED
///   vs.)
/// - RedisError (server-side) → QueryResult içinde fırlatılır
/// - Closed socket → DisconnectedConnection
///
/// NOT: Bu provider `DatabaseProvider` interface'inin **gerçek** implementasyonudur.
/// Mock'un aksine external resource (network) gerektirir — CI'da test edilmez,
/// yalnızca Phase 8 integration test'lerinde bir test container'a karşı çalışır.
class RealRedisProvider implements DatabaseProvider {
  RealRedisProvider();

  final _log = getLogger('RealRedisProvider');

  // Session bazlı connection handle map'i.
  final Map<String, _Session> _sessions = {};

  _Session _require(DatabaseConnection connection) {
    final state = connection.state;
    if (state is! ConnectedConnection) {
      throw StateError(
        'Operation called on inactive connection '
        '(state=${state.runtimeType})',
      );
    }
    final session = _sessions[state.sessionId];
    if (session == null) {
      throw StateError(
        'Session ${state.sessionId} is gone (auto-disconnect?)',
      );
    }
    return session;
  }

  // ─── Provider identity ────────────────────────────────────────────
  @override
  String get id => 'redis';

  @override
  DatabaseKind get kind => DatabaseKind.redis;

  @override
  DatabaseCapabilities get capabilities => const DatabaseCapabilities({
    DatabaseCapability.streaming,
    DatabaseCapability.completion,
    DatabaseCapability.fullTextSearch,
    DatabaseCapability.serverInfo,
    DatabaseCapability.liveStats,
    DatabaseCapability.tlsSupport,
    DatabaseCapability.insert,
    DatabaseCapability.update,
    DatabaseCapability.delete,
    DatabaseCapability.bulkWrite,
    DatabaseCapability.transactions,
    DatabaseCapability.createCollection,
    DatabaseCapability.dropCollection,
    DatabaseCapability.userManagement,
    DatabaseCapability.backup,
  });

  // ─── Connection lifecycle ─────────────────────────────────────────
  @override
  Future<DatabaseConnection> connect(DatabaseConnectionConfig config) async {
    if (config is! RedisConnectionProfile) {
      throw ArgumentError(
        'RealRedisProvider requires RedisConnectionProfile, '
        'got ${config.runtimeType}',
      );
    }

    final dbConn = DatabaseConnection(profile: config, providerId: id);
    dbConn.state = const ConnectingConnection(message: 'Resolving host...');

    try {
      dbConn.state = const ConnectingConnection(
        progress: 0.4,
        message: 'Opening socket...',
      );

      final redisConn = RedisConnection();
      final command = config.useTls
          ? await redisConn.connectSecure(config.host, config.port)
          : await redisConn.connect(config.host, config.port);

      // AUTH — ACL (Redis 6+) veya legacy.
      dbConn.state = const ConnectingConnection(
        progress: 0.7,
        message: 'Authenticating...',
      );
      if (config.password != null && config.password!.isNotEmpty) {
        if (config.username != null && config.username!.isNotEmpty) {
          await command.send_object(
            ['AUTH', config.username, config.password],
          );
        } else {
          await command.send_object(['AUTH', config.password]);
        }
      }

      // SELECT dbIndex (default 0).
      if (config.dbIndex != 0) {
        await command.send_object(['SELECT', config.dbIndex.toString()]);
      }

      // PING ile bağlantıyı doğrula + latency ölç.
      final t0 = DateTime.now();
      await command.send_object(['PING']);
      final latency = DateTime.now().difference(t0).inMilliseconds;

      // Server info (opsiyonel — PING sonrası).
      String? serverVersion;
      int? uptime;
      try {
        final info = await command.send_object(['INFO', 'server']);
        if (info is List && info.isNotEmpty) {
          final text = info.first?.toString() ?? '';
          serverVersion = _extractInfoValue(text, 'redis_version');
          final uptimeSec = _extractInfoValue(text, 'uptime_in_seconds');
          uptime = int.tryParse(uptimeSec ?? '');
        }
      } catch (_) {
        // INFO yoksa skip.
      }

      final sessionId =
          'redis-sess-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
      _sessions[sessionId] = _Session(
        redisConn: redisConn,
        command: command,
        dbIndex: config.dbIndex,
      );

      dbConn.state = ConnectedConnection(
        sessionId: sessionId,
        at: DateTime.now(),
        serverVersion: serverVersion,
        latencyMs: latency,
        uptimeSeconds: uptime,
        extra: {
          'protocol': 'RESP2',
          'mode': 'real-driver',
          'dbIndex': config.dbIndex.toString(),
          'tls': config.useTls.toString(),
        },
      );
      _log.i('Connect OK: $sessionId (${config.label}, redis=$serverVersion)');
      return dbConn;
    } on RedisError catch (e) {
      dbConn.state = ErrorConnection(
        message: e.error,
        code: 'REDIS_SERVER_ERROR',
        cause: e,
      );
      _log.w('Connect failed (Redis): ${e.error}');
      rethrow;
    } on RedisRuntimeError catch (e) {
      dbConn.state = ErrorConnection(
        message: e.error,
        code: 'REDIS_RUNTIME_ERROR',
        cause: e,
      );
      _log.w('Connect failed (runtime): ${e.error}');
      rethrow;
    } on SocketException catch (e) {
      dbConn.state = ErrorConnection(
        message: 'Could not reach ${config.host}:${config.port}',
        code: 'REDIS_CONNECTION_REFUSED',
        cause: e,
      );
      rethrow;
    } catch (e) {
      dbConn.state = ErrorConnection(
        message: e.toString(),
        code: 'REDIS_UNKNOWN_ERROR',
        cause: e,
      );
      rethrow;
    }
  }

  @override
  Future<void> disconnect(DatabaseConnection connection) async {
    final state = connection.state;
    if (state is! ConnectedConnection) return;
    final session = _sessions.remove(state.sessionId);
    if (session != null) {
      try {
        await session.redisConn.close();
      } catch (_) {
        // Close hatası yoksayılabilir.
      }
    }
    connection.state = const DisconnectedConnection(reason: 'user-request');
    _log.i('Disconnect: ${connection.profile.label}');
  }

  @override
  Future<bool> ping(DatabaseConnection connection) async {
    final session = _require(connection);
    try {
      await session.command.send_object(['PING']);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Schema discovery ─────────────────────────────────────────────
  @override
  Future<List<DatabaseNode>> listDatabases(
    DatabaseConnection connection,
  ) async {
    final session = _require(connection);
    try {
      final raw = await session.command.send_object(['CONFIG', 'GET', 'databases']);
      // Yanıt: ['databases', '16']
      int count = 16; // Redis default.
      if (raw is List && raw.length >= 2) {
        final parsed = int.tryParse(raw[1]?.toString() ?? '');
        if (parsed != null && parsed > 0) count = parsed;
      }
      return List.generate(
        count,
        (i) => RedisDatabase(name: 'db$i'),
      );
    } on RedisError catch (_) {
      // CONFIG GET yetkisi yoksa default 16'yı döner.
      return List.generate(16, (i) => RedisDatabase(name: 'db$i'));
    }
  }

  @override
  Future<List<CollectionNode>> listCollections(
    DatabaseConnection connection,
    String database,
  ) async {
    final session = _require(connection);
    // Aktif dbIndex'i değiştir (SCAN tek db'ye bağlı).
    final requestedDb = int.tryParse(database.replaceFirst('db', '')) ?? session.dbIndex;
    if (requestedDb != session.dbIndex) {
      await session.command.send_object(['SELECT', requestedDb.toString()]);
    }
    try {
      // SCAN ile tüm key'leri cursor-based çek (KEYS O(N) blocking).
      final raw = await session.command.send_object(['SCAN', '0', 'COUNT', '100']);
      if (raw is! List || raw.length < 2) return const [];

      final keysList = raw[1];
      if (keysList is! List) return const [];

      final result = <RedisKey>[];
      for (final key in keysList) {
        final keyName = key.toString();
        // TYPE + (opsiyonel) TTL + SIZE paralel olarak okunabilir — Phase 8+
        // için. Şimdilik yalnızca TYPE.
        final typeRaw = await session.command
            .send_object(['TYPE', keyName]);
        final keyType = (typeRaw is List && typeRaw.isNotEmpty)
            ? (typeRaw.first?.toString() ?? 'string')
            : typeRaw.toString();

        result.add(RedisKey(name: keyName, keyType: keyType));
      }
      return result;
    } finally {
      if (requestedDb != session.dbIndex) {
        await session.command
            .send_object(['SELECT', session.dbIndex.toString()]);
      }
    }
  }

  // ─── Query execution ──────────────────────────────────────────────
  @override
  Future<QueryResult> execute(
    DatabaseConnection connection,
    QueryRequest request,
  ) async {
    final session = _require(connection);
    if (request.language != QueryLanguage.redisCmd) {
      throw ArgumentError(
        'Redis provider only supports redisCmd, got ${request.language}',
      );
    }

    final started = DateTime.now();
    try {
      final raw = await _sendCommandText(session, request.text);
      final rows = _normalizeResponse(raw);

      return QueryResult(
        columns: rows.isNotEmpty
            ? rows.first.values.keys.toList()
            : const <String>[],
        rows: rows,
        executionTime: DateTime.now().difference(started),
        totalCount: rows.length,
      );
    } on RedisError catch (e) {
      throw FormatException('Redis error: ${e.error}', e);
    }
  }

  // ─── Explain ──────────────────────────────────────────────────────
  @override
  Future<String> explain(
    DatabaseConnection connection,
    QueryRequest request,
  ) async {
    // Redis'te native EXPLAIN yok. Komut hakkında bilinen complexity bilgisini
    // komut adına göre döndürürüz.
    final cmd = request.text.trim().split(RegExp(r'\s+')).first.toUpperCase();
    return '''
// Redis — no native explain
Command: $cmd
Source: real Redis server (no query planner)
''';
  }

  // ─── Completion ───────────────────────────────────────────────────
  @override
  Future<List<CompletionItem>> complete(
    DatabaseConnection connection,
    CompletionContext context,
  ) async {
    // Phase 6: komut listesi. Schema-aware autocomplete (key/value önerileri)
    // Phase 8+ için.
    return const [
      CompletionItem(label: 'GET', kind: 'keyword', detail: 'GET key'),
      CompletionItem(label: 'SET', kind: 'keyword', detail: 'SET key value'),
      CompletionItem(label: 'DEL', kind: 'keyword', detail: 'DEL key [key ...]'),
      CompletionItem(label: 'KEYS', kind: 'keyword', detail: 'KEYS pattern'),
      CompletionItem(label: 'SCAN', kind: 'keyword', detail: 'SCAN cursor COUNT n'),
      CompletionItem(label: 'EXISTS', kind: 'keyword', detail: 'EXISTS key'),
      CompletionItem(label: 'EXPIRE', kind: 'keyword'),
      CompletionItem(label: 'TTL', kind: 'keyword'),
      CompletionItem(label: 'HGET', kind: 'keyword'),
      CompletionItem(label: 'HSET', kind: 'keyword'),
      CompletionItem(label: 'HGETALL', kind: 'keyword'),
      CompletionItem(label: 'HDEL', kind: 'keyword'),
      CompletionItem(label: 'LPUSH', kind: 'keyword'),
      CompletionItem(label: 'RPUSH', kind: 'keyword'),
      CompletionItem(label: 'LRANGE', kind: 'keyword'),
      CompletionItem(label: 'SADD', kind: 'keyword'),
      CompletionItem(label: 'SMEMBERS', kind: 'keyword'),
      CompletionItem(label: 'ZADD', kind: 'keyword'),
      CompletionItem(label: 'ZRANGE', kind: 'keyword'),
      CompletionItem(label: 'PING', kind: 'keyword'),
      CompletionItem(label: 'DBSIZE', kind: 'keyword'),
      CompletionItem(label: 'INFO', kind: 'keyword'),
      CompletionItem(label: 'SELECT', kind: 'keyword'),
      CompletionItem(label: 'CONFIG', kind: 'keyword'),
      CompletionItem(label: 'MULTI', kind: 'keyword'),
      CompletionItem(label: 'EXEC', kind: 'keyword'),
      CompletionItem(label: 'DISCARD', kind: 'keyword'),
    ];
  }

  // ─── Internal helpers ─────────────────────────────────────────────
  Future<dynamic> _sendCommandText(_Session session, String text) async {
    // Redis protocol = array of bulk strings. Boşlukla ayrılmış token'lara böl.
    final tokens = _tokenize(text);
    // İlk token command adı (uppercase — Redis convention).
    final command = <Object>[
      tokens.first.toUpperCase(),
      ...tokens.skip(1),
    ];
    return await session.command.send_object(command);
  }

  List<String> _tokenize(String text) {
    // Basit tokenizer — tırnaklı argüman desteklemez (Phase 8+ için eklenebilir).
    return text.trim().split(RegExp(r'\s+'));
  }

  List<DataRow> _normalizeResponse(dynamic raw) {
    final rows = <DataRow>[];
    if (raw == null) {
      return rows;
    } else if (raw is List) {
      // İki öğeli [key, value] çiftlerini flat'e çevir; tek liste'yi direkt satır yap.
      if (_looksLikeKvPairs(raw)) {
        for (var i = 0; i + 1 < raw.length; i += 2) {
          rows.add(DataRow({'key': raw[i]?.toString(), 'value': raw[i + 1]}));
        }
      } else if (raw.isEmpty) {
        // empty.
      } else {
        // Tek liste: 1 satırlı cevap.
        rows.add(DataRow({
          for (var i = 0; i < raw.length; i++) 'col_$i': raw[i],
        }));
      }
    } else {
      rows.add(DataRow({'response': raw.toString()}));
    }
    return rows;
  }

  bool _looksLikeKvPairs(List<dynamic> list) {
    if (list.length < 2 || list.length.isOdd) return false;
    // HGETALL cevabı [field1, value1, field2, value2, ...] şeklinde.
    // SCAN cevabı [cursor, [k1, k2, k3]] — ilk eleman string, ikinci liste.
    // Bunu ayırt etmek için ilk elemanın içerdiği şekline bakıyoruz.
    return list.every((e) => e is String || e is num);
  }

  String? _extractInfoValue(String infoText, String key) {
    for (final line in infoText.split('\n')) {
      if (line.startsWith('#') || !line.contains(':')) continue;
      final parts = line.split(':');
      if (parts.first.trim() == key) {
        return parts.skip(1).join(':').trim();
      }
    }
    return null;
  }
}

/// Internal session state — connection handle + aktif dbIndex.
class _Session {
  _Session({
    required this.redisConn,
    required this.command,
    required this.dbIndex,
  });
  final RedisConnection redisConn;
  final Command command;
  final int dbIndex;
}

/// RealRedisProvider factory.
///
/// Phase 6'da default değil — feature flag ile Phase 8'de wiring yapılacak.
/// Şimdiden factory tanımlı; registry'de mock default kalır.
class RealRedisProviderFactory implements DatabaseProviderFactory {
  const RealRedisProviderFactory();

  @override
  DatabaseProvider create() => RealRedisProvider();

  @override
  DatabaseKind get kind => DatabaseKind.redis;
}
