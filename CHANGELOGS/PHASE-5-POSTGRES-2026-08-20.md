# Phase 5 — PostgreSQL Provider (Mock + Real)

**Tarih:** 2026-08-20
**Build:** 0.6.0+6 (Phase 5)

## Özet

Bu faz, db_explorer_app'e **PostgreSQL** desteğini ekledi:
- `postgres: ^3.5.0` paketi (isoos/stablekernel — pure-Dart driver) dependency olarak bağlandı
- Sealed `DatabaseConnectionConfig` family'ye `PostgresConnectionProfile` eklendi
- `PostgresDBProvider` (mock, seed data) ve `RealPostgresProvider` (`postgres` paketini kullanan) implementasyonları yazıldı
- Şema node'ları (`PostgresDatabase`, `PostgresTable`, `PostgresColumn`, `PostgresIndex`) concrete sınıfları oluşturuldu
- Registry'ye Postgres factory kayıtları eklendi (mock default, real wiring Phase 8'de)
- 19 yeni test (provider contract + sealed profile + JSON round-trip)

Phase 5 sonunda MongoDB + PostgreSQL iki provider çalışır durumda. UI henüz provider seçtirmiyor — bu Phase 8 release prep kapsamında (connection list ekranında "New Connection" wizard).

---

## Kapsam

### Eklenen dosyalar

| Dosya | Amaç |
|---|---|
| `lib/infrastructure/database_providers/postgres/postgres_schema.dart` | `PostgresDatabase`, `PostgresTable`, `PostgresColumn`, `PostgresIndex` concrete schema node'ları (SQL dünyasının table/column/index abstraction'ları) |
| `lib/infrastructure/database_providers/postgres/postgres_provider.dart` | `PostgresDBProvider` (mock, SELECT * FROM x LIMIT/OFFSET parser) + `PostgresDBProviderFactory` |
| `lib/infrastructure/database_providers/postgres/real_postgres_provider.dart` | `RealPostgresProvider` (gerçek `postgres` paketi — TCP + SCRAM-SHA-256 + information_schema introspection) + `RealPostgresProviderFactory` |
| `test/postgres_provider_contract_test.dart` | 19 unit test (lifecycle, schema, query, capabilities, completion, profile round-trip) |

### Değiştirilen dosyalar

| Dosya | Değişiklik |
|---|---|
| `pubspec.yaml` | `postgres: ^3.5.0` eklendi (Phase 5 — pure-Dart PG driver); version `0.5.0+5` → `0.6.0+6` |
| `lib/domain/database/connection.dart` | `PostgresConnectionProfile` (sealed family'ye ek); `PostgresSslMode` enum (disable/require/verifyFull) + `storageValue` + `label` extension |
| `lib/infrastructure/storage/secure_connection_store.dart` | `_profileToJson`/`_profileFromJson` exhaustive switch genişletildi (`PostgresConnectionProfile` branch); `_sslModeFromJson` helper |
| `lib/product/providers_registry/builtin.dart` | `_registerDatabase` artık MongoDB + Postgres ikisini de kayıt eder |
| `test/skeleton_smoke_test.dart` | Registry length `1` → `2` (MongoDB + Postgres); kind-bazlı kontrol |

---

## Kararlar

### 1. **`postgres: ^3.5.12` (isoos/stablekernel) seçildi**

`mongo_dart` gibi pure-Dart; native binding yok → cross-platform build sorunsuz. API yüzeyi:
- `Connection.open(Endpoint, settings: ConnectionSettings)`
- `conn.execute(Sql | String, parameters, ...)` → `Result` (rows + affectedRows + ResultSchema)
- `ResultRow.toColumnMap()` (column name → value)
- `ResultSchemaColumn.typeOid` + `type` (Type registry) + `columnName`
- Exception hiyerarşisi: `PgException` → `ServerException` (PG SQLSTATE `code` field'ı ile)

`postgres 2.x` yerine `3.x` seçildi — `3.x` parameter binding API'si daha temiz (`Sql.named()` ve positional).

### 2. **`PostgresConnectionProfile` + `PostgresSslMode` enum**

Sealed family genişletildi — derleyici artık `switch (profile)` exhaustive kontrolü yapıyor. Alanlar:
- `password` (RAM'de; secure store'da ayrı)
- `sslMode` (disable/require/verifyFull — `verifyFull` production için tek güvenli mod)
- `applicationName` (pg_stat_activity'te görünür)
- `connectTimeoutSeconds` (TCP bağlantı zaman aşımı)
- `statementTimeoutSeconds` (per-query max süre; 0 = sınırsız)

Default: port 5432, sslMode `require`. `databaseName` SQL dünyasında zorunlu (her connection bir db'ye bağlanır) — bu yüzden `required`.

### 3. **Mock vs Real provider: ikisi de registry'de, mock default**

Phase 5'te **mock** default (UI geliştirme + test için). `RealPostgresProvider` Phase 5.3'te yazıldı ama Phase 8'de `settings.useRealPostgresDriver` feature flag ile wiring yapılacak.

Registry pattern:
```dart
// builtin.dart — Phase 5 sonunda:
if (!dbRegistry.isRegistered(DatabaseKind.postgres)) {
  dbRegistry.register(const PostgresDBProviderFactory());
}
// RealPostgresProviderFactory sadece Phase 8'de (AppBootstrap'ta):
dbRegistry.register(const RealPostgresProviderFactory()); // mock'u override eder
```

### 4. **RealPostgresProvider — exception sınıflandırması**

`postgres` paketinin exception hiyerarşisi:
- `PgException` (base, client-side: parser, codec, vs.)
- `ServerException` extends `PgException` (server-side, `code` field = PG SQLSTATE)
- `UniqueViolationException`, `ForeignKeyViolationException` (specific 23505/23503)

`RealPostgresProvider.connect()` exception handling:
1. `ServerException` → `ErrorConnection(code: 'PG_${sqlstate}', isRetryable: severity != fatal/panic)`
2. `PgException` → `ErrorConnection(code: 'PG_CLIENT_ERROR', isRetryable: true)`
3. `SocketException` → `ErrorConnection(code: 'PG_CONNECTION_REFUSED', isRetryable: true)` (network seviyesi)
4. Generic `catch` → `ErrorConnection(cause: e, isRetryable: true)`

### 5. **Schema introspection: information_schema + pg_catalog hibrit**

Phase 5'te iki source kombine edildi:
- `information_schema.tables/columns` — standard SQL, portable
- `pg_class`, `pg_index`, `pg_attribute` — PG-specific ama `reltuples` (row estimate) ve primary key detection için gerekli

`_readColumns(conn, tableName)` her tablo için:
1. `information_schema.columns` → field listesi (data_type, is_nullable, column_default)
2. `pg_index + pg_attribute` (indisprimary) → primary key set
3. `pg_index + pg_attribute` (NOT indisprimary) → indexed columns set

`_escapeIdentifier(tableName)` — `^[A-Za-z_][A-Za-z0-9_]*$` regex ile basit identifier validation. SQL injection regclass cast ile sınırlı; Phase 8'de Sql.named + parameters kalıbına geçilecek.

### 6. **`prefer_single_quotes` lint suppress (real_postgres_provider.dart)**

SQL string'leri çoğunlukla tek-tırnak literal içerir (örn. `'public'`, `'BASE TABLE'`); çift tırnak kullanımı kasıtlı. Dosya başına `// ignore_for_file: prefer_single_quotes` eklendi.

### 7. **Real provider'da `Sql.named` yerine raw SQL (Phase 5.3)**

`Sql.named()` zaten sadece sql alır (parametreler `execute`'a ayrıca verilir) — bu yüzden interpolation + identifier validation daha okunabilir. `Sql.named` Phase 8'e ertelendi.

### 8. **`secure_connection_store` JSON round-trip**

`PostgresConnectionProfile` → JSON: `kind: 'postgres'`, tüm PG-spesifik alanlar. `sslMode` storage value olarak (`'disable'` / `'require'` / `'verify-full'`). Reverse mapping: bilinmeyen sslMode → `require` default (forward-compatible).

---

## API uyumluluğu

| Tip | Değişti mi? | Etki |
|---|---|---|
| `DatabaseConnectionConfig` (sealed) | Hayır | Postgres alt sınıfı eklendi, sealed contract korundu |
| `MongoConnectionProfile` | Hayır | aynen kullanılıyor |
| `DatabaseProvider` interface | Hayır | Postgres impl'leri aynı interface'i kullanır |
| `SecureConnectionStore._profileToJson` | **Evet, exhaustive switch genişledi** | Bilinmeyen profile kind → `ArgumentError` (önceden de aynı) |
| `DatabaseProviderRegistry.all` length | `1` → `2` | UI'da `registry.all.length` hardcoded check varsa güncelleme gerekli (skeleton_smoke_test güncellendi) |

`PostgresConnectionProfile` tümüyle yeni — Phase 0-4'te hiç import edilmediği için migration gerekmiyor.

---

## Test dağılımı

| Test dosyası | Test sayısı | Kapsam |
|---|---|---|
| `postgres_provider_contract_test.dart` | 19 | lifecycle (connect/ping/disconnect/reconnect), schema discovery (databases + collections + column meta + PK), query (SELECT/LIMIT/OFFSET/ArgumentError/FormatException), capabilities, completion, profile round-trip (copyWith/default port/sslMode) |
| (önceki fazlardan) | 95 | storage, schema, connection, mongo provider, AI provider, registry, workspace, results grid, query editor cubit, skeleton smoke |
| **Toplam** | **114** | tüm `flutter test` clean |

---

## Bilinen sınırlamalar / Phase 8+ için TODO

1. **Real provider wiring** — `settings.useRealPostgresDriver` feature flag implementasyonu (Phase 8 — `RealMongoDBProviderFactory` ile paralel)
2. **Connection wizard UI** — kullanıcı connection oluştururken provider + profile seçimi (şimdilik sadece mock seed connection var)
3. **Schema-aware completion** — `RealPostgresProvider.complete()` sadece SQL keyword'leri; tablo/kolon adları autocomplete için introspection query eklenmeli (Phase 8)
4. **Sql.named + parameters** — şu an identifier validation + raw SQL; prepared statement kalıbına geçiş (Phase 8)
5. **Transaction support** — capability'de `transactions` var ama `execute()` şu an auto-commit; `SessionExecutor.runTx()` Phase 8+ (transactional UI yok)
6. **SSL certificate management** — `verifyFull` için `SecurityContext` UI'da ayarlanamıyor (Phase 8)
7. **Postgres-specific EXPLAIN parser** — şu an `EXPLAIN (FORMAT JSON)` raw text; UI'da JSON tree görselleştirmesi Phase 8+
8. **Connection string parser** — `postgresql://user:pass@host:port/db` URL form'dan profile oluşturan helper yok (Phase 8 — UI'da "paste connection string" butonu)

---

## Aksiyonlar (kayıt)

| Saat | Aksiyon |
|---|---|
| Phase 5 başlangıcı | Phase 4 commit (`e09f1c2`) üzerine Phase 5 başladı |
| Phase 5.1 | `pubspec.yaml`: `postgres: ^3.5.0` eklendi, `flutter pub get` başarılı |
| Phase 5.2 | `PostgresConnectionProfile` + `PostgresSslMode` enum + `secure_connection_store` JSON round-trip genişletildi |
| Phase 5.3 | `postgres_schema.dart` (concrete node'lar) + `postgres_provider.dart` (mock + factory) + `real_postgres_provider.dart` (gerçek driver) yazıldı — 12 analyze hatası düzeltildi (PgException.code → ServerException cast, SocketException import, Sql.named API, redundant arg defaults) |
| Phase 5.4 | `builtin.dart` registry wiring — MongoDB + Postgres factory'leri kayıtlı |
| Phase 5.5 | 19 yeni unit test (`postgres_provider_contract_test.dart`) + skeleton_smoke_test güncellendi (length 1→2) + analyze clean + 114/114 test pass |

---

## Verification (Phase 5 kapanışı)

```
$ flutter analyze
No issues found! (ran in 4.2s)

$ flutter test
00:18 +114: All tests passed!

$ flutter pub get
Got dependencies! (postgres 3.5.12 added)
```

✅ Analyze clean.
✅ 114/114 tests passing (Phase 4: 95 + Phase 5: 19).
✅ Phase 4 commit (`e09f1c2`) üzerine Phase 5 commit hazır.
