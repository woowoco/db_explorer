import 'package:db_explorer_app/domain/database/schema.dart';

/// Elasticsearch schema node'ları.
///
/// ES'te "schema" = mapping. Her index bir mapping'e sahip (alanlar +
/// tipleri + analyzer'lar). Capability-driven UI için schema tree:
/// - `ElasticsearchCluster`: cluster-level node (listDatabases() döner).
///   Tek bir cluster bağlantısı tüm index'leri kapsar.
/// - `ElasticsearchIndex`: bir index (MongoDB collection muadili).
/// - `ElasticsearchField`: index mapping'teki alan (text/keyword/integer/date...).
/// - `ElasticsearchAnalyzer`: index'teki analyzer (custom analyzer).

/// Elasticsearch cluster.
class ElasticsearchCluster extends DatabaseNode {
  const ElasticsearchCluster({
    required super.name,
    this.clusterName,
    this.numberOfNodes = 0,
  });

  /// ES cluster.name.
  final String? clusterName;

  /// Cluster node sayısı.
  final int numberOfNodes;
}

/// Elasticsearch index.
class ElasticsearchIndex extends CollectionNode {
  const ElasticsearchIndex({
    required super.name,
    this.documentCount,
    this.sizeBytes,
    this.primaryShards = 1,
    this.replicaShards = 0,
    super.fields = const [],
  });

  /// Index'teki toplam document sayısı.
  final int? documentCount;

  /// Index'in disk üzerindeki boyutu (bytes).
  final int? sizeBytes;

  /// Primary shard sayısı.
  final int primaryShards;

  /// Replica shard sayısı.
  final int replicaShards;
}

/// Elasticsearch mapping field.
class ElasticsearchField extends FieldNode {
  const ElasticsearchField({
    required super.name,
    required super.dataType,
    this.isSearchable = true,
    this.isAggregatable = false,
  });

  /// Text field searchable mi? (keyword field'lar genelde searchable=false)
  final bool isSearchable;

  /// Aggregations için kullanılabilir mi?
  final bool isAggregatable;
}

/// Elasticsearch analyzer.
class ElasticsearchAnalyzer extends SchemaNode {
  const ElasticsearchAnalyzer({
    required super.name,
    required this.type,
    this.tokenizer,
  });

  /// Analyzer type: standard / simple / whitespace / custom / vs.
  final String type;

  /// Custom analyzer'ların tokenizer'ı (örn. standard, lowercase).
  final String? tokenizer;
}
