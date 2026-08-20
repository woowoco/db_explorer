import 'package:equatable/equatable.dart';

/// Query history entry — saved on every successful query execution.
///
/// TTL configurable (settings.historyTtlDays).
class QueryHistoryEntry extends Equatable {
  const QueryHistoryEntry({
    required this.id,
    required this.connectionId,
    required this.database,
    required this.collection,
    required this.language,
    required this.text,
    required this.executedAt,
    required this.rowCount,
    required this.executionTimeMs,
    this.affectedRows,
  });

  /// UUID v4 (storage key).
  final String id;

  final String connectionId;
  final String database;
  final String collection;
  final String language;
  final String text;
  final DateTime executedAt;

  /// Dönen satır sayısı (0 = write/DDL).
  final int rowCount;

  /// Execution time (ms).
  final int executionTimeMs;

  /// Write query'lerde etkilenen satır.
  final int? affectedRows;

  /// Storage key.
  String get storageKey => 'q:$id';

  Map<String, Object?> toMap() => {
    'id': id,
    'connectionId': connectionId,
    'database': database,
    'collection': collection,
    'language': language,
    'text': text,
    'executedAt': executedAt.millisecondsSinceEpoch,
    'rowCount': rowCount,
    'executionTimeMs': executionTimeMs,
    'affectedRows': affectedRows,
  };

  static QueryHistoryEntry fromMap(Map<dynamic, dynamic> map) {
    return QueryHistoryEntry(
      id: map['id'] as String,
      connectionId: map['connectionId'] as String,
      database: map['database'] as String? ?? '',
      collection: map['collection'] as String? ?? '',
      language: map['language'] as String,
      text: map['text'] as String,
      executedAt: DateTime.fromMillisecondsSinceEpoch(
        map['executedAt'] as int,
        isUtc: true,
      ),
      rowCount: map['rowCount'] as int? ?? 0,
      executionTimeMs: map['executionTimeMs'] as int? ?? 0,
      affectedRows: map['affectedRows'] as int?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    connectionId,
    database,
    collection,
    language,
    text,
    executedAt,
    rowCount,
    executionTimeMs,
    affectedRows,
  ];
}