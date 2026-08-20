# Phase 2 — Storage Full Implementation (2026-08-20)

**Status:** ✅ Tamamlandı
**Build:** v0.3.0+3
**Test:** 59/59 passed (45 Phase 1 + 14 Phase 2 storage)
**Analyze:** zero issues

## Scope

Phase 0'da skeleton olarak bırakılan storage katmanı (SecureConnectionStore, LocalCache, AppSettings) **gerçek implementasyona** kavuştu:

1. **SecureConnectionStore**: JSON serialization tüm MongoConnectionProfile alanları (Phase 1'de eklenen ssl, replicaSet, directConnection, serverSelectionTimeoutMs dahil); SharedPreferences index (`dbx_conn_index`) ile listIds(); corrupt JSON → StorageFailure
2. **LocalCache**: AES-GCM encrypted Hive box (schema_cache, query_history); QueryHistoryEntry model; prune by TTL
3. **SchemaService**: cache + provider wrapper (cache miss → provider → cache put)
4. **DatabaseModule DI**: SchemaService + provider factory delegate registered

## Kararlar

| Konu | Karar | Kaynak |
|---|---|---|
| Schema cache TTL | 5 dakika (Phase 2'de) | Provider-aware UI için yeterli tazelik |
| Query history TTL | Configurable, default 30 gün (settings.historyTtlDays) | User control |
| Hive serialization | Map-based (TypeAdapter gerekmez) | Simpler; primitif type'lar için yeterli |
| Cipher key storage | flutter_secure_storage (`dbx_hive_cache_key`) | Production keychain/keystore/libsecret |
| Test mode | LocalCache.forTesting(constructor) — sabit key | Test'ler secure_storage platform-channel çağıramaz |
| listIds index | SharedPreferences `dbx_conn_index` (string list) | Secure storage API'si key enumeration yok |
| Corrupt JSON handling | StorageFailure fırlat (load null yerine) | Loud failure > silent corruption |

## Değişen / Eklenen Dosyalar (8 dosya)

### Storage
- `lib/infrastructure/storage/secure_connection_store.dart` — JSON serializer genişletildi (replicaSet, ssl, directConnection, serverSelectionTimeoutMs); SharedPreferences index; loadAll(); loadAll corrupt entry skip
- `lib/infrastructure/storage/local_cache.dart` — schema_cache box (TTL 5min, getCachedSchema/cacheSchema/invalidateSchema/clearSchemaCache); query_history box (addHistoryEntry/getRecentHistory/getHistoryForConnection/pruneHistory/clearHistory); LocalCache.forTesting constructor (test-only)
- `lib/infrastructure/storage/query_history_entry.dart` (yeni) — Equatable model + toMap/fromMap + storageKey
- `lib/infrastructure/storage/schema_service.dart` (yeni) — listDatabases (no cache) + listCollections (cache-aside) + invalidateForDatabase + clearAll

### DI
- `lib/product/init/getIt/modules/database_module.dart` — DatabaseProviderFactory placeholder delegate + SchemaService registration (storage_module'den sonra)

### Tests
- `test/storage_test.dart` (yeni) — 14 test:
  - QueryHistoryEntry: 2 (roundtrip, storageKey)
  - LocalCache schema cache: 4 (put/get, miss, invalidate, clear)
  - LocalCache query history: 3 (add/recent, prune, filter by conn)
  - SchemaService: 2 (cache hit, invalidate forces refresh)
  - SecureConnectionStore: 2 (index read, empty)
  - StorageFailure: 1 (sealed)

## Mock ↔ Real — SchemaService

```dart
// SchemaService artik provider-agnostic cache layer
class SchemaService {
  Future<List<CollectionNode>> listCollections(conn, db) async {
    final cached = await cache.getCachedSchema(conn.profile.id, db);
    if (cached != null) return cached;          // cache hit
    final fresh = await provider.listCollections(conn, db);
    await cache.cacheSchema(conn.profile.id, db, fresh);  // cache put
    return fresh;
  }
}
```

Phase 3'te (gerçek MongoDB) provider değişir, SchemaService ve cache layer aynen kalır.

## Verification

- ✅ `flutter analyze` — No issues found!
- ✅ `flutter test` — 59/59 passed
- ✅ LocalCache.forTesting constructor ile secure storage bypass
- ✅ Cache hit/miss sayacı (factory counter ile kanıtlandı)
- ✅ TTL prune çalışıyor (40-gün entry silindi, 5-gün kaldı)
- ✅ QueryHistoryEntry UTC roundtrip doğru

## Test Dağılımı (Phase 2 eklenen)

| Kategori | Test | Davranış |
|---|---|---|
| QueryHistoryEntry | roundtrip | toMap → fromMap eşit |
| QueryHistoryEntry | storageKey | unique per id |
| Schema cache | put/get | cacheSchema sonra getCachedSchema döner |
| Schema cache | miss | olmayan key → null |
| Schema cache | invalidate | sonra null döner |
| Schema cache | clear | tüm schema cache temizlenir |
| Query history | add/recent | eklenen entry recent'te |
| Query history | prune | 40-gün entry silindi, 5-gün kaldı |
| Query history | filter by conn | sadece ilgili connection |
| SchemaService | cache miss/hit | 1. çağrı provider, 2. cache |
| SchemaService | invalidate | invalidate sonrası tekrar provider |
| SecureConnStore | index read | listIds SharedPreferences'tan |
| SecureConnStore | empty index | yoksa boş liste |
| StorageFailure | sealed check | AppFailure subclass |

## Sonraki Faz

**Phase 3 — Real MongoDB provider**:
- mongo_dart_flutter dependency ekle (pubspec.yaml)
- MongoDBProvider.connect → Db.open + authenticate (gerçek TLS, SCRAM)
- MongoDBProvider.execute → DbCollection.aggregate/find
- MongoDBProvider.listDatabases/listCollections → gerçek API
- MongoDBProvider.explain → aggregate with $explain
- Mock'u kaldır veya feature flag ile arkaya al
- Integration test (Phase 8 platform_io) hazırlığı

**Plan: CHANGELOGS/PHASE-3-MONGODB-2026-08-20.md**