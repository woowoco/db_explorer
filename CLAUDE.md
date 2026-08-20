# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project snapshot

`db_explorer_app` — Flutter cross-platform Database Workbench + AI Query Assistant. MVP centers on MongoDB, with a read-only AI Query Copilot (no write authority). Targets Windows/macOS/Linux desktop + Android/iOS. Versioning schema is `<major>.<minor>.<patch>+<build>`; current `0.9.0+9` is the public release prep branch (Phase 8).

Full product brief lives in `CHANGELOGS/start-prompt.md` (33 items) and architecture-level research in `CHANGELOGS/RESEARCH-REPORT-2026-08-20.md`. Phase 8 decisions and security guarantees are in `CHANGELOGS/PHASE-8-RELEASE-PREP-2026-08-20.md`.

## Working with Tolga (cross-project standards)

This block lifts process rules that F_AISUBCRIBE and xd both enforce verbatim — db_explorer inherits them too. Rules 1–10 below are the canonical "Plan / Phase Execution Integrity" set authored 2026-07-12; rule #7 (cross-AI coordination) is marked N/A here because db_explorer is a single-AI project. User is **Tolga** — address them by name.

### Commit / push policy (xd-style — autonomous)

Commit + push autonomous yapılır (gerekli zamanlar). Format kurallarına uyulur; `Co-Authored-By: Claude <noreply@anthropic.com>` trailer zorunlu. Push öncesi kullanıcı onayı gerekmez — **destructive push (`--force`, branch silme) istisna**: bunlar için Tolga'ya sor. Read-only `git status`, `git log`, `git diff` her zaman serbesttir.

### Plan / Phase Execution Integrity (KRİTİK — Tolga direktifi)

Tüm plan dosyaları veya fazların uygulanmasında aşağıdaki **10 ortak kural** KESİN olarak uygulanır.

**1. GAP Olmamalı** — Plan veya fazlar uygulanırken hiçbir task/öğe atlanmamalı, sessizce geçiştirilmemeli. Her task "yapıldı" durumu sadece gerçekten yapıldığında işaretlenmeli.

**2. Kullanıcıya Danışmadan İş Atlanmamalı** — "Bu önemsiz / atlayalım / sonra yaparız" gibi kestirme yollar yasak. Task atlanması veya scope dışına çıkılması gerekiyorsa → DUR ve Tolga'ya sor. Sessiz skip YASAK — incomplete work raporlamak atlamaktan iyidir.

**3. Faz / Plan Bitirildiğinde Doğrulama ZORUNLU** — Her faz veya plan sonunda 4 koşullu sweep:
- Bu fazdaki tüm işler başarıyla yapıldı mı?
- Plan dosyasındaki tüm acceptance criteria karşılandı mı?
- Bağımlı alt fazlar / planlar da tetiklendi mi?
- Testler yeşil mi? (`flutter analyze --no-pub` → 0 errors, `flutter test` → all green)

**Pre-Flight (Uygulama Öncesi):** Yeni plan uygulamasına başlamadan önce 4 maddelik mental checklist:
1. Plan, mevcut mimariyle (5-layer, GetIt DI, flutter_bloc, sealed types, capability-driven UI) çelişen bir varsayım içeriyor mu?
2. Plan, bu CLAUDE.md'deki kurallara (DI / BLoC / lint / ThemeExtension / AI safety) aykırı mı?
3. Plan, scope dışı bir task içeriyor mu?
4. Bağımli fazlar / planlar var mı, tetiklenmeli mi?

Herhangi bir "evet" → DUR, Tolga'ya sor.

**4. Mevcut Mimariye Uyum Kontrolü** — Her adımda mevcut mimariye (GetIt DI, flutter_bloc, ThemeExtension, sealed types, iki-registry extension point) ters yapı veya bozukluk kontrol edilir. Mimari uyumsuzluk → DUR, raporla, uyumlu alternatif öner.

**5. Tahmin Değil, Kesin ve Gerçek Sonuçlar** — "Muhtemelen / sanırım / büyük ihtimalle" gibi tahminler YASAK. Her değişiklik Read, Grep, tool çağrısı veya çalıştırılabilir kanıt ile desteklenmeli.

**6. Öneri Mekanizması** — Sohbet sırasında workflow / plan / mimari iyileştirme önerileri:
- **Gerekçe:** neden öneriliyor
- **Etki:** ne kazandıracağı / hangi riski azaltacağı
- **Maliyet:** kolay / orta / büyük

Memory veya CLAUDE.md'ye **Tolga'ya sormadan** ekleme yapma — öneriyi sun, onay al, sonra uygula.

**7. Çapraz-AI Koordinasyon** — N/A: db_explorer tek-AI projesi (multi-AI plan-file-as-source-of-truth modeli F_AISUBCRIBE↔xd arasındaki koordinasyon içindir).

**8. Kanıt Formatı (zorunlu)** — Her "tamamlandı" raporu şu formatta olmalı:

```
✅ Task <ID> tamamlandı
  - Dosya: <path:line> (ne değişti)
  - Test: <test_path::test_name> PASSED (kanıt: çıktı satırı)
  - Log/Run: <komut + sonuç)
  - Commit: <sha> (varsa)
```

"Implementasyonu yaptım" demek yetmez; kanıt (test çıktısı / log / dosya yolu / commit SHA) şart.

**9. Plan Tamamlanma Tanımı** — **Plan tamamlandı** = tüm fazlar ✅ + SUMMARY.md yazıldı + memory update + plan arşivlendi/`DONE` işaretlendi. **Sadece son faz commit'i plan tamamlandı anlamına GELMEZ.** Her plan için kapanış ritüeli zorunlu.

**10. Tekrarlayan Hata Kalıbı Audit** — Bir bug fix uygularken: **"Bu kalıp daha önce hangi fazlarda görüldü?"** kontrolü zorunlu. Aynı kalıp 2+ fazda görülmüşse → **root cause audit zorunlu**, yüzeysel fix kabul edilmez.

### Overengineering'den Kaçınma (KISS — Dengeli)

- Sadece istenen değişikliği yap — scope creep yapma
- Mevcut pattern'i takip et; aynı işi yapan 2. abstraction kurma
- "Gelecekte lazım olur" diye hook / utility / plugin / feature-flag ekleme
- Çalışan kodu yeniden yazma / refactor etme (görev dışıysa)
- **LLM mimari / pattern önerileri değerlidir** — vibecoding'de öneri sunabilir; gerekçe + etki + maliyet belirtmeli (bkz. §6 Öneri Mekanizması)
- Değişiklik öncesi: **"Bu minimum gerekli mi?"** sorusunu sor — gereksiz ise yapma

## Commands

```bash
# Bootstrap
flutter pub get

# Analyze (strict — see analysis_options.yaml)
flutter analyze

# Run all tests
flutter test

# Run a single test file
flutter test test/database_provider_contract_test.dart

# Run a single test by name pattern
flutter test --name "ping → true when connected"

# Run a group of tests in a file
flutter test test/ai_prompt_builder_test.dart

# Run on a desktop or device
flutter run -d windows
flutter run -d macos
flutter run -d linux
flutter run -d emulator-5554          # Android emulator
flutter run -d <device-id>

# Build
flutter build windows --debug
flutter build macos --debug
flutter build apk --debug
flutter build ios --debug --no-codesign
```

`flutter test` and `flutter analyze` are CI-grade gates. Phase 8 baseline: `flutter analyze --no-pub` → 0 errors (21 info-level hints); `flutter test` → 208/208 passed.

## Architecture

5-layer DDD-leaning split. Imports flow strictly downward; never import `presentation/` from `domain/` or `infrastructure/`.

```
lib/
├── core/           # Cross-cutting: theme, logger, constants, UI primitives
├── domain/         # Pure Dart — interfaces, sealed types, capability enums.
│                   #   No Flutter, no I/O. (database/, ai/)
├── infrastructure/ # Implementations: registries, drivers, storage, AI providers.
│                   #   (database_providers/*, ai_providers/*, registry/, storage/)
├── presentation/   # Cubits + Pages. flutter_bloc + Equatable.
├── product/        # Wiring: DI (GetIt), router, bootstrap, provider registry, theme.
└── main.dart       # 15-line entry → AppBootstrap
```

### Bootstrap sequence (`lib/product/app/app_bootstrap.dart`)

`main()` → `AppBootstrap.minimalInitialize()` (WidgetBinding + ScreenUtil) → `AppBootstrap.fullInitialize()` (Hive.initFlutter → `GetItInjections.registerSync` → `await GetItInjections.registerAsync` → `registerProviders(settings)` → settings ping → `aiRegistry.defaultProvider()` → `getIt<AiCubit>().refresh(aiRegistry)`) → `buildAppRoot()` returns `MultiBlocProvider` (ThemeCubit, AppCubit, AiCubit) wrapping `AppRoot`.

### GetIt DI modules (`lib/product/init/getIt/modules/`)

`registerSync(getIt)` → `CoreModule` (Logger, ThemeCubit, ConnectionCubit) · `DatabaseModule` (DatabaseProviderRegistry singleton, default `_MongoDbFactoryDelegate`, SchemaService) · `AiModule` (AiProviderRegistry, AiCubit). `registerAsync` → `StorageModule.initAsync` (SharedPreferences then AppSettings, SecureConnectionStore, LocalCache, AppCubit). `registerProviders(settings)` → `builtin.registerBuiltinProviders(settings)` is what actually installs the database + AI factories.

### Two registries — the extension points

Adding a new database engine or AI backend always means: implement the interface → register a factory in `lib/product/providers_registry/builtin.dart`.

- `DatabaseProviderRegistry` (singleton, `Map<DatabaseKind, DatabaseProviderFactory>`, **last-registration-wins**). `create(kind)` throws `ArgumentError` if unregistered. Domain seam: `DatabaseProvider` (`connect/disconnect/ping/listDatabases/listCollections/execute/explain/complete`) + `DatabaseProviderFactory` (`create()` + `kind`). Mock + real pairs share this seam.
- `AiProviderRegistry` (singleton, ordered `List<AiQueryProvider>`, **first-available-wins**). `available()` skips providers whose `isAvailable()` throws; `defaultProvider()` returns the first surviving entry. Domain seam: `AiQueryProvider` (`id`, `label`, `isAvailable()`, `complete(AiRequest, {onCancelSetup})`).

### Capability-driven UI

`DatabaseCapability` enum + `DatabaseCapabilities` immutable set describe what each provider can do (schema hierarchy, aggregation, transactions, write groups, security hints, etc.). UI uses `caps.hasInsert`, `caps.isMutable`, `caps.hasAnyWrite` to gate buttons. Never hard-code a capability check on a provider kind.

### Sealed types

- `DatabaseConnectionConfig` (sealed base) → `MongoConnectionProfile` / `PostgresConnectionProfile` / `RedisConnectionProfile` / `ElasticsearchConnectionProfile`. Passwords live on the profile in RAM but **persist to `SecureConnectionStore`**, never to `SharedPreferences`.
- `DatabaseConnectionState` (sealed) → `IdleConnection` / `ConnectingConnection(progress, message)` / `ConnectedConnection(sessionId, at, serverVersion, latencyMs, uptimeSeconds, extra)` / `ErrorConnection(message, code, cause, isRetryable)` / `DisconnectedConnection(reason)`. Exhaustive `switch` is required by the analyzer.

### Storage layout

- `SharedPreferences` → `AppSettings` (theme, AI mode/provider params, `sensitiveFieldPatterns` newline-separated, telemetry opt-in, history TTL).
- `FlutterSecureStorage` → `dbx_hive_cache_key` (256-bit AES-GCM cipher key) + all connection passwords + SecureConnectionStore index.
- Hive encrypted boxes (`schema_cache` 5 min TTL, `query_history` 30 day TTL). `LocalCache.forTesting({required List<int> cipherKey})` bypasses secure storage for tests.

## Gotchas

### Mock vs real database providers

`lib/product/providers_registry/builtin.dart` currently registers only the **mock** factories (`MongoDBProvider`, `PostgresDBProvider`, `RedisDBProvider`, `ElasticsearchDBProvider`). The four `Real*ProviderFactory` classes exist (`real_mongodb_provider.dart`, `real_postgres_provider.dart`, `real_redis_provider.dart`, `real_elasticsearch_provider.dart`) and are referenced from tests, but **they are never wired into bootstrap**. The doc comment in `builtin.dart` mentions `settings.useRealMongoDriver` / `useRealPostgresDriver` / `useRealRedisDriver` / `useRealElasticsearchDriver` flags that do not exist in `AppSettings` — that wiring is Phase 8/9 work. Until it lands, the app runs on mock providers only; AI providers ARE genuinely wired (local llama.cpp / Ollama / OpenAI-compatible, chosen by `AppSettings.aiMode`).

### AI safety invariants — `lib/infrastructure/ai_providers/ai_prompt_builder.dart`

The AI is a Copilot, not an agent. Hard rules enforced in two layers:

1. `AiPromptBuilder.preflight(AiRequest)` scans `userMessage` before send — returns a refusal `AiCompletion` if a write keyword (`insert into`, `drop table`, `drop database`, `drop index`, `delete from`, `alter table`, `create index`, `truncate`, `update `, `insert `, `drop `, `delete `) or sensitive regex matches.
2. `AiPromptBuilder.parseCompletion(raw, request)` re-scans the model's generated query **after** generation (defense-in-depth) and rejects on the same signals.

System prompt is schema-only — credentials never enter the context. The UI never auto-executes a completion; the user must copy/review/submit. Do not remove or weaken either guard without security review.

### ThemeExtensions use `!` — widget tests crash without production theme

`extension AppThemeContext on BuildContext` calls `Theme.of(context).extension<DataGridPalette>()!` etc. A vanilla `MaterialApp` in tests leaves extensions null → `context.dataGrid` throws. **Widget tests must wrap with `wrapWithAppTheme()` from `test/test_helpers.dart`**, which uses `AppTheme().lightThemeData()` / `.darkThemeData()` so the same extensions are present as in production.

### Provider-contract test = the seam for swapping in real drivers

`test/database_provider_contract_test.dart` is provider-agnostic and written against the MongoDB mock. When wiring a real driver, run this same test against the `Real*Provider` to validate the interface is honored — do not duplicate the contract in a per-driver test file.

### Editor dependency

`flutter_code_editor` requires `highlight` as a direct dependency (the `depend_on_referenced_packages` lint rejects indirect). Keep both pins in `pubspec.yaml`.

### cubit `clearLastResult` / `clearLastError` idiom

Nullable fields in `copyWith` use explicit `clearLastResult` / `clearLastError` boolean flags (e.g. `QueryEditorState`). Don't collapse them into a single nullable — distinguishing "explicit null" from "leave alone" needs the flag.

### macOS secure-storage key characters

`SecureConnectionStore` constrains keys to `_` and `-` only (macOS 2026 key-name bug workaround). Don't introduce other separators in `dbx_conn_*` keys.

## Design language

Inherited from `F_AISUBCRIBE`. Poppins (400/500/600/700/900) loaded via `assets/fonts/google-poppins/`. Primary `Deep Purple #6F31DA`. Flat Material 3 — `surfaceTint: Colors.transparent`, `cardTheme.elevation: 0`. Design tokens are exposed via 5 `ThemeExtension`s (`AppSpacings`, `AppRadii`, `DataGridPalette` BSON-type semantic colors, `EditorPalette` VSCode-inspired, `ConnectionPalette` for `DatabaseConnectionState` colors) consumed through `context.spacing`, `context.radius`, `context.dataGrid`, `context.editor`, `context.connection`. Responsive sizing via `flutter_screenutil` (design size iPhone 14 Pro).

## Analyzer / lint rules

`analysis_options.yaml` extends `flutter_lints` with strict-inference, strict-raw-types, no implicit casts, no implicit dynamic. Errors: `missing_required_param`, `missing_return`. ~60 explicit rules worth knowing: `prefer_single_quotes`, `require_trailing_commas`, `avoid_print`, `always_declare_return_types`, `close_sinks`, `cancel_subscriptions`, `use_build_context_synchronously`, `depend_on_referenced_packages`. Excludes `**/*.g.dart`, `**/*.freezed.dart`, `**/*.gr.dart`, `build/**`. Doc comments are in **Turkish** throughout — keep new doc comments Turkish to match the existing convention.

## Phase workflow

Each phase produces `CHANGELOGS/PHASE-N-<slug>-<date>.md` documenting decisions (D1, D2, …), files added/changed, security guarantees, test results, and the next-phase backlog. Bump `pubspec.yaml` build number `+<n>` per phase. `git commit` messages follow `<phase>: <description>` (e.g. `Phase 8.4 — Settings UI page (full AI config surface)`).

## Where things live (quick index)

| Concern | Path |
| --- | --- |
| Bootstrap + DI wiring | `lib/product/app/`, `lib/product/init/getIt/` |
| Router + guards | `lib/product/router/` |
| Theme + extensions | `lib/core/theme/`, `lib/core/theme/theme_extensions.dart` |
| Provider registry builtin | `lib/product/providers_registry/builtin.dart` |
| DB provider mocks | `lib/infrastructure/database_providers/<kind>/` |
| DB provider real impls | `lib/infrastructure/database_providers/<kind>/real_<kind>_provider.dart` |
| AI providers + safety | `lib/infrastructure/ai_providers/` |
| AI safety shared logic | `lib/infrastructure/ai_providers/ai_prompt_builder.dart` |
| Settings + secure storage | `lib/infrastructure/storage/` |
| Cubits | `lib/presentation/` (workspace_cubit, query_editor_cubit, connection_cubit, theme_cubit, ai_cubit, app_cubit) |
| Domain contracts | `lib/domain/database/`, `lib/domain/ai/` |
| Test helpers | `test/test_helpers.dart` |
