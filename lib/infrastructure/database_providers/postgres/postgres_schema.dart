import 'package:db_explorer_app/domain/database/schema.dart';

/// PostgreSQL-specific şema node'ları.
///
/// SQL dünyasında:
/// - database = MongoDB'deki database
/// - schema = namespace (default: "public") — UI'da ikinci seviye gösterilir
/// - table = collection muadili
/// - column = field muadili
/// - index = ayrı bir node tipi
///
/// NOT: SchemaNode isimlendirmesi `PostgresSchema` veya `PostgresNamespace`
/// ile karışmasın diye `PostgresTableSchema`/`PostgresColumn` tercih edildi.

/// PostgreSQL database.
class PostgresDatabase extends DatabaseNode {
  const PostgresDatabase({required super.name});
}

/// PostgreSQL namespace (default: "public").
class PostgresNamespace extends SchemaNode {
  const PostgresNamespace({required super.name});
}

/// PostgreSQL table.
class PostgresTable extends CollectionNode {
  const PostgresTable({
    required super.name,
    super.fields = const [],
    this.rowEstimate,
    this.totalSizeBytes,
  });

  /// pg_statistic'ten tahmini satır sayısı.
  final int? rowEstimate;

  /// pg_relation_size() — sadece data (index hariç), bytes.
  final int? totalSizeBytes;
}

/// PostgreSQL column.
class PostgresColumn extends FieldNode {
  const PostgresColumn({
    required super.name,
    required super.dataType,
    super.isNullable = true,
    super.isIndexed = false,
    this.columnDefault,
    this.isPrimaryKey = false,
  });

  /// Default value (CREATE TABLE ... DEFAULT nextval('seq')).
  final String? columnDefault;

  /// Primary key parçası mı?
  final bool isPrimaryKey;
}

/// PostgreSQL index.
class PostgresIndex extends SchemaNode {
  const PostgresIndex({
    required super.name,
    this.tableName,
    this.columns = const [],
    this.isUnique = false,
    this.method = 'btree',
  });

  /// Index'in ait olduğu tablo.
  final String? tableName;

  /// Index kolonları (sıralı; DESC marker'ı varsa sondaki boşluğa bakılır).
  final List<String> columns;

  /// Unique index mi?
  final bool isUnique;

  /// Index method (btree, hash, gin, gist, vs.).
  final String method;
}
