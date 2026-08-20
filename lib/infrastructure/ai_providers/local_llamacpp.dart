import 'dart:math';

import 'package:db_explorer_app/core/utils/app_error.dart';
import 'package:db_explorer_app/core/utils/app_logger.dart';
import 'package:db_explorer_app/domain/ai/ai_provider.dart';

/// Local llama.cpp (llamadart / llm_llamacpp) provider — Phase 1 fake.
///
/// Gerçek model yükleme Phase 7'de yapılacak. Phase 1'de:
/// - isAvailable: modelPath konfigüre edilmişse true, aksi false
/// - complete: gelen request'e göre canned response (echo + structured intent)
///
/// Güvenlik: write yeteneği olan collectionlar için sorgu üretmez; sadece
/// read-only sorgular (find/aggregate/explain) önerir.
class LocalLlamaCppProvider implements AiQueryProvider {
  LocalLlamaCppProvider({this.modelPath});

  final String? modelPath;

  final _log = getLogger('LocalLlamaCpp');

  @override
  String get id => 'local_llamacpp';

  @override
  String get label => 'Local (llama.cpp)';

  @override
  Future<bool> isAvailable() async {
    return modelPath != null && modelPath!.isNotEmpty;
  }

  @override
  Future<AiCompletion> complete(
    AiRequest request, {
    void Function()? onCancelSetup,
  }) async {
    if (modelPath == null || modelPath!.isEmpty) {
      throw const AiFailure(
        'Local model not configured. Set model path in Settings.',
      );
    }

    // Mock latency: 200-600ms.
    await Future<void>.delayed(
      Duration(milliseconds: 200 + Random().nextInt(400)),
    );

    _log.i('Mock complete: task=${request.task} message="${request.userMessage}"');

    // Write-context güvenlik kontrolü (brief madde 11).
    final dangerousCollection = _containsWriteTarget(request);
    if (dangerousCollection != null) {
      return AiCompletion(
        message: 'Cannot suggest query on writeable collection '
            '"$dangerousCollection" — AI only generates read-only queries.',
        suggestedQuery: '',
        explanation: 'Refusing to generate INSERT/UPDATE/DELETE/DDL on '
            '"$dangerousCollection" per AI safety policy.',
        warnings: const ['Write query rejected by safety policy'],
      );
    }

    switch (request.task) {
      case AiTask.generate:
        return _mockGenerate(request);
      case AiTask.modify:
        return _mockModify(request);
      case AiTask.explain:
        return _mockExplain(request);
      case AiTask.optimize:
        return _mockOptimize(request);
      case AiTask.fix:
        return _mockFix(request);
    }
  }

  // ─── Mock implementations per task ─────────────────────────────────
  AiCompletion _mockGenerate(AiRequest req) {
    final collections = req.context.databases
        .expand((db) => db.collections.map((c) => c.name))
        .toList();
    final firstColl = collections.isNotEmpty ? collections.first : 'users';

    final lower = req.userMessage.toLowerCase();
    String suggestedQuery;
    String explanation;

    if (lower.contains('count')) {
      suggestedQuery = 'db.$firstColl.count()';
      explanation = 'Counts total documents in $firstColl collection.';
    } else if (lower.contains('find one') || lower.contains('first')) {
      suggestedQuery = 'db.$firstColl.findOne()';
      explanation = 'Returns the first document in $firstColl.';
    } else {
      suggestedQuery = 'db.$firstColl.find()';
      explanation = 'Returns all documents in $firstColl. Add filter() to narrow.';
    }

    return AiCompletion(
      message: 'Mock generated query (no real inference).',
      suggestedQuery: suggestedQuery,
      explanation: explanation,
      warnings: const ['Local mock provider — real LLM comes in Phase 7'],
    );
  }

  AiCompletion _mockModify(AiRequest req) {
    final existing = req.existingQuery ?? '';
    final modified = '$existing /* limit 10 */'.trim();
    return AiCompletion(
      message: 'Mock modified: appended limit 10 hint.',
      suggestedQuery: modified,
      explanation: 'This is a placeholder modification; real LLM integration '
          'will replace with semantic-aware refactoring.',
    );
  }

  AiCompletion _mockExplain(AiRequest req) {
    final q = req.existingQuery ?? '';
    return AiCompletion(
      message: 'Mock explanation.',
      suggestedQuery: q,
      explanation: 'Query runs against the schema collections. Real LLM '
          'will provide collection-specific field-by-field analysis.',
    );
  }

  AiCompletion _mockOptimize(AiRequest req) {
    final q = req.existingQuery ?? '';
    return AiCompletion(
      message: 'Mock optimization.',
      suggestedQuery: q,
      explanation: 'Suggestion: add an index on the most-filtered field. '
          'Real LLM will provide explain-plan-aware advice.',
    );
  }

  AiCompletion _mockFix(AiRequest req) {
    return const AiCompletion(
      message: 'Mock fix: assumed syntax issue with brackets.',
      suggestedQuery: 'db.collection.find({ field: "value" })',
      explanation: 'Fixed bracket syntax. Real LLM will use error-context '
          'to produce targeted corrections.',
    );
  }

  // ─── Safety helpers ───────────────────────────────────────────────
  String? _containsWriteTarget(AiRequest req) {
    // Basit sezgisel: kullanıcı mesajı DROP/DELETE/UPDATE/INSERT içeriyorsa
    // ve context'te bir writeable collection varsa, reddet.
    final lower = req.userMessage.toLowerCase();
    final writeHints = ['drop ', 'delete', 'update ', 'insert', 'truncate'];
    final isWriteIntent = writeHints.any(lower.contains);
    if (!isWriteIntent) return null;
    for (final db in req.context.databases) {
      for (final c in db.collections) {
        if (c.name != '_internal') return c.name;
      }
    }
    return null;
  }
}