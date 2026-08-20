import 'dart:io';

import 'package:db_explorer_app/core/utils/app_error.dart';
import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/domain/database/database_provider.dart';
import 'package:db_explorer_app/infrastructure/database_providers/mongodb/mongodb_provider.dart';
import 'package:db_explorer_app/infrastructure/database_providers/mongodb/mongodb_schema.dart';
import 'package:db_explorer_app/infrastructure/storage/local_cache.dart';
import 'package:db_explorer_app/infrastructure/storage/query_history_entry.dart';
import 'package:db_explorer_app/infrastructure/storage/schema_service.dart';
import 'package:db_explorer_app/infrastructure/storage/secure_connection_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage layer test — local_cache + schema_service + query_history_entry.
///
/// Hive için `Hive.init(path)` kullanır (test ortamında flutter binding yok).
/// flutter_secure_storage platform-channel kullandığı için test'te mock'lanamaz;
/// SecureConnectionStore integration test'leri Phase 8'de yapılacak.
const _testCipherKey = <int>[
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
  17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
];

void main() {
  setUp(() async {
    Hive.close();
    final tmpDir = Directory.systemTemp.createTempSync('dbx_hive_test_');
    Hive.init(tmpDir.path);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await Hive.close();
  });

  group('QueryHistoryEntry', () {
    test('toMap → fromMap roundtrip preserves all fields', () {
      final entry = QueryHistoryEntry(
        id: 'q-1',
        connectionId: 'c-1',
        database: 'sample',
        collection: 'users',
        language: 'mongoShell',
        text: 'db.users.find()',
        executedAt: DateTime.utc(2026, 8, 20, 10, 30),
        rowCount: 4,
        executionTimeMs: 13,
      );

      final restored = QueryHistoryEntry.fromMap(entry.toMap() as Map<dynamic, dynamic>);

      expect(restored.id, entry.id);
      expect(restored.connectionId, entry.connectionId);
      expect(restored.database, entry.database);
      expect(restored.collection, entry.collection);
      expect(restored.language, entry.language);
      expect(restored.text, entry.text);
      expect(restored.executedAt, entry.executedAt);
      expect(restored.rowCount, entry.rowCount);
      expect(restored.executionTimeMs, entry.executionTimeMs);
      expect(restored.affectedRows, isNull);
    });

    test('storageKey is unique per entry', () {
      final e = QueryHistoryEntry(
        id: 'q-1',
        connectionId: 'c',
        database: 'd',
        collection: 'col',
        language: 'mongoShell',
        text: '',
        executedAt: DateTime.now(),
        rowCount: 0,
        executionTimeMs: 0,
      );
      expect(e.storageKey, 'q:q-1');
    });
  });

  group('LocalCache — schema cache', () {
    test('cacheSchema then getCachedSchema returns same collections', () async {
      final cache = LocalCache.forTesting(cipherKey: _testCipherKey);
      await cache.initialize();

      final collections = [
        const MongoCollection(
          name: 'users',
          fields: [
            MongoField(name: '_id', dataType: 'objectId', isIndexed: true),
          ],
          documentCount: 100,
        ),
      ];

      await cache.cacheSchema('conn-1', 'sample', collections);
      final cached = await cache.getCachedSchema('conn-1', 'sample');

      expect(cached, isNotNull);
      expect(cached!.length, 1);
      expect(cached.first.name, 'users');
      expect((cached.first as MongoCollection).documentCount, 100);
    });

    test('getCachedSchema returns null when not cached', () async {
      final cache = LocalCache.forTesting(cipherKey: _testCipherKey);
      await cache.initialize();
      final cached = await cache.getCachedSchema('nonexistent', 'sample');
      expect(cached, isNull);
    });

    test('invalidateSchema removes entry', () async {
      final cache = LocalCache.forTesting(cipherKey: _testCipherKey);
      await cache.initialize();

      await cache.cacheSchema('conn-1', 'sample', [
        const MongoCollection(name: 'users'),
      ]);
      expect(await cache.getCachedSchema('conn-1', 'sample'), isNotNull);

      await cache.invalidateSchema('conn-1', 'sample');
      expect(await cache.getCachedSchema('conn-1', 'sample'), isNull);
    });

    test('clearSchemaCache removes all entries', () async {
      final cache = LocalCache.forTesting(cipherKey: _testCipherKey);
      await cache.initialize();

      await cache.cacheSchema('conn-1', 'sample', [
        const MongoCollection(name: 'users'),
      ]);
      await cache.cacheSchema('conn-2', 'sample', [
        const MongoCollection(name: 'products'),
      ]);

      await cache.clearSchemaCache();

      expect(await cache.getCachedSchema('conn-1', 'sample'), isNull);
      expect(await cache.getCachedSchema('conn-2', 'sample'), isNull);
    });
  });

  group('LocalCache — query history', () {
    test('addHistoryEntry then getRecentHistory returns entry', () async {
      final cache = LocalCache.forTesting(cipherKey: _testCipherKey);
      await cache.initialize();

      final entry = QueryHistoryEntry(
        id: 'q-1',
        connectionId: 'c-1',
        database: 'sample',
        collection: 'users',
        language: 'mongoShell',
        text: 'db.users.find()',
        executedAt: DateTime.utc(2026, 8, 20, 10, 30),
        rowCount: 4,
        executionTimeMs: 12,
      );

      await cache.addHistoryEntry(entry);
      final recent = await cache.getRecentHistory();

      expect(recent.length, 1);
      expect(recent.first.id, 'q-1');
      expect(recent.first.text, 'db.users.find()');
    });

    test('pruneHistory removes old entries', () async {
      final cache = LocalCache.forTesting(cipherKey: _testCipherKey);
      await cache.initialize();

      await cache.addHistoryEntry(QueryHistoryEntry(
        id: 'q-old',
        connectionId: 'c-1',
        database: 'sample',
        collection: 'users',
        language: 'mongoShell',
        text: 'old query',
        executedAt: DateTime.now().subtract(const Duration(days: 40)),
        rowCount: 0,
        executionTimeMs: 0,
      ));

      await cache.addHistoryEntry(QueryHistoryEntry(
        id: 'q-new',
        connectionId: 'c-1',
        database: 'sample',
        collection: 'users',
        language: 'mongoShell',
        text: 'new query',
        executedAt: DateTime.now().subtract(const Duration(days: 5)),
        rowCount: 0,
        executionTimeMs: 0,
      ));

      final pruned = await cache.pruneHistory(ttlDays: 30);
      expect(pruned, 1); // q-old pruned

      final remaining = await cache.getRecentHistory();
      expect(remaining.length, 1);
      expect(remaining.first.id, 'q-new');
    });

    test('getHistoryForConnection filters by connectionId', () async {
      final cache = LocalCache.forTesting(cipherKey: _testCipherKey);
      await cache.initialize();

      await cache.addHistoryEntry(QueryHistoryEntry(
        id: 'q-a',
        connectionId: 'conn-a',
        database: 'd',
        collection: 'c',
        language: 'sql',
        text: 'A',
        executedAt: DateTime.now(),
        rowCount: 0,
        executionTimeMs: 0,
      ));
      await cache.addHistoryEntry(QueryHistoryEntry(
        id: 'q-b',
        connectionId: 'conn-b',
        database: 'd',
        collection: 'c',
        language: 'sql',
        text: 'B',
        executedAt: DateTime.now(),
        rowCount: 0,
        executionTimeMs: 0,
      ));

      final aHistory = await cache.getHistoryForConnection('conn-a');
      expect(aHistory.length, 1);
      expect(aHistory.first.id, 'q-a');
    });
  });

  group('SchemaService — cache layer', () {
    test('listCollections cache miss → cache hit on second call', () async {
      final cache = LocalCache.forTesting(cipherKey: _testCipherKey);
      await cache.initialize();

      int callCount = 0;
      final factory = _CountingFactory(callCountRef: () {
        callCount++;
        return callCount;
      });

      final service = SchemaService(cache: cache, providerFactory: factory);

      final provider = MongoDBProvider();
      final conn = await provider.connect(const MongoConnectionProfile(
        id: 's-conn',
        label: 'Schema',
        host: '127.0.0.1',
        port: 27017,
      ));
      addTearDown(() async {
        if (conn.isActive) await provider.disconnect(conn);
      });

      final first = await service.listCollections(conn, 'sample');
      expect(first.length, 3); // users/products/orders from mock
      expect(callCount, 1);

      final second = await service.listCollections(conn, 'sample');
      expect(second.length, 3);
      expect(callCount, 1); // unchanged → cache hit
    });

    test('invalidateForDatabase forces refresh', () async {
      final cache = LocalCache.forTesting(cipherKey: _testCipherKey);
      await cache.initialize();
      int callCount = 0;
      final factory = _CountingFactory(callCountRef: () {
        callCount++;
        return callCount;
      });
      final service = SchemaService(cache: cache, providerFactory: factory);

      final provider = MongoDBProvider();
      final conn = await provider.connect(const MongoConnectionProfile(
        id: 'inv-conn',
        label: 'Invalidate Test',
        host: '127.0.0.1',
        port: 27017,
      ));
      addTearDown(() async {
        if (conn.isActive) await provider.disconnect(conn);
      });

      await service.listCollections(conn, 'sample');
      expect(callCount, 1);

      await service.invalidateForDatabase('inv-conn', 'sample');

      await service.listCollections(conn, 'sample');
      expect(callCount, 2); // invalidated → provider called again
    });
  });

  group('SecureConnectionStore — index layer (SharedPreferences)', () {
    test('listIds reads from index key', () async {
      SharedPreferences.setMockInitialValues({
        'dbx_conn_index': <String>['test-1', 'test-2'],
      });
      final store = SecureConnectionStore();
      final ids = await store.listIds();
      expect(ids, ['test-1', 'test-2']);
    });

    test('listIds returns empty when index absent', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SecureConnectionStore();
      final ids = await store.listIds();
      expect(ids, isEmpty);
    });
  });

  group('StorageFailure', () {
    test('is sealed AppFailure subclass', () {
      const f = StorageFailure('test');
      expect(f, isA<AppFailure>());
      expect(f.message, 'test');
    });
  });
}

/// Provider factory that counts invocations for cache hit/miss tests.
class _CountingFactory implements DatabaseProviderFactory {
  _CountingFactory({required this.callCountRef});

  final int Function() callCountRef;

  @override
  DatabaseProvider create() {
    callCountRef();
    return MongoDBProvider();
  }

  @override
  DatabaseKind get kind => DatabaseKind.mongodb;
}