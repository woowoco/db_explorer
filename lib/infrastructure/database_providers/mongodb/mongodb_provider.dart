import 'dart:async';
import 'dart:math';

import 'package:db_explorer_app/core/utils/app_logger.dart';
import 'package:db_explorer_app/domain/database/capability.dart';
import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/domain/database/database_provider.dart';
import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/domain/database/schema.dart';
import 'package:db_explorer_app/infrastructure/database_providers/mongodb/mongodb_schema.dart';

/// In-memory MongoDB mock provider.
///
/// Phase 1'de geliştirme sürecini hızlandırmak için seed verili mock.
/// Gerçek `mongo_dart_flutter` entegrasyonu Phase 3'te yapılacak.
///
/// Mock'un davranışı:
/// - connect: hemen başarılı (gecikme: 50-150ms)
/// - disconnect: state reset
/// - ping: true
/// - listDatabases: ["admin", "config", "local", "sample"]
/// - listCollections("sample"): ["users", "products", "orders"]
/// - execute: çok basit parser — sadece `db.<collection>.find()` ve
///   `db.<collection>.findOne()` sorgularını destekler. Diğer sorgular
///   için bilgilendirici hata döner.
class MongoDBProvider implements DatabaseProvider {
  MongoDBProvider();

  final _log = getLogger('MongoDBProvider');

  // ─── Provider identity ────────────────────────────────────────────
  @override
  String get id => 'mongodb';

  @override
  DatabaseKind get kind => DatabaseKind.mongodb;

  @override
  DatabaseCapabilities get capabilities => const DatabaseCapabilities({
    DatabaseCapability.schemaHierarchy,
    DatabaseCapability.schemaless,
    DatabaseCapability.schemaIntrospection,
    DatabaseCapability.indexIntrospection,
    DatabaseCapability.aggregationPipeline,
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

  // ─── Sample seed data ─────────────────────────────────────────────
  static final _sampleSeed = _buildSampleSeed();

  static _SampleData _buildSampleSeed() {
    final users = <Map<String, Object?>>[
      {
        '_id': 'ObjectId(1)',
        'name': 'Alice',
        'email': 'alice@example.com',
        'age': 30,
        'active': true,
        'role': 'admin',
        'createdAt': '2024-01-15T08:30:00Z',
      },
      {
        '_id': 'ObjectId(2)',
        'name': 'Bob',
        'email': 'bob@example.com',
        'age': 24,
        'active': true,
        'role': 'user',
        'createdAt': '2024-02-20T12:00:00Z',
      },
      {
        '_id': 'ObjectId(3)',
        'name': 'Carol',
        'email': 'carol@example.com',
        'age': 41,
        'active': false,
        'role': 'user',
        'createdAt': '2024-03-10T09:15:00Z',
      },
      {
        '_id': 'ObjectId(4)',
        'name': 'Dave',
        'email': 'dave@example.com',
        'age': 35,
        'active': true,
        'role': 'moderator',
        'createdAt': '2024-04-05T14:45:00Z',
      },
    ];

    final products = <Map<String, Object?>>[
      {
        '_id': 'ObjectId(10)',
        'sku': 'WIDGET-001',
        'name': 'Premium Widget',
        'price': 29.99,
        'stock': 150,
        'tags': ['premium', 'bestseller'],
      },
      {
        '_id': 'ObjectId(11)',
        'sku': 'GIZMO-002',
        'name': 'Standard Gizmo',
        'price': 9.99,
        'stock': 500,
        'tags': ['standard'],
      },
    ];

    final orders = <Map<String, Object?>>[
      {
        '_id': 'ObjectId(100)',
        'userId': 'ObjectId(1)',
        'productId': 'ObjectId(10)',
        'quantity': 2,
        'total': 59.98,
        'status': 'completed',
      },
      {
        '_id': 'ObjectId(101)',
        'userId': 'ObjectId(2)',
        'productId': 'ObjectId(11)',
        'quantity': 1,
        'total': 9.99,
        'status': 'pending',
      },
    ];

    return _SampleData(
      users: users,
      products: products,
      orders: orders,
    );
  }

  // ─── Connection lifecycle ─────────────────────────────────────────
  @override
  Future<DatabaseConnection> connect(DatabaseConnectionConfig config) async {
    final connection = DatabaseConnection(profile: config, providerId: id);
    connection.state = const ConnectingConnection(message: 'Resolving host...');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    connection.state = const ConnectingConnection(
      progress: 0.5,
      message: 'Authenticating...',
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final sessionId = 'sess-${Random().nextInt(0xFFFFFF).toRadixString(16)}';
    connection.state = ConnectedConnection(
      sessionId: sessionId,
      at: DateTime.now(),
      serverVersion: '7.0.5-mock',
      latencyMs: 130,
      uptimeSeconds: 86400,
      extra: {'mode': 'in-memory-mock'},
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
    // Küçük gecikme — gerçekçi hissettirmek için.
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
    return const [
      MongoDatabase(name: 'admin'),
      MongoDatabase(name: 'config'),
      MongoDatabase(name: 'local'),
      MongoDatabase(name: 'sample'),
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
    if (database != 'sample') return const [];
    return [
      MongoCollection(
        name: 'users',
        fields: const [
          MongoField(name: '_id', dataType: 'objectId', isIndexed: true),
          MongoField(name: 'name', dataType: 'string'),
          MongoField(name: 'email', dataType: 'string', isIndexed: true),
          MongoField(name: 'age', dataType: 'int'),
          MongoField(name: 'active', dataType: 'bool'),
          MongoField(name: 'role', dataType: 'string'),
          MongoField(name: 'createdAt', dataType: 'date'),
        ],
        documentCount: _sampleSeed.users.length,
        averageDocumentSize: 180,
      ),
      MongoCollection(
        name: 'products',
        fields: const [
          MongoField(name: '_id', dataType: 'objectId', isIndexed: true),
          MongoField(name: 'sku', dataType: 'string', isIndexed: true),
          MongoField(name: 'name', dataType: 'string'),
          MongoField(name: 'price', dataType: 'double'),
          MongoField(name: 'stock', dataType: 'int'),
          MongoField(name: 'tags', dataType: 'array<string>'),
        ],
        documentCount: _sampleSeed.products.length,
        averageDocumentSize: 120,
      ),
      MongoCollection(
        name: 'orders',
        fields: const [
          MongoField(name: '_id', dataType: 'objectId', isIndexed: true),
          MongoField(name: 'userId', dataType: 'objectId', isIndexed: true),
          MongoField(name: 'productId', dataType: 'objectId'),
          MongoField(name: 'quantity', dataType: 'int'),
          MongoField(name: 'total', dataType: 'double'),
          MongoField(name: 'status', dataType: 'string'),
        ],
        documentCount: _sampleSeed.orders.length,
        averageDocumentSize: 90,
      ),
    ];
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
    if (request.language != QueryLanguage.mongoShell) {
      throw ArgumentError(
        'MongoDB provider only supports mongoShell, got ${request.language}',
      );
    }

    final started = DateTime.now();

    // Çok basit parser:
    //   db.<collection>.find()
    //   db.<collection>.findOne()
    //   db.<collection>.count()
    final regex = RegExp(r'db\.(\w+)\.(\w+)\(?\)?');
    final match = regex.firstMatch(request.text.trim());

    if (match == null) {
      throw FormatException(
        'Mock MongoDB only supports `db.<collection>.find()` / '
        '`findOne()` / `count()` syntax. Got: ${request.text}',
      );
    }

    final collection = match.group(1)!;
    final op = match.group(2)!;

    final docs = _readCollection(collection);
    final limited = request.pageSize != null
        ? docs.skip(request.pageOffset ?? 0).take(request.pageSize!)
        : docs;

    // Gecikme simülasyonu (5-25ms).
    await Future<void>.delayed(Duration(
      milliseconds: 5 + Random().nextInt(20),
    ));

    switch (op) {
      case 'find':
        final rows = limited
            .map((d) => DataRow({'doc': d.toString()}))
            .toList();
        return QueryResult(
          columns: const ['doc'],
          rows: rows,
          totalCount: docs.length,
          executionTime: DateTime.now().difference(started),
          hasMore: request.pageSize != null &&
              docs.length > (request.pageOffset ?? 0) + request.pageSize!,
          cursor: request.pageSize != null && docs.length > (request.pageOffset ?? 0) + (request.pageSize ?? 0)
              ? 'mock-cursor-${(request.pageOffset ?? 0) + (request.pageSize ?? 0)}'
              : null,
          warnings: const ['In-memory mock — data resets on app restart'],
        );

      case 'findOne':
        if (docs.isEmpty) {
          return QueryResult(
            columns: const ['doc'],
            rows: const [],
            executionTime: DateTime.now().difference(started),
          );
        }
        return QueryResult(
          columns: const ['doc'],
          rows: [DataRow({'doc': docs.first.toString()})],
          executionTime: DateTime.now().difference(started),
        );

      case 'count':
        return QueryResult(
          columns: const ['count'],
          rows: [DataRow({'count': docs.length})],
          executionTime: DateTime.now().difference(started),
        );

      default:
        throw FormatException(
          'Mock MongoDB supports only find/findOne/count. Got: $op',
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
// Mock explain plan
queryPlanner: {
  winningPlan: {
    stage: 'mock',
    inputStage: {
      stage: 'collScan',
      collection: '${request.collection ?? 'unknown'}',
      indexUsed: false,
      docsExamined: 100,
    },
  },
},
note: 'IN-MEMORY MOCK — not a real MongoDB explain plan';
''';
  }

  // ─── Completion ───────────────────────────────────────────────────
  @override
  Future<List<CompletionItem>> complete(
    DatabaseConnection connection,
    CompletionContext context,
  ) async {
    return const [
      CompletionItem(label: 'find', kind: 'method', detail: 'find(filter)'),
      CompletionItem(label: 'findOne', kind: 'method', detail: 'findOne(filter)'),
      CompletionItem(label: 'count', kind: 'method', detail: 'count(filter)'),
      CompletionItem(label: 'aggregate', kind: 'method', detail: 'aggregate(pipeline)'),
      CompletionItem(label: 'insertOne', kind: 'method', detail: 'insertOne(doc)'),
      CompletionItem(label: 'updateOne', kind: 'method', detail: 'updateOne(filter, update)'),
      CompletionItem(label: 'deleteOne', kind: 'method', detail: 'deleteOne(filter)'),
      CompletionItem(label: '\$match', kind: 'operator'),
      CompletionItem(label: '\$group', kind: 'operator'),
      CompletionItem(label: '\$project', kind: 'operator'),
      CompletionItem(label: '\$sort', kind: 'operator'),
      CompletionItem(label: '\$limit', kind: 'operator'),
    ];
  }

  // ─── Internal helpers ─────────────────────────────────────────────
  List<Map<String, Object?>> _readCollection(String name) {
    switch (name) {
      case 'users':
        return List<Map<String, Object?>>.from(_sampleSeed.users);
      case 'products':
        return List<Map<String, Object?>>.from(_sampleSeed.products);
      case 'orders':
        return List<Map<String, Object?>>.from(_sampleSeed.orders);
      default:
        throw ArgumentError(
          'Unknown collection in mock: $name (available: users, products, orders)',
        );
    }
  }
}

/// Seed data holder — `_buildSampleSeed()` tarafından üretilir.
class _SampleData {
  const _SampleData({
    required this.users,
    required this.products,
    required this.orders,
  });
  final List<Map<String, Object?>> users;
  final List<Map<String, Object?>> products;
  final List<Map<String, Object?>> orders;
}

/// MongoDBProvider factory — registry tarafından kullanılır.
class MongoDBProviderFactory implements DatabaseProviderFactory {
  const MongoDBProviderFactory();

  @override
  DatabaseProvider create() => MongoDBProvider();

  @override
  DatabaseKind get kind => DatabaseKind.mongodb;
}