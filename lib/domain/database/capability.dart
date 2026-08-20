/// Veritabanı yetenek kümeleri — capability-driven UI.
///
/// Her provider (MongoDB, PostgreSQL, Redis, Elasticsearch...) capability
/// set'ini doldurur; UI bu set'e göre adaptif davranır (örn. Redis'te
/// "schema" kavramı yoksa Explorer'da collection tree yerine key list
/// gösterir).
///
/// Capability'ler capability-driven UI için ince bir enum olarak tutulur;
/// provider implementasyonu hangi capability'leri desteklediğini
/// `DatabaseCapabilities` sınıfı üzerinden bildirir.
enum DatabaseCapability {
  /// Hiyerarşik şema (database > collection/table > field)
  schemaHierarchy,

  /// Şemasız/değişken şema (MongoDB documents, Redis keys)
  schemaless,

  /// İlişkisel JOIN desteği (SQL provider'lar)
  relationalJoins,

  /// Tam metin arama (Elasticsearch, MongoDB text index)
  fullTextSearch,

  /// Aggregation pipeline (MongoDB)
  aggregationPipeline,

  /// Transactional ACID (SQL, MongoDB 4.0+)
  transactions,

  /// Streaming cursor (cursor batch'i büyük dataset için)
  streaming,

  /// Index yönetimi (CREATE/DROP INDEX)
  indexManagement,

  /// Explain plan (query optimizer output)
  explainPlan,

  /// Completion / autocomplete (LSP-benzeri)
  completion,

  /// Read-only mode (UI'da write button disable)
  readOnly,
}

/// Provider'ın desteklediği capability set'i.
class DatabaseCapabilities {
  const DatabaseCapabilities(this.capabilities);

  final Set<DatabaseCapability> capabilities;

  bool supports(DatabaseCapability cap) => capabilities.contains(cap);

  bool get hasSchemaHierarchy => supports(DatabaseCapability.schemaHierarchy);
  bool get isSchemaless => supports(DatabaseCapability.schemaless);
  bool get hasRelationalJoins =>
      supports(DatabaseCapability.relationalJoins);
  bool get hasFullTextSearch => supports(DatabaseCapability.fullTextSearch);
  bool get hasAggregationPipeline =>
      supports(DatabaseCapability.aggregationPipeline);
  bool get hasTransactions => supports(DatabaseCapability.transactions);
  bool get hasStreaming => supports(DatabaseCapability.streaming);
  bool get hasIndexManagement => supports(DatabaseCapability.indexManagement);
  bool get hasExplainPlan => supports(DatabaseCapability.explainPlan);
  bool get hasCompletion => supports(DatabaseCapability.completion);
  bool get isReadOnly => supports(DatabaseCapability.readOnly);

  /// Capability set'inden UI için özet string (debug/log).
  String get summary => capabilities.map((c) => c.name).join(', ');
}
