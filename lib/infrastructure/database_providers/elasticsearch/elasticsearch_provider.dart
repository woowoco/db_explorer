import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:db_explorer_app/core/utils/app_logger.dart';
import 'package:db_explorer_app/domain/database/capability.dart';
import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/domain/database/database_provider.dart';
import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/domain/database/schema.dart';
import 'package:db_explorer_app/infrastructure/database_providers/elasticsearch/elasticsearch_schema.dart';

/// In-memory Elasticsearch mock provider.
///
/// ES semantiği:
/// - Cluster → Index → Mapping(field'lar + type)
/// - Query: `_search` API'sine JSON DSL gönderir (`{"query": {...}}`).
///   Mock'ta JSON parse edilip basit match kontrolü yapılır.
///
/// Real provider (Phase 6.3 ayrı dosyada): `RealElasticsearchProvider` —
/// `elastic_client` paketini kullanır.
class ElasticsearchDBProvider implements DatabaseProvider {
  ElasticsearchDBProvider();

  final _log = getLogger('ElasticsearchDBProvider');

  // ─── Provider identity ────────────────────────────────────────────
  @override
  String get id => 'elasticsearch-mock';

  @override
  DatabaseKind get kind => DatabaseKind.elasticsearch;

  @override
  DatabaseCapabilities get capabilities => const DatabaseCapabilities({
    DatabaseCapability.schemaHierarchy,
    DatabaseCapability.schemaIntrospection,
    DatabaseCapability.fullTextSearch,
    DatabaseCapability.geospatial,
    DatabaseCapability.streaming,
    DatabaseCapability.aggregationPipeline,
    DatabaseCapability.explainPlan,
    DatabaseCapability.completion,
    DatabaseCapability.insert,
    DatabaseCapability.update,
    DatabaseCapability.delete,
    DatabaseCapability.bulkWrite,
    DatabaseCapability.createCollection,
    DatabaseCapability.dropCollection,
    DatabaseCapability.indexManagement,
    DatabaseCapability.serverInfo,
    DatabaseCapability.liveStats,
    DatabaseCapability.backup,
    DatabaseCapability.userManagement,
    DatabaseCapability.tlsSupport,
  });

  // ─── Sample seed data ─────────────────────────────────────────────
  static final _sampleSeed = _buildSampleSeed();

  static _SampleData _buildSampleSeed() {
    final productsIndex = ElasticsearchIndex(
      name: 'products',
      documentCount: 3,
      sizeBytes: 4096,
      primaryShards: 1,
      replicaShards: 0,
      fields: const [
        ElasticsearchField(
          name: 'sku',
          dataType: 'keyword',
          isSearchable: true,
          isAggregatable: true,
        ),
        ElasticsearchField(name: 'name', dataType: 'text', isAggregatable: false),
        ElasticsearchField(
          name: 'price',
          dataType: 'double',
          isSearchable: false,
          isAggregatable: true,
        ),
        ElasticsearchField(name: 'description', dataType: 'text'),
        ElasticsearchField(
          name: 'tags',
          dataType: 'keyword',
          isAggregatable: true,
        ),
      ],
    );

    final ordersIndex = ElasticsearchIndex(
      name: 'orders',
      documentCount: 2,
      sizeBytes: 2048,
      fields: const [
        ElasticsearchField(name: 'order_id', dataType: 'keyword'),
        ElasticsearchField(name: 'user_id', dataType: 'keyword'),
        ElasticsearchField(name: 'total', dataType: 'double', isAggregatable: true),
        ElasticsearchField(name: 'status', dataType: 'keyword', isAggregatable: true),
        ElasticsearchField(name: 'created_at', dataType: 'date'),
      ],
    );

    final productsDocs = <Map<String, Object?>>[
      {
        '_id': 'p-001',
        'sku': 'WIDGET-001',
        'name': 'Premium Widget',
        'price': 29.99,
        'description': 'A high-quality widget for all purposes',
        'tags': ['premium', 'bestseller'],
      },
      {
        '_id': 'p-002',
        'sku': 'GIZMO-002',
        'name': 'Standard Gizmo',
        'price': 9.99,
        'description': 'An affordable gizmo for everyday use',
        'tags': ['standard'],
      },
      {
        '_id': 'p-003',
        'sku': 'DELUXE-003',
        'name': 'Deluxe Item',
        'price': 99.99,
        'description': 'A premium deluxe item with extra features',
        'tags': ['premium', 'new'],
      },
    ];

    final ordersDocs = <Map<String, Object?>>[
      {
        '_id': 'o-100',
        'order_id': '100',
        'user_id': '1',
        'total': 59.98,
        'status': 'completed',
        'created_at': '2024-01-15',
      },
      {
        '_id': 'o-101',
        'order_id': '101',
        'user_id': '2',
        'total': 9.99,
        'status': 'pending',
        'created_at': '2024-02-20',
      },
    ];

    return _SampleData(
      indices: [productsIndex, ordersIndex],
      productsDocs: productsDocs,
      ordersDocs: ordersDocs,
    );
  }

  // ─── Connection lifecycle ─────────────────────────────────────────
  @override
  Future<DatabaseConnection> connect(DatabaseConnectionConfig config) async {
    if (config is! ElasticsearchConnectionProfile) {
      throw ArgumentError(
        'ElasticsearchDBProvider requires ElasticsearchConnectionProfile, '
        'got ${config.runtimeType}',
      );
    }
    final connection = DatabaseConnection(profile: config, providerId: id);
    connection.state = const ConnectingConnection(message: 'Resolving host...');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    connection.state = const ConnectingConnection(
      progress: 0.5,
      message: 'Authenticating...',
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final sessionId = 'es-sess-${Random().nextInt(0xFFFFFF).toRadixString(16)}';
    connection.state = ConnectedConnection(
      sessionId: sessionId,
      at: DateTime.now(),
      serverVersion: '8.11-mock',
      latencyMs: 130,
      uptimeSeconds: 86400,
      extra: {
        'mode': 'in-memory-mock',
        'cluster': 'db-explorer-mock',
        'scheme': config.scheme,
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
    await Future<void>.delayed(const Duration(milliseconds: 10));
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
    // Mock tek cluster.
    return const [
      ElasticsearchCluster(
        name: 'db-explorer-mock',
        clusterName: 'db-explorer-mock',
        numberOfNodes: 1,
      ),
    ];
  }

  @override
  Future<List<CollectionNode>> listCollections(
    DatabaseConnection connection,
    String database,
  ) async {
    if (!connection.isConnected) {
      throw StateError('listCollections called without active connection');
    }
    return _sampleSeed.indices;
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
    if (request.language != QueryLanguage.elasticDsl) {
      throw ArgumentError(
        'Elasticsearch provider only supports elasticDsl, got '
        '${request.language}',
      );
    }

    final started = DateTime.now();
    final trimmed = request.text.trim();

    Map<String, dynamic> body;
    try {
      body = jsonDecode(trimmed) as Map<String, dynamic>;
    } on FormatException catch (_) {
      throw FormatException(
        'Mock ES expects JSON DSL body. Got: ${request.text}',
      );
    }

    final indexHint = request.database ?? 'products';
    final docs = _readDocs(indexHint);

    // Çok basit match query parser — sadece match/match_all desteği.
    final query = body['query'];
    final matched = docs.where((doc) {
      if (query == null) return true;
      if (query is Map<String, dynamic>) {
        if (query.containsKey('match_all')) return true;
        if (query.containsKey('match')) {
          final match = query['match'] as Map<String, dynamic>;
          return match.entries.every((entry) {
            final term = entry.value is Map<String, dynamic>
                ? entry.value['query']?.toString().toLowerCase()
                : entry.value.toString().toLowerCase();
            final termNonNull = term ?? '';
            final fieldValue = doc[entry.key]?.toString().toLowerCase() ?? '';
            return fieldValue.contains(termNonNull);
          });
        }
      }
      return false;
    }).toList();

    final size = body['size'] as int? ?? matched.length;
    final sliced = matched.take(size).toList();

    await Future<void>.delayed(Duration(
      milliseconds: 5 + Random().nextInt(20),
    ));

    return QueryResult(
      columns: const ['_id', '_score', '_source'],
      rows: sliced
          .map((d) => DataRow({
                '_id': d['_id'],
                '_score': 1.0,
                '_source': d.toString(),
              }))
          .toList(),
      totalCount: matched.length,
      executionTime: DateTime.now().difference(started),
      hasMore: matched.length > sliced.length,
      warnings: const ['In-memory mock — data resets on app restart'],
    );
  }

  // ─── Explain ──────────────────────────────────────────────────────
  @override
  Future<String> explain(
    DatabaseConnection connection,
    QueryRequest request,
  ) async {
    return '''
// Mock ES — no real explain
Query: ${request.text}
note: 'IN-MEMORY MOCK — not a real ES explain';
''';
  }

  // ─── Completion ───────────────────────────────────────────────────
  @override
  Future<List<CompletionItem>> complete(
    DatabaseConnection connection,
    CompletionContext context,
  ) async {
    return const [
      CompletionItem(label: 'match_all', kind: 'operator'),
      CompletionItem(label: 'match', kind: 'operator'),
      CompletionItem(label: 'term', kind: 'operator'),
      CompletionItem(label: 'terms', kind: 'operator'),
      CompletionItem(label: 'range', kind: 'operator'),
      CompletionItem(label: 'bool', kind: 'operator'),
      CompletionItem(label: 'must', kind: 'operator'),
      CompletionItem(label: 'should', kind: 'operator'),
      CompletionItem(label: 'must_not', kind: 'operator'),
      CompletionItem(label: 'filter', kind: 'operator'),
      CompletionItem(label: 'sort', kind: 'keyword'),
      CompletionItem(label: 'size', kind: 'keyword'),
      CompletionItem(label: 'from', kind: 'keyword'),
      CompletionItem(label: 'aggs', kind: 'keyword'),
      CompletionItem(label: 'query', kind: 'keyword'),
    ];
  }

  // ─── Internal helpers ─────────────────────────────────────────────
  List<Map<String, Object?>> _readDocs(String index) {
    switch (index) {
      case 'products':
        return List<Map<String, Object?>>.from(_sampleSeed.productsDocs);
      case 'orders':
        return List<Map<String, Object?>>.from(_sampleSeed.ordersDocs);
      default:
        return List<Map<String, Object?>>.from(_sampleSeed.productsDocs);
    }
  }
}

/// Seed data holder.
class _SampleData {
  const _SampleData({
    required this.indices,
    required this.productsDocs,
    required this.ordersDocs,
  });
  final List<ElasticsearchIndex> indices;
  final List<Map<String, Object?>> productsDocs;
  final List<Map<String, Object?>> ordersDocs;
}

/// Mock provider factory — registry tarafından kullanılır.
class ElasticsearchDBProviderFactory implements DatabaseProviderFactory {
  const ElasticsearchDBProviderFactory();

  @override
  DatabaseProvider create() => ElasticsearchDBProvider();

  @override
  DatabaseKind get kind => DatabaseKind.elasticsearch;
}
