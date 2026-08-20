import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/infrastructure/database_providers/postgres/postgres_provider.dart';
import 'package:db_explorer_app/infrastructure/database_providers/postgres/postgres_schema.dart';
import 'package:flutter_test/flutter_test.dart';

/// Postgres mock provider contract test.
///
/// RealPostgresProvider (gerçek `postgres` paketi) integration test'i
/// Phase 8'de test container'a karşı çalışacak. Burada sadece
/// `PostgresDBProvider` (mock) için:
/// - lifecycle: connect → ConnectedConnection state
/// - schema discovery: listDatabases + listCollections
/// - query execution: SELECT * FROM users
/// - completion: SQL keyword listesi
/// - capabilities: hasSchemaHierarchy + hasRelationalJoins + transactions
///
/// Pattern: MongoDB provider contract test ile aynı (Phase 1 kalıbı).
void main() {
  group('PostgresDBProvider — lifecycle', () {
    late PostgresDBProvider provider;
    late PostgresConnectionProfile profile;
    late DatabaseConnection conn;

    setUp(() async {
      provider = PostgresDBProvider();
      profile = const PostgresConnectionProfile(
        id: 'test-pg-1',
        label: 'Test Local PG',
        host: '127.0.0.1',
        databaseName: 'sample',
        username: 'postgres',
        password: 'secret',
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
      expect(s.serverVersion, startsWith('16.'));
      expect(s.latencyMs, greaterThan(0));
      expect(s.sessionId, startsWith('pg-sess-'));
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

  group('PostgresDBProvider — schema discovery', () {
    late PostgresDBProvider provider;
    late DatabaseConnection conn;

    setUp(() async {
      provider = PostgresDBProvider();
      conn = await provider.connect(const PostgresConnectionProfile(
        id: 'schema-pg',
        label: 'Schema Test',
        host: '127.0.0.1',
        databaseName: 'sample',
      ));
    });

    tearDown(() async {
      if (conn.isActive) await provider.disconnect(conn);
    });

    test('listDatabases returns postgres/template1/sample', () async {
      final dbs = await provider.listDatabases(conn);
      expect(dbs.length, greaterThanOrEqualTo(3));
      final names = dbs.map((d) => d.name).toSet();
      expect(names, containsAll({'postgres', 'template1', 'sample'}));
    });

    test('listCollections("sample") returns users/products/orders', () async {
      final colls = await provider.listCollections(conn, 'sample');
      expect(colls.length, 3);
      final names = colls.map((c) => c.name).toSet();
      expect(names, equals({'users', 'products', 'orders'}));
    });

    test('listCollections("postgres") returns empty (mock)', () async {
      final colls = await provider.listCollections(conn, 'postgres');
      expect(colls, isEmpty);
    });

    test('users table has expected columns + primary key', () async {
      final tables = await provider.listCollections(conn, 'sample');
      final users = tables.firstWhere((c) => c.name == 'users');
      expect(users.fields.length, greaterThanOrEqualTo(5));
      final fieldNames = users.fields.map((f) => f.name).toSet();
      expect(fieldNames, containsAll({'id', 'email', 'name'}));

      // id PRIMARY KEY olmalı (mock seed'de yes).
      final idCol = users.fields.firstWhere((f) => f.name == 'id');
      expect(idCol, isA<PostgresColumn>());
      expect((idCol as PostgresColumn).isPrimaryKey, isTrue);
      expect(idCol.isIndexed, isTrue);
    });
  });

  group('PostgresDBProvider — query execution', () {
    late PostgresDBProvider provider;
    late DatabaseConnection conn;

    setUp(() async {
      provider = PostgresDBProvider();
      conn = await provider.connect(const PostgresConnectionProfile(
        id: 'q-pg',
        label: 'Query Test',
        host: '127.0.0.1',
        databaseName: 'sample',
      ));
    });

    tearDown(() async {
      if (conn.isActive) await provider.disconnect(conn);
    });

    test('SELECT * FROM users returns 4 rows', () async {
      final result = await provider.execute(
        conn,
        const QueryRequest(
          connectionId: 'q-pg',
          language: QueryLanguage.sql,
          text: 'SELECT * FROM users',
        ),
      );
      expect(result.rows.length, 4);
      expect(result.totalCount, 4);
      expect(result.hasMore, isFalse);
      expect(result.columns, contains('id'));
      expect(result.columns, contains('name'));
    });

    test('SELECT * FROM users LIMIT 2 OFFSET 1 paginates', () async {
      final result = await provider.execute(
        conn,
        const QueryRequest(
          connectionId: 'q-pg',
          language: QueryLanguage.sql,
          text: 'SELECT * FROM users LIMIT 2 OFFSET 1',
        ),
      );
      expect(result.rows.length, 2);
      expect(result.hasMore, isTrue);
      expect(result.cursor, isNotNull);
    });

    test('unknown table throws ArgumentError', () {
      expect(
        () => provider.execute(
          conn,
          const QueryRequest(
            connectionId: 'q-pg',
            language: QueryLanguage.sql,
            text: 'SELECT * FROM nonexistent',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('non-SQL language throws ArgumentError', () {
      expect(
        () => provider.execute(
          conn,
          const QueryRequest(
            connectionId: 'q-pg',
            language: QueryLanguage.mongoShell,
            text: 'db.users.find()',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('unsupported SQL syntax throws FormatException', () {
      expect(
        () => provider.execute(
          conn,
          const QueryRequest(
            connectionId: 'q-pg',
            language: QueryLanguage.sql,
            text: 'DROP TABLE users',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('PostgresDBProvider — capabilities', () {
    test('capabilities include relationalJoins + transactions + tls', () {
      final provider = PostgresDBProvider();
      final caps = provider.capabilities;
      expect(caps.hasSchemaHierarchy, isTrue);
      expect(caps.hasRelationalJoins, isTrue);
      expect(caps.hasTransactions, isTrue);
      expect(caps.supportsTls, isTrue);
      expect(caps.hasExplainPlan, isTrue);
      expect(caps.hasAnyWrite, isTrue);
      expect(caps.isMutable, isTrue);
    });

    test('not schemaless (SQL is strictly typed)', () {
      final provider = PostgresDBProvider();
      expect(provider.capabilities.isSchemaless, isFalse);
    });
  });

  group('PostgresDBProvider — completion', () {
    test('complete returns SQL keywords', () async {
      final provider = PostgresDBProvider();
      final conn = await provider.connect(const PostgresConnectionProfile(
        id: 'c-pg',
        label: 'Completion Test',
        host: '127.0.0.1',
        databaseName: 'sample',
      ));
      addTearDown(() async {
        if (conn.isActive) await provider.disconnect(conn);
      });

      final items = await provider.complete(
        conn,
        const CompletionContext(
          connectionId: 'c-pg',
          database: 'sample',
          text: 'SEL',
          cursorOffset: 3,
        ),
      );
      expect(items, isNotEmpty);
      final labels = items.map((i) => i.label).toSet();
      expect(labels, contains('SELECT'));
      expect(labels, contains('FROM'));
      expect(labels, contains('WHERE'));
    });
  });

  group('PostgresConnectionProfile — JSON round-trip', () {
    test('copyWith preserves all fields', () {
      const p = PostgresConnectionProfile(
        id: '1',
        label: 'L',
        host: 'h',
        databaseName: 'd',
        username: 'u',
        password: 'p',
        sslMode: PostgresSslMode.verifyFull,
        applicationName: 'app',
        connectTimeoutSeconds: 10,
        statementTimeoutSeconds: 30,
      );
      final p2 = p.copyWith(label: 'L2', port: 5433);
      expect(p2.id, '1');
      expect(p2.label, 'L2');
      expect(p2.port, 5433);
      expect(p2.sslMode, PostgresSslMode.verifyFull);
      expect(p2.applicationName, 'app');
      expect(p2.password, 'p');
    });

    test('default port is 5432 and default sslMode is require', () {
      const p = PostgresConnectionProfile(
        id: '1',
        label: 'L',
        host: 'h',
        databaseName: 'd',
      );
      expect(p.port, 5432);
      expect(p.sslMode, PostgresSslMode.require);
      expect(p.kind, DatabaseKind.postgres);
    });

    test('PostgresSslMode.storageValue round-trips', () {
      expect(PostgresSslMode.disable.storageValue, 'disable');
      expect(PostgresSslMode.require.storageValue, 'require');
      expect(PostgresSslMode.verifyFull.storageValue, 'verify-full');
    });
  });
}
