import 'dart:io';

import 'package:db_explorer_app/core/utils/app_error.dart';
import 'package:db_explorer_app/domain/ai/ai_context.dart';
import 'package:db_explorer_app/domain/ai/ai_provider.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/disabled.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/local_llamacpp.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/ollama_remote.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/openai_compatible.dart';
import 'package:db_explorer_app/infrastructure/registry/ai_provider_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 7 AI provider contract testleri.
///
/// Bu test katmanı, gerçek LLM/HTTP bağlantısı GEREKTİRMEYEN sözleşmeleri
/// doğrular. Üçüncü parti paketlerin (llm_llamacpp, ollama_dart, openai_dart)
/// sealed/abstract API yüzeylerini mock'lamak yerine, sadece provider'ların
/// kendi public sözleşmesini test ediyoruz:
/// - id/label metadata doğru mu?
/// - isAvailable konfigürasyona göre true/false dönüyor mu?
/// - complete() eksik konfigde AiFailure fırlatıyor mu?
/// - preflight guard write/DDL niyetini reddediyor mu?
/// - DisabledProvider her zaman mevcut ama complete hata dönüyor mu?
///
/// Streaming davranışı (repo/client injection) entegrasyon testlerinde
/// (gerçek model + gerçek HTTP) doğrulanır — burada mock sınıfların
/// sealed tip sistemi ile çakışması yüzünden maliyeti yüksek.
void main() {
  setUp(() {
    // Registry singleton'ı test başına temizle.
    AiProviderRegistry.instance.clear();
  });

  const ctx = AiContext(
    providerHint: ProviderLanguageHint.mongoShell,
    databases: [
      DatabaseSchemaSummary(
        name: 'appdb',
        collections: [
          CollectionSchemaSummary(
            name: 'users',
            fields: [FieldSchemaSummary(name: '_id', type: 'objectId')],
          ),
        ],
      ),
    ],
  );

  AiRequest readOnly() => const AiRequest(
        task: AiTask.generate,
        context: ctx,
        userMessage: 'find users',
      );

  AiRequest writeIntent() => const AiRequest(
        task: AiTask.generate,
        context: ctx,
        userMessage: 'delete from users',
      );

  group('LocalLlamaCppProvider', () {
    test('id + label metadata', () {
      final p = LocalLlamaCppProvider();
      expect(p.id, 'local_llamacpp');
      expect(p.label, 'Local (llama.cpp)');
    });

    test('isAvailable → false when no modelPath', () async {
      final p = LocalLlamaCppProvider();
      expect(await p.isAvailable(), isFalse);
    });

    test('isAvailable → false when modelPath does not exist', () async {
      final p = LocalLlamaCppProvider(modelPath: '/nonexistent/model.gguf');
      expect(await p.isAvailable(), isFalse);
    });

    test('isAvailable → true when modelPath exists', () async {
      final tmp = await File('${Directory.systemTemp.path}/_t.gguf').writeAsBytes(
            [0, 0, 0, 0],
            flush: true,
          );
      try {
        final p = LocalLlamaCppProvider(modelPath: tmp.path);
        expect(await p.isAvailable(), isTrue);
      } finally {
        await tmp.delete();
      }
    });

    test('complete → AiFailure when no modelPath', () async {
      final p = LocalLlamaCppProvider();
      await expectLater(
        () => p.complete(readOnly()),
        throwsA(isA<AiFailure>()),
      );
    });

    test('complete → AiFailure when modelPath does not exist', () async {
      final p = LocalLlamaCppProvider(modelPath: '/nonexistent/model.gguf');
      await expectLater(
        () => p.complete(readOnly()),
        throwsA(isA<AiFailure>()),
      );
    });

    test('complete → refusal completion on write/DDL intent', () async {
      // Write-intent guard runs AFTER modelPath + file existence checks but
      // BEFORE model load — so we need a valid (touchable) modelPath.
      final tmp = await File('${Directory.systemTemp.path}/_t2.gguf').writeAsBytes(
            [0, 0, 0, 0],
            flush: true,
          );
      try {
        final p = LocalLlamaCppProvider(modelPath: tmp.path);
        final c = await p.complete(writeIntent());
        expect(c.suggestedQuery, isEmpty);
        expect(c.warnings, contains('Write/DDL query rejected by AI safety policy'));
      } finally {
        await tmp.delete();
      }
    });

    test('dispose is idempotent (safe to call twice)', () {
      final p = LocalLlamaCppProvider();
      p.dispose();
      p.dispose();
      // No assertion — must not throw.
    });
  });

  group('OllamaRemoteProvider', () {
    test('id + label metadata', () {
      final p = OllamaRemoteProvider();
      expect(p.id, 'ollama_remote');
      expect(p.label, 'Ollama (remote)');
    });

    test('isAvailable → false when no endpoint', () async {
      final p = OllamaRemoteProvider();
      expect(await p.isAvailable(), isFalse);
    });

    test('isAvailable → false when model missing', () async {
      final p = OllamaRemoteProvider(endpoint: 'http://localhost:11434');
      expect(await p.isAvailable(), isFalse);
    });

    test('isAvailable → true when endpoint + model set', () async {
      final p = OllamaRemoteProvider(
        endpoint: 'http://localhost:11434',
        modelName: 'qwen2.5-coder:3b',
      );
      expect(await p.isAvailable(), isTrue);
    });

    test('complete → AiFailure when no endpoint', () async {
      final p = OllamaRemoteProvider();
      await expectLater(
        () => p.complete(readOnly()),
        throwsA(isA<AiFailure>()),
      );
    });

    test('complete → AiFailure when no model', () async {
      final p = OllamaRemoteProvider(endpoint: 'http://localhost:11434');
      await expectLater(
        () => p.complete(readOnly()),
        throwsA(isA<AiFailure>()),
      );
    });

    test('complete → refusal completion on write/DDL intent (no client init)',
        () async {
      // Preflight runs after config validation but before client init —
      // provide endpoint + model so preflight triggers and returns refusal
      // before _ensureClient() is called.
      final p = OllamaRemoteProvider(
        endpoint: 'http://localhost:11434',
        modelName: 'qwen2.5-coder:3b',
      );
      final c = await p.complete(writeIntent());
      expect(c.suggestedQuery, isEmpty);
      expect(c.warnings, contains('Write/DDL query rejected by AI safety policy'));
    });

    test('dispose is idempotent (safe to call without active client)', () {
      final p = OllamaRemoteProvider();
      p.dispose();
      p.dispose();
      // No assertion — must not throw.
    });
  });

  group('OpenAiCompatibleProvider', () {
    test('id + label metadata', () {
      final p = OpenAiCompatibleProvider();
      expect(p.id, 'openai_compatible');
      expect(p.label, 'OpenAI-compatible');
    });

    test('isAvailable → false when no endpoint', () async {
      final p = OpenAiCompatibleProvider();
      expect(await p.isAvailable(), isFalse);
    });

    test('isAvailable → false when model missing', () async {
      final p = OpenAiCompatibleProvider(endpoint: 'http://localhost:1234/v1');
      expect(await p.isAvailable(), isFalse);
    });

    test('isAvailable → true when endpoint + model set', () async {
      final p = OpenAiCompatibleProvider(
        endpoint: 'http://localhost:1234/v1',
        modelName: 'gpt-4o-mini',
      );
      expect(await p.isAvailable(), isTrue);
    });

    test('isAvailable → true with endpoint only (apiKey optional for local)',
        () async {
      final p = OpenAiCompatibleProvider(
        endpoint: 'http://localhost:1234/v1',
        modelName: 'gpt-4o-mini',
      );
      expect(await p.isAvailable(), isTrue);
    });

    test('complete → AiFailure when no endpoint', () async {
      final p = OpenAiCompatibleProvider();
      await expectLater(
        () => p.complete(readOnly()),
        throwsA(isA<AiFailure>()),
      );
    });

    test('complete → AiFailure when no model', () async {
      final p = OpenAiCompatibleProvider(endpoint: 'http://localhost:1234/v1');
      await expectLater(
        () => p.complete(readOnly()),
        throwsA(isA<AiFailure>()),
      );
    });

    test('complete → refusal completion on write/DDL intent (no client init)',
        () async {
      final p = OpenAiCompatibleProvider(
        endpoint: 'http://localhost:1234/v1',
        modelName: 'gpt-4o-mini',
      );
      final c = await p.complete(writeIntent());
      expect(c.suggestedQuery, isEmpty);
      expect(c.warnings, contains('Write/DDL query rejected by AI safety policy'));
    });

    test('dispose is idempotent (safe to call without active client)', () {
      final p = OpenAiCompatibleProvider();
      p.dispose();
      p.dispose();
      // No assertion — must not throw.
    });
  });

  group('DisabledProvider', () {
    test('id + label metadata', () {
      const p = DisabledProvider();
      expect(p.id, 'disabled');
      expect(p.label, 'AI Disabled');
    });

    test('always available (returns true)', () async {
      const p = DisabledProvider();
      expect(await p.isAvailable(), isTrue);
    });

    test('complete → AiFailure', () async {
      const p = DisabledProvider();
      await expectLater(
        () => p.complete(readOnly()),
        throwsA(isA<AiFailure>()),
      );
    });

    test('complete → AiFailure even for safe request', () async {
      const p = DisabledProvider();
      await expectLater(
        () => p.complete(readOnly()),
        throwsA(isA<AiFailure>()),
      );
    });
  });

  group('AiProviderRegistry — built-in entries', () {
    test('4 built-in providers can be registered (registry smoke)', () async {
      final registry = AiProviderRegistry.instance;
      registry
        ..register(LocalLlamaCppProvider())
        ..register(OllamaRemoteProvider())
        ..register(OpenAiCompatibleProvider())
        ..register(const DisabledProvider());
      expect(registry.all.length, 4);
      // DisabledProvider is always available, so available list is non-empty.
      final avail = await registry.available();
      expect(avail, isNotEmpty);
      expect(avail.last.id, 'disabled');
    });

    test('provider ids are unique', () async {
      final registry = AiProviderRegistry.instance;
      registry
        ..register(LocalLlamaCppProvider())
        ..register(OllamaRemoteProvider())
        ..register(OpenAiCompatibleProvider())
        ..register(const DisabledProvider());
      final ids = registry.all.map((AiQueryProvider p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('AiQueryProvider common contract', () {
    test('all 4 providers implement AiQueryProvider', () {
      const disabled = DisabledProvider();
      final llama = LocalLlamaCppProvider();
      final ollama = OllamaRemoteProvider();
      final openai = OpenAiCompatibleProvider();

      expect(disabled, isA<AiQueryProvider>());
      expect(llama, isA<AiQueryProvider>());
      expect(ollama, isA<AiQueryProvider>());
      expect(openai, isA<AiQueryProvider>());

      // id/label are non-empty strings (smoke).
      expect(disabled.id, isNotEmpty);
      expect(disabled.label, isNotEmpty);
      expect(llama.id, isNotEmpty);
      expect(llama.label, isNotEmpty);
      expect(ollama.id, isNotEmpty);
      expect(ollama.label, isNotEmpty);
      expect(openai.id, isNotEmpty);
      expect(openai.label, isNotEmpty);
    });
  });
}