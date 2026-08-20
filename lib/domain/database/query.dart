import 'package:db_explorer_app/domain/database/schema.dart';
import 'package:equatable/equatable.dart';

/// Query language — provider'a göre farklı syntax.
enum QueryLanguage {
  /// MongoDB shell / extended JSON aggregation pipeline.
  mongoShell,

  /// SQL (PostgreSQL, MySQL, vs.)
  sql,

  /// Redis komutları (GET, SET, HGETALL, vs.)
  redisCmd,

  /// Elasticsearch DSL (JSON-based query DSL)
  elasticDsl,
}

/// Query isteği — provider'a gönderilen execute komutu.
class QueryRequest extends Equatable {
  const QueryRequest({
    required this.connectionId,
    required this.language,
    required this.text,
    this.database,
    this.parameters = const {},
    this.timeout,
  });

  /// Hangi connection üzerinde çalışacak.
  final String connectionId;

  final QueryLanguage language;

  /// Query metni (mongo shell syntax, SQL, vs.).
  final String text;

  /// Optional: explicit database (bağlam için).
  final String? database;

  /// Parametreler (parameterized query için — Phase 0'da kullanılmaz).
  final Map<String, Object?> parameters;

  /// Timeout (saniye). null = provider default.
  final Duration? timeout;

  @override
  List<Object?> get props => [connectionId, language, text, database];
}

/// Query sonucu — generic Result modeli.
class QueryResult extends Equatable {
  const QueryResult({
    required this.columns,
    required this.rows,
    required this.executionTime,
    this.affectedRows,
    this.explainPlan,
    this.metadata = const {},
  });

  final List<String> columns;
  final List<DataRow> rows;

  final Duration executionTime;

  /// UPDATE/INSERT için etkilenen satır sayısı.
  final int? affectedRows;

  /// Explain plan output (provider-specific).
  final String? explainPlan;

  /// Provider-specific metadata (örn. MongoDB cursor id).
  final Map<String, Object?> metadata;

  @override
  List<Object?> get props => [
    columns,
    rows,
    executionTime,
    affectedRows,
    explainPlan,
  ];
}

/// Streaming query progress (büyük dataset için cursor).
class QueryProgress extends Equatable {
  const QueryProgress({required this.received, this.total});
  final int received;
  final int? total;

  @override
  List<Object?> get props => [received, total];
}

/// Completion item — autocomplete için.
class CompletionItem extends Equatable {
  const CompletionItem({
    required this.label,
    required this.kind,
    this.detail,
    this.documentation,
  });

  final String label;

  /// kind: keyword / field / collection / function / operator / variable
  final String kind;

  final String? detail;
  final String? documentation;

  @override
  List<Object?> get props => [label, kind, detail, documentation];
}

/// Completion context — provider'a autocomplete sorulurken.
class CompletionContext extends Equatable {
  const CompletionContext({
    required this.connectionId,
    required this.database,
    required this.text,
    required this.cursorOffset,
    this.language,
  });

  final String connectionId;
  final String database;
  final String text;
  final int cursorOffset;
  final QueryLanguage? language;

  @override
  List<Object?> get props => [connectionId, database, text, cursorOffset];
}
