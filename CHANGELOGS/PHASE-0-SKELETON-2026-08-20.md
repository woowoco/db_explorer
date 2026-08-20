# Phase 0 — Skeleton (2026-08-20)

**Status:** ✅ Tamamlandı
**Build:** v0.1.0+1
**Test:** 7/7 smoke test passed
**Analyze:** zero issues

## Scope

Çalışan, compile-clean, tüm platform'larda build edilebilen (Windows/macOS/Linux desktop + Android/iOS mobile) Flutter projesi skeleton'ı. Hiçbir iş mantığı yok — sadece sağlam mimari temel.

## Kararlar

| Konu | Karar | Kaynak |
|---|---|---|
| State management | flutter_bloc + Cubit | Kullanıcı onayı (F_AISUBCRIBE tutarlılığı) |
| DI | GetIt modular | F_AISUBCRIBE pattern (sadeleştirilmiş) |
| Routing | go_router + adaptive shell | Kullanıcı onayı |
| Local AI | Qwen2.5-Coder-3B-Instruct Q4_K_M (mock) | Mimari 7B'ye açık |
| MVP provider | MongoDB | Kullanıcı onayı |
| Design language | F_AISUBCRIBE (Poppins + Deep Purple #6F31DA + flat + ThemeExtension) | Tolga standardı |
| UI/Feature-spesifik widget'lar | Kopyalanmaz (sadece design tokens + mimari) | Kullanıcı talimatı |

## Üretilen Dosyalar (31)

### core/
- `theme/uicolors.dart` (jenerik renkler — cinematic renkler çıkarılmış)
- `theme/app_text_styles.dart` (Poppins + ScreenUtil — cinematic stiller çıkarılmış)
- `theme/theme_extensions.dart` (AppSpacings, AppRadii, DataGridPalette, EditorPalette, ConnectionPalette)
- `theme/app_theme.dart` (light + dark; surfaceTint transparent fix; card elevation 0)
- `constants/app_constants.dart` (jenerik spacing/radius/elevation/opacity tokens)
- `responsive/screenutil_init.dart` (iPhone 14 Pro design size 390x844)
- `responsive/breakpoints.dart` (mobile <600, tablet <905, desktop ≥905)
- `responsive/adaptive_builder.dart` (AdaptiveLayoutBuilder widget)
- `utils/app_logger.dart` (logger wrapper)
- `utils/app_error.dart` (sealed AppFailure hiyerarşisi)
- `utils/isolate_helpers.dart` (computeSafe wrapper)

### domain/
- `database/capability.dart` (DatabaseCapability enum + DatabaseCapabilities)
- `database/connection.dart` (DatabaseKind, sealed DatabaseConnectionConfig, sealed DatabaseConnectionState, DatabaseConnection)
- `database/schema.dart` (abstract SchemaNode, DatabaseNode, CollectionNode, FieldNode, DataRow)
- `database/query.dart` (QueryLanguage, QueryRequest, QueryResult, QueryProgress, CompletionItem, CompletionContext)
- `database/database_provider.dart` (abstract DatabaseProvider interface + DatabaseProviderFactory)
- `ai/ai_provider.dart` (AiTask enum, AiRequest, AiCompletion, abstract AiQueryProvider)
- `ai/ai_context.dart` (ProviderLanguageHint, AiContext, DatabaseSchemaSummary, CollectionSchemaSummary, FieldSchemaSummary)
- `ai/query_intent.dart` (UserIntent value object)

### infrastructure/
- `storage/secure_connection_store.dart` (flutter_secure_storage wrapper)
- `storage/local_cache.dart` (Hive encrypted box + AES-GCM cipher)
- `storage/settings.dart` (SharedPreferences wrapper + AiMode enum)
- `registry/database_provider_registry.dart` (singleton, Map<DatabaseKind, Factory>)
- `registry/ai_provider_registry.dart` (singleton, List<AiQueryProvider>)
- `database_providers/mongodb/mongodb_provider.dart` (MongoDBProvider + Factory + capability set)
- `database_providers/mongodb/mongodb_connection.dart` (Phase 3 stub)
- `database_providers/mongodb/mongodb_schema.dart` (MongoDatabase, MongoCollection, MongoField, MongoIndex)
- `database_providers/mongodb/bson_codec.dart` (BsonValueType enum)
- `database_providers/mongodb/cursor_stream.dart` (Phase 3 stub)
- `ai_providers/disabled.dart` (default — always available, throws AiFailure)
- `ai_providers/local_llamacpp.dart` (Phase 7 stub)
- `ai_providers/ollama_remote.dart` (Phase 7 stub)
- `ai_providers/openai_compatible.dart` (Phase 7 stub)

### presentation/
- `theme_cubit.dart` (Cubit<ThemeMode>)
- `app_cubit.dart` (Cubit<AppState> — aiMode, aiModelPath, telemetryOptIn, historyTtlDays)
- `connection_cubit.dart` (Cubit<ConnectionState> — connection list, active)
- `ai_cubit.dart` (Cubit<AiState> — status, activeProviderId)
- `home/home_page.dart` (AdaptiveLayoutBuilder)
- `home/home_shell_desktop.dart` (3-panel: sidebar + explorer + workspace + AI drawer)
- `home/home_shell_mobile.dart` (bottom navigation + IndexedStack)
- `home/placeholder_panel.dart` (generic "Phase N" placeholder)
- `connections/connections_page.dart` (Phase 3 placeholder)
- `explorer/explorer_page.dart` (Phase 3 placeholder)
- `workspace/workspace_page.dart` (Phase 4 placeholder)
- `ai_assistant/ai_assistant_page.dart` (Phase 7 placeholder)
- `settings/settings_page.dart` (theme RadioGroup + AI mode chips)

### product/
- `app/app.dart` (MaterialApp.router + theme switch)
- `app/app_bootstrap.dart` (minimalInitialize + fullInitialize + buildAppRoot)
- `router/routes.dart` (path constants + labelFor)
- `router/app_router.dart` (GoRouter config + 6 routes)
- `router/route_guards.dart` (Phase 0 pass-through)
- `init/getIt/dependency_injection.dart` (GetItInjections orchestration)
- `init/getIt/modules/core_module.dart` (logger, ThemeCubit, ConnectionCubit)
- `init/getIt/modules/storage_module.dart` (AppSettings, SecureConnectionStore, LocalCache, AppCubit)
- `init/getIt/modules/database_module.dart` (DatabaseProviderRegistry)
- `init/getIt/modules/ai_module.dart` (AiProviderRegistry, AiCubit)
- `providers_registry/builtin.dart` (MongoDB + 4 AI provider factory registrations)

### root/
- `lib/main.dart` (entry → AppBootstrap)
- `pubspec.yaml` (final dependency set; AI binding deferred to Phase 7)
- `analysis_options.yaml` (flutter_lints + custom rules, ui_lints çıkarılmış)
- `README.md` (project description + Phase 0 status)
- `test/skeleton_smoke_test.dart` (7 tests: registry, capabilities, settings, profile, state)

## Kopyalanan / Adapte Edilen (F_AISUBCRIBE)

| F_AISUBCRIBE | db_explorer karşılığı | Not |
|---|---|---|
| `lib/core/ui/uicolors.dart` | `lib/core/theme/uicolors.dart` | Cinematic renkler çıkarılmış |
| `lib/core/constants/app_constants.dart` | `lib/core/constants/app_constants.dart` | Birebir (feature-spesifik alanlar çıkarılmış) |
| `lib/core/ui/app_text_styles.dart` | `lib/core/theme/app_text_styles.dart` | Cinematic stiller çıkarılmış |
| `lib/core/ui/theme_extensions.dart` (AppSpacings + AppRadii) | `lib/core/theme/theme_extensions.dart` | Aynı + DataGridPalette, EditorPalette, ConnectionPalette |
| `lib/core/ui/app_theme.dart` | `lib/core/theme/app_theme.dart` | F_AISUBCRIBE'e özel extension'lar çıkarılmış |
| `lib/core/theme/theme_cubit.dart` | `lib/presentation/theme_cubit.dart` | Aynı kalıp |
| `lib/main.dart` (entry) | `lib/main.dart` | Aynı yapı, sadeleştirilmiş |
| `lib/product/init/app_bootstrap.dart` (prensip) | `lib/product/app/app_bootstrap.dart` | Firebase/AdMob/HMAC çıkarılmış, Hive/GetIt/Registry eklenmiş |
| `lib/product/init/getIt/dependency_injection.dart` (modüler) | `lib/product/init/getIt/dependency_injection.dart` | 4 modül: core, storage, database, ai |
| `assets/fonts/google-poppins/` | `assets/fonts/google-poppins/` | Birebir kopyalandı (5 font + OFL.txt) |

## Kopyalanmayan (F_AISUBCRIBE feature-spesifik)

- `lib/core/widgets/AppCard`, `ProcessingView`, `GlassLoadingOverlay`, `AnimatedAuthHeaderWidget`, `CustomStepProgressIndicator`, `DashedRoundedBorder`, `StaggeredEntranceAnimation` (video subtitle feature)
- `lib/core/ui/show_app_dialog.dart`, `uihelper.dart` (F_AISUBCRIBE dialog formatları)
- `lib/core/ui/theme_extensions.dart` içindeki `TimelineColors`, `ExportScreenColors`
- `lib/feature/` (tüm feature klasörleri)
- `lib/product/services/` (Firebase, AdMob, FCM, RevenueCat, Dio, RemoteConfig)
- `lib/product/routes/` (custom Navigator — go_router ile değiştirildi)
- `assets/` (lottie, svg, png, video) — db_explorer'da placeholder icon'lar yeterli
- `pubspec.yaml` dependency_overrides

## Verification

- ✅ `flutter analyze` — zero issues
- ✅ `flutter test` — 7/7 smoke test passed
- ✅ `flutter build windows --debug` (kullanıcı tarafından doğrulandı)
- ✅ `flutter build chrome` (kullanıcı tarafından doğrulandı)

## Notlar

- `flutter_secure_storage` v10 encryptedSharedPreferences false (deprecated)
- `RadioListTile` deprecated → `RadioGroup` pattern (Flutter 3.32+)
- Sealed classes (schema.dart) abstract yapıldı (cross-library extension için)
- `type` field override fix (EditorPalette)
- Bootstrapping logger prefix'leri: `bootstrap`, `app`
- AI default provider: `DisabledProvider` (always available, throws AiFailure)
- Database default provider: `MongoDBProviderFactory`
