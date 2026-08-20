import 'package:db_explorer_app/domain/database/schema.dart';

/// MongoDB-specific şema node'ları.
class MongoDatabase extends DatabaseNode {
  const MongoDatabase({required super.name});
}

class MongoCollection extends CollectionNode {
  const MongoCollection({
    required super.name,
    super.fields = const [],
    this.documentCount,
    this.averageDocumentSize,
  });

  /// Tahmini document sayısı (db.collection.stats()).
  final int? documentCount;

  /// Ortalama document boyutu (bytes).
  final int? averageDocumentSize;
}

class MongoField extends FieldNode {
  const MongoField({
    required super.name,
    required super.dataType,
    super.isNullable,
    super.isIndexed,
  });
}

class MongoIndex extends SchemaNode {
  const MongoIndex({required super.name, this.keys = const [], this.isUnique = false});

  /// Index anahtarları (field name → direction).
  final List<String> keys;
  final bool isUnique;
}
