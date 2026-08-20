import 'package:db_explorer_app/domain/ai/ai_context.dart';
import 'package:db_explorer_app/domain/ai/ai_provider.dart';
import 'package:llm_core/llm_core.dart';

/// AI provider'lar için ortak güvenlik ve prompt kurma yardımcısı.
///
/// Üç Phase 7 provider'ı (local_llamacpp, ollama_remote, openai_compatible)
/// tarafından paylaşılır:
/// 1. **Write-intent guard** — INSERT/UPDATE/DELETE/DROP/ALTER/CREATE INDEX
///    gibi write/DDL sorguları AI tarafından ASLA üretilmez (brief madde 11).
/// 2. **Schema-only context** — `AiContext` zaten credentials/value içermez;
///    bu sınıf bu kuralı dokümante eder ve context'i LLM system mesajına
///    dönüştürür.
/// 3. **Completion parsing** — model yanıtından `AiCompletion` üretirken
///    task-specific yapı çıkarır (kod bloğu, açıklama, uyarılar).
///
/// Hassas alan maskeleme (regex pattern listesi) burada değil; AI'in
/// `userMessage`'ından alan adı geçtiğinde maskeleme istemci tarafında
/// (UI katmanında) olur — bu provider'lar yalnızca metin tabanlı schema
/// context alır, dolayısıyla değer görme riski sıfırdır.
class AiPromptBuilder {
  AiPromptBuilder._();

  /// Tehlikeli yazma niyetlerinin lowercase anahtar kelime listesi.
  /// (Tek başına yeterli değil — kullanıcı açıkça "update" deyince de
  /// reddedilir; "modify row" gibi dolaylı niyetler için ayrı bir
  /// semantic check eklenebilir.)
  static const _writeKeywords = <String>[
    'insert into',
    'drop table',
    'drop database',
    'drop index',
    'delete from',
    'alter table',
    'create index',
    'truncate',
    'update ', // trailing space: "updated" gibi kelimeleri elemek
    'insert ',
    'drop ',
    'delete ',
  ];

  /// Sensitive pattern maskeleme (regex) — config-driven olmalı,
  /// burada default boş. Provider'a injection yapılabilir.
  static List<RegExp> _sensitivePatterns = const [];

  /// Dışarıdan sensitive pattern listesi set et (Settings'ten okunur).
  static void setSensitivePatterns(List<RegExp> patterns) {
    _sensitivePatterns = patterns;
  }

  /// Maskeleme uygula — kullanıcı mesajı ve mevcut sorgudaki hassas
  /// alanları `[REDACTED]` ile değiştir.
  static String _mask(String input) {
    if (_sensitivePatterns.isEmpty) return input;
    var masked = input;
    for (final pattern in _sensitivePatterns) {
      masked = masked.replaceAll(pattern, '[REDACTED]');
    }
    return masked;
  }

  /// Phase 7.5 — security gate (write-intent guard).
  ///
  /// Returns `null` if request is safe to proceed.
  /// Returns a refusal `AiCompletion` if write-intent detected.
  static AiCompletion? preflight(AiRequest request) {
    final lower = request.userMessage.toLowerCase();
    final hasWriteIntent = _writeKeywords.any(lower.contains);
    if (!hasWriteIntent) return null;
    return const AiCompletion(
      message: 'AI safety policy: Write/DDL queries are rejected.',
      suggestedQuery: '',
      explanation: 'INSERT, UPDATE, DELETE, DROP, ALTER, TRUNCATE, '
          'CREATE INDEX gibi yazma/DDL sorguları AI tarafından üretilmez. '
          'Sadece read-only (find/select/aggregate/explain) üretilir.',
      warnings: ['Write/DDL query rejected by AI safety policy'],
    );
  }

  /// Provider dil ipucuna göre üretim syntax'ı.
  static String _languageHint(ProviderLanguageHint hint) => switch (hint) {
        ProviderLanguageHint.mongoShell => 'MongoDB shell (db.users.find(...))',
        ProviderLanguageHint.sql => 'SQL (SELECT ... FROM ...)',
        ProviderLanguageHint.redisCmd => 'Redis commands (GET, HGETALL, ...)',
        ProviderLanguageHint.elasticDsl =>
          'Elasticsearch DSL (JSON: {query: {match: ...}})',
      };

  /// Schema özetini string'e çevir (system prompt için).
  static String _schemaToText(AiContext ctx) {
    final buf = StringBuffer();
    for (final db in ctx.databases) {
      buf.writeln('Database: ${db.name}');
      for (final c in db.collections) {
        buf.writeln('  Collection: ${c.name}');
        for (final f in c.fields) {
          final nullable = f.isNullable ? ' (nullable)' : '';
          buf.writeln('    - ${f.name}: ${f.type}$nullable');
        }
        if (c.indexes.isNotEmpty) {
          buf.writeln('    Indexes: ${c.indexes.join(', ')}');
        }
      }
    }
    return buf.toString().trim();
  }

  /// System prompt — AI'a rolünü ve güvenlik kurallarını hatırlat.
  static String _buildSystemPrompt(AiRequest request) {
    final lang = _languageHint(request.context.providerHint);
    final schema = _schemaToText(request.context);
    return '''You are a database query copilot. Generate ONLY read-only queries in $lang.

HARD RULES (always refuse):
- NEVER generate INSERT, UPDATE, DELETE, DROP, ALTER, TRUNCATE, CREATE INDEX.
- NEVER invent field names or values not in the schema.
- NEVER add credentials (usernames, passwords, hosts).
- Use the schema provided below EXACTLY. Field names are case-sensitive.

Schema (READ-ONLY, no values):
```
$schema
```

Respond with:
1. A short explanation.
2. The query (code block).
3. A note if the user intent is ambiguous.''';
  }

  /// User prompt — task tipine göre farklı ön-ekler.
  static String _buildUserPrompt(AiRequest request) {
    final buf = StringBuffer();
    switch (request.task) {
      case AiTask.generate:
        buf.writeln('Generate a query for the following request:');
        buf.writeln(_mask(request.userMessage));
      case AiTask.modify:
        buf.writeln('Modify this existing query:');
        buf.writeln('```');
        buf.writeln(request.existingQuery ?? '');
        buf.writeln('```');
        buf.writeln(_mask(request.userMessage));
      case AiTask.explain:
        buf.writeln('Explain this query:');
        buf.writeln('```');
        buf.writeln(request.existingQuery ?? '');
        buf.writeln('```');
        if (request.userMessage.isNotEmpty) {
          buf.writeln(_mask(request.userMessage));
        }
      case AiTask.optimize:
        buf.writeln('Optimize this query:');
        buf.writeln('```');
        buf.writeln(request.existingQuery ?? '');
        buf.writeln('```');
        if (request.userMessage.isNotEmpty) {
          buf.writeln(_mask(request.userMessage));
        }
      case AiTask.fix:
        buf.writeln('Fix this query:');
        buf.writeln('```');
        buf.writeln(request.existingQuery ?? '');
        buf.writeln('```');
        if (request.errorMessage != null) {
          buf.writeln('Error: ${request.errorMessage}');
        }
        if (request.userMessage.isNotEmpty) {
          buf.writeln(_mask(request.userMessage));
        }
    }
    return buf.toString().trim();
  }

  /// Chat mesajlarını LlamaCpp-compatible formata çevir.
  ///
  /// `llm_llamacpp` package'i `LLMMessage` (llm_core) kullanır.
  static List<LLMMessage> buildChatMessages(AiRequest request) {
    return [
      LLMMessage(role: LLMRole.system, content: _buildSystemPrompt(request)),
      LLMMessage(role: LLMRole.user, content: _buildUserPrompt(request)),
    ];
  }

  /// Ollama / OpenAI için mesajları list of maps olarak üret.
  ///
  /// Ollama `ChatMessage` tipini, OpenAI `ChatMessage` tipini kullanır.
  /// İki ayrı metod yerine ortak bir JSON map listesine çevirip caller'
  /// in dönüştürmesine izin vermek temiz olur — ama Ollama ve OpenAI
  /// kendi mesaj constructor'larına ihtiyaç duyduğu için ayrı metod
  /// burada eklenmedi. Bunun yerine provider'lar kendi map'lerini
  /// [buildSystemPrompt] / [buildUserPrompt]'tan kurabilir.
  static String systemPrompt(AiRequest request) =>
      _buildSystemPrompt(request);
  static String userPrompt(AiRequest request) => _buildUserPrompt(request);

  /// Model yanıtını parse et — code block'tan sorguyu, gerisinden
  /// açıklamayı çıkar.
  ///
  /// Beklenen biçim (zorunlu değil, fallback var):
  /// ````
  /// <short explanation>
  ///
  /// ```<lang>
  /// <query>
  /// ```
  /// ````
  static AiCompletion parseCompletion(String raw, AiRequest request) {
    final text = raw.trim();
    if (text.isEmpty) {
      return const AiCompletion(
        message: 'Model returned empty response.',
        suggestedQuery: '',
        explanation: '',
        warnings: ['Empty AI response'],
      );
    }

    // Markdown code block (```...```) çıkar.
    final codeBlockRegex = RegExp(r'```([a-zA-Z0-9_+\-]*)\n?([\s\S]*?)```');
    final codeMatch = codeBlockRegex.firstMatch(text);
    String suggestedQuery = '';
    if (codeMatch != null) {
      suggestedQuery = codeMatch.group(2)?.trim() ?? '';
    }

    // Code block dışındaki metni explanation olarak kullan.
    final explanation = codeMatch != null
        ? text.replaceFirst(codeMatch.group(0)!, '').trim()
        : text;

    // Defense-in-depth: modelin ürettiği sorguyu da write-intent için
    // tara. Model güvenlik talimatlarını ignore ederse burada reject.
    final containsWrite = _writeKeywords.any(
      (kw) => suggestedQuery.toLowerCase().contains(kw),
    );
    if (containsWrite) {
      return const AiCompletion(
        message: 'AI safety policy: Generated query rejected.',
        suggestedQuery: '',
        explanation: 'Model output contained write/DDL keywords. '
            'Only read-only queries are allowed.',
        warnings: ['Post-generation write/DDL rejected'],
      );
    }

    return AiCompletion(
      message: codeMatch != null
          ? 'Generated query:'
          : 'Model response (no code block detected):',
      suggestedQuery: suggestedQuery,
      explanation: explanation,
    );
  }
}
