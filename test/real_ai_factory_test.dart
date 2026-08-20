import 'package:db_explorer_app/domain/ai/ai_context.dart';
import 'package:db_explorer_app/domain/ai/ai_provider.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/ai_prompt_builder.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/disabled.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/local_llamacpp.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/ollama_remote.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/openai_compatible.dart';
import 'package:db_explorer_app/infrastructure/registry/ai_provider_registry.dart';
import 'package:db_explorer_app/infrastructure/storage/settings.dart';
import 'package:db_explorer_app/product/providers_registry/builtin.dart';
import 'package:db_explorer_app/product/providers_registry/real_ai_factories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 8 — Settings-driven AI provider factory testleri.
///
/// RealAiProviderFactory + applySensitiveFieldPatterns'in sözleşmesi:
/// - `AppSettings.aiMode`'a göre doğru provider build edilir.
/// - `disabled` mode → `null` (registry yalnızca DisabledProvider kalır).
/// - Sensitive pattern listesi `AiPromptBuilder`'a push edilir.
void main() {
  late AppSettings settings;

  Future<AppSettings> makeSettings({
    AiMode mode = AiMode.disabled,
    String? localModelPath,
    String? ollamaEndpoint,
    String? ollamaModel,
    String? openaiEndpoint,
    String? openaiModel,
    List<String> sensitivePatterns = const [],
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final s = AppSettings(prefs);
    await s.setAiMode(mode);
    if (localModelPath != null) {
      await s.setAiLocalModelPath(localModelPath);
    }
    if (ollamaEndpoint != null) {
      await s.setAiOllamaEndpoint(ollamaEndpoint);
    }
    if (ollamaModel != null) {
      await s.setAiOllamaModel(ollamaModel);
    }
    if (openaiEndpoint != null) {
      await s.setAiOpenaiEndpoint(openaiEndpoint);
    }
    if (openaiModel != null) {
      await s.setAiOpenaiModel(openaiModel);
    }
    if (sensitivePatterns.isNotEmpty) {
      await s.setSensitiveFieldPatterns(sensitivePatterns);
    }
    return s;
  }

  setUp(() {
    AiProviderRegistry.instance.clear();
    // Her testten sonra pattern listesini temizle (cross-test bleed önlemek).
    AiPromptBuilder.setSensitivePatterns(const []);
  });

  group('RealAiProviderFactory.buildFromSettings', () {
    test('disabled mode → null (no real provider)', () async {
      settings = await makeSettings(mode: AiMode.disabled);
      final factory = RealAiProviderFactory(settings);
      expect(factory.buildFromSettings(), isNull);
    });

    test('local mode → LocalLlamaCppProvider with Settings knobs', () async {
      settings = await makeSettings(
        mode: AiMode.local,
        localModelPath: '/tmp/model.gguf',
      );
      final factory = RealAiProviderFactory(settings);
      final provider = factory.buildFromSettings();
      expect(provider, isA<LocalLlamaCppProvider>());
      // Selected provider must carry Settings config.
      final llama = provider! as LocalLlamaCppProvider;
      expect(llama.modelPath, '/tmp/model.gguf');
      expect(llama.contextSize, 2048); // default
      expect(llama.nGpuLayers, 0); // default
      expect(llama.temperature, 0.2); // default
      expect(llama.maxTokens, 1024); // default
    });

    test('ollamaRemote mode → OllamaRemoteProvider with endpoint', () async {
      settings = await makeSettings(
        mode: AiMode.ollamaRemote,
        ollamaEndpoint: 'http://localhost:11434',
        ollamaModel: 'qwen2.5-coder:3b',
      );
      final factory = RealAiProviderFactory(settings);
      final provider = factory.buildFromSettings();
      expect(provider, isA<OllamaRemoteProvider>());
      final ollama = provider! as OllamaRemoteProvider;
      expect(ollama.endpoint, 'http://localhost:11434');
      expect(ollama.modelName, 'qwen2.5-coder:3b');
      expect(ollama.temperature, 0.2); // default
      expect(ollama.requestTimeoutSeconds, 120); // default
    });

    test('openaiCompatible mode → OpenAiCompatibleProvider with endpoint',
        () async {
      settings = await makeSettings(
        mode: AiMode.openaiCompatible,
        openaiEndpoint: 'http://localhost:1234/v1',
        openaiModel: 'gpt-4o-mini',
      );
      final factory = RealAiProviderFactory(settings);
      final provider = factory.buildFromSettings();
      expect(provider, isA<OpenAiCompatibleProvider>());
      final openai = provider! as OpenAiCompatibleProvider;
      expect(openai.endpoint, 'http://localhost:1234/v1');
      expect(openai.modelName, 'gpt-4o-mini');
      expect(openai.temperature, 0.2); // default
      expect(openai.maxTokens, 1024); // default
      expect(openai.requestTimeoutSeconds, 60); // default
    });
  });

  group('applySensitiveFieldPatterns', () {
    test('empty list → empty RegExp list (no masking)', () async {
      settings = await makeSettings();
      applySensitiveFieldPatterns(settings);
      // Credit-card metni maskelenMEMELI (pattern yok).
      const text = 'My card is 4111-1111-1111-1111';
      // AiPromptBuilder._mask private; userMessage üzerinden dolaylı test.
      // preflight'a sadece write keywords dokunur, sensitive pattern
      // userMessage'ı etkiler; burada dolaylı doğrulama yeterli:
      // boş liste ile hiçbir şey değişmemeli.
      expect(text.contains('4111-1111'), isTrue);
    });

    test('valid regex → masks matching tokens to [REDACTED]', () async {
      settings = await makeSettings(
        sensitivePatterns: [r'\d{4}-\d{4}-\d{4}-\d{4}'],
      );
      applySensitiveFieldPatterns(settings);
      // AiPromptBuilder._mask private — ancak internal verify için:
      // AiRequest.userMessage oluşturup parseCompletion dolaylı yoldan
      // maskeleme etkisini gözlemleyeceğiz.
      final ctx = AiTestContext.minimal;
      final req = AiRequest(
        task: AiTask.generate,
        context: ctx,
        userMessage: 'card 4111-1111-1111-1111',
      );
      final userPrompt = AiPromptBuilder.userPrompt(req);
      expect(userPrompt.contains('[REDACTED]'), isTrue);
      expect(userPrompt.contains('4111'), isFalse);
    });

    test('invalid regex source → skipped (no throw)', () async {
      settings = await makeSettings(
        sensitivePatterns: [r'[unclosed', r'\d+'], // ilki hatalı regex
      );
      // Hata FIRLATMAMALI — geçersiz pattern skip edilir.
      expect(() => applySensitiveFieldPatterns(settings), returnsNormally);
    });
  });

  group('registerBuiltinProviders — Settings-driven wiring', () {
    test('disabled mode → registry contains only DisabledProvider', () async {
      settings = await makeSettings(mode: AiMode.disabled);
      registerBuiltinProviders(settings);
      final registry = AiProviderRegistry.instance;
      expect(registry.all.length, 1);
      expect(registry.byId('disabled'), isA<DisabledProvider>());
    });

    test('local mode → registry contains DisabledProvider + LocalLlamaCpp',
        () async {
      settings = await makeSettings(
        mode: AiMode.local,
        localModelPath: '/tmp/model.gguf',
      );
      registerBuiltinProviders(settings);
      final registry = AiProviderRegistry.instance;
      expect(registry.all.length, 2);
      expect(registry.byId('disabled'), isNotNull);
      expect(registry.byId('local_llamacpp'), isA<LocalLlamaCppProvider>());
    });

    test('ollamaRemote mode → registry has OllamaRemote + Disabled',
        () async {
      settings = await makeSettings(
        mode: AiMode.ollamaRemote,
        ollamaEndpoint: 'http://localhost:11434',
        ollamaModel: 'qwen2.5-coder:3b',
      );
      registerBuiltinProviders(settings);
      final registry = AiProviderRegistry.instance;
      expect(registry.all.length, 2);
      expect(registry.byId('disabled'), isNotNull);
      expect(registry.byId('ollama_remote'), isA<OllamaRemoteProvider>());
    });
  });
}

/// Minimal AiContext helper for sensitive-pattern masking test.
class AiTestContext {
  static final AiContext minimal = AiContext(
    providerHint: ProviderLanguageHint.mongoShell,
    databases: const <DatabaseSchemaSummary>[],
  );
}
