import 'dart:math';

import 'package:db_explorer_app/core/utils/app_error.dart';
import 'package:db_explorer_app/core/utils/app_logger.dart';
import 'package:db_explorer_app/domain/ai/ai_provider.dart';

/// OpenAI-compatible provider — Phase 1 fake.
///
/// OpenAI API, LM Studio, oobabooga, vLLM, vs. tüm OpenAI-uyumlu
/// endpoint'ler için jenerik HTTP provider. Phase 1'de HTTP çağrısı
/// yapılmıyor; sadece canned response. Phase 7'de `http` + bearer auth.
class OpenAiCompatibleProvider implements AiQueryProvider {
  OpenAiCompatibleProvider({this.endpoint, this.apiKey, this.modelName});

  /// Örn. 'https://api.openai.com/v1' veya 'http://localhost:1234/v1'.
  final String? endpoint;

  /// Bearer token. Phase 1'de hiçbir yere gönderilmez (güvenlik).
  final String? apiKey;

  /// Model adı (örn. 'gpt-4o-mini', 'qwen2.5-coder:7b').
  final String? modelName;

  final _log = getLogger('OpenAICompat');

  @override
  String get id => 'openai_compatible';

  @override
  String get label => 'OpenAI-compatible';

  @override
  Future<bool> isAvailable() async {
    return endpoint != null && endpoint!.isNotEmpty;
  }

  @override
  Future<AiCompletion> complete(
    AiRequest request, {
    void Function()? onCancelSetup,
  }) async {
    if (endpoint == null || endpoint!.isEmpty) {
      throw const AiFailure(
        'OpenAI-compatible endpoint not configured. Set endpoint in Settings.',
      );
    }

    // Cloud latency simulation: 400-1200ms.
    await Future<void>.delayed(
      Duration(milliseconds: 400 + Random().nextInt(800)),
    );

    // Güvenlik: API key asla loglanmaz.
    _log.i(
      'Mock OpenAI call (endpoint configured, key redacted) '
      'model=$modelName task=${request.task}',
    );

    return _buildResponse(request);
  }

  AiCompletion _buildResponse(AiRequest req) {
    final lower = req.userMessage.toLowerCase();
    final isWrite = ['drop ', 'delete', 'update ', 'insert', 'truncate']
        .any(lower.contains);
    if (isWrite) {
      return const AiCompletion(
        message: 'Refusing to generate write/DDL query.',
        suggestedQuery: '',
        explanation: 'AI safety: only read-only queries are suggested.',
        warnings: ['Write rejected'],
      );
    }

    switch (req.task) {
      case AiTask.generate:
        return const AiCompletion(
          message: 'Mock OpenAI generated SQL/Mongo query.',
          suggestedQuery: 'SELECT * FROM users WHERE active = TRUE LIMIT 100',
          explanation: 'Generated read-only query targeting active users. '
              'Real model would use schema context for precise field names.',
        );
      case AiTask.modify:
        return const AiCompletion(
          message: 'Mock OpenAI modified.',
          suggestedQuery: 'SELECT id, name, email FROM users WHERE active = TRUE',
          explanation: 'Reduced columns; narrowed result set.',
        );
      case AiTask.explain:
        return AiCompletion(
          message: 'Mock OpenAI explanation.',
          suggestedQuery: req.existingQuery ?? '',
          explanation: 'Will use real explain plan analysis in Phase 7.',
        );
      case AiTask.optimize:
        return AiCompletion(
          message: 'Mock OpenAI optimization.',
          suggestedQuery: req.existingQuery ?? '',
          explanation: 'Suggested composite index based on WHERE+ORDER BY columns.',
        );
      case AiTask.fix:
        return const AiCompletion(
          message: 'Mock OpenAI fix.',
          suggestedQuery: r'SELECT * FROM users WHERE id = $1',
          explanation: 'Parameterized query (safer than string concat).',
        );
    }
  }
}