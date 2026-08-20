import 'package:db_explorer_app/domain/ai/ai_context.dart';
import 'package:equatable/equatable.dart';

/// AI Query Copilot görev tipleri.
///
/// `generate`: doğal dil → sorgu oluştur.
/// `modify`: mevcut sorguyu değiştir (refactor / parametre değişikliği).
/// `explain`: sorgunun ne yaptığını açıkla.
/// `optimize`: sorguyu optimize et (index önerisi, vs.).
/// `fix`: hatalı sorguyu düzelt.
enum AiTask { generate, modify, explain, optimize, fix }

extension AiTaskLabel on AiTask {
  String get label => switch (this) {
    AiTask.generate => 'Generate',
    AiTask.modify => 'Modify',
    AiTask.explain => 'Explain',
    AiTask.optimize => 'Optimize',
    AiTask.fix => 'Fix',
  };
}

/// AI provider'a gönderilen istek.
class AiRequest extends Equatable {
  const AiRequest({
    required this.task,
    required this.context,
    required this.userMessage,
    this.existingQuery,
    this.errorMessage,
  });

  final AiTask task;

  /// Schema-only context (NO document values, NO credentials).
  final AiContext context;

  /// Kullanıcının doğal dil mesajı.
  final String userMessage;

  /// Modify / explain / optimize / fix için var olan sorgu.
  final String? existingQuery;

  /// Fix için error mesajı.
  final String? errorMessage;

  @override
  List<Object?> get props => [task, context, userMessage, existingQuery, errorMessage];
}

/// AI completion response.
class AiCompletion extends Equatable {
  const AiCompletion({
    required this.message,
    required this.suggestedQuery,
    required this.explanation,
    this.warnings = const [],
  });

  /// AI'ın açıklayıcı mesajı.
  final String message;

  /// Önerilen sorgu (varsa).
  final String suggestedQuery;

  /// Açıklama (explain task için).
  final String explanation;

  /// Güvenlik / uyarı mesajları (örn. "Bu sorgu tüm dokümanları siler!").
  final List<String> warnings;

  @override
  List<Object?> get props => [message, suggestedQuery, explanation, warnings];
}

/// AI provider abstract interface.
///
/// Önemli kısıtlar (brief madde 10, 11, 14):
/// - AI asla otomatik execute etmez; sadece öneri üretir.
/// - AI asla INSERT/UPDATE/DELETE/DROP/ALTER/CREATE INDEX gibi write/DDL
///   üretmez; sadece read-only sorgular (SELECT/FIND/AGGREGATE/EXPLAIN).
/// - Database credentials AI context'ine ASLA dahil edilmez.
/// - AI context = schema-only (field names, types, indexes; document
///   values veya satır içerikleri DAHİL EDİLMEZ).
///
/// Phase 0'da sadece interface; gerçek implementasyonlar Phase 7+
/// (local_llamacpp, ollama_remote, openai_compatible, disabled).
abstract interface class AiQueryProvider {
  /// Provider identifier (registry key). Örn. 'local_llamacpp', 'ollama'.
  String get id;

  /// Human-readable ad.
  String get label;

  /// Provider'ın kullanılabilir olup olmadığı (model yüklendi mi, vb.).
  Future<bool> isAvailable();

  /// Completion üret.
  ///
  /// [cancelToken] ile AI iptal edilebilir (kullanıcı "Stop"a bastığında).
  Future<AiCompletion> complete(
    AiRequest request, {
    void Function()? onCancelSetup,
  });
}
