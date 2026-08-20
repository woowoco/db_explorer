import 'package:db_explorer_app/domain/database/capability.dart';
import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/infrastructure/database_providers/mongodb/mongodb_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// DatabaseProvider interface contract test.
///
/// Provider-agnostic — MongoDBProvider'ın (mock implementasyon)
/// interface sözleşmesine uyduğunu doğrular. Gerçek driver ile
/// değiştirildiğinde (Phase 3) aynı test bağlantı noktası olarak
/// kullanılacak.
void main() {
  group('MongoDBProvider — lifecycle', () {
    late MongoDBProvider provider;
    late MongoConnectionProfile profile;
    late DatabaseConnection conn;

    setUp(() async {
      provider = MongoDBProvider();
      profile = const MongoConnectionProfile(
        id: 'test-conn-1',
        label: 'Test Local',
        host: '127.0.0.1',
        port: 27017,
        databaseName: 'sample',
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
      expect(s.serverVersion, startsWith('7.'));
      expect(s.latencyMs, greaterThan(0));
      expect(s.sessionId, startsWith('sess-'));
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

  group('MongoDBProvider — schema discovery', () {
    late MongoDBProvider provider;
    late DatabaseConnection conn;

    setUp(() async {
      provider = MongoDBProvider();
      conn = await provider.connect(const MongoConnectionProfile(
        id: 'schema-conn',
        label: 'Schema Test',
        host: '127.0.0.1',
        port: 27017,
      ));
    });

    tearDown(() async {
      if (conn.isActive) await provider.disconnect(conn);
    });

    test('listDatabases returns admin/config/local/sample', () async {
      final dbs = await provider.listDatabases(conn);
      expect(dbs.length, greaterThanOrEqualTo(4));
      final names = dbs.map((d) => d.name).toSet();
      expect(names, containsAll({'admin', 'config', 'local', 'sample'}));
    });

    test('listCollections("sample") returns users/products/orders', () async {
      final colls = await provider.listCollections(conn, 'sample');
      expect(colls.length, 3);
      final names = colls.map((c) => c.name).toSet();
      expect(names, equals({'users', 'products', 'orders'}));
    });

    test('listCollections("admin") returns empty (mock)', () async {
      final colls = await provider.listCollections(conn, 'admin');
      expect(colls, isEmpty);
    });

    test('users collection has expected fields', () async {
      final colls = await provider.listCollections(conn, 'sample');
      final users = colls.firstWhere((c) => c.name == 'users');
      expect(users.fields.length, greaterThanOrEqualTo(5));
      final fieldNames = users.fields.map((f) => f.name).toSet();
      expect(fieldNames, containsAll({'_id', 'name', 'email'}));
    });
  });

  group('MongoDBProvider — query execution', () {
    late MongoDBProvider provider;
    late DatabaseConnection conn;

    setUp(() async {
      provider = MongoDBProvider();
      conn = await provider.connect(const MongoConnectionProfile(
        id: 'q-conn',
        label: 'Query Test',
        host: '127.0.0.1',
        port: 27017,
      ));
    });

    tearDown(() async {
      if (conn.isActive) await provider.disconnect(conn);
    });

    test('db.users.find() returns 4 rows', () async {
      final result = await provider.execute(
        conn,
        const QueryRequest(
          connectionId: 'q-conn',
          language: QueryLanguage.mongoShell,
          text: 'db.users.find()',
        ),
      );
      expect(result.columns, ['doc']);
      expect(result.rows.length, 4);
      expect(result.totalCount, 4);
      expect(result.hasMore, isFalse);
      expect(result.isEmpty, isFalse);
    });

    test('db.users.findOne() returns exactly 1 row', () async {
      final result = await provider.execute(
        conn,
        const QueryRequest(
          connectionId: 'q-conn',
          language: QueryLanguage.mongoShell,
          text: 'db.users.findOne()',
        ),
      );
      expect(result.rows.length, 1);
      expect(result.singleRow, isNotNull);
    });

    test('db.users.count() returns 4 in single row', () async {
      final result = await provider.execute(
        conn,
        const QueryRequest(
          connectionId: 'q-conn',
          language: QueryLanguage.mongoShell,
          text: 'db.users.count()',
        ),
      );
      expect(result.rows.length, 1);
      expect(result.rows.first.values['count'], 4);
    });

    test('pageSize=2 + pageOffset=0 returns 2 rows with hasMore=true', () async {
      final result = await provider.execute(
        conn,
        const QueryRequest(
          connectionId: 'q-conn',
          language: QueryLanguage.mongoShell,
          text: 'db.users.find()',
          pageSize: 2,
          pageOffset: 0,
        ),
      );
      expect(result.rows.length, 2);
      expect(result.hasMore, isTrue);
      expect(result.cursor, isNotNull);
    });

    test('unknown collection throws ArgumentError', () async {
      expect(
        () => provider.execute(
          conn,
          const QueryRequest(
            connectionId: 'q-conn',
            language: QueryLanguage.mongoShell,
            text: 'db.nonexistent.find()',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('non-mongoShell language throws ArgumentError', () async {
      expect(
        () => provider.execute(
          conn,
          const QueryRequest(
            connectionId: 'q-conn',
            language: QueryLanguage.sql,
            text: 'SELECT * FROM users',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('malformed query throws FormatException', () async {
      expect(
        () => provider.execute(
          conn,
          const QueryRequest(
            connectionId: 'q-conn',
            language: QueryLanguage.mongoShell,
            text: 'not a mongo shell command',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('MongoDBProvider — capabilities', () {
    test('capabilities set is non-empty and contains expected flags', () {
      final provider = MongoDBProvider();
      final caps = provider.capabilities;
      expect(caps.capabilities, isNotEmpty);
      expect(caps.hasSchemaHierarchy, isTrue);
      expect(caps.isSchemaless, isTrue);
      expect(caps.hasAggregationPipeline, isTrue);
      expect(caps.hasTransactions, isTrue);
      expect(caps.hasExplainPlan, isTrue);
      expect(caps.hasInsert, isTrue);
      expect(caps.hasUpdate, isTrue);
      expect(caps.hasDelete, isTrue);
      expect(caps.hasAnyWrite, isTrue);
      expect(caps.isMutable, isTrue);
    });

    test('capabilities are immutable (set hashcode stable)', () {
      const caps = DatabaseCapabilities({
        DatabaseCapability.insert,
      });
      final caps2 = caps.withCapabilities({DatabaseCapability.update});
      expect(caps.supports(DatabaseCapability.update), isFalse);
      expect(caps2.supports(DatabaseCapability.update), isTrue);
      expect(caps2.supports(DatabaseCapability.insert), isTrue);
    });
  });

  group('MongoDBProvider — completion', () {
    test('complete returns MongoDB keywords', () async {
      final provider = MongoDBProvider();
      final conn = await provider.connect(const MongoConnectionProfile(
        id: 'c-conn',
        label: 'Completion Test',
        host: '127.0.0.1',
        port: 27017,
      ));
      addTearDown(() async {
        if (conn.isActive) await provider.disconnect(conn);
      });

      final items = await provider.complete(
        conn,
        const CompletionContext(
          connectionId: 'c-conn',
          database: 'sample',
          text: 'db.',
          cursorOffset: 3,
        ),
      );
      expect(items, isNotEmpty);
      expect(items.map((i) => i.label), contains('find'));
      expect(items.map((i) => i.label), contains('count'));
    });
  });
}