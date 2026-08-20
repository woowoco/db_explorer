import 'package:db_explorer_app/domain/database/capability.dart';
import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/domain/database/database_provider.dart';
import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/domain/database/schema.dart';

/// MongoDB provider — Phase 0 stub.
///
/// Gerçek `mongo_dart_flutter` entegrasyonu Faz 3'te yapılacak. Şimdilik
/// compile-clean skeleton + capability set declaration.
class MongoDBProvider implements DatabaseProvider {
  MongoDBProvider();

  @override
  String get id => 'mongodb';

  @override
  DatabaseKind get kind => DatabaseKind.mongodb;

  @override
  DatabaseCapabilities get capabilities => const DatabaseCapabilities({
    DatabaseCapability.schemaHierarchy,
    DatabaseCapability.schemaless,
    DatabaseCapability.aggregationPipeline,
    DatabaseCapability.transactions,
    DatabaseCapability.streaming,
    DatabaseCapability.indexManagement,
    DatabaseCapability.explainPlan,
    DatabaseCapability.completion,
  });

  // TODO(Phase 3): implement using mongo_dart_flutter
  // - connect(): open Db, authenticate, set _db handle
  // - listDatabases(): db.listDatabases()
  // - listCollections(): db.collectionNames() per database
  // - execute(): db.collection().aggregate() / find()
  // - explain(): aggregate with $explain
  // - complete(): LSP-like helper (Phase 4)

  @override
  Future<DatabaseConnection> connect(DatabaseConnectionConfig config) async {
    final connection = DatabaseConnection(profile: config, providerId: id);
    connection.state = const IdleConnection();
    return connection;
  }

  @override
  Future<void> disconnect(DatabaseConnection connection) async {
    connection.state = const DisconnectedConnection();
  }

  @override
  Future<bool> ping(DatabaseConnection connection) async {
    return false;
  }

  @override
  Future<List<DatabaseNode>> listDatabases(
    DatabaseConnection connection,
  ) async {
    return const [];
  }

  @override
  Future<List<CollectionNode>> listCollections(
    DatabaseConnection connection,
    String database,
  ) async {
    return const [];
  }

  @override
  Future<QueryResult> execute(
    DatabaseConnection connection,
    QueryRequest request,
  ) async {
    return const QueryResult(
      columns: [],
      rows: [],
      executionTime: Duration.zero,
    );
  }

  @override
  Future<String> explain(
    DatabaseConnection connection,
    QueryRequest request,
  ) async {
    return '// Phase 0 stub — Phase 3 implementasyonu';
  }

  @override
  Future<List<CompletionItem>> complete(
    DatabaseConnection connection,
    CompletionContext context,
  ) async {
    return const [];
  }
}

/// MongoDBProvider factory — registry tarafından kullanılır.
class MongoDBProviderFactory implements DatabaseProviderFactory {
  @override
  DatabaseProvider create() => MongoDBProvider();

  @override
  DatabaseKind get kind => DatabaseKind.mongodb;
}
