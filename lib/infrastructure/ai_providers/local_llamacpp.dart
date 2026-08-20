import 'package:db_explorer_app/domain/ai/ai_provider.dart';
import 'package:db_explorer_app/core/utils/app_error.dart';

/// Local llama.cpp provider — Phase 7+ stub.
///
/// Qwen2.5-Coder-3B-Instruct Q4_K_M (veya 7B) llama.cpp modelini
/// FFI binding (llamadart veya llm_llamacpp) üzerinden çalıştırır.
/// Phase 0'da stub.
class LocalLlamaCppProvider implements AiQueryProvider {
  const LocalLlamaCppProvider();

  @override
  String get id => 'local_llamacpp';

  @override
  String get label => 'Local (llama.cpp)';

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<AiCompletion> complete(
    AiRequest request, {
    void Function()? onCancelSetup,
  }) async {
    throw const AiFailure(
      'Local llama.cpp binding not yet implemented. Phase 7.',
    );
  }
}
