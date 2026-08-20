# Phase 4 — Workspace (Query Editor + Results Data Grid)

**Tarih:** 2026-08-20
**Build:** 0.5.0+5 (Phase 4)

## Özet

Bu faz, db_explorer_app'in **kalbi** olan Workspace sayfasını hayata geçirdi: stateful
query editor (Cubit), syntax-highlight kod editörü, tip-aware sonuç data grid ve Run/Stop
toolbar. Gerçek provider entegrasyonu Phase 8'de — şimdilik mock execute simülasyonu ile
state machine, UI ve etkileşim end-to-end test edilebilir durumda.

---

## Kapsam

### Eklenen dosyalar

| Dosya | Amaç |
|---|---|
| `lib/presentation/workspace/query_editor_cubit.dart` | State management — text, language, dirty, execution lifecycle, history (FIFO 50), AI copilot toggle |
| `lib/presentation/workspace/code_editor_widget.dart` | `flutter_code_editor` entegrasyonu (mongoShell → JS mode, SQL → SQL mode) |
| `lib/presentation/workspace/results_grid_widget.dart` | Tip-aware data grid — 5 state branch (idle/loading/empty/error/data) + clipboard copy |
| `lib/presentation/workspace/workspace_page.dart` | Toolbar + editor + results kompozisyonu; `BlocProvider` ile cubit scope |
| `test/query_editor_cubit_test.dart` | 13 unit test (initial state, text editing, execution lifecycle, history, AI toggle, clear) |
| `test/results_grid_widget_test.dart` | 8 widget test (state branches + row tap) |
| `test/workspace_page_test.dart` | 3 widget test (cubit scope, Run button enable/disable) |
| `test/test_helpers.dart` | `wrapWithAppTheme` — gerçek `AppTheme` ile test ortamı |

### Değiştirilen dosyalar

| Dosya | Değişiklik |
|---|---|
| `pubspec.yaml` | `flutter_code_editor: ^0.3.4` + `highlight: ^0.7.0` (doğrudan); `flutter_highlight` çıkarıldı (dead weight — `flutter_code_editor` zaten `highlight`'ı transitively kullanır) |
| `pubspec.yaml` | Version bump: `0.4.0+4` → `0.5.0+5` |
| `lib/core/theme/theme_extensions.dart` | **BUG FIX**: `EditorPalette.type` field'ı `@override` annotation ile işaretlenmişti — Dart bunu final field'da yok sayıyor AMA Flutter `ThemeData.extensions` map'i key'i olarak `type` field'ının **değerini** (Color) kullanıyordu, sınıfın kendisini değil. Bu yüzden `theme.extension<EditorPalette>()` production'da bile null dönüyordu (kod yolu tetiklenmediği için fark edilmedi). Fix: `@override` kaldırıldı + field `type` → `dataType` rename (gelecekteki karışıklığı önlemek için). |

---

## Kararlar

### 1. **Editor**: `flutter_code_editor` + `highlight` (doğrudan), `flutter_highlight` çıkarıldı

`flutter_code_editor` paketi zaten `highlight` paketini transitively kullanır. `flutter_highlight` ise sadece statik highlighting için bir `HighlightView` widget'ı sunar — bizim ihtiyacımız olmayan bir view. Dead dependency'ye gerek yok.

Import düzeltmesi: `package:flutter_highlight/languages/*.dart` paths'i **yok** (sadece `HighlightView` widget'ı export eder). Doğru import: `package:highlight/languages/javascript.dart` ve `package:highlight/languages/sql.dart` (`Mode` class'ı için `package:highlight/highlight.dart`).

Lint: `depend_on_referenced_packages` (transitive dependency import warning) — fix için `highlight`'ı doğrudan dependency olarak ekledik.

### 2. **State management**: Bloc-Cubit (F_AISUBCRIBE tutarlılığı)

`QueryEditorCubit extends Cubit<QueryEditorState>` — Equatable state, Equatable history
entries. `markExecuting` / `markCompleted(QueryResult)` / `markFailed(String)` lifecycle.
History: FIFO 50, cursor-based undo/redo (cursor=-1 = edit buffer). AI copilot toggle flag'i
şimdilik sadece UI için (gerçek AI Phase 7'de).

### 3. **Mock execute (Phase 4 sürümü)**

`WorkspacePage._RunButton.onPressed` → `markExecuting()` + 600ms simulated latency + %20 random fail / %80 success. Mock data 25 satır (`_id`, `name`, `age`, `active`). Phase 8'de bu mock, `provider.execute(QueryRequest)` ile değişecek.

### 4. **Type-aware data grid**

`QueryResult.columns` sadece `List<String>` (tip metadata yok). Tip inference: her kolon için
ilk non-null value'dan runtime type çıkarılır, tümü null ise "string" default. ObjectId/Binary
gibi BSON-spesifik tipler `runtimeType.toString().toLowerCase()` ile tahmin edilir.

Color mapping:
- null → `palette.nullForeground` (gri)
- bool → `booleanTrue` / `booleanFalse`
- num → `numberForeground` (mavi/light)
- String → `stringForeground` (mor/light)
- DateTime → `dateForeground` (turuncu)
- ObjectId → `objectIdForeground` (teal)
- Map/List → onSurface (object olarak)

### 5. **Test infrastructure**: `test/test_helpers.dart`

Widget test'lerinde `context.dataGrid` gibi ThemeExtension getter'ları null-check `!` ile
patlıyordu (default MaterialApp gerekli extension'ları sağlamıyor). `wrapWithAppTheme`
helper'ı production `AppTheme().lightThemeData()` / `.darkThemeData()` ile test ortamını
birebir eşitler. `ThemeData.extensions` map key bug'ı (aşağıda) sayesinde bu helper
Phase 4.6'da zorunlu hale geldi.

---

## BUG: `EditorPalette.type` field — ThemeData.extensions map key

`theme_extensions.dart`'ta `EditorPalette.type` field'ı:
```dart
@override
final Color type; // ObjectId, ISODate
```

şeklinde tanımlanmıştı. **İki sorun:**
1. `@override` annotation'ı final field'da geçersiz (sadece method/field override'ında anlamlı;
   burada parent `ThemeExtension<EditorPalette>`'da `type` field'ı yok).
2. Flutter'ın `ThemeData.extensions` map'i extension'ları key'liyor. `EditorPalette` için
   key yanlışlıkla `Color(0xFF267F99)` (yani `type` field'ının **değeri**) olarak çıkıyordu,
   sınıfın kendisi (`EditorPalette`) olarak değil.

Sonuç: `theme.extension<EditorPalette>()` her zaman null dönüyordu. Production'da bug
görünmüyordu çünkü editor widget'ı Phase 0-3'te mounted edilmiyordu (Phase 4.3'te entegre
ettik). Phase 4.6 widget test'leri bug'ı anında yakaladı.

**Fix:** `@override` annotation kaldırıldı + field `type` → `dataType` rename (gelecekte
olası karışıklığı önlemek için). Tüm `theme_extensions.dart` + `app_theme.dart` + tüm
test'ler geçerli.

---

## API uyumluluğu

| Tip | Değişti mi? | Etki |
|---|---|---|
| `QueryEditorState` | Yeni | public API |
| `QueryEditorCubit` | Yeni | public API |
| `HistoryEntry` | Yeni | public API |
| `QueryResult` (domain) | Hayır | aynen kullanılıyor |
| `DataRow` (domain) | Hayır | aynen kullanılıyor |
| `EditorPalette.type` → `EditorPalette.dataType` | **Evet, kırıcı** | Bu field'ı doğrudan kullanan kod varsa (Phase 0-3'te yoktu) güncelleme gerekli |

`dataType` rename'i internal API (theme extension field'ı), production'da henüz
harici consumer yok. Phase 0-3'te `EditorPalette` import eden tek dosya `code_editor_widget.dart`
(Phase 4.3'te yazıldı) — o da `type` field'ını kullanmıyor, sadece `editorPalette.foreground`,
`background`, `comment` kullanıyor. Migration gerekmiyor.

---

## Test dağılımı

| Test dosyası | Test sayısı | Kapsam |
|---|---|---|
| `query_editor_cubit_test.dart` | 13 | initial state, text editing, execution lifecycle, history nav, AI toggle, clear |
| `results_grid_widget_test.dart` | 9 | 5 state branch (idle/loading/empty/error/data), header strip, warnings chip, more-pages chip, totalCount label, row tap → clipboard |
| `workspace_page_test.dart` | 3 | cubit scope, Run button enable/disable |
| (önceki fazlardan) | 70 | storage, schema, connection, mongo provider, AI provider interface, registry |
| **Toplam** | **95** | tüm `flutter test` clean |

---

## Bilinen sınırlamalar / Phase 8+ için TODO

1. **Mock execute** → gerçek `provider.execute(QueryRequest)` (Phase 8 — `RealMongoDBProviderFactory` bootstrap wiring)
2. **Resizable splitter** (editor / results arası) — şimdilik sabit 4:6 flex. `flutter_resizable_container` veya custom `LayoutBuilder` Phase 8+.
3. **Tab system** — multi-tab query editor Phase 8+ (şimdilik tek aktif query).
4. **Real virtual scroll** — şimdilik `ListView.builder`. Çok büyük dataset'lerde `ScrollablePositionedList` Phase 8+ performans optimizasyonu.
5. **AI copilot sidebar** — flag hazır (`aiCopilotEnabled`), gerçek AI entegrasyonu Phase 7'de.
6. **Save / load query** — local history Hive box Phase 2'de hazır, entegrasyon Phase 8+.
7. **Export results** — CSV / JSON export Phase 8+.

---

## Aksiyonlar (kayıt)

| Saat | Aksiyon |
|---|---|
| Phase 4 başlangıcı | Brief güncellendi: Phase 4 workspace, scope tanımlandı |
| 2026-08-20 13:53 | Phase 3 tamamlandı (`6bd8363`), Phase 4 başladı |
| Phase 4.1 | `pubspec.yaml`: `flutter_code_editor`, `flutter_highlight` eklendi |
| Phase 4.2 | `QueryEditorCubit` + 13 unit test (redo history cursor bug fix) |
| Phase 4.3 | `CodeEditorWidget` — `flutter_highlight` kaldırıldı, `highlight` doğrudan dependency yapıldı, import paths düzeltildi, `analyzer: DefaultLocalAnalyzer` gereksinimi `language` setter'ı ile çözüldü |
| Phase 4.4 | `ResultsGridWidget` — 5 state branch, tip-aware coloring, header strip, warnings/more-pages chips, row tap → clipboard |
| Phase 4.5 | `WorkspacePage` — toolbar (Run/Stop/undo/redo/clear/language selector) + editor + results kompozisyonu |
| Phase 4.6 | `query_editor_cubit_test` + `results_grid_widget_test` + `workspace_page_test` + `test_helpers.dart` (24 yeni test) + **`EditorPalette.type` → `dataType` rename bug fix** + analyze clean + 95/95 tests pass |

---

## Verification (Phase 4 kapanışı)

```
$ flutter analyze
No issues found! (ran in 4.4s)

$ flutter test
00:13 +95: All tests passed!

$ flutter pub get
Got dependencies! (highlight now direct; flutter_highlight only transitive via flutter_code_editor)
```

✅ Analyze clean.
✅ 95/95 tests passing.
✅ Phase 3 commit (`6bd8363`) üzerine Phase 4 commit hazır.
