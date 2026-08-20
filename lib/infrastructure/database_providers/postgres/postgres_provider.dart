import 'dart:async';
import 'dart:math';

import 'package:db_explorer_app/core/utils/app_logger.dart';
import 'package:db_explorer_app/domain/database/capability.dart';
import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/domain/database/database_provider.dart';
import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/domain/database/schema.dart';
import 'package:db_explorer_app/infrastructure/database_providers/postgres/postgres_schema.dart';

/// In-memory PostgreSQL mock provider.
///
/// MongoDB mock'u ile aynı kalıp:
/// - connect: hemen başarılı (gecikme: 50-150ms)
/// - disconnect: state reset
/// - ping: true
/// - listDatabases: ["postgres", "template1", "sample"]
/// - listCollections("sample" schema "public"): ["users", "products", "orders"]
/// - execute: çok basit parser — `SELECT * FROM <table>` sorgusunu destekler.
///   `LIMIT`/`OFFSET` opsiyonel desteklenir. Diğer sorgular için bilgilendirici hata.
///
/// Real provider (Phase 5.3 ayrı dosyada): `RealPostgresProvider` — `postgres`
/// paketini kullanır (Phase 5 default).
class PostgresDBProvider implements DatabaseProvider {
  PostgresDBProvider();

  final _log = getLogger('PostgresDBProvider');

  // ─── Provider identity ────────────────────────────────────────────
  @override
  String get id => 'postgres-mock';

  @override
  DatabaseKind get kind => DatabaseKind.postgres;

  @override
  DatabaseCapabilities get capabilities => const DatabaseCapabilities({
    DatabaseCapability.schemaHierarchy,
    DatabaseCapability.schemaIntrospection,
    DatabaseCapability.indexIntrospection,
    DatabaseCapability.relationalJoins,
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
  });

  // ─── Sample seed data ─────────────────────────────────────────────
  static final _sampleSeed = _buildSampleSeed();

  static _SampleData _buildSampleSeed() {
    final users = <Map<String, Object?>>[
      {
        'id': 1,
        'email': 'alice@example.com',
        'name': 'Alice',
        'age': 30,
        'role': 'admin',
        'created_at': '2024-01-15T08:30:00Z',
      },
      {
        'id': 2,
        'email': 'bob@example.com',
        'name': 'Bob',
        'age': 24,
        'role': 'user',
        'created_at': '2024-02-20T12:00:00Z',
      },
      {
        'id': 3,
        'email': 'carol@example.com',
        'name': 'Carol',
        'age': 41,
        'role': 'user',
        'created_at': '2024-03-10T09:15:00Z',
      },
      {
        'id': 4,
        'email': 'dave@example.com',
        'name': 'Dave',
        'age': 35,
        'role': 'moderator',
        'created_at': '2024-04-05T14:45:00Z',
      },
    ];

    final products = <Map<String, Object?>>[
      {
        'id': 10,
        'sku': 'WIDGET-001',
        'name': 'Premium Widget',
        'price': 29.99,
        'stock': 150,
      },
      {
        'id': 11,
        'sku': 'GIZMO-002',
        'name': 'Standard Gizmo',
        'price': 9.99,
        'stock': 500,
      },
    ];

    final orders = <Map<String, Object?>>[
      {
        'id': 100,
        'user_id': 1,
        'product_id': 10,
        'quantity': 2,
        'total': 59.98,
        'status': 'completed',
      },
      {
        'id': 101,
        'user_id': 2,
        'product_id': 11,
        'quantity': 1,
        'total': 9.99,
        'status': 'pending',
      },
    ];

    return _SampleData(users: users, products: products, orders: orders);
  }

  // ─── Connection lifecycle ─────────────────────────────────────────
  @override
  Future<DatabaseConnection> connect(DatabaseConnectionConfig config) async {
    final connection = DatabaseConnection(profile: config, providerId: id);
    connection.state = const ConnectingConnection(message: 'Resolving host...');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    connection.state = const ConnectingConnection(
      progress: 0.5,
      message: 'Authenticating (SCRAM-SHA-256)...',
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final sessionId = 'pg-sess-${Random().nextInt(0xFFFFFF).toRadixString(16)}';
    connection.state = ConnectedConnection(
      sessionId: sessionId,
      at: DateTime.now(),
      serverVersion: '16.3-mock',
      latencyMs: 130,
      uptimeSeconds: 86400,
      extra: {'mode': 'in-memory-mock', 'protocol': 'postgres-v3'},
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
    return const [
      PostgresDatabase(name: 'postgres'),
      PostgresDatabase(name: 'template1'),
      PostgresDatabase(name: 'sample'),
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
    // Mock'ta yalnızca `sample` db'sinin `public` schema'sı dolu.
    if (database != 'sample') return const [];
    return [
      PostgresTable(
        name: 'users',
        fields: const [
          PostgresColumn(
            name: 'id',
            dataType: 'int',
            isNullable: false,
            isIndexed: true,
            isPrimaryKey: true,
          ),
          PostgresColumn(
            name: 'email',
            dataType: 'varchar',
            isNullable: false,
            isIndexed: true,
          ),
          PostgresColumn(name: 'name', dataType: 'varchar'),
          PostgresColumn(name: 'age', dataType: 'int'),
          PostgresColumn(name: 'role', dataType: 'varchar'),
          PostgresColumn(name: 'created_at', dataType: 'timestamptz'),
        ],
        rowEstimate: _sampleSeed.users.length,
        totalSizeBytes: 8192,
      ),
      PostgresTable(
        name: 'products',
        fields: const [
          PostgresColumn(
            name: 'id',
            dataType: 'int',
            isNullable: false,
            isIndexed: true,
            isPrimaryKey: true,
          ),
          PostgresColumn(
            name: 'sku',
            dataType: 'varchar',
            isNullable: false,
            isIndexed: true,
          ),
          PostgresColumn(name: 'name', dataType: 'varchar'),
          PostgresColumn(name: 'price', dataType: 'numeric'),
          PostgresColumn(name: 'stock', dataType: 'int'),
        ],
        rowEstimate: _sampleSeed.products.length,
        totalSizeBytes: 4096,
      ),
      PostgresTable(
        name: 'orders',
        fields: const [
          PostgresColumn(
            name: 'id',
            dataType: 'int',
            isNullable: false,
            isIndexed: true,
            isPrimaryKey: true,
          ),
          PostgresColumn(name: 'user_id', dataType: 'int', isIndexed: true),
          PostgresColumn(name: 'product_id', dataType: 'int'),
          PostgresColumn(name: 'quantity', dataType: 'int'),
          PostgresColumn(name: 'total', dataType: 'numeric'),
          PostgresColumn(name: 'status', dataType: 'varchar'),
        ],
        rowEstimate: _sampleSeed.orders.length,
        totalSizeBytes: 4096,
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
    if (request.language != QueryLanguage.sql) {
      throw ArgumentError(
        'Postgres provider only supports SQL, got ${request.language}',
      );
    }

    final started = DateTime.now();

    // Çok basit parser — `SELECT * FROM <table> [LIMIT N] [OFFSET M]`.
    final regex = RegExp(
      r'^\s*SELECT\s+\*\s+FROM\s+(\w+)(?:\s+LIMIT\s+(\d+))?(?:\s+OFFSET\s+(\d+))?\s*;?\s*$',
      caseSensitive: false,
    );
    final match = regex.firstMatch(request.text.trim());

    if (match == null) {
      throw FormatException(
        'Mock Postgres only supports `SELECT * FROM <table> '
        '[LIMIT N] [OFFSET M]`. Got: ${request.text}',
      );
    }

    final table = match.group(1)!.toLowerCase();
    final explicitLimit = match.group(2) != null ? int.parse(match.group(2)!) : null;
    final explicitOffset =
        match.group(3) != null ? int.parse(match.group(3)!) : null;

    final rows = _readTable(table);
    final limit = explicitLimit ?? request.pageSize;
    final offset = explicitOffset ?? request.pageOffset ?? 0;
    final sliced = rows.skip(offset).take(limit ?? rows.length);

    await Future<void>.delayed(Duration(
      milliseconds: 5 + Random().nextInt(20),
    ));

    // İlk satırın key'leri kolon adı olur.
    final columns = rows.isEmpty ? const <String>[] : rows.first.keys.toList();
    final dataRows = sliced.map((r) => DataRow(Map<String, Object?>.from(r))).toList();

    return QueryResult(
      columns: columns,
      rows: dataRows,
      totalCount: rows.length,
      executionTime: DateTime.now().difference(started),
      hasMore: limit != null && (offset + dataRows.length) < rows.length,
      cursor: limit != null && (offset + dataRows.length) < rows.length
          ? 'mock-cursor-${offset + dataRows.length}'
          : null,
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
// Mock Postgres EXPLAIN
Plan: {
  Node Type: "Seq Scan",
  Relation Name: "${request.collection ?? 'unknown'}",
  Startup Cost: 0.00,
  Total Cost: 14.20,
  Plan Rows: 100,
  Actual Rows: 100,
}
note: 'IN-MEMORY MOCK — not a real Postgres EXPLAIN';
''';
  }

  // ─── Completion ───────────────────────────────────────────────────
  @override
  Future<List<CompletionItem>> complete(
    DatabaseConnection connection,
    CompletionContext context,
  ) async {
    return const [
      CompletionItem(label: 'SELECT', kind: 'keyword'),
      CompletionItem(label: 'FROM', kind: 'keyword'),
      CompletionItem(label: 'WHERE', kind: 'keyword'),
      CompletionItem(label: 'LIMIT', kind: 'keyword'),
      CompletionItem(label: 'OFFSET', kind: 'keyword'),
      CompletionItem(label: 'ORDER BY', kind: 'keyword'),
      CompletionItem(label: 'GROUP BY', kind: 'keyword'),
      CompletionItem(label: 'JOIN', kind: 'keyword'),
      CompletionItem(label: 'LEFT JOIN', kind: 'keyword'),
      CompletionItem(label: 'INSERT INTO', kind: 'keyword'),
      CompletionItem(label: 'UPDATE', kind: 'keyword'),
      CompletionItem(label: 'DELETE FROM', kind: 'keyword'),
      CompletionItem(label: 'count(*)', kind: 'function', detail: 'Aggregate'),
      CompletionItem(label: 'now()', kind: 'function', detail: 'Current timestamp'),
    ];
  }

  // ─── Internal helpers ─────────────────────────────────────────────
  List<Map<String, Object?>> _readTable(String name) {
    switch (name) {
      case 'users':
        return List<Map<String, Object?>>.from(_sampleSeed.users);
      case 'products':
        return List<Map<String, Object?>>.from(_sampleSeed.products);
      case 'orders':
        return List<Map<String, Object?>>.from(_sampleSeed.orders);
      default:
        throw ArgumentError(
          'Unknown table in mock: $name (available: users, products, orders)',
        );
    }
  }
}

/// Seed data holder.
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

/// Mock provider factory — registry tarafından kullanılır.
///
/// Default davranış: registry'ye mock bağlanır (Phase 8'de feature flag ile
/// `RealPostgresProviderFactory` aktifleştirilebilir).
class PostgresDBProviderFactory implements DatabaseProviderFactory {
  const PostgresDBProviderFactory();

  @override
  DatabaseProvider create() => PostgresDBProvider();

  @override
  DatabaseKind get kind => DatabaseKind.postgres;
}
