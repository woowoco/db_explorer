# 🔬 db_explorer_app — Teknik Araştırma Raporu

> **Hazırlayan:** Claude (MiniMax-M3) · **Tarih:** 2026-08-20 · **Durum:** Onay bekliyor
> **Kapsam:** `C:\Users\tolga.durak\Desktop\F_AISUBCRIBE\mongodb-yonetim-app` — başlangıç Flutter projesi (sadece `flutter create` iskeleti).
> **Referans tasarım dili:** `C:\Users\tolga.durak\Desktop\F_AISUBCRIBE\F_AISUBCRIBE_APP` (Poppins + Deep Purple #6F31DA + Material 3 + flat, ThemeExtension tabanlı design system).
> **Brief:** `CHANGELOGS/start-prompt.md` (33 maddelik detaylı spec)

---

## 1. Product Definition

**Ürün adı (öneri):** `db_explorer_app` (mevcut klasör adı) veya `PolyglotDB` / `Workbench`.

**Ürün tanımı:**

> **Extensible Cross-Platform Database Workbench + AI Query Assistant** — Flutter tabanlı, kendi kullanımın için başlayıp sonra public release'e uygun şekilde geliştirilecek bir **veritabanı yönetim iş istasyonu**. MongoDB ilk provider olacak; PostgreSQL, MySQL, Redis, Elasticsearch, SQLite ve gelecek provider'lar için **common capabilities + provider-specific capabilities** mimarisi ile genişleyecek. Çekirdek farklılaştırıcı özellik **AI Query Assistant** olacak — bu AI, bir chatbot değil, **Query Workspace'in doğal parçası olan bir query copilot**.

**Ürünün 3 sütunu:**

| Sütun | Amaç |
|---|---|
| **Database Explorer** | Birden fazla bağlantı profili, provider-aware navigation, schema introspection, veri görüntüleme |
| **Query Workspace** | Çok sekmeli, syntax-highlighting, autocomplete, explain plan, query history |
| **AI Query Assistant** | Natural language → provider-aware query; query modify/explain/optimize; **otomatik execute yok** |

**Neden "MongoDB GUI" değil:**
- MongoDB, document database paradigmasına sahip; relational/key-value/search farklı. Common + specific yaklaşımı ile her paradigm UI'da korunur.
- Public release hedefi var; bu nedenle **plugin-extensible architecture** zorunlu.
- AI Query Assistant, AI-autonomous agent değildir — **read-mostly copilot**'tır.

**Hedef kullanıcı:** Tolga (kendi kullanım) → sonra public release (Windows, macOS, Linux, Android, iOS, opsiyonel web).

---

## 2. Architecture (Önerilen Genel Mimari)

F_AISUBCRIBE'in **3-katmanlı** `core / product / feature` yaklaşımı bu proje için de referans alınmalı, ama database workbench'in doğası gereği **domain layer** core'a entegre edilmeli. Aşağıda pragmatic clean architecture önerisi:

```
db_explorer_app
│
├── presentation/                # UI katmanı (Pages, Widgets, Riverpod providers)
│   ├── connections/             # Connection Manager UI
│   ├── explorer/                # Database Explorer (provider-aware tree)
│   ├── workspace/               # Query Workspace (editor + results)
│   ├── ai_assistant/            # AI Query Assistant UI
│   ├── shared/                  # Reusable widgets (responsive layout, dialogs)
│   └── adaptive/                # Desktop/Mobile breakpoint logic
│
├── domain/                      # Saf iş mantığı + abstraction
│   ├── database/                # DatabaseProvider sözleşmeleri
│   │   ├── connection.dart
│   │   ├── capability.dart
│   │   ├── schema.dart
│   │   ├── query.dart
│   │   └── result.dart
│   ├── ai/                      # AI abstraction
│   │   ├── ai_provider.dart
│   │   ├── query_intent.dart
│   │   └── ai_context.dart
│   └── entities/                # Value objects
│
├── infrastructure/              # Provider implementasyonları
│   ├── database_providers/
│   │   ├── mongodb/             # MongoDB provider (implementations + BSON codecs)
│   │   ├── postgres/            # (v2)
│   │   ├── redis/               # (v2)
│   │   └── elasticsearch/       # (v2)
│   ├── ai_providers/
│   │   ├── local_llamacpp.dart  # llama.cpp FFI binding
│   │   ├── ollama_remote.dart   # HTTP API (Ollama server)
│   │   └── openai_compatible.dart # Cloud
│   └── storage/                 # secure_storage + hive
│
├── core/                        # Cross-cutting
│   ├── theme/                   # Poppins + DeepPurple + ThemeExtensions
│   ├── responsive/              # ScreenUtil + adaptive helpers
│   ├── utils/                   # logger, isolation, error
│   └── constants/
│
└── product/                     # Bootstrap & wiring
    ├── app.dart
    ├── di/                      # Riverpod root providers
    ├── router/                  # GoRouter (adaptive)
    └── providers_registry/      # Built-in + 3rd-party provider discovery
```

**Neden F_AISUBCRIBE'in `core`/`product`/`feature` yapısı tam olarak kopyalanmadı:**
- `feature/<name>/data|domain|presentation` üçlüsü **her feature** için tekrarlanır; bizim senaryoda database provider'lar zaten "feature" değil, **altyapı abstraction'ı**. Bu nedenle `domain/database` ve `infrastructure/database_providers` ayrımı daha doğru.
- AI katmanı feature değil, **cross-cutting capability**. Bu nedenle `domain/ai` + `infrastructure/ai_providers`.
- Riverpod her katmanda presentation'da kalır; `core`'a sızmasına izin vermeyiz.

---

## 3. Database Abstraction (Provider Architecture)

### 3.1 Capability-Driven Model

Her database provider, bir **Capability Set** bildirir. UI, bu set'e göre kendini adapte eder:

```dart
// domain/database/capability.dart
enum DatabaseCapability {
  // Şema kavramları
  documents, collections, databases,         // document
  tables, schemas, columns, rows, relations,  // relational
  keys, hashes, lists, sets, streams,         // key-value
  indices, mappings, aggregations,            // search

  // Operasyonlar
  crud, aggregationPipeline, fullTextSearch, explain,
  transactions, changeStreams, storedProcedures,
  userDefinedFunctions, views, indexes,

  // Bağlantı
  tls, sshTunnel, replicaSet, sharding,
}

class DatabaseCapabilities {
  final Set<DatabaseCapability> supported;
  final Set<DatabaseCapability> experimental;
  DatabaseCapabilities({required this.supported, this.experimental = const {}});

  bool supports(DatabaseCapability c) =>
      supported.contains(c) || experimental.contains(c);
}
```

### 3.2 DatabaseProvider Abstract Class

```dart
abstract interface class DatabaseProvider {
  DatabaseKind get kind;                 // mongodb, postgres, redis, ...
  DatabaseCapabilities get capabilities;
  String get displayName;
  IconData get icon;

  Future<DatabaseConnection> connect(DatabaseConnectionConfig config);
  Future<void> disconnect(DatabaseConnection conn);
  Future<bool> ping(DatabaseConnection conn);

  Future<List<DatabaseNode>> listDatabases(DatabaseConnection conn);
  Future<List<SchemaNode>> listSchema(DatabaseConnection conn, DatabaseNode parent);
  Future<QueryResult> execute(DatabaseConnection conn, QueryRequest request);
  Future<void> cancel(DatabaseConnection conn, String executionId);
  Future<QueryPlan?> explain(DatabaseConnection conn, QueryRequest request);
  Future<List<CompletionItem>> complete(DatabaseConnection conn, CompletionContext ctx);
  Stream<QueryProgress> executeStream(DatabaseConnection conn, QueryRequest req);
}
```

### 3.3 Provider-Specific Modellerin Korunması

**MongoDB** için domain model:

```dart
class MongoDatabase implements DatabaseNode { final String name; }
class MongoCollection implements SchemaNode {
  final String name;
  final int count;
  final List<MongoIndex> indexes;
  final List<MongoField> fields;
}
class MongoDocument implements DataRow {
  final BsonDocument data;
  final ObjectId id;
}
class BsonValue {
  // Int32, Int64, Decimal128, ObjectId, DateTime, Binary, Regex ...
}
```

**PostgreSQL** için domain model:

```dart
class PgDatabase implements DatabaseNode { final String name; }
class PgSchema implements SchemaNode { final String name; }
class PgTable implements SchemaNode {
  final String name;
  final List<PgColumn> columns;
  final List<PgForeignKey> foreignKeys;
  final List<PgIndex> indexes;
}
class PgRow implements DataRow { final Map<String, dynamic> values; }
```

**Redis** için domain model:

```dart
class RedisDatabase implements DatabaseNode { final int dbIndex; }
class RedisKey implements DataRow {
  final String key;
  final RedisValueType type;
  final dynamic value;
}
class RedisValue { String, List, Hash, Set, ZSet, Stream }
```

> Bu modeller **zorla tek bir base interface'e sıkıştırılmaz**. `DatabaseNode` ve `SchemaNode` marker interface'leri sadece tree-view için polymorphic navigasyon sağlar; gerçek tip provider-spesifik kalır.

### 3.4 Provider Registry / Discovery

```dart
class DatabaseProviderRegistry {
  final Map<DatabaseKind, DatabaseProviderFactory> _factories = {};

  void register(DatabaseKind kind, DatabaseProviderFactory factory) =>
      _factories[kind] = factory;

  DatabaseProvider? create(DatabaseKind kind) =>
      _factories[kind]?.build();

  Iterable<DatabaseProvider> get all =>
      _factories.values.map((f) => f.build());
}

// Built-in registrations (product/providers_registry/builtin.dart):
registry.register(DatabaseKind.mongodb, MongoDbProviderFactory());
// v2:
// registry.register(DatabaseKind.postgres, PostgresProviderFactory());
// registry.register(DatabaseKind.redis, RedisProviderFactory());
```

**Yeni provider eklemek için:** Tek yapılması gereken `DatabaseProvider` interface'ini implemente eden bir sınıf yazmak + factory'sini register etmek. UI, AI, connection manager **hiçbir şekilde değişmez**. Bu, brief'in 25. maddesindeki "mevcut sistemi yeniden yazmayı gerektirmemeli" kuralını sağlar.

### 3.5 Common + Specific Capabilities Matrisi (vizyon)

| Capability | MongoDB | PostgreSQL | Redis | Elasticsearch |
|---|---|---|---|---|
| Documents/Rows | ✓ Documents | ✓ Rows | ✗ (Key/Value) | ✓ Documents |
| Aggregations | ✓ Pipeline | ✓ SQL agg | ✓ Streams | ✓ Aggregations |
| Indexes | ✓ | ✓ | ✗ (built-in) | ✓ |
| Full-text search | ✓ (text index) | ✓ (tsvector) | ✗ | ✓ (core) |
| Transactions | ✓ | ✓ | ✓ (MULTI/EXEC) | ✗ |
| Explain | ✓ executionStats | ✓ EXPLAIN | ✓ DEBUG | ✓ profile API |
| Stored Procedures | ✗ | ✓ functions | ✓ Lua scripts | ✗ |
| Relations | ✗ (manual $lookup) | ✓ FK | ✗ | ✗ |

UI navigation her provider için **farklılaşır** (brief madde 5):
- MongoDB → Collections / Documents / Indexes / Aggregation
- PostgreSQL → Schemas / Tables / Views / Functions / Relations
- Redis → Databases / Keys / Streams
- Elasticsearch → Indices / Mappings / Aliases

---

## 4. MongoDB Provider (İlk Provider — Detaylı)

### 4.1 Sürücü Seçimi

**Karar:** `mongo_dart_flutter` (resmi, MongoDB ekibi tarafından sürdürülüyor).

- **Source:** [pub.dev/packages/mongo_dart_flutter](https://pub.dev/packages/mongo_dart_flutter)
- **Repo:** [github.com/mongo-dart/mongo_dart](https://github.com/mongo-dart/mongo_dart)
- **Desteklenenler:** MongoDB 3.4+, replica set, sharded cluster, BSON, CRUD, aggregation, indexes, GridFS, change streams, transactions.
- **Cross-platform:** Android, iOS, macOS, Windows, Linux, Web (Dart VM + Flutter).
- **Neden `mongo_dart` değil de `mongo_dart_flutter`?** Flutter binding'leriyle birlikte gelir, mobile/desktop binary optimizasyonu yapılmıştır.

### 4.2 Bağlantı Yönetimi

**URI formatları:**
- Local: `mongodb://localhost:27017`
- Replica Set: `mongodb://host1:27017,host2:27017,host3:27017/?replicaSet=rs0`
- Atlas: `mongodb+srv://cluster0.xxxxx.mongodb.net`
- TLS: `mongodb://host:27017/?ssl=true&tlsCAFile=...`

**Authentication:**
- SCRAM-SHA-1, SCRAM-SHA-256 (default)
- X.509 (client certificates)
- LDAP, Kerberos (advanced — v2'de)

**Dynamic Connection Form:** Brief madde 7'deki gibi provider-aware form. MongoDB için alanlar:
- Connection Name (display)
- Connection Type (dropdown: MongoDB)
- URI (string)
- Authentication Database (optional)
- TLS/SSL (toggle)
- CA Certificate (file picker, optional)
- SSH Tunnel (v2)

### 4.3 Capabilities (MongoDB)

```dart
class MongoDbProvider implements DatabaseProvider {
  DatabaseCapabilities get capabilities => const DatabaseCapabilities(
    supported: {
      DatabaseCapability.documents,
      DatabaseCapability.collections,
      DatabaseCapability.databases,
      DatabaseCapability.crud,
      DatabaseCapability.aggregationPipeline,
      DatabaseCapability.fullTextSearch,
      DatabaseCapability.explain,
      DatabaseCapability.transactions,
      DatabaseCapability.changeStreams,
      DatabaseCapability.indexes,
      DatabaseCapability.tls,
      DatabaseCapability.replicaSet,
      DatabaseCapability.sharding,
      DatabaseCapability.views,
    },
  );
}
```

### 4.4 Doğrudan Bağlantı — Avantaj/Dezavantaj Analizi

**Avantajlar:**
- Self-hosted/local DB için **backend gerektirmez** → hızlı iterasyon
- Latency düşük (network hop yok)
- Tolga'nın "kendi kullanım" senaryosunda pratik

**Dezavantajlar / Riskler:**
- Public release'te **kullanıcı credential'ları client bundle'da saklanmak zorunda kalır** (rootlanamaz)
- Atlas IP allowlisting mobile client için uygulanamaz
- TLS private key / DB password istemcide görünür → secure storage zorunlu
- Bir DB'de 50k+ document → memory pressure (bunu aşmak için streaming + virtualization gerekli)

**Karar:**
- **MVP:** Self-hosted + local dev DB için direct connection kabul edilebilir. Credential'lar `flutter_secure_storage`'da (Keychain/KeyStore/DPAPI/libsecret).
- **Production/Public release:** "Direct connection" opsiyonu **varsayılan olarak kapalı**, "Local development only" olarak işaretlenmiş bir gelişmiş ayar olmalı; **asıl önerilen** ek bir remote "DB Proxy/Broker" servisidir. Bu public release'te ayrı bir repo olabilir.

### 4.5 BSON Tip Sistemi

MongoDB'nin güçlü tip sistemi UI'da korunmalı:
- ObjectId, String, Int32, Int64, Double, Decimal128, Boolean, Date, Timestamp, Binary, Regex, JS, Array, Embedded Document
- Bunlar için custom **BsonValueRenderer** widget'ı:
  - ObjectId → monospace kısa string + copy butonu
  - Date → ISO + relative time
  - Binary → base64 + size + type badge
  - Decimal128 → exact decimal
  - Embedded document → recursive tree-view

---

## 5. Future Database Providers (Vizyon)

### 5.1 PostgreSQL (v2)

- **Paket:** [`postgres`](https://pub.dev/packages/postgres) (community standard, pure Dart).
- **Connection pool, SSL, SCRAM auth, listen/notify, COPY, prepared statements.**
- **Schema:** `PgSchema → PgTable → PgColumn, PgIndex, PgForeignKey, PgCheck, PgView, PgFunction, PgTrigger`.
- **AI context:** schemalar, tablolar, kolon tipleri, FK ilişkileri, indexler.
- **Editor:** SQL, syntax highlighting için `flutter_code_editor` + `pg_sql` parser.

### 5.2 MySQL (v2)

- **Paket:** [`mysql1`](https://pub.dev/packages/mysql1) (pure Dart, fork of sqljocky).
- MySQL 5.7+/8.x, prepared statements, transactions.
- PostgreSQL ile ortak `RelationalProvider` base'i tasarlanabilir.

### 5.3 Redis (v2)

- **Paket:** [`redis`](https://pub.dev/packages/redis).
- Key-value primitive'ler: GET/SET/HSET/LPUSH/ZADD/STREAM ops.
- UI: monospaced key list + value viewer (string/hash/list/set/zset tiplerine göre değişen renderer).
- Query workspace: Redis command-line tarzı editor + history.

### 5.4 Elasticsearch / OpenSearch (v3)

- **Paket:** Resmi Dart client yok; REST API ile `dio` üzerinden erişim (JSON DSL).
- Search/Analytics UI: query DSL editor, aggregation visualizer.
- Mapping inspection, index templates, alias yönetimi.

### 5.5 SQLite (v3, Local)

- **Paket:** [`drift`](https://pub.dev/packages/drift) (Flutter-friendly, Dart-native SQL).
- Yerel `.sqlite` dosyalarını explore etme — özellikle **iOS/Android app sandbox'larındaki SQLite'lar için debugger aracı** olarak değerli.

### 5.6 Plugin / Marketplace (uzun vade)

Brief madde 29'daki plugin/provider marketplace fikri **gerçekçi** ama **v4+** konusu. Önce stable core API gerek. Üç katmanlı plugin modeli:
1. **Dart-native providers** (`DatabaseProvider` interface, build-time registry)
2. **Process providers** (subprocess olarak çalışan 3rd-party binary'ler — ileride)
3. **Remote providers** (broker üzerinden erişim)

---

## 6. Query Workspace

### 6.1 Layout (Desktop)

```
┌──────────────────────────────────────────────────────────────────┐
│ [Connections] │ [Explorer Tree]      │ [Workspace Tabs]          │
│               │                       │                           │
│ ▸ prod-mongo  │ ▸ admin               │ ┌─ Query 1 ─ Query 2 ─┐   │
│ ▸ dev-mongo   │   ▸ users             │ │                      │   │
│ ▸ local-redis │   ▸ orders            │ │ db.users.aggregate(  │   │
│   ...         │   ▸ products          │ │   ...                 │   │
│               │   ▸ analytics         │ │ )                     │   │
│               │ ▸ indexes             │ └──────────────────────┘   │
│               │                       │                           │
│               │                       │ ┌─ AI Assistant ────────┐   │
│               │                       │ │ "Generate failed SMS  │   │
│               │                       │ │  by operator for 7d"  │   │
│               │                       │ │ [Generate] [History]  │   │
│               │                       │ └───────────────────────┘   │
│               │                       │                           │
│               │                       │ ┌─ Results ─────────────┐   │
│               │                       │ │ ⏱ 1.2s · 1.4k docs    │   │
│               │                       │ │ ┌──────┬──────┬──────┐│   │
│               │                       │ │ │ _id  │ name │ stat ││   │
│               │                       │ │ ├──────┼──────┼──────┤│   │
│               │                       │ │ │ ... │ ...  │ ...  ││   │
│               │                       │ │ └──────┴──────┴──────┘│   │
│               │                       │ │ ◀ 1 2 3 ... 47 ▶     │   │
│               │                       │ └───────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

### 6.2 Editor Seçimi

**Birincil öneri:** [`flutter_code_editor`](https://pub.dev/packages/flutter_code_editor)

- Çoklu dil desteği (JavaScript/JSON for MongoDB, SQL for relational, custom for Redis)
- `CodeController` ile autocomplete hook'ları
- Code folding
- Real-time highlighting
- Active maintenance

**İkincil / lightweight fallback:** [`flutter_highlight`](https://pub.dev/packages/flutter_highlight)

- Sadece highlighting; metin editöre `TextEditingController` ile bağlanır
- Multi-language `highlight` paketini kullanır

**Editor Seçim Kararı:** Brief madde 11'deki tüm gereksinimler (syntax highlighting, autocomplete, code completion, history, multi-tab) için `flutter_code_editor` **tek paketle en kapsamlı çözüm**. `flutter_highlight` sadece basit read-only viewer'lar için (örn. snippet library).

### 6.3 Autocomplete Stratejisi

**Provider-aware**, **context-driven** autocomplete:
1. **Collection/Table names** → provider'ın `listSchema()`'sından cache'lenmiş liste
2. **Field/Column names** → aktif collection/table seçildiğinde introspection
3. **Functions** → provider'ın capability set'inden operatör listesi (`$match`, `$group`, `SELECT`, `JOIN`, `GET`, ...)
4. **Keywords** → sabit keyword listesi (`db`, `find`, `aggregate`, `SELECT`, `FROM`, ...)

**Performance:** Schema introspection → Hive cache (TTL 5 min). Autocomplete lookup → trie veya basit prefix search.

### 6.4 Multi-Tab, History, Saved Queries

- **Tabs:** `flutter_code_editor` `CodeController` array'i + `TabController`. `lib/feature/workspace/presentation/tabs/`.
- **History:** Tüm execute edilen sorgular `Hive` box'ta (encrypted box, sensitive data için flag).
- **Saved queries:** Kullanıcı tanımlı, `SavedQuery` entity (id, name, query, provider, tags, createdAt).
- **Snippets:** Yeniden kullanılabilir parçalar (örn. `find by date range`, `aggregate by operator`).

### 6.5 Execution Engine

```dart
abstract interface class QueryExecutor {
  Future<QueryResult> execute(QueryRequest req);
  Stream<QueryProgress> executeStream(QueryRequest req);
  Future<void> cancel(String executionId);
  Future<QueryPlan?> explain(QueryRequest req);
}

class QueryRequest {
  final String connectionId;
  final String query;
  final QueryLanguage language; // mongoShell, sql, redisCmd
  final Map<String, dynamic> params;  // parameterized values
  final Duration? timeout;
  final int? maxRows;
  final bool dryRun;
}
```

**Timeout/Cancellation:** `Future.timeout()` + provider tarafında native cancel. UI'da `Cancel` butonu + progress stream.

**Error handling:** Provider-specific error class → UI'da expandable error card (stack trace collapsible).

**Result pagination:**
- MongoDB: cursor-based (`skip` + `limit`, veya aggregation `$facet`)
- PostgreSQL/MySQL: `LIMIT/OFFSET` veya cursor-based
- Redis: streaming

---

## 7. AI Query Assistant (Mimari)

### 7.1 UX Akışı (Brief madde 19/20)

```
User Intent → AI Assistant Panel → Generated Query → Editor → User Review → Run
```

AI bir **chatbot değil**, **Query Workspace'in bir paneli**. Chat modu opsiyonel olarak sağda collapsible drawer olarak mevcut.

### 7.2 Sistem Akışı

```
┌──────────────────────────────────────────────────────────────┐
│ AI Query Assistant                                           │
│                                                              │
│  UserInput: "Son 7 gündeki başarısız SMS'leri operatöre      │
│              göre grupla."                                   │
│                            ↓                                 │
│  ContextBuilder: connected provider = mongodb                │
│                  active db = smsdb                           │
│                  active collection = SmsTransaction          │
│                  sampled docs (3) → field inference          │
│                  indexes                                     │
│                  current editor query (varsa)                │
│                            ↓                                 │
│  PromptComposer:                                             │
│    [System: provider-specific grammar + safety rules]        │
│    [Schema context]                                          │
│    [User intent + editor context]                            │
│                            ↓                                 │
│  AIProvider.complete(prompt) → streaming                    │
│                            ↓                                 │
│  QueryValidator: syntax + capability check                   │
│                            ↓                                 │
│  Display + "Insert into Editor" butonu                       │
└──────────────────────────────────────────────────────────────┘
```

### 7.3 Capability-Aware Query Generation

Brief madde 12 — AI provider'a göre query üretmeli:

```dart
abstract interface class AIQueryProvider {
  String get displayName;
  Future<AICompletion> complete(AIRequest req);
  Stream<AIToken> streamComplete(AIRequest req);
  Future<void> cancel(String requestId);
}

class AIRequest {
  final String userIntent;
  final AIContext context;
  final ProviderLanguageHint hint;       // mongoShell, sql, redisCmd
  final AITask task;                     // generate, modify, explain, optimize, fix
  final int? maxTokens;
  final double? temperature;
}
```

**Output validator:**
- MongoDB output → `mongo_dart` shell parser ile parse et, geçerli mi kontrol et
- SQL output → `sqlparser` veya custom parser ile geçerlilik kontrolü
- Geçersiz → fallback retry (max 1) veya "AI yanlış query üretti — manuel düzeltme gerekli" mesajı

### 7.4 Yetki Matrisi (Brief madde 13)

| Görev | AI yapabilir | Otomatik run? |
|---|---|---|
| Natural language → query | ✓ | ❌ |
| Query explanation | ✓ | ❌ |
| Query modification | ✓ | ❌ |
| Query optimization suggestion | ✓ | ❌ |
| Aggregation/SQL generation | ✓ | ❌ |
| Schema-aware query generation | ✓ | ❌ |
| **INSERT/UPDATE/DELETE** | ❌ | ❌ |
| **DROP/ALTER/CREATE INDEX** | ❌ | ❌ |
| **Schema migration** | ❌ | ❌ |
| Execute query (herhangi bir tür) | ❌ | ❌ |

**AI Safety Rules (system prompt'a gömülü):**
1. AI asla write/ddl komut üretmez.
2. AI ürettiği sorguyu kendi çalıştırmaz, sadece editöre ekler.
3. AI, user'ın credential/URI/connection string görmez.

---

## 8. Local AI (Detaylı Karşılaştırma)

### 8.1 Seçenekler ve Platform Desteği

| Seçenek | Flutter Binding | Cross-Platform | CPU | GPU | Model Formatı | Latency (warm) |
|---|---|---|---|---|---|---|
| **llama.cpp + ffigen** | Manuel (özel binding) | Win/macOS/Linux/Android/iOS | ✓ | ✓ (CUDA/Metal/Vulkan/OpenCL) | GGUF | <100ms |
| **`llm_llamacpp` paketi** | Hazır | Android/iOS/macOS/Win/Linux | ✓ | ✓ | GGUF | <200ms |
| **`llamadart` paketi** | Hazır | Cross (FFI) | ✓ | ✓ | GGUF | <200ms |
| **`llama_flutter` plugin** | Hazır | Cross (FFI) | ✓ | ✓ | GGUF | <200ms |
| **Ollama** | HTTP API (remote) | Server-only | ✓ | ✓ | GGUF/GGML | Network-bound |
| **ONNX Runtime + `onnxruntime` paketi** | Var | Cross (FFI) | ✓ | ✓ (DirectML/CUDA/EP) | ONNX | <200ms |
| **ExecuTorch** | Yeni, sınırlı | Mobile-first | ✓ | ✓ (XNNPACK/MPS) | PTE | <150ms |
| **Cloud (OpenAI-compatible)** | HTTP | Tümü | — | — | — | Network-bound |

### 8.2 Önerilen Yaklaşım: 3 Katmanlı AI Provider

```dart
abstract interface class AIQueryProvider { ... }

class LocalLlamaCppProvider implements AIQueryProvider {
  // llama_dart veya kendi FFI binding'i
  // GGUF model loading, streaming inference
  // Platform-specific binary management
}

class OllamaRemoteProvider implements AIQueryProvider {
  // HTTP API (default: http://localhost:11434)
  // /api/generate + /api/chat
  // Streaming via SSE
}

class OpenAICompatibleProvider implements AIQueryProvider {
  // OpenAI /v1/chat/completions
  // Local proxy'ler (LM Studio, vLLM) ile uyumlu
}

class DisabledProvider implements AIQueryProvider {
  // AI kapalı — kullanıcı manuel çalışır
}
```

**MVP için seçim:** `llamadart` veya `llm_llamacpp` paketi (hangisi daha stabil ise — research sırasında ikisi de aktif). İlk hedef: **Windows + macOS** desktop'ta 3-4B parametreli bir code-tuned model (örn. `Qwen2.5-Coder-3B-Instruct-Q4_K_M.gguf`).

### 8.3 Model Seçimi (Query/Code Generation İçin)

| Model | Size | RAM (Q4) | Türkçe | MongoDB/SQL bilgisi | Coding | Lisans |
|---|---|---|---|---|---|---|
| **Qwen2.5-Coder-3B-Instruct** | 3B | ~2.5GB | Orta | Yüksek | Çok iyi | Apache 2.0 |
| **Qwen2.5-Coder-7B-Instruct** | 7B | ~5GB | İyi | Yüksek | Mükemmel | Apache 2.0 |
| **DeepSeek-Coder-V2-Lite-Instruct** | 16B (MoE) | ~8GB | İyi | Çok yüksek | Mükemmel | DeepSeek |
| **CodeLlama-7B-Instruct** | 7B | ~5GB | Zayıf | Yüksek | Çok iyi | Llama Community |
| **Phi-3.5-mini-instruct** | 3.8B | ~2.7GB | İyi | Orta | İyi | MIT |
| **Llama-3.2-3B-Instruct** | 3B | ~2.4GB | İyi | Orta | Orta | Llama Community |

**Önerilen MVP:** `Qwen2.5-Coder-3B-Instruct-Q4_K_M.gguf` (~2GB, hem coding hem Türkçe yeterli, hızlı). 7B model opsiyonel olarak "high quality" toggle'ı ile sunulabilir.

### 8.4 GGUF Model Yönetimi

- Modeller app'in `assets/ai_models/` altında değil — **user-managed** (`Documents/models/` veya user-chosen path). Public release'te indirme yöneticisi:
  - HuggingFace URL'i gir → background fetch → progress → "use this model"
  - **Veya** in-app bundle: küçük bir 1B parametre model önceden yüklenmiş (sadece basic queries için).

### 8.5 Platform-Specific Performans

| Platform | CPU | GPU/NPU | Öneri |
|---|---|---|---|
| **Windows** | x86_64 | CUDA / DirectML / Vulkan | llama.cpp CUDA build → yüksek performans |
| **macOS Apple Silicon** | ARM64 | Metal | llama.cpp Metal backend → mükemmel |
| **Linux** | x86_64 | CUDA / Vulkan | llama.cpp CUDA build |
| **Android** | ARM64 | Adreno GPU / NPU | llama.cpp OpenCL + Q4 quant |
| **iOS** | ARM64 | Metal / Neural Engine | llama.cpp Metal |

---

## 9. Security (Kapsamlı)

### 9.1 Credential Storage

**Paket:** [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) (juliansteenbakker)

| Platform | Backend |
|---|---|
| Android | EncryptedSharedPreferences + AndroidKeyStore |
| iOS | Keychain (accessibility: `first_unlock_this_device`) |
| macOS | Keychain (Data Protection — 2026'da bilinen key-name bug var; workaround: prefix kontrolü) |
| Windows | DPAPI / Windows Credential Locker |
| Linux | libsecret / GNOME Keyring / KWallet |

**Kullanım:** Her connection için tek `connectionId` key'i altında JSON blob: `{ uri, authDb, tlsEnabled, sshEnabled }`. Password/URI **asla** düz metin olarak `shared_preferences`'a yazılmaz.

### 9.2 AI Privacy (Brief madde 18)

**AI'a ASLA gönderilmeyecek:**
- Connection URI
- Username/Password
- API Key, OAuth token
- TLS private key, SSH key
- Connection log'ları (IP, host)
- **Document values** (sadece schema/structure)

**AI'a gönderilebilir (configurable):**
- Collection/table adları
- Field/column adları + tipleri
- Sample **structure** (ilk 1-3 document'ın SADECE field path'leri — values placeholder'lar)
- Index listesi (definition, values değil)
- Provider capabilities
- User intent (natural language)
- Current editor query

**Gelecek (v2) — Sensitive Fields Masking:**
- `SensitiveFieldsConfig` per connection: `password`, `email`, `phone`, `token`, `ssn`, custom regex
- Sample document'lardan bu alanlar `<REDACTED>` ile değiştirilir

### 9.3 Local AI Güvenliği

- GGUF model dosyaları **user-managed path**'te (app sandbox dışında opsiyonel)
- **Local inference ASLA network'e çıkmaz** — kullanıcıya görünür indicator: "AI Mode: Local · Offline"
- Prompt içeriği diske yazılmaz (in-memory only)

### 9.4 Cloud AI Privacy

- AI modu "Cloud" seçildiğinde **explicit consent dialog**:
  ```
  ⚠ Cloud AI Mode
  Following metadata will be sent to <provider>:
   - Schema: 12 collections, 47 fields total
   - Field names: userId, status, createdAt, ...
   - Your intent text: "..."
  [Cancel] [Send]
  ```
- TLS 1.3 zorunlu (HTTP fall-through yok)
- Prompt/response loglanmaz; analytics'e gönderilmez

### 9.5 Logs / Crash Reports

- `logger` paketi (F_AISUBCRIBE zaten kullanıyor) + **local-only** default
- Opsiyonel Sentry/Crashlytics toggle (default off)
- Log'lar hiçbir zaman credential içermez; redaction katmanı zorunlu

### 9.6 Query History Encryption

- `Hive` encrypted box (`HiveCipher` + AES-GCM)
- Encryption key → `flutter_secure_storage`
- History TTL (default 30 gün, kullanıcı ayarlanabilir)

### 9.7 Sertifika Yönetimi

- Self-signed CA import (PEM/DER) → `tlsCAFile` MongoDB URI param'ı
- macOS Keychain access (system root CA'lar)
- Windows: `crypt32` üzerinden

---

## 10. Desktop/Mobile UX (Adaptive Strategy)

### 10.1 Design System — F_AISUBCRIBE'den Devralınan

| Token | Değer (F_AISUBCRIBE) | Bu projede kullanım |
|---|---|---|
| **Font** | Poppins (400, 500, 600, 700, 900) | Aynı — DB explorer için mükemmel okunabilirlik |
| **Primary** | Deep Purple `#6F31DA` | Aynı — tutarlılık için |
| **Surface tint** | `Colors.transparent` (AI-slop fix) | Aynı |
| **Card elevation** | 0 (flat) | Aynı |
| **Spacing scale** | 2/4/6/8/10/12/16/20/24/28/32/36/40/48/60/64/96 | Aynı (AppSpacings ThemeExtension) |
| **Radius scale** | 4/6/8/12/16/20/24/32/40 | Aynı (AppRadii ThemeExtension) |
| **Border radius** | Input/Card: 16, Button: 8 | Aynı |

**Fark (bu projeye özel eklenen):**
- **DataGrid palette** — monospace, zebra row, semantic colors:
  - `null` → grey300 fill
  - `bool` → amber100
  - `number` → blue 50
  - `string` → default
  - `date` → purple 50
  - `ObjectId` → green 50
- **Editor palette** (dark mode için):
  - Background: `#1E1E1E` (VSCode benzeri)
  - Keyword: `#C586C0` (purple)
  - String: `#CE9178` (orange)
  - Number: `#B5CEA8` (green)
  - Comment: `#6A9955` (green-grey)
  - Operator: `#D4D4D4`

### 10.2 Desktop Layout (≥900dp width)

```
┌──────────────────────────────────────────────────────────────────┐
│ TitleBar (custom) │ File / Edit / View / Connection / AI │  ⚙    │
├──────────┬─────────┴─────────┬────────────────────────────────────┤
│          │                   │  Workspace Tabs                    │
│ Sidebar  │   Explorer Tree   │ ┌────────────────────────────────┐ │
│ 260px    │   320px           │ │  Editor (CodeController)        │ │
│          │                   │ │                                  │ │
│ Conns    │   ▸ Connection    │ └────────────────────────────────┘ │
│ ▸ prod   │     ▸ admin       │ ┌────────────────────────────────┐ │
│ ▸ dev    │       ▸ users     │ │  AI Assistant Panel (drawer)     │ │
│ ▸ local  │       ▸ orders    │ │                                  │ │
│          │       ▸ analytics │ └────────────────────────────────┘ │
│          │                   │ ┌────────────────────────────────┐ │
│          │                   │ │  Results (virtualized table)    │ │
│          │                   │ └────────────────────────────────┘ │
└──────────┴───────────────────┴────────────────────────────────────┘
```

### 10.3 Mobile Layout (< 900dp width)

```
┌────────────────────────┐
│  ⋮  db_explorer  ⚙     │
├────────────────────────┤
│ ▾ Connection: prod-mongo│
├────────────────────────┤
│ [Tabs]  [Explorer] [Query] [AI]│
├────────────────────────┤
│                        │
│  Content per tab       │
│                        │
│                        │
└────────────────────────┘
```

Navigation: **adaptive NavigationRail/BottomNavigationBar** Material 3 switch.

### 10.4 Breakpoints (F_AISUBCRIBE ScreenUtil + custom)
- Mobile: < 600dp
- Tablet: 600–900dp
- Desktop: ≥ 900dp

### 10.5 Klavye / Kısayollar (Desktop)
- `Ctrl/Cmd+Enter` → Run query
- `Ctrl/Cmd+S` → Save query (saved queries)
- `Ctrl/Cmd+/` → Toggle comment
- `Ctrl/Cmd+Shift+P` → Command palette (connection quick switch)
- `Ctrl/Cmd+K` → AI assistant focus
- `Ctrl/Cmd+Shift+F` → Format query (basic)

---

## 11. Performance (Büyük Dataset Stratejisi)

### 11.1 Büyük Collection (1M+ documents)

- **Tam memory'ye yükleme YOK.**
- **Streaming cursor** + cursor-based pagination.
- **Virtualized table:** `flutter_data_grid` veya custom `ListView.builder` + `AutomaticKeepAliveClientMixin`. 50–100 satır window.
- **MongoDB cursor:**
  ```dart
  final cursor = collection.find(filter).skip(offset).limit(limit);
  // veya server-side cursor:
  final cursor = collection.aggregate(pipeline, batchSize: 100);
  await for (final doc in cursor.stream) { ... }
  ```

### 11.2 Büyük Document (BSON 16MB+ limit)

- Default projection: **sadece listede gösterilecek field'lar**.
- "View full document" → ayrı bir detail view, lazy-load ile fetch.
- Tree-view renderer → derinlik limit (default 5 levels), "show more" lazy expand.

### 11.3 Büyük Query Result

- `maxRows` default 1000; UI warning > 10k.
- Export butonu → CSV/JSON stream (provider tarafından).
- Lazy column resize, sticky headers.

### 11.4 Query Editor (Büyük Script)

- `flutter_code_editor` virtualized rendering.
- Document length > 50k karakter → warning + perf mode toggle (highlight off, fold off).
- Background parse isolate (compute()).

### 11.5 AI Inference (CPU/GPU)

- **Isolate** ile UI thread bloklamaz.
- llama.cpp kendi thread pool'unu yönetir; biz `compute()` veya platform thread.
- Streaming response → UI progressive render.
- Warm-up: app açılışta küçük bir "ping" prompt ile model yükle (ilk sorgu gecikmesini gizle).

### 11.6 Schema Introspection

- İlk yükleme → async + progress.
- Cache: `Hive` encrypted box, TTL 5 dakika (user-configurable).
- Background refresh (her 10 dakikada).

### 11.7 Compute / Workers

- `compute()` (Dart isolate) → CPU-bound parse, JSON serialization.
- Custom isolate pool (`IsolatePool` paketi) → heavy tasks.
- Provider-specific heavy ops (örn. MongoDB aggregation büyük data dönerse) → provider thread'inde.

---

## 12. Flutter Architecture (Folder Structure + State Management)

### 12.1 State Management Kararı

**Brief madde 31'de F_AISUBCRIBE yaklaşımı değerlendirilecek diyor. F_AISUBCRIBE `flutter_bloc` kullanıyor.**

**2026 değerlendirmesi:**
- **BLoC:** yapısal, testable, complex business logic için iyi, ama boilerplate yoğun.
- **Riverpod:** daha az boilerplate, async-first, type-safe, 2026'da yükselen trend.
- **GetX:** lightweight ama global state antipattern'leri.

**Karar: Riverpod 2.x** (`flutter_riverpod` + `riverpod_annotation` + `riverpod_generator`).

**Nedenleri:**
1. Database workbench = async + stream-heavy (query execution, results streaming, AI streaming). Riverpod `StreamProvider`/`FutureProvider`/`AsyncValue` native.
2. BLoC'tan daha az boilerplate, ama testing (`riverpod_test`) yeterli.
3. **F_AISUBCRIBE'in `flutter_bloc` mirası zorlamayalım** — bu yeni bir proje, fresh stack.
4. Provider registration pattern (DB providers, AI providers) için `@Riverpod(keepAlive: true)` native.

> **Not:** Brief madde 23'te "Pragmatic Clean Architecture" ve "over-engineering yok" diyor. Riverpod, Bloc'tan daha az ceremony ile aynı separation of concerns'ı sağlar.

### 12.2 Folder Structure (Final)

```
lib/
├── main.dart
│
├── core/
│   ├── theme/                   # UIColors, AppTextStyles, AppTheme, AppSpacings/AppRadii ThemeExtensions
│   ├── responsive/              # ScreenUtil wrapper, breakpoint helpers
│   ├── constants/               # app_constants.dart (F_AISUBCRIBE'den adapte)
│   ├── utils/                   # logger, isolate helpers, error types
│   └── widgets/                 # Reusable cross-cutting widgets
│
├── domain/
│   ├── database/
│   │   ├── database_provider.dart         # abstract interface
│   │   ├── capability.dart                # enum + capabilities set
│   │   ├── connection.dart                # connection state
│   │   ├── query.dart                     # QueryRequest, QueryResult
│   │   ├── schema.dart                    # SchemaNode marker
│   │   └── entities/                      # ConnectionProfile (value object)
│   ├── ai/
│   │   ├── ai_provider.dart
│   │   ├── ai_request.dart
│   │   ├── ai_context.dart
│   │   └── query_intent.dart
│   └── entities/
│
├── infrastructure/
│   ├── database_providers/
│   │   ├── mongodb/
│   │   │   ├── mongodb_provider.dart
│   │   │   ├── mongodb_connection.dart
│   │   │   ├── mongodb_schema.dart
│   │   │   ├── bson_codec.dart
│   │   │   └── cursor_stream.dart
│   │   ├── postgres/                      # (v2)
│   │   ├── redis/                         # (v2)
│   │   └── elasticsearch/                 # (v3)
│   ├── ai_providers/
│   │   ├── local_llamacpp.dart
│   │   ├── ollama_remote.dart
│   │   ├── openai_compatible.dart
│   │   └── disabled.dart
│   └── storage/
│       ├── secure_connection_store.dart   # flutter_secure_storage wrapper
│       ├── local_cache.dart               # Hive encrypted
│       └── settings.dart
│
├── presentation/
│   ├── connections/
│   │   ├── presentation/                  # Pages, Widgets
│   │   └── application/                   # Riverpod providers
│   ├── explorer/
│   │   ├── presentation/                  # TreeView, NodeWidgets
│   │   └── application/                   # ExplorerProvider
│   ├── workspace/
│   │   ├── presentation/
│   │   │   ├── tabs/
│   │   │   ├── editor/
│   │   │   ├── results/
│   │   │   └── explain/
│   │   └── application/
│   ├── ai_assistant/
│   │   ├── presentation/                  # Panel widget
│   │   └── application/                   # AIProvider controller
│   ├── shared/
│   │   ├── adaptive/                      # NavigationRail/BottomNav switch
│   │   ├── dialogs/
│   │   ├── data_grid/                     # Virtualized table
│   │   └── bson_renderers/                # BSON type widgets
│   └── home/
│
├── product/
│   ├── app.dart
│   ├── di/                                # Riverpod root providers
│   ├── router/                            # GoRouter (adaptive)
│   └── providers_registry.dart            # Built-in provider registration
│
└── gen/                                   # Generated assets (assets.gen.dart etc.)
```

### 12.3 Routing

**Öneri:** GoRouter (stateful shell route ile desktop'ta persistent sidebar).

Neden GoRouter:
- Adaptive layout routing (mobile drawer / desktop rail)
- Deep linking
- Community standard

---

## 13. Technology Stack (Final Öneri — Tablo)

### 13.1 Core Dependencies

| Paket | Versiyon (öneri) | Neden | Alternatif |
|---|---|---|---|
| `flutter_riverpod` | ^2.5+ | State management | `flutter_bloc` |
| `riverpod_annotation` + `riverpod_generator` | ^2.x | Type-safe providers | Manual providers |
| `get_it` | ^8.x | DI fallback (UI dışı singletons) | `injectable` |
| `go_router` | ^14.x | Adaptive routing | Custom Navigator |
| `flutter_screenutil` | ^5.9+ | Responsive (F_AISUBCRIBE standardı) | `media_query` |
| `equatable` | ^2.x | Value equality | `freezed` |

### 13.2 Database

| Paket | Versiyon (öneri) | Neden |
|---|---|---|
| `mongo_dart_flutter` | latest | Resmi MongoDB driver, cross-platform |
| `postgres` (v2) | ^3.x | Pure Dart PostgreSQL |
| `mysql1` (v2) | ^0.20+ | MySQL client |
| `redis` (v2) | ^4.x | Redis RESP3 client |

### 13.3 Code Editor

| Paket | Versiyon (öneri) | Neden |
|---|---|---|
| `flutter_code_editor` | ^0.3+ | Comprehensive code editor + autocomplete |
| `flutter_highlight` | ^0.7+ | Lightweight syntax viewer (read-only snippets) |
| `tree_view` | ^1.x | Hierarchical tree widget |

### 13.4 AI / Inference

| Paket | Versiyon (öneri) | Neden |
|---|---|---|
| `llamadart` veya `llm_llamacpp` | latest | llama.cpp FFI binding |
| `dio` | ^5.x | HTTP (Ollama + OpenAI API) |

### 13.5 Storage

| Paket | Versiyon (öneri) | Neden |
|---|---|---|
| `flutter_secure_storage` | ^9.x | Credential + encryption key |
| `hive_flutter` | ^1.x | Encrypted local DB |
| `shared_preferences` | ^2.x | Non-sensitive settings |

### 13.6 Utilities

| Paket | Versiyon (öneri) | Neden |
|---|---|---|
| `logger` | ^2.x | Logging (F_AISUBCRIBE standardı) |
| `rxdart` | ^0.28+ | Stream composition |
| `path_provider` | ^2.x | Models/user data paths |
| `file_picker` | ^8.x | TLS cert, model files |
| `intl` | ^0.19+ | Date/number formatting |
| `permission_handler` | ^11.x | Network/file access |

### 13.7 Dev Dependencies

| Paket | Versiyon (öneri) | Neden |
|---|---|---|
| `flutter_lints` | ^6.x | Standard lints |
| `custom_lint` + `riverpod_lint` | ^0.6+ / ^2.x | Provider rule enforcement |
| `build_runner` | ^2.4.x | Code gen (Hive + Riverpod) |
| `riverpod_generator` | ^2.x | Provider generation |
| `hive_generator` | ^2.x | Adapter generation |
| `mocktail` | ^1.x | Test mocking |
| `go_router_builder` | ^2.x | Type-safe routing |

### 13.8 Neden BLoC Değil, Riverpod?

Bu brief **yeni bir proje** için. F_AISUBCRIBE'in BLoC tercihi **orada bağlamda doğruydu** (büyük ekip, güçlü typing, 3rd-party lints ekibi). Burada:
- Tek geliştirici (Tolga) → boilerplate azaltma kritik
- Stream/async yoğun (query execution, AI streaming) → Riverpod `AsyncValue` native
- Provider registration pattern → `@Riverpod(keepAlive: true)` doğal

> **Brief madde 2'ye saygı:** "Mimari kararların uygun olmadığını düşünüyorsan körü körüne kopyalama" → BLoC yerine Riverpod bu nedenle bilinçli bir tercih.

---

## 14. MVP (İlk Sürümün Kesin Kapsamı)

### 14.1 Dahil

- ✅ MongoDB provider (mongo_dart_flutter)
  - Standalone, Replica Set, Atlas
  - SCRAM-SHA-256 auth
  - TLS optional
- ✅ Connection Manager
  - Add / Edit / Delete / Test connection
  - Multiple connections
  - Credentials → flutter_secure_storage
- ✅ Database Explorer
  - Databases → Collections → Indexes tree
  - Field inference from sample documents
- ✅ Document Viewer
  - Virtualized table
  - Tree-view for embedded docs
  - BSON type rendering
- ✅ Data Editor (manual only)
  - Insert / Update / Delete (user-driven, AI yok)
  - JSON input modal
- ✅ Query Workspace
  - Multi-tab editor (flutter_code_editor)
  - MongoDB shell syntax highlighting
  - Autocomplete (collections, fields, operators)
  - Execute + Cancel + Timeout
  - Explain plan viewer
  - Results table + pagination
  - Query history (encrypted Hive)
  - Saved queries
- ✅ AI Query Assistant
  - Local AI (llama.cpp, Qwen2.5-Coder-3B Q4)
  - Ollama remote (opsiyonel)
  - Cloud OpenAI-compatible (opsiyonel, explicit consent)
  - Generate / Explain / Modify / Optimize
  - NO write authority
  - Streaming response
- ✅ Desktop (Windows + macOS) + Mobile (Android + iOS) adaptive
- ✅ Theme: F_AISUBCRIBE design language (Poppins + DeepPurple + flat + ThemeExtensions)
- ✅ Settings: theme mode, AI mode, model path, history TTL, sensitive field masking config
- ✅ Logs (local-only)

### 14.2 Hariç (V2+)

- ❌ PostgreSQL / MySQL / Redis / Elasticsearch providers (V2)
- ❌ SSH Tunnel (V2)
- ❌ Aggregation visualizer (V2)
- ❌ Query performance analyzer (V2)
- ❌ Index advisor (V2)
- ❌ Schema visualization (V3)
- ❌ Export/Import CSV/JSON (V2)
- ❌ Plugin marketplace (V4+)
- ❌ Cloud sync (V3)
- ❌ Team collaboration (V4+)

### 14.3 Süre Tahmini (Tolga solo, hafta sonu ritmi)

| Faz | Hafta |
|---|---|
| Faz 0: Proje skeleton, theme, pubspec, GoRouter, Riverpod wiring | 1 |
| Faz 1: Domain layer (provider interface, capability, query) | 1 |
| Faz 2: Infrastructure — secure_storage, hive, settings | 1 |
| Faz 3: MongoDB provider + connection manager | 2 |
| Faz 4: Database Explorer (tree, schema introspection) | 2 |
| Faz 5: Document viewer + data editor | 2 |
| Faz 6: Query Workspace (editor + execution + results) | 3 |
| Faz 7: AI Assistant (local llama.cpp + context builder) | 3 |
| Faz 8: Desktop/Mobile adaptive polish | 1 |
| Faz 9: Testing + bug bash | 2 |
| **Toplam MVP** | **~18 hafta (4.5 ay)** |

---

## 15. Roadmap (MVP Sonrası)

### V2 (3-6 ay sonra)
- PostgreSQL provider
- MySQL provider
- Redis provider
- SSH Tunnel (mongo_dart_flutter sınırlaması varsa proxy üzerinden)
- Aggregation visualizer (MongoDB pipeline → tree)
- Index advisor
- Export/Import (CSV, JSON, NDJSON)
- Saved queries tags + folders
- AI query history
- AI debugging (failed query → "neden hata verdi?")
- Sensitive field masking

### V3 (6-12 ay sonra)
- Elasticsearch/OpenSearch provider
- Schema visualization (ER diagram for relational, schema graph for MongoDB)
- Database comparison (dev vs prod diff)
- Backup/restore utilities
- MCP integration (Claude/agent tools)
- Cloud sync (settings, saved queries)
- Drift/SQLite local provider
- Performance analyzer + slow query log
- macOS code signing + notarization
- Windows MSIX packaging

### V4 (12+ ay)
- Plugin/provider marketplace (dynamic provider loading)
- Team collaboration (shared queries)
- Database migration assistant (MongoDB → PostgreSQL)
- Multi-window desktop (multiple workspaces)
- Web build (WASM target)

---

## 16. Risks (Teknik Riskler ve Alternatifler)

### 16.1 Yüksek Risk

| Risk | Etki | Mitigation |
|---|---|---|
| **mongo_dart_flutter mobile TLS bug** | Bağlantı kopması | Pin to known-good version, custom FFI fallback (mongo-cxx via native plugin) |
| **llama.cpp FFI platform binary yönetimi** | Build hatası (iOS/Android) | `llamadart` paketi (hazır binary) tercih et, fallback manual build script |
| **AI context window aşımı** | Query generation hatası | Schema summary → field path tree, sample 1-3 doc values truncated |
| **AI write authority yanlışlıkla** | Veri kaybı (kullanıcı yanlışlıkla DROP çalıştırırsa) | Output validator: AI output'ta "DROP/DELETE/UPDATE/INSERT/ALTER" reject, user'a "AI write sorgu üretti, manuel çalıştırma" uyarısı |
| **Public release'te credential leak** | Security incident | Public release için **varsayılan remote broker** modu, direct connection "advanced/dev only" toggle |
| **Flutter desktop stability (Win/Linux)** | Crash, missing features | `master` channel takibi, `win32`/`gtk` backend sorunları için fallback |

### 16.2 Orta Risk

| Risk | Mitigation |
|---|---|
| Provider UI fragmentation | Common capability set → capability-driven UI; her provider kendi renderer'ını register eder |
| BSON 16MB doc UI render | Lazy load + depth limit + "load more" |
| MongoDB Atlas IP allowlisting | Direct connection'da bu kısıtlama var; kullanıcıya açıkça bildir |
| Schema caching stale | TTL + manual refresh button |
| Query history büyümesi | Hive box rotation (max 10k entry, FIFO) |
| AI model büyüklüğü (7B → 5GB) | Varsayılan 3B, "high quality" toggle user choice |
| Adaptive layout edge case (tablet portrait) | Manual breakpoint override, user preference save |

### 16.3 Düşük Risk

| Risk | Mitigation |
|---|---|
| Hive migration | Schema versioning built-in |
| Poppins font yükleme | Asset bundled, fallback to system sans-serif |
| ColorScheme deprecation (Material 3 evolution) | ThemeExtensions üzerinden soyutlama |
| Custom lint karmaşıklığı | F_AISUBCRIBE'in `ui_lints` paketinden ilham, minimal başla |

### 16.4 Alternatif Teknolojiler Değerlendirmesi

| Karar | Alternatif | Neden Alternatif Değil |
|---|---|---|
| Flutter | Electron / Tauri / React Native | Tolga Flutter ekosistemine yatırımlı, F_AISUBCRIBE Flutter |
| mongo_dart_flutter | Native subprocess (mongo shell) | Subprocess spawn ağır, native binary dağıtımı zor |
| llama.cpp | Ollama subprocess | Ollama server-side; mobile'da subprocess ağır; ayrıca Ollama Docker gerektirir |
| llama.cpp | ExecuTorch | ExecuTorch Flutter binding'i 2026'da immature |
| llama.cpp | ONNX Runtime | llama.cpp GGUF ecosystem daha mature, code-tuned modeller hazır |
| Riverpod | BLoC | Boilerplate, brief'in pragmatik olma isteği |
| Hive | Drift | Drift relational, bizim ihtiyacımız key-value (history, cache) |
| flutter_code_editor | Monaco/CodeMirror via WebView | Native perf, daha iyi UX, native keybinding |
| flutter_secure_storage | Custom AES | Platform-native crypto çok daha güvenli |
| GoRouter | AutoRoute | GoRouter daha mainstream |

---

## 17. Final Recommendation

> **Bu projeyi şu mimari + teknolojiler + provider modeli + AI yaklaşımıyla geliştirmeyi öneriyorum:**

### Mimari

- **Pragmatic Clean Architecture**: `presentation / domain / infrastructure / core / product`
- **Provider-based database abstraction** — `DatabaseProvider` interface + `DatabaseCapabilities` + `DatabaseProviderRegistry`
- **Capability-driven UI** — UI provider'ın yetenek setine göre adapte olur
- **Common + specific model preservation** — relational/document/key-value/search paradigmaları zorla tek base'e sıkıştırılmaz
- **AI = Query Copilot**, autonomous agent değil; Query Workspace'in doğal parçası

### Teknoloji Stack

| Katman | Tercih |
|---|---|
| Framework | Flutter 3.44+ (latest stable) |
| State Management | **Riverpod 2.x** (BLoC değil — yeni proje, fresh stack) |
| Routing | GoRouter |
| Responsive | flutter_screenutil + custom breakpoint |
| MongoDB Driver | **mongo_dart_flutter** (resmi) |
| Code Editor | **flutter_code_editor** |
| Local AI | **llama.cpp + llamadart/llm_llamacpp FFI** |
| Model (MVP) | **Qwen2.5-Coder-3B-Instruct-Q4_K_M** |
| Storage | **flutter_secure_storage** + Hive encrypted |
| Theme | **F_AISUBCRIBE design language** (Poppins + #6F31DA + flat + AppSpacings/AppRadii ThemeExtensions) |

### Provider Model

- İlk provider: **MongoDB** (standalone + replica set + Atlas)
- Registry-based: yeni provider = interface implementasyonu + factory register
- UI/AI/Workspace provider-aware ama MongoDB-spesifik hard-coded değil

### AI Yaklaşımı

- **3 katmanlı provider**: Local (llama.cpp) → Ollama remote → OpenAI-compatible cloud → Disabled
- Local AI öncelikli (privacy, offline)
- Schema context (no values), credential yok
- **NO write authority** — AI üretir, user çalıştırır
- Output validator: write/DDL komutları reject

### MVP Süresi

- ~18 hafta solo (hafta sonu ritmi)
- Faz 0 → 9 sıralı delivery
- Desktop-first (Windows + macOS), sonra mobile polish

### Brief'in 21 Kuralıyla Uyum

| Kural | Karar |
|---|---|
| 1. Önce araştır | ✅ Bu rapor |
| 2. Seçenekleri karşılaştır | ✅ Bölüm 8, 13, 16 |
| 3. Mimari öner | ✅ Bölüm 2, 3, 12 |
| 4. Onay olmadan implementation yok | ✅ Bu rapor onay bekliyor |
| 5. Güncel teknolojiler | ✅ 2026 kaynaklar |
| 6. MongoDB-first, hard-code değil | ✅ Bölüm 3, 4, 5 |
| 7. Paradigma farkları korunur | ✅ Bölüm 3.3 |
| 8. Common + specific | ✅ Bölüm 3.1, 3.2 |
| 9. AI autonomous değil | ✅ Bölüm 7.4 |
| 10. AI write authority yok | ✅ Bölüm 7.4 |
| 11. Auto-execute yok | ✅ Bölüm 7.2 |
| 12. AI Query Workspace'in parçası | ✅ Bölüm 6, 7 |
| 13. Local AI öncelikli | ✅ Bölüm 8 |
| 14. Credentials AI'a gönderilmez | ✅ Bölüm 9.2 |
| 15. F_AISUBCRIBE tasarım dili | ✅ Bölüm 10.1 |
| 16. Pragmatic Clean Arch | ✅ Bölüm 2 |
| 17. Over-engineering yok | ✅ Riverpod, BLoC değil; thin interface; sade abstractions |
| 18. Desktop/Mobile ayrı | ✅ Bölüm 10.2, 10.3 |
| 19. Performans ilk günden | ✅ Bölüm 11 |
| 20. MVP şişirme yok | ✅ Bölüm 14 |
| 21. Yeni provider mevcut sistemi değiştirmez | ✅ Bölüm 3.4, 5 |

---

## 📋 Onayın İçin Sorular

Bu raporu uygulamaya geçmeden önce aşağıdaki kararları netleştirmemi ister misin? Yoksa direkt Faz 0 (proje skeleton) implementation'ına geçelim mi?

1. **State management:** Riverpod önerisi onaylı mı, yoksa BLoC (F_AISUBCRIBE tutarlılığı) tercih edilir mi? // Block-Cubit istiyorum.
2. **Local AI model:** Qwen2.5-Coder-3B yeterli mi, yoksa 7B ile başlamayı tercih eder misin (RAM etkisi: 3B ~2.5GB, 7B ~5GB)? // 3b ile başla, mimari 7B'ye açık olsun.
3. **Provider sayısı (MVP):** Sadece MongoDB mi, yoksa MVP'de MongoDB + Redis (basit key-value) birlikte mi? //Sadece mongodb
4. **Public release takvimi:** MVP kendi kullanım için mi, yoksa Google Play Store + macOS App Store + Windows Store public release zaman planı var mı? // Önce kendi kullanımım + stabil MVP, public release mimari gereksinim olarak şimdiden düşünülmeli
5. **Routing:** GoRouter önerisi onaylı mı, yoksa F_AISUBCRIBE tarzı custom Navigator tercih edilir mi? // go_router

Bu soruların cevaplarına göre Faz 0 (pubspec.yaml, theme, folder skeleton, base abstractions) implementation'ına geçebilirim.

---

**Kaynaklar (research'te kullanılan):**
- [pub.dev/packages/mongo_dart_flutter](https://pub.dev/packages/mongo_dart_flutter) — Official MongoDB Dart driver
- [pub.dev/packages/flutter_code_editor](https://pub.dev/packages/flutter_code_editor) — Code editor
- [pub.dev/packages/flutter_highlight](https://pub.dev/packages/flutter_highlight) — Syntax highlighting
- [pub.dev/packages/flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) — Secure storage
- [pub.dev/packages/redis](https://pub.dev/packages/redis) — Redis client
- [pub.dev/packages/llm_llamacpp](https://pub.dev/packages/llm_llamacpp/versions/0.1.8) — llama.cpp FFI
- [llama.cpp GitHub](https://github.com/ggml-org/llama.cpp) — Inference C/C++
- [flutter.dev/blog/whats-new-in-flutter-3-44](https://flutter.dev/blog/whats-new-in-flutter-3-44) — Flutter 3.44 (May 2026)
- [fluttergems.dev/database-adapter](https://fluttergems.dev/database-adapter/) — Database adapters overview
- [dev.to — llamadart](https://dev.to/gde/why-i-built-llamadart-offline-local-llm-inference-for-dartflutter-38pf) — llamadart package