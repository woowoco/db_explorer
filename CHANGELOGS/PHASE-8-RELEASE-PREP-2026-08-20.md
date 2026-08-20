# Phase 8 — Public Release Prep (2026-08-20)

## Scope

Phase 8, `db_explorer_app`'in Phase 7'de gelen gerçek AI provider
implementasyonunu (Local llama.cpp / Ollama / OpenAI-compatible)
**uçtan uca bağlanabilir** hale getirir: Settings ekranından
provider seçimi + uçtan uca konfig + sensitive field regex
yönetimi, ardından tüm akış `AppBootstrap` ve `AppCubit` üzerinden
koşturulur. Hedef: dışarıdan indirilen projeyi açtığında
`flutter run` ile AI özelliği çalışır halde olsun.

## Kararlar (Decisions)

### D1 — AppSettings → RealAiProviderFactory wiring

`AppSettings` artık 16 yeni alan taşır:
- Local (llama.cpp): `modelPath`, `contextSize`, `nGpuLayers`,
  `temperature`, `maxTokens`
- Ollama: `endpoint`, `model`, `bearerToken`, `temperature`, `timeoutSeconds`
- OpenAI-compatible: `endpoint`, `apiKey`, `model`, `temperature`,
  `maxTokens`, `timeoutSeconds`
- `sensitiveFieldPatterns` (newline-separated regex sources)

`lib/product/providers_registry/real_ai_factories.dart` yeni dosya:
- `RealAiProviderFactory` → `buildFromSettings()` Settings.aiMode'a
  göre tek bir `AiQueryProvider` döner (null = disabled mode).
- `applySensitiveFieldPatterns(AppSettings)` → Settings'teki regex
  listelerini `RegExp`'e çevirir ve `AiPromptBuilder.setSensitivePatterns()`
  ile global state'e push eder.

### D2 — Registry bootstrap'ı feature-flag driven

Phase 7'de 4 provider koşulsuz kayıtlıydı; Phase 8.2'de
`registerBuiltinProviders(AppSettings)` imzası değişti:
- `_registerAi()` önce registry'yi temizler, `DisabledProvider` fallback
  olarak her zaman register eder, ardından `RealAiProviderFactory` çıktısını
  ekler. Seçim `Settings.aiMode`'a göre yapılır.
- `applySensitiveFieldPatterns()` çağrısı boot'ta bir kez tetiklenir.

### D3 — AiCubit ↔ AiProviderRegistry bağlantısı (Phase 8.3)

`AiCubit.refresh(AiProviderRegistry)` async probe ekler:
- Registry `defaultProvider()` döner → state `loaded(providerId)` olur.
- Null → state `unavailable`.
- Exception → state `error(lastError)`.

`AppBootstrap.fullInitialize()` provider registration sonrasında
`getIt<AiCubit>().refresh(getIt<AiProviderRegistry>())` çağırır.

### D4 — Settings UI page tam yüzey (Phase 8.4)

`SettingsPage` placeholder'dan functional oldu:
- Appearance: theme mode radio.
- AI Provider: `RadioListTile<AiMode>` ile 4 mod arası seçim. Seçim
  → `AppCubit.setAiMode()` + registry rebuild + sensitive re-apply.
- Mode-specific config cards (Local / Ollama / OpenAI): her Settings
  alanı için TextField, submit'te setter'a yazılır. Sensitive patterns
  multiline textarea `onChanged`'da real-time push.
- About: `state.buildVersion` gösterimi (0.9.0+9).

`AppState` + `AppCubit` 16 yeni alan + setter ile extend edildi
(immutable state + copyWith). Setters `AppSettings` üzerinden
`SharedPreferences`'a otomatik persist eder.

### D5 — Cross-platform build verification (Phase 8.5)

Windows + Android debug build'leri bu makinede derlendi:
- `flutter build windows --debug` → `build/windows/x64/runner/Debug/db_explorer_app.exe`
- `flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk`

`llm_llamacpp` native binary'leri Android ABIs (armeabi-v7a, arm64-v8a,
x86_64) için cache'e prebuilt zip olarak indirildi; native build
dependency'si Windows'ta `unzip` yokluğu nedeniyle atlandı. Phase 9 backlog:
`README`'de unzip-on-Windows note'u + bir setup helper script.

macOS / iOS build'leri macOS makinesi gerektirdiğinden bu hesapta
doğrulanmadı (build farm dışı scope). Linux için feature flag aktif
ancak VS Community 2022 ile desktop build set edilmemiş olduğundan
Windows-only doğrulama yapıldı.

## Eklenen / Değişen Dosyalar

### Yeni
- `lib/product/providers_registry/real_ai_factories.dart` — Settings-aware
  factory + sensitive pattern applier.
- `test/real_ai_factory_test.dart` — 10 test (4 mode x factory build +
  sensitive pattern apply + invalid regex skip + 3 registry wiring).
- `test/ai_cubit_test.dart` — 7 test (refresh paths + mark* methods + registry order).

### Değişen
- `lib/infrastructure/storage/settings.dart` — Phase 8.1 AI config alanları.
- `lib/presentation/app_cubit.dart` — Phase 8.1 AI state alanları +
  Phase 8.4 setter'lar + buildVersion 0.9.0+9.
- `lib/presentation/settings/settings_page.dart` — Tam işlevsel UI.
- `lib/presentation/ai_cubit.dart` — `refresh(AiProviderRegistry)` eklendi.
- `lib/product/providers_registry/builtin.dart` — `registerBuiltinProviders(AppSettings)`
  + Settings-driven `_registerAi()` + boot-time sensitive apply.
- `lib/product/init/getIt/dependency_injection.dart` — `registerProviders(AppSettings)`
  imza değişikliği.
- `lib/product/app/app_bootstrap.dart` — Provider registration sonrası
  `AiCubit.refresh()` çağrısı.
- `test/skeleton_smoke_test.dart` — aiMode=disabled default beklentisi
  ile Phase 8 wiring'i doğrulayan güncel test.
- `pubspec.yaml` — version 0.9.0+9.

## Güvenlik (Brief Madde 11, 14) — Phase 7'den Süren Garanti

| Gereksinim | Karşılama (Phase 8 doğrulama) |
|---|---|
| AI asla otomatik sorgu çalıştırmaz | `AiCompletion` (öneri) döner; database provider execute yok |
| AI asla write/DDL üretmez | Preflight (useMessage) + post-scan (output) — toplam 208 test içinde 9 senaryo |
| Database credentials AI context'ine ASLA girmez | `AiContext` schema-only; endpoint/apiKey YALNIZCA provider constructor'ında |
| AI context = schema-only | `AiPromptBuilder.systemPrompt()` yalnızca `DatabaseSchemaSummary` döner |
| **Sensitive field regex maskeleme** | `applySensitiveFieldPatterns()` Settings.sensitiveFieldPatterns'ı `AiPromptBuilder.setSensitivePatterns()` üzerinden global set eder. Regex listesi olmasa bile `[REDACTED]` mekanizması hazır; default'ta boş (yani tüm metin maskelenmeden geçer). |

## Versiyon

`pubspec.yaml`: `0.9.0+9` (build 9 = Phase 8 commit).
AppState.buildVersion eşit değerdedir.

## Testler

- `flutter analyze --no-pub` → 0 error (21 önceden var olan info-level
  lint hints — Phase 6'dan kalan `prefer_const_constructors` ve
  `avoid_redundant_argument_values` calls).
- `flutter test --no-pub` → **208/208 passed**
  - Phase 7 carry-over: 191
  - Phase 8.2 (`real_ai_factory_test.dart`): 10
  - Phase 8.3 (`ai_cubit_test.dart`): 7

## Sınırlamalar (Phase 9'a bırakılanlar)

1. **Settings UI widget testleri** — Phase 8.4'te SettingsPage için
   `flutter_test` widget testi eklenmedi (Provider tree + MultiBlocProvider +
   GetIt gerektiriyor). Phase 9 backlog: scaffold + golden + integration smoke.
2. **`llm_llamacpp` prebuilt cache unzip helper** — Windows'ta `unzip`
   PATH'te olmadığı için Android build'in başarılı olabilmesi için
   PowerShell `Expand-Archive` ile manuel çıkarma gerekli. Phase 9
   backlog: `scripts/setup_windows.ps1`.
3. **macOS / iOS build verification** — cross-compile yok, fiziksel
   macOS makinesi gerek. Phase 9 backlog: GitHub Actions matrix.
4. **Settings'i değiştirince active ai_mode'da aktif provider'ın
   sıcak değişimi** — şu an registry rebuild + cubit refresh var;
   ancak eğer local llama.cpp seçildiyse model yükleme post-frame
   callback'inde olmalı. Mevcut implementasyon default provider
   probe eder — yükleme lazy `complete()` çağrısında olur. Faz 9
   backlog: ilk aktif provider'da warm-up.

## Sonraki Faz

**Phase 9** — Beta hardening + cross-platform distribution:
- macOS / iOS build verification (CI matrix veya el ile)
- README + setup rehberi (`scripts/setup_windows.ps1` Windows unzip helper)
- Settings UI widget testleri + golden image tests
- Local llama.cpp warm-up post-frame callback
- Entegrasyon smoke (gerçek model ile inference — mevcut test
  seam üzerinden; native build olmadan)
- Crash reporting opt-in (Sentry) + telemetry opt-in wiring
- CI workflow (`.github/workflows/flutter.yml`) + tag-driven release
