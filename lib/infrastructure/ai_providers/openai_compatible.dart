import 'package:db_explorer_app/domain/ai/ai_provider.dart';
import 'package:db_explorer_app/core/utils/app_error.dart';

/// OpenAI-compatible HTTP provider — Phase 7+ stub.
///
/// OpenAI API'si veya LM Studio / oobabooga / vs. local server'lar
/// (OpenAI uyumlu) için jenerik HTTP provider. Phase 0'da stub.
class OpenAiCompatibleProvider implements AiQueryProvider {
  const OpenAiCompatibleProvider();

  @override
  String get id => 'openai_compatible';

  @override
  String get label => 'OpenAI-compatible';

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<AiCompletion> complete(
    AiRequest request, {
    void Function()? onCancelSetup,
  }) async {
    throw const AiFailure(
      'OpenAI-compatible binding not yet implemented. Phase 7.',
    );
  }
}
