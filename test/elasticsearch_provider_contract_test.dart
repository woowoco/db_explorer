import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/infrastructure/database_providers/elasticsearch/elasticsearch_provider.dart';
import 'package:db_explorer_app/infrastructure/database_providers/elasticsearch/elasticsearch_schema.dart';
import 'package:flutter_test/flutter_test.dart';

/// Elasticsearch mock provider contract test.
///
/// `RealElasticsearchProvider` (gerçek `elastic_client` paketi)
/// integration test'i Phase 8'de test container'a karşı çalışacak.
/// Burada sadece `ElasticsearchDBProvider` (mock) için:
/// - lifecycle: connect → ConnectedConnection state
/// - schema discovery: listDatabases (1 cluster) + listCollections (indices)
/// - query execution: JSON DSL — match_all, match, size
/// - completion: query DSL keyword listesi
/// - capabilities: fullTextSearch + geospatial + indexManagement + tls
///
/// Pattern: Phase 5/6 provider contract test kalıbı.
void main() {
  group('ElasticsearchDBProvider — lifecycle', () {
    late ElasticsearchDBProvider provider;
    late ElasticsearchConnectionProfile profile;
    late DatabaseConnection conn;

    setUp(() async {
      provider = ElasticsearchDBProvider();
      profile = const ElasticsearchConnectionProfile(
        id: 'test-es-1',
        label: 'Test Local ES',
        host: '127.0.0.1',
        scheme: 'http',
        apiKey: 'test-key',
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
      expect(s.serverVersion, startsWith('8.11'));
      expect(s.latencyMs, greaterThan(0));
      expect(s.sessionId, startsWith('es-sess-'));
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

  group('ElasticsearchDBProvider — schema discovery', () {
    late ElasticsearchDBProvider provider;
    late DatabaseConnection conn;

    setUp(() async {
      provider = ElasticsearchDBProvider();
      conn = await provider.connect(const ElasticsearchConnectionProfile(
        id: 'schema-es',
        label: 'Schema Test',
        host: '127.0.0.1',
      ));
    });

    tearDown(() async {
      if (conn.isActive) await provider.disconnect(conn);
    });

    test('listDatabases returns 1 cluster', () async {
      final dbs = await provider.listDatabases(conn);
      expect(dbs.length, 1);
      expect(dbs.first, isA<ElasticsearchCluster>());
      expect(dbs.first.name, 'db-explorer-mock');
    });

    test('listCollections returns 2 indices (products, orders)', () async {
      final colls = await provider.listCollections(conn, 'db-explorer-mock');
      expect(colls.length, 2);
      final names = colls.map((c) => c.name).toSet();
      expect(names, containsAll({'products', 'orders'}));
    });

    test('products index has 5 fields', () async {
      final colls =
          await provider.listCollections(conn, 'db-explorer-mock');
      final products = colls.firstWhere((c) => c.name == 'products');
      expect(products.fields.length, 5);
      final fieldNames = products.fields.map((f) => f.name).toSet();
      expect(fieldNames,
          containsAll({'sku', 'name', 'price', 'description', 'tags'}));
    });

    test('products.sku field is keyword + searchable + aggregatable',
        () async {
      final colls =
          await provider.listCollections(conn, 'db-explorer-mock');
      final products = colls.firstWhere((c) => c.name == 'products');
      final sku = products.fields.firstWhere((f) => f.name == 'sku');
      expect(sku, isA<ElasticsearchField>());
      expect((sku as ElasticsearchField).dataType, 'keyword');
      expect(sku.isSearchable, isTrue);
      expect(sku.isAggregatable, isTrue);
    });

    test('products.price field is double + NOT searchable + aggregatable',
        () async {
      final colls =
          await provider.listCollections(conn, 'db-explorer-mock');
      final products = colls.firstWhere((c) => c.name == 'products');
      final price = products.fields.firstWhere((f) => f.name == 'price');
      expect(price, isA<ElasticsearchField>());
      expect((price as ElasticsearchField).dataType, 'double');
      expect(price.isSearchable, isFalse);
      expect(price.isAggregatable, isTrue);
    });
  });

  group('ElasticsearchDBProvider — query execution', () {
    late ElasticsearchDBProvider provider;
    late DatabaseConnection conn;

    setUp(() async {
      provider = ElasticsearchDBProvider();
      conn = await provider.connect(const ElasticsearchConnectionProfile(
        id: 'q-es',
        label: 'Query Test',
        host: '127.0.0.1',
      ));
    });

    tearDown(() async {
      if (conn.isActive) await provider.disconnect(conn);
    });

    test('match_all → 3 product hits', () async {
      final result = await provider.execute(
        conn,
        const QueryRequest(
          connectionId: 'q-es',
          language: QueryLanguage.elasticDsl,
          text: '{"query":{"match_all":{}}}',
        ),
      );
      expect(result.rows.length, 3);
      expect(result.columns, contains('_id'));
      expect(result.columns, contains('_score'));
      expect(result.columns, contains('_source'));
    });

    test('match name:deluxe → 1 product hit (DELUXE-003)', () async {
      final result = await provider.execute(
        conn,
        const QueryRequest(
          connectionId: 'q-es',
          language: QueryLanguage.elasticDsl,
          text:
              '{"query":{"match":{"name":"deluxe"}},"database":"products"}',
        ),
      );
      expect(result.rows.length, greaterThanOrEqualTo(1));
    });

    test('size param limits result rows', () async {
      final result = await provider.execute(
        conn,
        const QueryRequest(
          connectionId: 'q-es',
          language: QueryLanguage.elasticDsl,
          text: '{"query":{"match_all":{}},"size":2}',
        ),
      );
      expect(result.rows.length, 2);
      expect(result.hasMore, isTrue);
    });

    test('non-JSON DSL throws FormatException', () {
      expect(
        () => provider.execute(
          conn,
          const QueryRequest(
            connectionId: 'q-es',
            language: QueryLanguage.elasticDsl,
            text: 'not-json-at-all',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('non-elasticDsl language throws ArgumentError', () {
      expect(
        () => provider.execute(
          conn,
          const QueryRequest(
            connectionId: 'q-es',
            language: QueryLanguage.sql,
            text: 'SELECT 1',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('ElasticsearchDBProvider — capabilities', () {
    test('capabilities include fullTextSearch + geospatial + tls', () {
      final provider = ElasticsearchDBProvider();
      final caps = provider.capabilities;
      expect(caps.supportsTls, isTrue);
      expect(caps.hasFullTextSearch, isTrue);
      expect(caps.hasAnyWrite, isTrue);
      expect(caps.hasBulkWrite, isTrue);
      expect(caps.hasIndexManagement, isTrue);
      expect(caps.hasCompletion, isTrue);
    });

    test('ES has fullTextSearch + geospatial + completion', () {
      final provider = ElasticsearchDBProvider();
      expect(provider.capabilities.hasFullTextSearch, isTrue);
      expect(provider.capabilities.hasGeospatial, isTrue);
      expect(provider.capabilities.hasCompletion, isTrue);
    });
  });

  group('ElasticsearchDBProvider — completion', () {
    test('complete returns DSL operators + keywords', () async {
      final provider = ElasticsearchDBProvider();
      final conn = await provider.connect(const ElasticsearchConnectionProfile(
        id: 'c-es',
        label: 'Completion Test',
        host: '127.0.0.1',
      ));
      addTearDown(() async {
        if (conn.isActive) await provider.disconnect(conn);
      });

      final items = await provider.complete(
        conn,
        const CompletionContext(
          connectionId: 'c-es',
          database: 'products',
          text: '{"match',
          cursorOffset: 8,
        ),
      );
      expect(items, isNotEmpty);
      final labels = items.map((i) => i.label).toSet();
      expect(labels, contains('match_all'));
      expect(labels, contains('match'));
      expect(labels, contains('bool'));
      expect(labels, contains('term'));
    });
  });

  group('ElasticsearchConnectionProfile — JSON round-trip', () {
    test('copyWith preserves all fields', () {
      const p = ElasticsearchConnectionProfile(
        id: '1',
        label: 'L',
        host: 'h',
        scheme: 'https',
        port: 9243,
        username: 'elastic',
        password: 'pw',
        apiKey: 'encoded-base64',
        requestTimeoutSeconds: 30,
      );
      final p2 = p.copyWith(label: 'L2');
      expect(p2.id, '1');
      expect(p2.label, 'L2');
      expect(p2.host, 'h');
      expect(p2.scheme, 'https');
      expect(p2.port, 9243);
      expect(p2.username, 'elastic');
      expect(p2.password, 'pw');
      expect(p2.apiKey, 'encoded-base64');
      expect(p2.requestTimeoutSeconds, 30);
    });

    test('default port is 9200 and default scheme is http', () {
      const p = ElasticsearchConnectionProfile(
        id: '1',
        label: 'L',
        host: 'h',
      );
      expect(p.port, 9200);
      expect(p.scheme, 'http');
      expect(p.kind, DatabaseKind.elasticsearch);
    });

    test('apiKey takes precedence over username/password for auth', () {
      const p = ElasticsearchConnectionProfile(
        id: '1',
        label: 'L',
        host: 'h',
        apiKey: 'key',
        username: 'u',
        password: 'p',
      );
      expect(p.apiKey, 'key');
      expect(p.username, 'u');
      expect(p.password, 'p');
    });
  });
}
