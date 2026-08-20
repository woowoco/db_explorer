# db_explorer_app

**Extensible Cross-Platform Database Workbench + AI Query Assistant.**

Flutter cross-platform database workbench. İlk provider MongoDB; PostgreSQL, Redis, Elasticsearch sonraki fazlarda eklenebilecek **extensible provider-based** mimari. Çekirdek farklılaştırıcı özellik **AI Query Assistant** (Query Workspace'in doğal parçası; autonomous agent değil — Query Copilot pattern).

> Hedef platformlar: Windows / macOS / Linux desktop + Android / iOS mobile.
> Release stratejisi: önce kendi kullanım + stabil MVP; public release mimari gereksinimleri şimdiden düşünülmüştür.

---

## Phase 0 — Skeleton (current)

Phase 0 tamamlandığında:

- ✅ Compile-clean, tüm platform'larda build edilebilir (Android/iOS/Windows/macOS/Linux).
- ✅ F_AISUBCRIBE design language (Poppins + Deep Purple `#6F31DA` + flat + ThemeExtension).
- ✅ Bloc-Cubit state management + GetIt modular DI + go_router adaptive shell.
- ✅ Database provider registry (MongoDB factory MVP; Postgres/Redis/Elasticsearch sonraki fazlar).
- ✅ AI provider registry (4 stub provider; gerçek llama.cpp binding Phase 7).
- ✅ Encrypted storage (flutter_secure_storage + Hive AES-GCM cipher).
- ✅ Settings persistence (SharedPreferences).

### Mimari katmanlar

```
lib/
├── core/           # Cross-cutting (theme, responsive, utils)
├── domain/         # Saf abstractions (database, ai)
├── infrastructure/ # Provider implementations (mongodb, ai_providers, storage, registry)
├── presentation/   # UI + Cubits (home shell + placeholder pages)
├── product/        # Bootstrap (app, di, router, providers_registry)
└── main.dart
```

### Theme System

`UIColors` (renkler), `AppConstants` (spacing/radius), `AppTextStyles` (Poppins stiller), `AppTheme` (light/dark), `ThemeExtensions` (`AppSpacings`, `AppRadii`, `DataGridPalette`, `EditorPalette`, `ConnectionPalette`).

`BuildContext` extension'ları: `context.spacing`, `context.radius`, `context.dataGrid`, `context.editor`, `context.connection`.

**AI-slop fix korundu**: `surfaceTint: Colors.transparent` + `cardTheme.elevation: 0` + Material 3 flat.

---

## Running

```bash
flutter pub get
flutter run                # default target
flutter run -d windows      # Windows desktop
flutter run -d emulator-5554  # Android emulator
```

## Verification (Phase 0)

```bash
flutter analyze         # zero issues hedefi
flutter test            # skeleton smoke test
flutter build apk --debug
flutter build windows --debug
```

## Project Documents

- Brief: [`CHANGELOGS/start-prompt.md`](CHANGELOGS/start-prompt.md) — 33-maddelik ürün spec.
- Research report: [`CHANGELOGS/RESEARCH-REPORT-2026-08-20.md`](CHANGELOGS/RESEARCH-REPORT-2026-08-20.md) — 17-bölümlük teknik araştırma raporu.
- Phase 0 plan: `~/.claude/plans/curious-prancing-biscuit.md` (Claude planları).

## Architecture Decisions

1. **State management**: Bloc-Cubit (F_AISUBCRIBE tutarlılığı).
2. **DI**: GetIt modular (F_AISUBCRIBE pattern).
3. **Routing**: go_router + adaptive shell.
4. **Local AI**: Qwen2.5-Coder-3B-Instruct Q4_K_M (Phase 7+); mimari 7B'ye açık.
5. **MVP provider**: MongoDB.
6. **AI Safety**: Read-only queries. AI asla otomatik execute etmez. Schema-only context (no values, no credentials).

---

Built by Tolga. Phase 0 skeleton — v0.1.0+1.
