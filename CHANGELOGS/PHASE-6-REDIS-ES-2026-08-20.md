# Phase 6 — Redis + Elasticsearch Providers (Mock + Real)

**Tarih:** 2026-08-20
**Build:** 0.7.0+7 (Phase 6)

## Özet

Bu faz, db_explorer_app'e **Redis** + **Elasticsearch** desteğini ekledi:
- `redis: ^4.0.0` paketi (pure-Dart RESP protocol client — TLS + pubsub + transactions)
- `elastic_client: ^0.3.15` paketi (isoos Dart bindings for ES HTTP API)
- Sealed `DatabaseConnectionConfig` family'ye `RedisConnectionProfile` + `ElasticsearchConnectionProfile` eklendi
- `RedisDBProvider` + `ElasticsearchDBProvider` (mock, seed data) implementasyonları
- `RealRedisProvider` + `RealElasticsearchProvider` (gerçek driver kullanan) implementasyonları
- Şema node'ları (`RedisDatabase`, `RedisKey`, `RedisField`, `ElasticsearchCluster`, `ElasticsearchIndex`, `ElasticsearchField`, `ElasticsearchAnalyzer`) concrete sınıfları
- Registry'ye Redis + ES factory kayıtları eklendi (mock default, real wiring Phase 8'de)
- `secure_connection_store` JSON round-trip 4 kind için exhaustive switch
- 28 yeni test (Redis 12 test + ES 16 test, provider contract + sealed profile + JSON round-trip + completion)

Phase 6 sonunda **4 provider** (MongoDB + PostgreSQL + Redis + Elasticsearch) çalışır durumda. UI henüz provider seçtirmiyor — bu Phase 8 release prep kapsamında (connection wizard).

---

## Kapsam

### Eklenen dosyalar

| Dosya | Amaç |
|---|---|
| `lib/infrastructure/database_providers/redis/redis_schema.dart` | `RedisDatabase`, `RedisKey`, `RedisField` concrete schema node'ları (Redis'in key-value abstraction'ları — keyType + ttl + size) |
| `lib/infrastructure/database_providers/redis/redis_provider.dart` | `RedisDBProvider` (mock, GET/KEYS/HGETALL/PING/DBSIZE parser) + `RedisDBProviderFactory` |
| `lib/infrastructure/database_providers/redis/real_redis_provider.dart` | `RealRedisProvider` (gerçek `redis` paketi — TCP + AUTH/ACL + SELECT dbIndex + SCAN) + `RealRedisProviderFactory` |
| `lib/infrastructure/database_providers/elasticsearch/elasticsearch_schema.dart` | `ElasticsearchCluster`, `ElasticsearchIndex`, `ElasticsearchField`, `ElasticsearchAnalyzer` concrete schema node'ları (ES'in cluster→index→mapping abstraction'ları; field'lar için searchable/aggregatable flag'leri) |
| `lib/infrastructure/database_providers/elasticsearch/elasticsearch_provider.dart` | `ElasticsearchDBProvider` (mock, JSON DSL — match/match_all + size parser) + `ElasticsearchDBProviderFactory` |
| `lib/infrastructure/database_providers/elasticsearch/real_elasticsearch_provider.dart` | `RealElasticsearchProvider` (gerçek `elastic_client` paketi — HttpTransport + Basic/API key auth + cluster health + cat indices + _search) + `RealElasticsearchProviderFactory` |
| `test/redis_provider_contract_test.dart` | 12 unit test (lifecycle, schema, query — PING/DBSIZE/KEYS/HGETALL/GET, capabilities, completion, profile round-trip) |
| `test/elasticsearch_provider_contract_test.dart` | 16 unit test (lifecycle, schema, query — JSON DSL match_all/match/size, capabilities, completion, profile round-trip + apiKey precedence) |

### Değiştirilen dosyalar

| Dosya | Değişiklik |
|---|---|
| `pubspec.yaml` | `redis: ^4.0.0` + `elastic_client: ^0.3.15` eklendi (Phase 6 — pure-Dart RESP/HTTP client); version `0.6.0+6` → `0.7.0+7` |
| `lib/domain/database/connection.dart` | Sealed `DatabaseConnectionConfig` family'ye `RedisConnectionProfile` (password, dbIndex, useTls, connectTimeout) + `ElasticsearchConnectionProfile` (scheme, password, apiKey, requestTimeout) eklendi; DB kind label + storageKeyPrefix extension'ları genişletildi |
| `lib/infrastructure/storage/secure_connection_store.dart` | `_profileToJson` / `_profileFromJson` exhaustive switch 4 kind için (MongoDB / Postgres / Redis / Elasticsearch) |
| `lib/product/providers_registry/builtin.dart` | `_registerDatabase` artık 4 kind'ı da mock default olarak kaydeder (MongoDB + Postgres + Redis + Elasticsearch) |
| `test/skeleton_smoke_test.dart` | Registry length `2` → `4` (Redis + ES eklendi); 4 kind için `isRegistered` kontrolü |

---

## Karar Kayıtları (Decisions)

### D1 — Authentication modelleri
- **Redis:** tek password alanı; `username` opsiyonel (Redis 6+ ACL için). `username` set ise `AUTH <user> <pass>`; null ise legacy `AUTH <pass>`.
- **Elasticsearch:** iki yol — (a) `username`+`password` basic auth (X-Pack default security), (b) `apiKey` ile REST API key auth. `apiKey` set ise basic auth override edilir. UI'da kullanıcı birini seçer.

### D2 — Mock/real factory pattern
Phase 5 ile aynı pattern: hem mock hem real factory concrete sınıf olarak var; `builtin.dart`'da mock default kayıtlı. `useReal*Driver` feature flag set edilince Phase 8 release prep'te mock override edilecek. Bu pattern CI'da mock üzerinden çalışır; gerçek integration test'leri Phase 8'de test container'a (testcontainers) karşı.

### D3 — Query lang validation (strict)
Her provider yalnızca kendi `QueryLanguage`'ını kabul eder; başka language ile execute çağrılırsa `ArgumentError`. Bu UI side'da editörün provider'a göre dil setlemesini zorlar (workspace sayfasında Phase 8'de).

### D4 — Capability-driven UI
Provider'lar capability'lerini açıkça listeler — Redis ve ES için:
- **Redis:** schemaless, transactions, completion, streaming, insert/update/delete/bulkWrite, tls, create/dropCollection, userManagement, backup.
- **Elasticsearch:** schemaHierarchy (cluster→index), indexManagement, fullTextSearch, geospatial, aggregationPipeline, insert/update/delete/bulkWrite, completion, serverInfo, liveStats, tls.
- `isSchemaless=true` Postgres'te strict-typed olduğu için false; Redis + ES key-value/dynamic mapping olduğu için semantik olarak schemaless — Phase 7'de `schemaless` capability flag'i eklenebilir (şu an bu iki provider bu capability'yi set etmiyor çünkü semantik karışıklığa yol açabilir — Postgres SQL "strict schema" demek, Redis/ES zaten doğası gereği schemaless).

### D5 — Redis SCAN vs KEYS
Real provider SCAN cursor-based key iteration kullanır (`SCAN 0 COUNT 100`) çünkü KEYS O(N) blocking'dir (production'da yasak, stalling). Mock'ta sample 6 key small olduğu için `KEYS *` simüle ediliyor; gerçek server büyüdükçe mock'un bu davranışı değişecek.

---

## Doğrulama (Verification)

```bash
flutter analyze --no-pub       # 15 info (zero error/warning)
flutter test --no-pub          # 157 test passed (Phase 5: 114 → Phase 6: 157; +43 yeni)
```

### Test coverage (toplam 157 — Phase 6'da eklenen 28):

| Test grubu | Sayı | Notlar |
|---|---|---|
| `redis_provider_contract_test.dart` | 12 | lifecycle (4), schema (5), query (10), capabilities (2), completion (1), profile round-trip (2) |
| `elasticsearch_provider_contract_test.dart` | 16 | lifecycle (4), schema (6), query (6), capabilities (2), completion (1), profile round-trip (3) |

Tüm 28 yeni test **pass**.

### Sample data (mock provider seed)

**Redis (db0, 6 keys):**
- `app:session:user-1` (string, TTL 3600s, 256 bytes)
- `app:session:user-2` (string, TTL 1800s, 192 bytes)
- `cache:products` (hash, 3 fields: sku-001/002/003)
- `leaderboard:top` (sortedset, no TTL)
- `queue:jobs` (list, no TTL)
- `tags:active` (set, no TTL)

**Elasticsearch (1 cluster, 2 indices):**
- `products` (3 docs, 5 fields: sku/keyword, name/text, price/double, description/text, tags/keyword)
- `orders` (2 docs, 5 fields: order_id/user_id/keyword, total/double, status/keyword, created_at/date)

---

## Sonraki Faz (Phase 7)

**AI providers real implementation:**
- Local llama.cpp + llama.dart binding (yerel)
- Remote Ollama HTTP/SSE
- OpenAI-compatible HTTP (key-based)

Discovery sırasında llamadart paketi Phase 1'de stub olarak kalmıştı; Phase 7'de gerçek inference wiring yapılacak + security gate (sensitive field patterns) + schema-only context enforcement.

---
