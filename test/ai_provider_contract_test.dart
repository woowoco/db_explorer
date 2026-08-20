import 'package:db_explorer_app/core/utils/app_error.dart';
import 'package:db_explorer_app/domain/ai/ai_context.dart';
import 'package:db_explorer_app/domain/ai/ai_provider.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/disabled.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/local_llamacpp.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/ollama_remote.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/openai_compatible.dart';
import 'package:flutter_test/flutter_test.dart';

/// AiQueryProvider interface contract test.
///
/// Her provider için:
/// - isAvailable mantığı doğru
/// - complete schema-only context ile çalışır
/// - tamamlanmamış config → AiFailure
/// - write-intent → uyarılı red veya güvenli response
const _sampleContext = AiContext(
  providerHint: ProviderLanguageHint.mongoShell,
  databases: [
    DatabaseSchemaSummary(
      name: 'sample',
      collections: [
        CollectionSchemaSummary(
          name: 'users',
          fields: [
            FieldSchemaSummary(name: '_id', type: 'objectId'),
            FieldSchemaSummary(name: 'name', type: 'string'),
            FieldSchemaSummary(name: 'email', type: 'string'),
            FieldSchemaSummary(name: 'active', type: 'bool'),
          ],
        ),
      ],
    ),
  ],
);

void main() {
  group('DisabledProvider', () {
    test('id and label are stable', () {
      const p = DisabledProvider();
      expect(p.id, 'disabled');
      expect(p.label, 'AI Disabled');
    });

    test('isAvailable → true (always available as default fallback)', () async {
      const p = DisabledProvider();
      expect(await p.isAvailable(), isTrue);
    });

    test('complete always throws AiFailure', () async {
      const p = DisabledProvider();
      expect(
        () => p.complete(const AiRequest(
          task: AiTask.generate,
          context: _sampleContext,
          userMessage: 'list users',
        )),
        throwsA(isA<AiFailure>()),
      );
    });
  });

  group('LocalLlamaCppProvider — fake (Phase 1)', () {
    test('without modelPath → isAvailable false + complete throws', () async {
      final p = LocalLlamaCppProvider();
      expect(await p.isAvailable(), isFalse);
      expect(
        () => p.complete(const AiRequest(
          task: AiTask.generate,
          context: _sampleContext,
          userMessage: 'find all users',
        )),
        throwsA(isA<AiFailure>()),
      );
    });

    test('with modelPath → isAvailable true', () async {
      final p = LocalLlamaCppProvider(modelPath: '/models/qwen3b.gguf');
      expect(await p.isAvailable(), isTrue);
    });

    test('generate task → returns AiCompletion with suggested query', () async {
      final p = LocalLlamaCppProvider(modelPath: '/models/qwen3b.gguf');
      final result = await p.complete(const AiRequest(
        task: AiTask.generate,
        context: _sampleContext,
        userMessage: 'show me all users',
      ));
      expect(result.suggestedQuery, isNotEmpty);
      expect(result.message, isNotEmpty);
      expect(result.warnings, isNotEmpty); // mock warning
    });

    test('count keyword → count() query', () async {
      final p = LocalLlamaCppProvider(modelPath: '/models/x.gguf');
      final result = await p.complete(const AiRequest(
        task: AiTask.generate,
        context: _sampleContext,
        userMessage: 'how many users are there? count please',
      ));
      expect(result.suggestedQuery, contains('count'));
    });

    test('write intent → rejected with safety warning', () async {
      final p = LocalLlamaCppProvider(modelPath: '/models/x.gguf');
      final result = await p.complete(const AiRequest(
        task: AiTask.generate,
        context: _sampleContext,
        userMessage: 'drop the users collection',
      ));
      expect(result.suggestedQuery, isEmpty);
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.first.toLowerCase(), contains('reject'));
    });

    test('modify task → preserves existing query structure', () async {
      final p = LocalLlamaCppProvider(modelPath: '/models/x.gguf');
      final result = await p.complete(const AiRequest(
        task: AiTask.modify,
        context: _sampleContext,
        userMessage: 'add limit',
        existingQuery: 'db.users.find()',
      ));
      expect(result.suggestedQuery, contains('db.users.find()'));
    });

    test('explain task → returns explanation text', () async {
      final p = LocalLlamaCppProvider(modelPath: '/models/x.gguf');
      final result = await p.complete(const AiRequest(
        task: AiTask.explain,
        context: _sampleContext,
        userMessage: 'explain this',
        existingQuery: 'db.users.find({ active: true })',
      ));
      expect(result.explanation, isNotEmpty);
    });
  });

  group('OllamaRemoteProvider — fake (Phase 1)', () {
    test('without endpoint → isAvailable false + complete throws', () async {
      final p = OllamaRemoteProvider();
      expect(await p.isAvailable(), isFalse);
      expect(
        () => p.complete(const AiRequest(
          task: AiTask.generate,
          context: _sampleContext,
          userMessage: 'list users',
        )),
        throwsA(isA<AiFailure>()),
      );
    });

    test('with endpoint → isAvailable true', () async {
      final p = OllamaRemoteProvider(endpoint: 'http://localhost:11434');
      expect(await p.isAvailable(), isTrue);
    });

    test('generate task → returns suggested query', () async {
      final p = OllamaRemoteProvider(endpoint: 'http://localhost:11434');
      final result = await p.complete(const AiRequest(
        task: AiTask.generate,
        context: _sampleContext,
        userMessage: 'show active users',
      ));
      expect(result.suggestedQuery, contains('users'));
    });

    test('optimize task → returns optimization hint', () async {
      final p = OllamaRemoteProvider(endpoint: 'http://localhost:11434');
      final result = await p.complete(const AiRequest(
        task: AiTask.optimize,
        context: _sampleContext,
        userMessage: 'optimize this',
        existingQuery: 'db.users.find({ active: true })',
      ));
      expect(result.explanation.toLowerCase(), contains('index'));
    });

    test('write intent → rejected', () async {
      final p = OllamaRemoteProvider(endpoint: 'http://localhost:11434');
      final result = await p.complete(const AiRequest(
        task: AiTask.generate,
        context: _sampleContext,
        userMessage: 'delete all inactive users',
      ));
      expect(result.suggestedQuery, isEmpty);
      expect(result.warnings, isNotEmpty);
    });
  });

  group('OpenAiCompatibleProvider — fake (Phase 1)', () {
    test('without endpoint → isAvailable false + complete throws', () async {
      final p = OpenAiCompatibleProvider();
      expect(await p.isAvailable(), isFalse);
      expect(
        () => p.complete(const AiRequest(
          task: AiTask.generate,
          context: _sampleContext,
          userMessage: 'list users',
        )),
        throwsA(isA<AiFailure>()),
      );
    });

    test('with endpoint → isAvailable true (apiKey optional)', () async {
      final p = OpenAiCompatibleProvider(endpoint: 'https://api.openai.com/v1');
      expect(await p.isAvailable(), isTrue);
    });

    test('fix task → returns parameterized SQL', () async {
      final p = OpenAiCompatibleProvider(endpoint: 'https://api.x.com/v1');
      final result = await p.complete(const AiRequest(
        task: AiTask.fix,
        context: _sampleContext,
        userMessage: 'fix this query',
        existingQuery: 'SELECT * FROM users WHERE id = 5',
        errorMessage: 'syntax error near FROM',
      ));
      expect(result.suggestedQuery, contains(r'$1'));
      expect(result.explanation.toLowerCase(), contains('parameterized'));
    });

    test('generate task → returns read-only SQL suggestion', () async {
      final p = OpenAiCompatibleProvider(endpoint: 'https://api.x.com/v1');
      final result = await p.complete(const AiRequest(
        task: AiTask.generate,
        context: _sampleContext,
        userMessage: 'show active users',
      ));
      expect(result.suggestedQuery.toUpperCase(), contains('SELECT'));
    });
  });

  group('AiContext — schema-only invariants', () {
    test('AiContext does not expose any document values (compile-time)', () {
      // Bu test compile-time kontrolü sağlar: AiContext sadece name + type
      // alanları içeriyor; value alanı yok.
      const c = CollectionSchemaSummary(
        name: 'users',
        fields: [
          FieldSchemaSummary(name: 'email', type: 'string'),
        ],
      );
      expect(c.fields.length, 1);
      expect(c.fields.first.name, 'email');
      expect(c.fields.first.type, 'string');
    });
  });
}