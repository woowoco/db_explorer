import 'package:db_explorer_app/domain/ai/ai_provider.dart';
import 'package:db_explorer_app/core/utils/app_error.dart';

/// Ollama remote provider — Phase 7+ stub.
///
/// Ollama HTTP API'si üzerinden uzak sunucuda çalışan modeli kullanır.
/// SSE streaming response. Phase 0'da stub.
class OllamaRemoteProvider implements AiQueryProvider {
  const OllamaRemoteProvider();

  @override
  String get id => 'ollama_remote';

  @override
  String get label => 'Ollama (remote)';

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<AiCompletion> complete(
    AiRequest request, {
    void Function()? onCancelSetup,
  }) async {
    throw const AiFailure(
      'Ollama remote binding not yet implemented. Phase 7.',
    );
  }
}
