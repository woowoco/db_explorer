import 'package:db_explorer_app/domain/database/capability.dart';
import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/infrastructure/database_providers/mongodb/real_mongodb_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// RealMongoDBProvider structure + invariants smoke test.
///
/// **No real MongoDB connection** — bu test'ler sadece:
/// 1. Constructor + identity invariants
/// 2. Capabilities set doğruluğu
/// 3. Falsy state guard'ları (not-connected → StateError, wrong language → ArgumentError)
///
/// Network gerektiren davranış (connect/listDatabases/execute) integration
/// test olarak Phase 8 (platform_io) kapsamında çalıştırılacak.
void main() {
  group('RealMongoDBProvider — identity', () {
    test('id and kind are mongodb', () {
      final provider = RealMongoDBProvider();
      expect(provider.id, 'mongodb');
      expect(provider.kind, DatabaseKind.mongodb);
    });

    test('capabilities include mongo-specific flags', () {
      final provider = RealMongoDBProvider();
      final caps = provider.capabilities;
      expect(caps.hasSchemaHierarchy, isTrue);
      expect(caps.isSchemaless, isTrue);
      expect(caps.hasAggregationPipeline, isTrue);
      expect(caps.hasTransactions, isTrue);
      expect(caps.hasExplainPlan, isTrue);
      expect(caps.hasInsert, isTrue);
      expect(caps.capabilities, contains(DatabaseCapability.tlsSupport));
    });
  });

  group('RealMongoDBProviderFactory', () {
    test('kind is mongodb', () {
      const factory = RealMongoDBProviderFactory();
      expect(factory.kind, DatabaseKind.mongodb);
    });

    test('create returns a fresh RealMongoDBProvider instance', () {
      const factory = RealMongoDBProviderFactory();
      final p1 = factory.create();
      final p2 = factory.create();
      expect(p1, isA<RealMongoDBProvider>());
      expect(p2, isA<RealMongoDBProvider>());
      expect(identical(p1, p2), isFalse);
    });
  });

  group('RealMongoDBProvider — state guards (no network)', () {
    late RealMongoDBProvider provider;
    late DatabaseConnection conn;

    setUp(() {
      provider = RealMongoDBProvider();
      conn = DatabaseConnection(
        profile: const MongoConnectionProfile(
          id: 'parser-conn',
          label: 'Parser Test',
          host: '127.0.0.1',
          port: 27017,
        ),
        providerId: 'mongodb',
      );
    });

    test('execute on disconnected connection throws StateError', () async {
      expect(
        () => provider.execute(
          conn,
          const QueryRequest(
            connectionId: 'parser-conn',
            language: QueryLanguage.mongoShell,
            text: 'db.users.find()',
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('listDatabases on disconnected connection throws StateError', () async {
      expect(
        () => provider.listDatabases(conn),
        throwsA(isA<StateError>()),
      );
    });

    test('listCollections on disconnected connection throws StateError',
        () async {
      expect(
        () => provider.listCollections(conn, 'sample'),
        throwsA(isA<StateError>()),
      );
    });

    test('explain on disconnected connection throws StateError', () async {
      expect(
        () => provider.explain(
          conn,
          const QueryRequest(
            connectionId: 'parser-conn',
            language: QueryLanguage.mongoShell,
            text: 'db.users.find()',
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('ping on disconnected connection returns false', () async {
      expect(await provider.ping(conn), isFalse);
    });

    test('complete on disconnected connection returns empty', () async {
      final result = await provider.complete(
        conn,
        const CompletionContext(
          connectionId: 'parser-conn',
          database: 'sample',
          text: 'db.',
          cursorOffset: 3,
        ),
      );
      expect(result, isEmpty);
    });

    test('execute rejects non-mongoShell language', () async {
      // Connected state simulate (handle yok → listDatabases vs execute
      // yine de language guard'a takılır).
      conn.state = ConnectedConnection(
        sessionId: 'test',
        at: DateTime.now(),
      );
      expect(
        () => provider.execute(
          conn,
          const QueryRequest(
            connectionId: 'parser-conn',
            language: QueryLanguage.sql,
            text: 'SELECT * FROM users',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}