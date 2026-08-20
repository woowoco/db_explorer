import 'dart:math';

import 'package:db_explorer_app/core/utils/app_error.dart';
import 'package:db_explorer_app/core/utils/app_logger.dart';
import 'package:db_explorer_app/domain/ai/ai_provider.dart';

/// Ollama remote provider — Phase 1 fake.
///
/// Phase 1'de gerçek HTTP çağrısı yapılmıyor; Ollama'nun /api/generate
/// endpoint'i simüle ediliyor. Phase 7'de `http` paketiyle gerçek
/// bağlantı kurulacak.
///
/// Güvenlik: tüm providerlar için ortak — write/DDL sorgu reddi.
class OllamaRemoteProvider implements AiQueryProvider {
  OllamaRemoteProvider({this.endpoint, this.modelName});

  /// Örn. 'http://localhost:11434'.
  final String? endpoint;

  /// Örn. 'qwen2.5-coder:3b'.
  final String? modelName;

  final _log = getLogger('OllamaRemote');

  @override
  String get id => 'ollama_remote';

  @override
  String get label => 'Ollama (remote)';

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
        'Ollama endpoint not configured. Set endpoint in Settings.',
      );
    }

    // Network latency simulation: 300-900ms.
    await Future<void>.delayed(
      Duration(milliseconds: 300 + Random().nextInt(600)),
    );

    _log.i(
      'Mock Ollama call to $endpoint (model=$modelName) '
      'task=${request.task}',
    );

    return _buildResponse(request);
  }

  AiCompletion _buildResponse(AiRequest req) {
    // Write intent guard.
    final lower = req.userMessage.toLowerCase();
    final isWrite = ['drop ', 'delete', 'update ', 'insert', 'truncate']
        .any(lower.contains);
    if (isWrite) {
      return const AiCompletion(
        message: 'Write/DDL rejected by AI safety policy.',
        suggestedQuery: '',
        explanation: 'Ollama mock enforces read-only AI suggestions.',
        warnings: ['Write query rejected'],
      );
    }

    switch (req.task) {
      case AiTask.generate:
        return const AiCompletion(
          message: 'Mock Ollama generated query.',
          suggestedQuery: 'db.users.find({ active: true })',
          explanation: 'Active users filter — based on schema field "active".',
        );
      case AiTask.modify:
        return const AiCompletion(
          message: 'Mock Ollama modified query.',
          suggestedQuery: 'db.users.find({ active: true }).limit(50)',
          explanation: 'Added limit 50 to bound result size.',
        );
      case AiTask.explain:
        return AiCompletion(
          message: 'Mock Ollama explanation.',
          suggestedQuery: req.existingQuery ?? '',
          explanation: 'Filter on `active=true` uses the `active` index.',
        );
      case AiTask.optimize:
        return AiCompletion(
          message: 'Mock Ollama optimization suggestion.',
          suggestedQuery: req.existingQuery ?? '',
          explanation: 'Create index on `{ active: 1 }` to avoid collScan.',
        );
      case AiTask.fix:
        return const AiCompletion(
          message: 'Mock Ollama fix.',
          suggestedQuery: 'db.users.find({ name: "Alice" })',
          explanation: 'Corrected filter syntax.',
        );
    }
  }
}