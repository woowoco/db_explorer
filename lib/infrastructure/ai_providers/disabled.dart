import 'package:db_explorer_app/domain/ai/ai_provider.dart';
import 'package:db_explorer_app/core/utils/app_error.dart';

/// AI kapalı provider — her şeyi no-op, error döner.
///
/// Default provider olarak kullanılır. Kullanıcı Ayarlar'dan AI'ı
/// açarsa (Local / Ollama / OpenAI) registry sırası değişir ve bu
/// provider skip edilir.
class DisabledProvider implements AiQueryProvider {
  const DisabledProvider();

  @override
  String get id => 'disabled';

  @override
  String get label => 'AI Disabled';

  @override
  Future<bool> isAvailable() async => true; // her zaman "mevcut" — sadece kapalı

  @override
  Future<AiCompletion> complete(
    AiRequest request, {
    void Function()? onCancelSetup,
  }) async {
    throw const AiFailure(
      'AI is disabled. Enable AI in Settings to use the Query Copilot.',
    );
  }
}
