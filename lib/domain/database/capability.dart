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
///
/// Phase 1'de genişletildi: write alt-komutları, query türleri, index
/// yönetimi detayları, schema introspection derinliği, security hints.
enum DatabaseCapability {
  // ─── Schema / Structure ────────────────────────────────────────────
  /// Hiyerarşik şema (database > collection/table > field)
  schemaHierarchy,

  /// Şemasız/değişken şema (MongoDB documents, Redis keys)
  schemaless,

  /// Runtime schema introspection (collection field tiplerini okuyabilme)
  schemaIntrospection,

  /// Index bilgisi okuma (hangi alanlarda index var?)
  indexIntrospection,

  // ─── Query / Read ─────────────────────────────────────────────────
  /// İlişkisel JOIN desteği (SQL provider'lar)
  relationalJoins,

  /// Tam metin arama (Elasticsearch, MongoDB text index)
  fullTextSearch,

  /// Aggregation pipeline (MongoDB)
  aggregationPipeline,

  /// Geospatial sorgu ($geoWithin, ST_DWithin)
  geospatial,

  /// Explain plan (query optimizer output)
  explainPlan,

  /// Completion / autocomplete (LSP-benzeri)
  completion,

  /// Streaming cursor (cursor batch'i büyük dataset için)
  streaming,

  // ─── Write / Mutations ─────────────────────────────────────────────
  /// INSERT desteği
  insert,

  /// UPDATE desteği
  update,

  /// DELETE desteği
  delete,

  /// Bulk write (çoklu doküman/satır tek istekte)
  bulkWrite,

  /// Transactional ACID (SQL, MongoDB 4.0+)
  transactions,

  // ─── Schema mutation ──────────────────────────────────────────────
  /// CREATE/DROP DATABASE
  createDatabase,

  /// CREATE/DROP COLLECTION/TABLE
  createCollection,

  /// DROP COLLECTION/TABLE
  dropCollection,

  /// CREATE/DROP INDEX
  indexManagement,

  /// Schema validation rules (JSON Schema, $jsonSchema)
  schemaValidation,

  // ─── Operational ──────────────────────────────────────────────────
  /// Server info (version, replica set, uptime)
  serverInfo,

  /// Realtime stats (oplog, slow queries, current ops)
  liveStats,

  /// Backup/restore (mongodump, pg_dump)
  backup,

  /// User/role management (CREATE USER, GRANT)
  userManagement,

  // ─── Security hints (UI için — güvenlik garantisi değil) ─────────
  /// TLS desteklenebilir (UI'da TLS toggle göster)
  tlsSupport,

  /// SSH tunnel desteklenebilir (UI'da SSH config göster)
  sshTunnelSupport,

  // ─── Read-only mode (provider seviyesinde) ────────────────────────
  /// Provider read-only modda çalışıyor (UI'da write button disable)
  readOnly,
}

/// Provider'ın desteklediği capability set'i.
///
/// Immutable. Builder ile yeni instance oluşturulabilir:
/// ```dart
/// const caps = DatabaseCapabilities({
///   DatabaseCapability.find,
///   DatabaseCapability.aggregate,
/// });
/// ```
class DatabaseCapabilities {
  const DatabaseCapabilities([this.capabilities = const {}]);

  /// Set olarak verilen capability koleksi.
  final Set<DatabaseCapability> capabilities;

  /// Tek capability var mı?
  bool supports(DatabaseCapability cap) => capabilities.contains(cap);

  // ─── Schema ────────────────────────────────────────────────────────
  bool get hasSchemaHierarchy => supports(DatabaseCapability.schemaHierarchy);
  bool get isSchemaless => supports(DatabaseCapability.schemaless);
  bool get hasSchemaIntrospection =>
      supports(DatabaseCapability.schemaIntrospection);
  bool get hasIndexIntrospection =>
      supports(DatabaseCapability.indexIntrospection);

  // ─── Query ─────────────────────────────────────────────────────────
  bool get hasRelationalJoins => supports(DatabaseCapability.relationalJoins);
  bool get hasFullTextSearch => supports(DatabaseCapability.fullTextSearch);
  bool get hasAggregationPipeline =>
      supports(DatabaseCapability.aggregationPipeline);
  bool get hasGeospatial => supports(DatabaseCapability.geospatial);
  bool get hasExplainPlan => supports(DatabaseCapability.explainPlan);
  bool get hasCompletion => supports(DatabaseCapability.completion);
  bool get hasStreaming => supports(DatabaseCapability.streaming);

  // ─── Write ─────────────────────────────────────────────────────────
  bool get hasInsert => supports(DatabaseCapability.insert);
  bool get hasUpdate => supports(DatabaseCapability.update);
  bool get hasDelete => supports(DatabaseCapability.delete);
  bool get hasBulkWrite => supports(DatabaseCapability.bulkWrite);
  bool get hasTransactions => supports(DatabaseCapability.transactions);

  /// Herhangi bir write operasyonu var mı?
  bool get hasAnyWrite => hasInsert || hasUpdate || hasDelete || hasBulkWrite;

  // ─── Schema mutation ──────────────────────────────────────────────
  bool get canCreateDatabase => supports(DatabaseCapability.createDatabase);
  bool get canCreateCollection =>
      supports(DatabaseCapability.createCollection);
  bool get canDropCollection => supports(DatabaseCapability.dropCollection);
  bool get hasIndexManagement => supports(DatabaseCapability.indexManagement);
  bool get hasSchemaValidation => supports(DatabaseCapability.schemaValidation);

  // ─── Operational ──────────────────────────────────────────────────
  bool get hasServerInfo => supports(DatabaseCapability.serverInfo);
  bool get hasLiveStats => supports(DatabaseCapability.liveStats);
  bool get hasBackup => supports(DatabaseCapability.backup);
  bool get hasUserManagement => supports(DatabaseCapability.userManagement);

  // ─── Security ──────────────────────────────────────────────────────
  bool get supportsTls => supports(DatabaseCapability.tlsSupport);
  bool get supportsSshTunnel => supports(DatabaseCapability.sshTunnelSupport);

  // ─── Read-only ─────────────────────────────────────────────────────
  bool get isReadOnly => supports(DatabaseCapability.readOnly);

  /// Capability set'inden UI için özet string (debug/log).
  String get summary => capabilities.map((c) => c.name).join(', ');

  /// Write yeteneği olan mı? UI "Edit" modu açık mı?
  bool get isMutable => hasAnyWrite && !isReadOnly;

  /// Builder: mevcut set + ek capability'ler → yeni immutable instance.
  DatabaseCapabilities withCapabilities(Iterable<DatabaseCapability> extra) {
    return DatabaseCapabilities({...capabilities, ...extra});
  }

  /// Builder: belirli capability'leri çıkar → yeni immutable instance.
  DatabaseCapabilities withoutCapabilities(Iterable<DatabaseCapability> minus) {
    final next = {...capabilities}..removeAll(minus);
    return DatabaseCapabilities(next);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DatabaseCapabilities) return false;
    return _setEquals(capabilities, other.capabilities);
  }

  @override
  int get hashCode => Object.hashAllUnordered(capabilities);

  @override
  String toString() => 'DatabaseCapabilities($summary)';
}

bool _setEquals<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) return false;
  for (final x in a) {
    if (!b.contains(x)) return false;
  }
  return true;
}