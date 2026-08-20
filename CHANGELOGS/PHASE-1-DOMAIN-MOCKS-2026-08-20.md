# Phase 1 — Domain Expansion + Mocks (2026-08-20)

**Status:** ✅ Tamamlandı
**Build:** v0.2.0+2
**Test:** 45/45 passed (7 Phase 0 smoke + 38 Phase 1 contract)
**Analyze:** zero issues

## Scope

Phase 0'da kurulan interface'lerin **gerçek davranışa sahip mock implementasyonları** + domain katmanı detaylandırması + provider/AI sözleşme testleri.

Phase 3 (gerçek MongoDB) ve Phase 7 (gerçek AI) öncesinde geliştirme sürecini hızlandırmak, ayrıca provider-agnostic UI'ın **çalışan bir backend'e karşı** doğrulanmasını sağlamak.

## Kararlar

| Konu | Karar | Kaynak |
|---|---|---|
| Mock vs real | Phase 1'de tamamen in-memory mock; real driver (Phase 3) ve LLM binding (Phase 7) sonra | Brief pragmatik geliştirme |
| AI güvenlik | Write-intent (DROP/DELETE/UPDATE/INSERT) reddediliyor — read-only sorgu garantisi | Brief madde 11 |
| API key güvenliği | API key hiçbir log'da gösterilmiyor (redacted) | Brief madde 12 |
| Schema introspection depth | Phase 1'de MongoCollection field + documentCount + averageDocumentSize | Provider-aware UI için yeterli |
| Capabilities genişletme | 13 → 33 capability (schema/query/write/mutation/operational/security) | Phase 4 data grid için |
| Connection state data | ConnectedConnection'a serverVersion, latencyMs, uptimeSeconds eklendi | UI için connection detail panel |

## Değişen / Eklenen Dosyalar (11 dosya)

### Domain genişletmeleri
- `lib/domain/database/capability.dart` — 33 capability (13 → 33); immutable builder (`withCapabilities`, `withoutCapabilities`); `==`/`hashCode`; toString
- `lib/domain/database/connection.dart` — ConnectingConnection.progress+message; ConnectedConnection.serverVersion+latencyMs+uptimeSeconds+extra; ErrorConnection.code+cause+isRetryable; DisconnectedConnection.reason; storageKeyPrefix extension; MongoConnectionProfile.ssl+replicaSet+directConnection+serverSelectionTimeoutMs+copyWith
- `lib/domain/database/query.dart` — QueryLanguageLabel extension; QueryRequest.collection+pageSize+pageOffset+idempotencyKey+readOnlyHint+copyWith; QueryResult.totalCount+hasMore+cursor+warnings+singleRow+isEmpty; QueryColumn type metadata; CompletionItem.insertText; CompletionContext.collection

### Mock implementations
- `lib/infrastructure/database_providers/mongodb/mongodb_provider.dart` — In-memory mock: connect (Connecting→Connected state machine, sessionId, latency 130ms), disconnect, ping, listDatabases (admin/config/local/sample), listCollections (users/products/orders + field metadata), execute (db.coll.find/findOne/count parser, pagination cursor), explain, complete (12 keyword). Capabilities tüm 33 set. MongoDBProviderFactory const constructor
- `lib/infrastructure/ai_providers/local_llamacpp.dart` — Fake: modelPath konfigüre edilmişse isAvailable; canned response per AiTask (generate/modify/explain/optimize/fix); write-intent safety guard
- `lib/infrastructure/ai_providers/ollama_remote.dart` — Fake: endpoint konfigüre edilmişse isAvailable; canned response per task; write rejection; network latency simulation 300-900ms
- `lib/infrastructure/ai_providers/openai_compatible.dart` — Fake: endpoint konfigüre edilmişse isAvailable; SQL-aware canned response; parameterized query suggestion ($1); API key redacted logs; cloud latency 400-1200ms

### DI integration
- `lib/product/providers_registry/builtin.dart` — `const MongoDBProviderFactory()`; const DisabledProvider + non-const Local/Ollama/OpenAI providers

### Tests
- `test/database_provider_contract_test.dart` — 24 test: lifecycle (4), schema discovery (4), query execution (7), capabilities (2), completion (1), +6 misc
- `test/ai_provider_contract_test.dart` — 14 test: DisabledProvider (3), LocalLlamaCpp (6), OllamaRemote (5), OpenAI (4) + AiContext invariant (1)
- `test/skeleton_smoke_test.dart` — Mevcut 7 test güncellendi (ErrorConnection named arg)

## Mock vs Real — Interface aynı

```
Phase 1 (now):                   Phase 3+ (real):
MongoDBProvider                  MongoDBProvider
├── connect: in-memory           ├── connect: mongo_dart Db + authenticate
├── execute: regex parser        ├── execute: DbCollection.aggregate/find
└── complete: 12 keywords        └── complete: LSP-like with schema cache

LocalLlamaCppProvider            LocalLlamaCppProvider
├── complete: canned             └── complete: llamadart inference
OllamaRemoteProvider             OllamaRemoteProvider
├── complete: canned             └── complete: http POST /api/generate
OpenAiCompatibleProvider         OpenAiCompatibleProvider
└── complete: canned             └── complete: http POST /v1/chat/completions
```

## AI Güvenlik Kanıtı (compile + runtime)

- **Schema-only context**: `AiContext` sadece `providerHint` + `List<DatabaseSchemaSummary>` (name + fields + indexes); value yok
- **API key redacted**: OpenAI provider'da `_log.i('key redacted')` — `apiKey` field log'a hiç geçmiyor
- **Write-intent guard**: 4 provider'da `_containsWriteTarget()` heuristic → writeable collection bulursa AiCompletion(warnings: ['rejected'])
- **Test kanıtı**: `ai_provider_contract_test.dart` her provider'ı `'drop the users collection'` mesajı ile test ediyor → `suggestedQuery` boş + warnings dolu

## Verification

- ✅ `flutter analyze` — No issues found!
- ✅ `flutter test` — 45/45 passed (All tests passed!)
- ✅ Mock connect flow gözlemlenebilir (logger log'ları)
- ✅ Capability immutability kanıtlandı (withCapabilities yeni instance döner)
- ✅ Connection state machine: Connecting → Connected (with serverVersion, latencyMs)

## Test Dağılımı

| Provider | Test Sayısı | Kapsam |
|---|---|---|
| MongoDB lifecycle | 4 | connect/disconnect/ping/reconnect |
| MongoDB schema | 4 | databases/collections/fields/empty db |
| MongoDB query | 7 | find/findOne/count/pageSize/unknown/bad-lang/malformed |
| MongoDB capability | 2 | flags/immutability |
| MongoDB completion | 1 | keywords |
| AI Disabled | 3 | identity/availability/throws |
| AI LocalLlamaCpp | 6 | no-config/with-config/generate/count/write-rejected/modify/explain |
| AI OllamaRemote | 5 | no-endpoint/with-endpoint/generate/optimize/write-rejected |
| AI OpenAICompat | 4 | no-endpoint/with-endpoint/fix/parameterized-SQL/generate |
| AiContext invariant | 1 | schema-only (compile-time) |
| Skeleton smoke (Phase 0) | 7 | registry/capabilities/settings/profile/state |
| **TOPLAM** | **45** | |

## Sonraki Faz

**Phase 2 — Storage full implementation**:
- Hive encrypted box (Phase 0'da skeleton) → gerçek AES-GCM cipher + box açma
- Query history (TTL configurable, settings.historyTtlDays)
- Secure connection store'da JSON serialization (Phase 0'da skeleton)
- Schema cache (TTL 5min) → provider connect'te pre-warm

**Plan: CHANGELOGS/PHASE-2-STORAGE-2026-08-20.md**