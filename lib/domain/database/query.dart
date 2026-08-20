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

/// Query language human-readable label.
extension QueryLanguageLabel on QueryLanguage {
  String get label => switch (this) {
    QueryLanguage.mongoShell => 'MongoDB Shell',
    QueryLanguage.sql => 'SQL',
    QueryLanguage.redisCmd => 'Redis',
    QueryLanguage.elasticDsl => 'Elasticsearch DSL',
  };

  /// File extension hint (editor için).
  String get fileExtension => switch (this) {
    QueryLanguage.mongoShell => '.mongo.js',
    QueryLanguage.sql => '.sql',
    QueryLanguage.redisCmd => '.redis',
    QueryLanguage.elasticDsl => '.es.json',
  };
}

/// Query isteği — provider'a gönderilen execute komutu.
///
/// Phase 1'de genişletildi: collection target, pagination, idempotency,
/// read preference, parameters (typed).
class QueryRequest extends Equatable {
  const QueryRequest({
    required this.connectionId,
    required this.language,
    required this.text,
    this.database,
    this.collection,
    this.parameters = const {},
    this.pageSize,
    this.pageOffset,
    this.timeout,
    this.idempotencyKey,
    this.readOnlyHint = false,
  });

  /// Hangi connection üzerinde çalışacak.
  final String connectionId;

  final QueryLanguage language;

  /// Query metni (mongo shell syntax, SQL, vs.).
  final String text;

  /// Optional: explicit database (bağlam için).
  final String? database;

  /// Optional: explicit collection/table (autocomplete + UI için).
  final String? collection;

  /// Parametreler (parameterized query için — Phase 4+ tam kullanım).
  final Map<String, Object?> parameters;

  /// Pagination: page size (find().limit() için).
  final int? pageSize;

  /// Pagination: page offset (find().skip() için).
  final int? pageOffset;

  /// Timeout (saniye). null = provider default.
  final Duration? timeout;

  /// Idempotency key (aynı key ile retry güvenli).
  final String? idempotencyKey;

  /// UI hint: bu sorgu read-only mi? Provider bunu zorlamaz; sadece
  /// read-only connection'larda kontrol için.
  final bool readOnlyHint;

  QueryRequest copyWith({
    String? connectionId,
    QueryLanguage? language,
    String? text,
    String? database,
    String? collection,
    Map<String, Object?>? parameters,
    int? pageSize,
    int? pageOffset,
    Duration? timeout,
    String? idempotencyKey,
    bool? readOnlyHint,
  }) {
    return QueryRequest(
      connectionId: connectionId ?? this.connectionId,
      language: language ?? this.language,
      text: text ?? this.text,
      database: database ?? this.database,
      collection: collection ?? this.collection,
      parameters: parameters ?? this.parameters,
      pageSize: pageSize ?? this.pageSize,
      pageOffset: pageOffset ?? this.pageOffset,
      timeout: timeout ?? this.timeout,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      readOnlyHint: readOnlyHint ?? this.readOnlyHint,
    );
  }

  @override
  List<Object?> get props => [
    connectionId,
    language,
    text,
    database,
    collection,
    parameters,
    pageSize,
    pageOffset,
    timeout,
    idempotencyKey,
    readOnlyHint,
  ];
}

/// Query sonucu — generic Result modeli.
///
/// Phase 1'de genişletildi: column metadata (type hints), totalCount,
/// cursor (pagination), warnings, hasMore.
class QueryResult extends Equatable {
  const QueryResult({
    required this.columns,
    required this.rows,
    required this.executionTime,
    this.affectedRows,
    this.totalCount,
    this.hasMore = false,
    this.cursor,
    this.explainPlan,
    this.warnings = const [],
    this.metadata = const {},
  });

  /// Kolon isimleri.
  final List<String> columns;

  /// Dönen satırlar.
  final List<DataRow> rows;

  /// Toplam satır sayısı (total count — provider destekliyorsa).
  /// pageSize varsa bu sayı genelde totalCount > rows.length olur.
  final int? totalCount;

  final Duration executionTime;

  /// UPDATE/INSERT için etkilenen satır sayısı.
  final int? affectedRows;

  /// Daha fazla sayfa var mı? (streaming/pagination)
  final bool hasMore;

  /// Sonraki sayfa cursor'ı (provider'a özel opaque token).
  final String? cursor;

  /// Explain plan output (provider-specific).
  final String? explainPlan;

  /// Provider'ın raporladığı uyarılar (örn. "index kullanılmadı").
  final List<String> warnings;

  /// Provider-specific metadata (örn. MongoDB cursor id).
  final Map<String, Object?> metadata;

  /// Boş mu? (UI için hızlı kontrol)
  bool get isEmpty => rows.isEmpty;

  /// Tek satır dönen sorgu sonucu (örn. findOne, aggregate $count).
  DataRow? get singleRow => rows.isEmpty ? null : rows.first;

  @override
  List<Object?> get props => [
    columns,
    rows,
    totalCount,
    executionTime,
    affectedRows,
    hasMore,
    cursor,
    explainPlan,
    warnings,
  ];
}

/// Kolon metadata — type-aware data grid için.
class QueryColumn extends Equatable {
  const QueryColumn({required this.name, required this.type});
  final String name;

  /// Tip string'i (örn. "string", "int32", "objectId", "date").
  /// DataGridPalette ile eşleştirilecek.
  final String type;

  @override
  List<Object?> get props => [name, type];
}

/// Streaming query progress (büyük dataset için cursor).
class QueryProgress extends Equatable {
  const QueryProgress({required this.received, this.total, this.message});
  final int received;
  final int? total;
  final String? message;

  @override
  List<Object?> get props => [received, total, message];
}

/// Completion item — autocomplete için.
class CompletionItem extends Equatable {
  const CompletionItem({
    required this.label,
    required this.kind,
    this.detail,
    this.documentation,
    this.insertText,
  });

  final String label;

  /// kind: keyword / field / collection / function / operator / variable
  final String kind;

  final String? detail;
  final String? documentation;

  /// Editör'e insert edilecek metin (label'dan farklı olabilir).
  final String? insertText;

  @override
  List<Object?> get props => [label, kind, detail, documentation, insertText];
}

/// Completion context — provider'a autocomplete sorulurken.
class CompletionContext extends Equatable {
  const CompletionContext({
    required this.connectionId,
    required this.database,
    required this.text,
    required this.cursorOffset,
    this.collection,
    this.language,
  });

  final String connectionId;
  final String database;
  final String text;
  final int cursorOffset;

  /// Collection scope (opsiyonel — daha iyi autocomplete için).
  final String? collection;

  final QueryLanguage? language;

  @override
  List<Object?> get props => [
    connectionId,
    database,
    text,
    cursorOffset,
    collection,
    language,
  ];
}