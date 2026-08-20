import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/infrastructure/database_providers/redis/redis_provider.dart';
import 'package:db_explorer_app/infrastructure/database_providers/redis/redis_schema.dart';
import 'package:flutter_test/flutter_test.dart';

/// Redis mock provider contract test.
///
/// `RealRedisProvider` (gerçek `redis` paketi) integration test'i
/// Phase 8'de test container'a karşı çalışacak. Burada sadece
/// `RedisDBProvider` (mock) için:
/// - lifecycle: connect → ConnectedConnection state
/// - schema discovery: listDatabases (16 db) + listCollections (db0 keys)
/// - query execution: PING / DBSIZE / KEYS / HGETALL / GET
/// - completion: Redis command listesi
/// - capabilities: fullTextSearch + transactions + tls + completion + streaming
///
/// Pattern: Phase 5 Postgres provider contract test kalıbı.
void main() {
  group('RedisDBProvider — lifecycle', () {
    late RedisDBProvider provider;
    late RedisConnectionProfile profile;
    late DatabaseConnection conn;

    setUp(() async {
      provider = RedisDBProvider();
      profile = const RedisConnectionProfile(
        id: 'test-redis-1',
        label: 'Test Local Redis',
        host: '127.0.0.1',
        username: 'default',
        password: 'secret',
        dbIndex: 0,
        useTls: false,
      );
      conn = await provider.connect(profile);
    });

    tearDown(() async {
      if (conn.isActive) {
        await provider.disconnect(conn);
      }
    });

    test('connect → ConnectedConnection state with server info', () {
      expect(conn.isConnected, isTrue);
      expect(conn.isConnecting, isFalse);
      final s = conn.state as ConnectedConnection;
      expect(s.serverVersion, isNotNull);
      expect(s.serverVersion, startsWith('7.2'));
      expect(s.latencyMs, greaterThan(0));
      expect(s.sessionId, startsWith('redis-sess-'));
    });

    test('ping → true when connected', () async {
      expect(await provider.ping(conn), isTrue);
    });

    test('disconnect → DisconnectedConnection state', () async {
      await provider.disconnect(conn);
      expect(conn.isDisconnected, isTrue);
      expect(conn.isConnected, isFalse);
    });

    test('reconnect after disconnect → Connected again', () async {
      await provider.disconnect(conn);
      final newConn = await provider.connect(profile);
      expect(newConn.isConnected, isTrue);
      conn = newConn;
    });
  });

  group('RedisDBProvider — schema discovery', () {
    late RedisDBProvider provider;
    late DatabaseConnection conn;

    setUp(() async {
      provider = RedisDBProvider();
      conn = await provider.connect(const RedisConnectionProfile(
        id: 'schema-redis',
        label: 'Schema Test',
        host: '127.0.0.1',
      ));
    });

    tearDown(() async {
      if (conn.isActive) await provider.disconnect(conn);
    });

    test('listDatabases returns 16 logical dbs (db0..db15)', () async {
      final dbs = await provider.listDatabases(conn);
      expect(dbs.length, 16);
      expect(dbs.first.name, 'db0');
      expect(dbs.last.name, 'db15');
    });

    test('listCollections("db0") returns 6 sample keys', () async {
      final colls = await provider.listCollections(conn, 'db0');
      expect(colls.length, 6);
      final names = colls.map((c) => c.name).toSet();
      expect(names, containsAll({
        'app:session:user-1',
        'app:session:user-2',
        'cache:products',
        'leaderboard:top',
        'queue:jobs',
        'tags:active',
      }));
    });

    test('listCollections("db5") returns empty (only db0 has sample)',
        () async {
      final colls = await provider.listCollections(conn, 'db5');
      expect(colls, isEmpty);
    });

    test('cache:products key is hash with 3 fields', () async {
      final colls = await provider.listCollections(conn, 'db0');
      final hashKey = colls.firstWhere((c) => c.name == 'cache:products');
      expect(hashKey, isA<RedisKey>());
      expect((hashKey as RedisKey).keyType, 'hash');
      expect(hashKey.fields.length, 3);
    });

    test('app:session:user-1 key is string with TTL + size', () async {
      final colls = await provider.listCollections(conn, 'db0');
      final stringKey = colls.firstWhere((c) => c.name == 'app:session:user-1');
      expect(stringKey, isA<RedisKey>());
      expect((stringKey as RedisKey).keyType, 'string');
      expect(stringKey.ttlSeconds, 3600);
      expect(stringKey.sizeBytes, 256);
    });
  });

  group('RedisDBProvider — query execution', () {
    late RedisDBProvider provider;
    late DatabaseConnection conn;

    setUp(() async {
      provider = RedisDBProvider();
      conn = await provider.connect(const RedisConnectionProfile(
        id: 'q-redis',
        label: 'Query Test',
        host: '127.0.0.1',
      ));
    });

    tearDown(() async {
      if (conn.isActive) await provider.disconnect(conn);
    });

    test('PING → PONG', () async {
      final result = await provider.execute(
        conn,
        const QueryRequest(
          connectionId: 'q-redis',
          language: QueryLanguage.redisCmd,
          text: 'PING',
        ),
      );
      expect(result.rows.length, 1);
      expect(result.rows.first.values['response'], 'PONG');
    });

    test('DBSIZE → 6 (sample key count)', () async {
      final result = await provider.execute(
        conn,
        const QueryRequest(
          connectionId: 'q-redis',
          language: QueryLanguage.redisCmd,
          text: 'DBSIZE',
        ),
      );
      expect(result.rows.length, 1);
      expect(result.rows.first.values['count'], 6);
    });

    test('KEYS * matches all 6 sample keys', () async {
      final result = await provider.execute(
        conn,
        const QueryRequest(
          connectionId: 'q-redis',
          language: QueryLanguage.redisCmd,
          text: 'KEYS *',
        ),
      );
      expect(result.rows.length, 6);
      expect(result.columns, contains('key'));
      expect(result.columns, contains('type'));
    });

    test('KEYS app:* matches 2 session keys', () async {
      final result = await provider.execute(
        conn,
        const QueryRequest(
          connectionId: 'q-redis',
          language: QueryLanguage.redisCmd,
          text: 'KEYS app:*',
        ),
      );
      expect(result.rows.length, 2);
      final keyNames =
          result.rows.map((r) => r.values['key']).toSet();
      expect(keyNames, contains('app:session:user-1'));
      expect(keyNames, contains('app:session:user-2'));
    });

    test('HGETALL cache:products returns 3 fields', () async {
      final result = await provider.execute(
        conn,
        const QueryRequest(
          connectionId: 'q-redis',
          language: QueryLanguage.redisCmd,
          text: 'HGETALL cache:products',
        ),
      );
      expect(result.rows.length, 3);
      expect(result.columns, contains('field'));
      expect(result.columns, contains('value'));
      final fields = result.rows.map((r) => r.values['field']).toSet();
      expect(fields, containsAll({'sku-001', 'sku-002', 'sku-003'}));
    });

    test('GET app:session:user-1 returns JSON-like value', () async {
      final result = await provider.execute(
        conn,
        const QueryRequest(
          connectionId: 'q-redis',
          language: QueryLanguage.redisCmd,
          text: 'GET app:session:user-1',
        ),
      );
      expect(result.rows.length, 1);
      expect(result.columns, contains('value'));
      expect(
        result.rows.first.values['value'].toString(),
        contains('user_id'),
      );
    });

    test('unknown command throws FormatException', () {
      expect(
        () => provider.execute(
          conn,
          const QueryRequest(
            connectionId: 'q-redis',
            language: QueryLanguage.redisCmd,
            text: 'WAT',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('non-redisCmd language throws ArgumentError', () {
      expect(
        () => provider.execute(
          conn,
          const QueryRequest(
            connectionId: 'q-redis',
            language: QueryLanguage.sql,
            text: 'SELECT 1',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('PING (missing arg) throws FormatException for non-zero-arg cmd',
        () {
      expect(
        () => provider.execute(
          conn,
          const QueryRequest(
            connectionId: 'q-redis',
            language: QueryLanguage.redisCmd,
            text: 'GET',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('RedisDBProvider — capabilities', () {
    test('capabilities include fullTextSearch + transactions + tls', () {
      final provider = RedisDBProvider();
      final caps = provider.capabilities;
      expect(caps.supportsTls, isTrue);
      expect(caps.hasTransactions, isTrue);
      expect(caps.hasAnyWrite, isTrue);
      expect(caps.hasCompletion, isTrue);
    });

    test('Redis has completion + supports transactions', () {
      final provider = RedisDBProvider();
      expect(provider.capabilities.hasCompletion, isTrue);
      expect(provider.capabilities.hasTransactions, isTrue);
    });
  });

  group('RedisDBProvider — completion', () {
    test('complete returns Redis commands', () async {
      final provider = RedisDBProvider();
      final conn = await provider.connect(const RedisConnectionProfile(
        id: 'c-redis',
        label: 'Completion Test',
        host: '127.0.0.1',
      ));
      addTearDown(() async {
        if (conn.isActive) await provider.disconnect(conn);
      });

      final items = await provider.complete(
        conn,
        const CompletionContext(
          connectionId: 'c-redis',
          database: 'db0',
          text: 'GE',
          cursorOffset: 2,
        ),
      );
      expect(items, isNotEmpty);
      final labels = items.map((i) => i.label).toSet();
      expect(labels, contains('GET'));
      expect(labels, contains('SET'));
      expect(labels, contains('HGETALL'));
      expect(labels, contains('PING'));
      expect(labels, contains('DBSIZE'));
    });
  });

  group('RedisConnectionProfile — JSON round-trip', () {
    test('copyWith preserves all fields', () {
      const p = RedisConnectionProfile(
        id: '1',
        label: 'L',
        host: 'h',
        username: 'u',
        password: 'p',
        dbIndex: 5,
        useTls: true,
        connectTimeoutSeconds: 10,
      );
      final p2 = p.copyWith(label: 'L2', port: 6380);
      expect(p2.id, '1');
      expect(p2.label, 'L2');
      expect(p2.port, 6380);
      expect(p2.username, 'u');
      expect(p2.password, 'p');
      expect(p2.dbIndex, 5);
      expect(p2.useTls, isTrue);
      expect(p2.connectTimeoutSeconds, 10);
    });

    test('default port is 6379 and default dbIndex is 0', () {
      const p = RedisConnectionProfile(
        id: '1',
        label: 'L',
        host: 'h',
      );
      expect(p.port, 6379);
      expect(p.dbIndex, 0);
      expect(p.useTls, isFalse);
      expect(p.kind, DatabaseKind.redis);
    });
  });
}
