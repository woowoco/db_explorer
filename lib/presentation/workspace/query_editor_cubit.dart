import 'package:db_explorer_app/domain/database/query.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Workspace query editor state.
///
/// Tek bir "çalıştırılan / çalıştırılacak" query bloğunu temsil eder:
/// metin, dil, dirty flag, son execution result, history navigation, AI
/// copilot toggle.
class QueryEditorState extends Equatable {
  const QueryEditorState({
    required this.text,
    required this.language,
    required this.dirty,
    this.lastResult,
    this.lastError,
    this.isExecuting = false,
    this.aiCopilotEnabled = false,
    this.historyCursor = -1,
    this.history = const [],
  });

  /// Editor metni.
  final String text;

  /// Aktif dil (syntax highlight + parser dispatch).
  final QueryLanguage language;

  /// Text, son kaydedilen/savedHistory'den farklı mı?
  final bool dirty;

  /// Son başarılı execute sonucu.
  final QueryResult? lastResult;

  /// Son başarısız execute hatası (display için).
  final String? lastError;

  /// Şu anda provider.execute() çalışıyor mu?
  final bool isExecuting;

  /// AI copilot sidebar açık mı?
  final bool aiCopilotEnabled;

  /// History navigation cursor (-1 = current edit buffer).
  final int historyCursor;

  /// History snapshot'ları (en yeni başta).
  final List<HistoryEntry> history;

  /// History'de geri gidilebilir mi?
  bool get canUndoHistory => historyCursor < history.length - 1;

  /// History'de ileri gidilebilir mi? (cursor=-1 = edit buffer; burada redo yok)
  bool get canRedoHistory => historyCursor >= 0;

  /// Empty result mı?
  bool get hasResult => lastResult != null || lastError != null;

  QueryEditorState copyWith({
    String? text,
    QueryLanguage? language,
    bool? dirty,
    QueryResult? lastResult,
    bool clearLastResult = false,
    String? lastError,
    bool clearLastError = false,
    bool? isExecuting,
    bool? aiCopilotEnabled,
    int? historyCursor,
    List<HistoryEntry>? history,
  }) {
    return QueryEditorState(
      text: text ?? this.text,
      language: language ?? this.language,
      dirty: dirty ?? this.dirty,
      lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      isExecuting: isExecuting ?? this.isExecuting,
      aiCopilotEnabled: aiCopilotEnabled ?? this.aiCopilotEnabled,
      historyCursor: historyCursor ?? this.historyCursor,
      history: history ?? this.history,
    );
  }

  @override
  List<Object?> get props => [
    text,
    language,
    dirty,
    lastResult,
    lastError,
    isExecuting,
    aiCopilotEnabled,
    historyCursor,
    history,
  ];
}

/// History'de saklanan snapshot.
class HistoryEntry extends Equatable {
  const HistoryEntry({
    required this.text,
    required this.language,
    required this.savedAt,
  });

  final String text;
  final QueryLanguage language;
  final DateTime savedAt;

  @override
  List<Object?> get props => [text, language, savedAt];
}

/// QueryEditor Cubit — workspace'in kalbi.
///
/// Tek bir workspace instance'ı için state yönetimi. Connection list ile
/// değil, sadece editör + result state'i ile ilgilenir.
class QueryEditorCubit extends Cubit<QueryEditorState> {
  QueryEditorCubit({
    String initialText = '',
    QueryLanguage language = QueryLanguage.mongoShell,
  }) : super(QueryEditorState(
          text: initialText,
          language: language,
          dirty: false,
        ));

  /// Editor metni değişti (typing event).
  void updateText(String newText) {
    if (newText == state.text) return;
    emit(state.copyWith(text: newText, dirty: true));
  }

  /// Dil değişti (UI selector).
  void setLanguage(QueryLanguage lang) {
    if (lang == state.language) return;
    emit(state.copyWith(language: lang, dirty: true));
  }

  /// AI copilot toggle.
  void toggleAiCopilot() {
    emit(state.copyWith(aiCopilotEnabled: !state.aiCopilotEnabled));
  }

  /// Execute başladı (provider çağrılmadan önce).
  void markExecuting() {
    emit(state.copyWith(
      isExecuting: true,
      clearLastError: true,
    ));
  }

  /// Execute tamamlandı (sonuçla birlikte).
  void markCompleted(QueryResult result) {
    final entry = HistoryEntry(
      text: state.text,
      language: state.language,
      savedAt: DateTime.now(),
    );
    final newHistory = [entry, ...state.history];
    emit(state.copyWith(
      lastResult: result,
      clearLastError: true,
      isExecuting: false,
      dirty: false,
      history: newHistory.take(50).toList(),
      historyCursor: -1, // current edit buffer'a dön
    ));
  }

  /// Execute hata verdi.
  void markFailed(String error) {
    emit(state.copyWith(
      clearLastResult: true,
      lastError: error,
      isExecuting: false,
    ));
  }

  /// History'de geri git (önceki snapshot'a dön).
  void undoHistory() {
    if (!state.canUndoHistory) return;
    final nextCursor = state.historyCursor < 0
        ? 0
        : state.historyCursor + 1;
    final entry = state.history[nextCursor];
    emit(state.copyWith(
      text: entry.text,
      language: entry.language,
      historyCursor: nextCursor,
      dirty: false,
    ));
  }

  /// History'de ileri git (cursor'ı edit buffer'a doğru geri getir).
  void redoHistory() {
    if (!state.canRedoHistory) return;
    final nextCursor = state.historyCursor - 1;
    if (nextCursor < 0) {
      // Edit buffer'a dön
      emit(state.copyWith(historyCursor: -1));
      return;
    }
    final entry = state.history[nextCursor];
    emit(state.copyWith(
      text: entry.text,
      language: entry.language,
      historyCursor: nextCursor,
      dirty: false,
    ));
  }

  /// Editor'ü temizle (history korunur).
  void clearEditor() {
    emit(state.copyWith(
      text: '',
      dirty: false,
      clearLastResult: true,
      clearLastError: true,
      historyCursor: -1,
    ));
  }
}