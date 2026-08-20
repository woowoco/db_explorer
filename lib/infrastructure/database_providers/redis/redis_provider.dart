import 'dart:async';
import 'dart:math';

import 'package:db_explorer_app/core/utils/app_logger.dart';
import 'package:db_explorer_app/domain/database/capability.dart';
import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/domain/database/database_provider.dart';
import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/domain/database/schema.dart';
import 'package:db_explorer_app/infrastructure/database_providers/redis/redis_schema.dart';

/// In-memory Redis mock provider.
///
/// Redis semantiği:
/// - Schema yok (key-value); capability-driven UI için key listesi + type
/// - Query: `GET <key>` / `KEYS <pattern>` / `HGETALL <key>` /
///   `ZRANGE <key> 0 -1`
/// - listDatabases: 16 logical db (0-15) — mock'ta sabit
/// - listCollections(db): KEYS * (sınırlı sayıda sample key)
///
/// Real provider (Phase 6.3 ayrı dosyada): `RealRedisDBProvider` — `redis`
/// paketini kullanır.
class RedisDBProvider implements DatabaseProvider {
  RedisDBProvider();

  final _log = getLogger('RedisDBProvider');

  // ─── Provider identity ────────────────────────────────────────────
  @override
  String get id => 'redis-mock';

  @override
  DatabaseKind get kind => DatabaseKind.redis;

  @override
  DatabaseCapabilities get capabilities => const DatabaseCapabilities({
    // Redis'te schema yok; schemaIntrospection = key list + type.
    DatabaseCapability.fullTextSearch,
    DatabaseCapability.streaming,
    DatabaseCapability.completion,
    DatabaseCapability.serverInfo,
    DatabaseCapability.liveStats,
    DatabaseCapability.tlsSupport,
    // Writes (string SET, HSET, vs.)
    DatabaseCapability.insert,
    DatabaseCapability.update,
    DatabaseCapability.delete,
    DatabaseCapability.bulkWrite,
    DatabaseCapability.transactions,
    // Operational
    DatabaseCapability.createCollection,
    DatabaseCapability.dropCollection,
    DatabaseCapability.userManagement,
    DatabaseCapability.backup,
  });

  // ─── Sample seed data ─────────────────────────────────────────────
  static final _sampleSeed = _buildSampleSeed();

  static _SampleData _buildSampleSeed() {
    return _SampleData(
      keys: <Map<String, Object?>>[
        {
          'name': 'app:session:user-1',
          'type': 'string',
          'ttl': 3600,
          'size': 256,
        },
        {
          'name': 'app:session:user-2',
          'type': 'string',
          'ttl': 1800,
          'size': 192,
        },
        {
          'name': 'cache:products',
          'type': 'hash',
          'ttl': -1,
          'size': 4096,
        },
        {
          'name': 'leaderboard:top',
          'type': 'sortedset',
          'ttl': -1,
          'size': 1024,
        },
        {
          'name': 'queue:jobs',
          'type': 'list',
          'ttl': -1,
          'size': 512,
        },
        {
          'name': 'tags:active',
          'type': 'set',
          'ttl': -1,
          'size': 256,
        },
      ],
      hashFields: const [
        RedisField(name: 'sku-001', dataType: 'string'),
        RedisField(name: 'sku-002', dataType: 'string'),
        RedisField(name: 'sku-003', dataType: 'string'),
      ],
    );
  }

  // ─── Connection lifecycle ─────────────────────────────────────────
  @override
  Future<DatabaseConnection> connect(DatabaseConnectionConfig config) async {
    if (config is! RedisConnectionProfile) {
      throw ArgumentError(
        'RedisDBProvider requires RedisConnectionProfile, '
        'got ${config.runtimeType}',
      );
    }
    final connection = DatabaseConnection(profile: config, providerId: id);
    connection.state = const ConnectingConnection(message: 'Resolving host...');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    connection.state = const ConnectingConnection(
      progress: 0.5,
      message: 'AUTH (if needed)...',
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final sessionId = 'redis-sess-${Random().nextInt(0xFFFFFF).toRadixString(16)}';
    connection.state = ConnectedConnection(
      sessionId: sessionId,
      at: DateTime.now(),
      serverVersion: '7.2-mock',
      latencyMs: 60,
      uptimeSeconds: 86400,
      extra: {
        'mode': 'in-memory-mock',
        'protocol': 'RESP2',
        'dbIndex': config.dbIndex.toString(),
      },
    );
    _log.i('Mock connect OK: $sessionId (${config.label})');
    return connection;
  }

  @override
  Future<void> disconnect(DatabaseConnection connection) async {
    connection.state = const DisconnectedConnection(reason: 'user-request');
    _log.i('Mock disconnect: ${connection.profile.label}');
  }

  @override
  Future<bool> ping(DatabaseConnection connection) async {
    if (!connection.isConnected) return false;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return true;
  }

  // ─── Schema discovery ─────────────────────────────────────────────
  @override
  Future<List<DatabaseNode>> listDatabases(
    DatabaseConnection connection,
  ) async {
    if (!connection.isConnected) {
      throw StateError('listDatabases called without active connection');
    }
    // Redis default 16 logical db.
    return List.generate(16, (i) => RedisDatabase(name: 'db$i'));
  }

  @override
  Future<List<CollectionNode>> listCollections(
    DatabaseConnection connection,
    String database,
  ) async {
    if (!connection.isConnected) {
      throw StateError('listCollections called without active connection');
    }
    // Mock: sample seed'i döner (sadece db0 için).
    if (!database.startsWith('db0')) return const [];
    return _sampleSeed.keys
        .map((k) => RedisKey(
              name: k['name']! as String,
              keyType: k['type']! as String,
              ttlSeconds: k['ttl'] as int?,
              sizeBytes: k['size'] as int?,
              fields: k['type'] == 'hash' ? _sampleSeed.hashFields : const [],
            ))
        .toList();
  }

  // ─── Query execution ──────────────────────────────────────────────
  @override
  Future<QueryResult> execute(
    DatabaseConnection connection,
    QueryRequest request,
  ) async {
    if (!connection.isConnected) {
      throw StateError('execute called without active connection');
    }
    if (request.language != QueryLanguage.redisCmd) {
      throw ArgumentError(
        'Redis provider only supports redisCmd, got ${request.language}',
      );
    }

    final started = DateTime.now();
    final trimmed = request.text.trim();

    // Basit parser — büyük harf zorunlu (Redis convention).
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      throw FormatException('Empty Redis command');
    }
    final cmd = parts[0].toUpperCase();

    await Future<void>.delayed(Duration(
      milliseconds: 2 + Random().nextInt(10),
    ));

    switch (cmd) {
      case 'GET':
        if (parts.length < 2) {
          throw FormatException('GET requires a key argument');
        }
        final key = parts[1];
        if (key.startsWith('app:session:')) {
          return QueryResult(
            columns: const ['value'],
            rows: [DataRow({'value': '{"user_id":1,"expires":1234}'})],
            executionTime: DateTime.now().difference(started),
          );
        }
        return QueryResult(
          columns: const ['value'],
          rows: const [],
          executionTime: DateTime.now().difference(started),
        );

      case 'KEYS':
        if (parts.length < 2) {
          throw FormatException('KEYS requires a pattern argument');
        }
        final pattern = parts[1];
        final matched = _sampleSeed.keys
            .where((k) {
              final name = k['name']! as String;
              // Çok basit wildcard: * -> tümü, prefix* -> prefix ile başlayan.
              if (pattern == '*') return true;
              if (pattern.endsWith('*')) {
                return name.startsWith(pattern.substring(0, pattern.length - 1));
              }
              return name == pattern;
            })
            .map((k) => DataRow({'key': k['name'], 'type': k['type']}))
            .toList();
        return QueryResult(
          columns: const ['key', 'type'],
          rows: matched,
          executionTime: DateTime.now().difference(started),
          totalCount: matched.length,
          warnings: const ['In-memory mock — data resets on app restart'],
        );

      case 'HGETALL':
        if (parts.length < 2) {
          throw FormatException('HGETALL requires a key argument');
        }
        if (parts[1] != 'cache:products') {
          return QueryResult(
            columns: const ['field', 'value'],
            rows: const [],
            executionTime: DateTime.now().difference(started),
          );
        }
        return QueryResult(
          columns: const ['field', 'value'],
          rows: const [
            DataRow({'field': 'sku-001', 'value': 'Premium Widget'}),
            DataRow({'field': 'sku-002', 'value': 'Standard Gizmo'}),
            DataRow({'field': 'sku-003', 'value': 'Deluxe Item'}),
          ],
          executionTime: DateTime.now().difference(started),
        );

      case 'PING':
        return QueryResult(
          columns: const ['response'],
          rows: const [DataRow({'response': 'PONG'})],
          executionTime: DateTime.now().difference(started),
        );

      case 'DBSIZE':
        return QueryResult(
          columns: const ['count'],
          rows: [DataRow({'count': _sampleSeed.keys.length})],
          executionTime: DateTime.now().difference(started),
        );

      default:
        throw FormatException(
          'Mock Redis supports GET / KEYS / HGETALL / PING / DBSIZE. '
          'Got: $cmd',
        );
    }
  }

  // ─── Explain ──────────────────────────────────────────────────────
  @override
  Future<String> explain(
    DatabaseConnection connection,
    QueryRequest request,
  ) async {
    return '''
// Mock Redis — no query planner
Command: ${request.text}
Time complexity: O(1) for GET, O(N) for KEYS, O(1) for HGETALL
note: 'IN-MEMORY MOCK — not a real Redis explain';
''';
  }

  // ─── Completion ───────────────────────────────────────────────────
  @override
  Future<List<CompletionItem>> complete(
    DatabaseConnection connection,
    CompletionContext context,
  ) async {
    return const [
      CompletionItem(label: 'GET', kind: 'keyword', detail: 'GET key'),
      CompletionItem(label: 'SET', kind: 'keyword', detail: 'SET key value'),
      CompletionItem(label: 'DEL', kind: 'keyword', detail: 'DEL key'),
      CompletionItem(label: 'KEYS', kind: 'keyword', detail: 'KEYS pattern'),
      CompletionItem(label: 'HGET', kind: 'keyword'),
      CompletionItem(label: 'HSET', kind: 'keyword'),
      CompletionItem(label: 'HGETALL', kind: 'keyword'),
      CompletionItem(label: 'LPUSH', kind: 'keyword'),
      CompletionItem(label: 'RPUSH', kind: 'keyword'),
      CompletionItem(label: 'LRANGE', kind: 'keyword'),
      CompletionItem(label: 'SADD', kind: 'keyword'),
      CompletionItem(label: 'SMEMBERS', kind: 'keyword'),
      CompletionItem(label: 'ZADD', kind: 'keyword'),
      CompletionItem(label: 'ZRANGE', kind: 'keyword'),
      CompletionItem(label: 'EXPIRE', kind: 'keyword'),
      CompletionItem(label: 'TTL', kind: 'keyword'),
      CompletionItem(label: 'PING', kind: 'keyword'),
      CompletionItem(label: 'DBSIZE', kind: 'keyword'),
      CompletionItem(label: 'INFO', kind: 'keyword'),
    ];
  }
}

/// Seed data holder.
class _SampleData {
  const _SampleData({required this.keys, required this.hashFields});
  final List<Map<String, Object?>> keys;
  final List<RedisField> hashFields;
}

/// Mock provider factory — registry tarafından kullanılır.
class RedisDBProviderFactory implements DatabaseProviderFactory {
  const RedisDBProviderFactory();

  @override
  DatabaseProvider create() => RedisDBProvider();

  @override
  DatabaseKind get kind => DatabaseKind.redis;
}
