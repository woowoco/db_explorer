import 'package:db_explorer_app/domain/database/capability.dart';
import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/domain/database/schema.dart';

/// Database provider abstract interface.
///
/// Tüm provider'lar (MongoDB, Postgres, Redis, Elasticsearch...) bu
/// interface'i implement eder. UI provider-agnostic olarak bu interface
/// üzerinden çalışır.
///
/// Phase 0'da bu interface'in sadece tip tanımları var; gerçek
/// implementasyonlar infrastructure katmanında (mongodb/, postgres/, vs.)
abstract interface class DatabaseProvider {
  /// Provider identifier (registry key). Örn. 'mongodb', 'postgres'.
  String get id;

  /// DatabaseKind.
  DatabaseKind get kind;

  /// Provider'ın desteklediği capability set'i.
  DatabaseCapabilities get capabilities;

  /// Connection lifecycle.
  Future<DatabaseConnection> connect(DatabaseConnectionConfig config);
  Future<void> disconnect(DatabaseConnection connection);
  Future<bool> ping(DatabaseConnection connection);

  /// Schema discovery.
  Future<List<DatabaseNode>> listDatabases(DatabaseConnection connection);
  Future<List<CollectionNode>> listCollections(
    DatabaseConnection connection,
    String database,
  );

  /// Query execution.
  Future<QueryResult> execute(
    DatabaseConnection connection,
    QueryRequest request,
  );

  /// Explain plan.
  Future<String> explain(
    DatabaseConnection connection,
    QueryRequest request,
  );

  /// Completion / autocomplete.
  Future<List<CompletionItem>> complete(
    DatabaseConnection connection,
    CompletionContext context,
  );
}

/// Provider factory — registry tarafından kullanılır.
abstract interface class DatabaseProviderFactory {
  DatabaseProvider create();
  DatabaseKind get kind;
}
