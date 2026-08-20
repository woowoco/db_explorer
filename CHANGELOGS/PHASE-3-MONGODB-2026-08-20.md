# Phase 3 — Real MongoDB Driver (2026-08-20)

**Status:** ✅ Tamamlandı
**Build:** v0.4.0+4
**Test:** 70/70 passed (59 Phase 1+2 + 11 Phase 3 RealMongoDBProvider)
**Analyze:** zero issues

## Scope

Phase 1'deki in-memory `MongoDBProvider` mock'u production-ready `RealMongoDBProvider` ile tamamlandı. `mongo_dart 0.10.9` (pure-Dart) driver ile gerçek TCP bağlantısı, SCRAM auth, schema discovery, query execution ve explain plan.

1. **RealMongoDBProvider**: `Db(uri).open(secure: ssl)` ile TLS, `Db.authenticate(user, pass, authDb:)` ile SCRAM auth, `Db.serverStatus()` + `runCommand({hello: 1})` ile handshake ölçümü
2. **URI builder**: `MongoConnectionProfile` → `mongodb://user:pass@host:port/db?replicaSet=...&directConnection=true&ssl=true`
3. **Schema discovery**: `Db.listDatabases()` + `getCollectionNames()` + sample-doc field introspection + `coll.count()`
4. **Query execution**: `db.<coll>.find({filter})` (Stream), `findOne` (Future), `count` (Future<int>), `aggregate` (cursor.firstBatch)
5. **Explain**: `Db.runCommand({'explain': {find: filter}, verbosity: 'queryPlanner'})`
6. **Completion**: collection names + MongoDB method/operator keywords (real collection lookup)
7. **Multi-database handle cache**: URI'da database yoksa veya farklı database'e geçilirse yeni `Db` açılır (`_ensureDatabaseHandle`)

## Kararlar

| Konu | Karar | Kaynak |
|---|---|---|
| Driver | `mongo_dart: ^0.10.8` (resolved 0.10.9) | Pure-Dart, Flutter uyumlu; mongo_dart_flutter pub.dev'de yok |
| Mock ↔ Real coexistence | İki ayrı factory (Mock default, Real Phase 8 wiring) | Registry `Map<DatabaseKind, ...>` duplicate kabul etmiyor; real kayıt feature flag'le |
| Connect timeout | URI `serverSelectionTimeoutMS` query param (Phase 4) | mongo_dart API'sinde Db ctor timeout yok; URI standardı |
| TLS | `Db.open(secure: true)` + URI `ssl=true` | mongo_dart API |
| Auth | `Db.authenticate(user, pass, authDb: 'admin')` (default) | mongo_dart default scheme = SCRAM-SHA-256 |
| Mongo shell parser | Private `db.<coll>.<op>(args)` regex + quick JSON parser | Phase 4'te full AST parser; Phase 3 yeterli |
| Multi-DB handle | `_handles: Map<key, Db>` cache, `_ensureDatabaseHandle` | Bağlantı başına tek Db; cache TTL Phase 4 |
| Error handling | `ErrorConnection(message, code, cause, isRetryable=true)` | Phase 1 sealed state extension |
| Phase 1 mock | Korundu (default factory) — test/UI geliştirme için | Public release Phase 8'de real binding wiring |

## Değişen / Eklenen Dosyalar (5 dosya)

### Real Provider
- `lib/infrastructure/database_providers/mongodb/real_mongodb_provider.dart` (yeni, ~520 satır) — `RealMongoDBProvider` + `RealMongoDBProviderFactory`; URI builder, parser, JSON parser, BSON type mapping
- `lib/infrastructure/database_providers/mongodb/real_mongodb_provider.dart` içinde `_ParsedCommand` private + `_ParsedCommand` test helper

### Tests
- `test/real_mongodb_provider_test.dart` (yeni, 11 test) — identity, capabilities, factory, state guards (no network)

### Bootstrap / Wiring (dokümantasyon)
- `lib/product/providers_registry/builtin.dart` — Real provider için wiring notu eklendi; mock default kalır
- `pubspec.yaml` — `mongo_dart: ^0.10.8` dependency eklendi (Phase 3.1)
- `pubspec.lock` — resolved transitives (sasl_scram 0.1.2, saslprep 1.0.3, unorm_dart 0.3.2, vy_string_utils 0.4.7)

### Cleanup
- `lib/infrastructure/storage/local_cache.dart` — `const StorageFailure(...)` (lint fix, Phase 2 carryover)

## API Uyumsuzlukları (tiedler ve çözümler)

| mongo_dart API | Kullanılan | Notlar |
|---|---|---|
| `Db.create(uri, ...)` | ❌ | URI'da timeout yok; doğrudan `Db(uri)` |
| `Db(uriString).open({secure, tlsCAFile, ...})` | ✅ | TLS için `secure: config.ssl` |
| `Db.authenticate(user, pass, {authDb})` | ✅ | Named `authDb` (positional `authSource` değil) |
| `Db.listDatabases()` → `Future<List<String>>` | ✅ | Doc'ta List<Map> yazıyor ama gerçekte sadece isimler (v0.10.9) |
| `Db.getCollectionNames()` → `Future<List<String?>>` | ✅ | Optional; `.whereType<String>()` ile filtrele |
| `DbCollection.find(filter)` → `Stream<Map<String, dynamic>>` | ✅ | Limit/skip manuel |
| `DbCollection.findOne(filter)` → `Future<Map?>` | ✅ | Null check gerekli |
| `DbCollection.count(filter)` → `Future<int>` | ✅ | Single int result (v0.10.9'da) |
| `DbCollection.aggregate(pipeline)` → `Future<Map>` | ✅ | `{cursor: {firstBatch: [docs...]}}` shape |
| `Db.runCommand({'hello': 1})` | ✅ | Replica set detection |
| `Db.serverStatus()` | ✅ | Version + uptime |
| `Db.pingCommand()` | ✅ | `ping()` implementasyonu |

## Public Surface

```dart
// Production binding (Phase 8'de AppBootstrap'a eklenecek)
class RealMongoDBProviderFactory implements DatabaseProviderFactory {
  const RealMongoDBProviderFactory();
  @override RealMongoDBProvider create();
  @override DatabaseKind get kind => DatabaseKind.mongodb;
}

// Provider implementasyonu
class RealMongoDBProvider implements DatabaseProvider {
  RealMongoDBProvider();
  // connect / disconnect / ping — gerçek TCP
  // listDatabases / listCollections — gerçek API
  // execute — find / findOne / count / aggregate (mongo shell subset)
  // explain — runCommand({explain: ..., verbosity: queryPlanner})
  // complete — collection names + keyword set
}
```

## Verification

- ✅ `flutter analyze` — No issues found!
- ✅ `flutter test` — 70/70 passed (mock 45 + storage 14 + real 11)
- ✅ Tüm Phase 1 + Phase 2 contract test'leri yeşil (regression yok)
- ✅ `mongo_dart 0.10.9` + transitives (`sasl_scram`, `saslprep`, `unorm_dart`) resolve oldu
- ✅ Network bağlantısı olmadan state guard'ları doğrulandı (disconnected → StateError, wrong language → ArgumentError, ping → false, complete → empty)

## Test Dağılımı (Phase 3 eklenen)

| Test | Davranış |
|---|---|
| id/kind | RealMongoDBProvider.id='mongodb', kind=mongodb |
| capabilities | hasSchemaHierarchy, isSchemaless, hasAggregationPipeline, hasTransactions, hasExplainPlan, hasInsert, tlsSupport |
| factory.kind | DatabaseKind.mongodb |
| factory.create() | iki ayrı instance |
| execute (no conn) | StateError |
| listDatabases (no conn) | StateError |
| listCollections (no conn) | StateError |
| explain (no conn) | StateError |
| ping (no conn) | false |
| complete (no conn) | empty |
| execute (wrong lang) | ArgumentError |

## Mock vs Real — Geçiş Stratejisi

```
Phase 3 (şu an):
  Mock: registered, default factory
  Real: yazıldı + tested (no-network), factory import edilebilir ama kayıtlı değil

Phase 8 (release prep):
  RealMongoDBProviderFactory bootstrap'ta mock'un yerini alır
  Feature flag: settings.useRealMongoDriver (default false → mock)
  CI'da real provider integration test (gerçek MongoDB container ile)
```

## Sonraki Faz

**Phase 4 — Workspace (Query Editor + Results Grid)**:
- `flutter_code_editor` + `flutter_highlight` syntax highlighting
- Code editor Cubit (text, language, dirty flag, history navigation)
- Results data grid (column types, virtual scroll, copy-to-clipboard)
- Mock data set için Phase 3 mock provider yeterli

**Plan: CHANGELOGS/PHASE-4-WORKSPACE-2026-08-20.md**