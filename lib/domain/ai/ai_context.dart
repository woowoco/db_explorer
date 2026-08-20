import 'package:db_explorer_app/domain/database/schema.dart';
import 'package:equatable/equatable.dart';

/// Provider dil ipucu — AI'ın hangi syntax'a göre üretim yapacağını belirler.
enum ProviderLanguageHint { mongoShell, sql, redisCmd, elasticDsl }

/// AI'a gönderilen schema-only context.
///
/// **ÖNEMLİ güvenlik kuralı** (brief madde 14):
/// - Sadece şema bilgisi (database/collection/field/index adları, tipleri).
/// - **ASLA** document value, raw data, örnek satır dahil edilmez.
/// - **ASLA** connection string, username, password, host bilgisi dahil edilmez.
class AiContext extends Equatable {
  const AiContext({
    required this.providerHint,
    required this.databases,
  });

  /// Hangi dilde sorgu üreteceğinin ipucu (örn. mongoShell → MongoDB query).
  final ProviderLanguageHint providerHint;

  /// Hangi database'lere erişim var.
  final List<DatabaseSchemaSummary> databases;

  @override
  List<Object?> get props => [providerHint, databases];
}

/// Bir database'in şema özeti (AI için güvenli).
class DatabaseSchemaSummary extends Equatable {
  const DatabaseSchemaSummary({
    required this.name,
    required this.collections,
  });

  final String name;
  final List<CollectionSchemaSummary> collections;

  @override
  List<Object?> get props => [name, collections];
}

/// Bir collection'ın şema özeti.
class CollectionSchemaSummary extends Equatable {
  const CollectionSchemaSummary({
    required this.name,
    required this.fields,
    this.indexes = const [],
  });

  final String name;

  /// Field isimleri + tipleri (sample value DEĞİL).
  final List<FieldSchemaSummary> fields;

  /// Index listesi (alan adları + unique/compound bilgisi).
  final List<String> indexes;

  @override
  List<Object?> get props => [name, fields, indexes];
}

/// Field özeti — AI'a sadece isim + tip, ASLA value.
class FieldSchemaSummary extends Equatable {
  const FieldSchemaSummary({
    required this.name,
    required this.type,
    this.isNullable = true,
  });

  final String name;
  final String type;
  final bool isNullable;

  @override
  List<Object?> get props => [name, type, isNullable];
}

/// Schema → AI context dönüşümü için extension.
///
/// Provider implementasyonu kendi şema node'larından (MongoCollection,
/// PostgresTable, ...) AiContext üretir.
extension SchemaNodeToAiContext on Iterable<DatabaseNode> {
  List<DatabaseSchemaSummary> toAiContextSummaries(
    String Function(DatabaseNode) dbNameExtractor,
    Iterable<CollectionNode> Function(DatabaseNode) collectionsExtractor,
  ) {
    return map((db) {
      final collections = collectionsExtractor(db)
          .map<CollectionSchemaSummary>(
            (c) => CollectionSchemaSummary(
              name: c.name,
              fields: c.fields
                  .map<FieldSchemaSummary>(
                    (f) => FieldSchemaSummary(
                      name: f.name,
                      type: f.dataType,
                      isNullable: f.isNullable,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList();
      return DatabaseSchemaSummary(
        name: dbNameExtractor(db),
        collections: collections,
      );
    }).toList();
  }
}
