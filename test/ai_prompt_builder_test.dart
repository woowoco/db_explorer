import 'package:db_explorer_app/domain/ai/ai_context.dart';
import 'package:db_explorer_app/domain/ai/ai_provider.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/ai_prompt_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llm_core/llm_core.dart';

/// AiPromptBuilder testleri — güvenlik katmanı + system / user prompt
/// kurulumunun doğruluğu.
///
/// Güvenlik gereksinimleri (brief madde 11, 14):
/// - AI asla write/DDL sorgu üretmez (write-intent guard).
/// - AI context ASLA credentials veya document value içermez.
void main() {
  group('AiPromptBuilder — preflight (write-intent guard)', () {
    const ctx = AiContext(
      providerHint: ProviderLanguageHint.mongoShell,
      databases: [
        DatabaseSchemaSummary(
          name: 'appdb',
          collections: [
            CollectionSchemaSummary(
              name: 'users',
              fields: [
                FieldSchemaSummary(name: '_id', type: 'objectId'),
                FieldSchemaSummary(name: 'email', type: 'string'),
              ],
            ),
          ],
        ),
      ],
    );

    AiRequest make(String userMessage) =>
        AiRequest(task: AiTask.generate, context: ctx, userMessage: userMessage);

    test('safe read request → null (no refusal)', () {
      expect(AiPromptBuilder.preflight(make('count users')), isNull);
      expect(AiPromptBuilder.preflight(make('find users')), isNull);
      expect(AiPromptBuilder.preflight(make('explain users')), isNull);
    });

    test('INSERT INTO → refusal', () {
      final r = AiPromptBuilder.preflight(make('INSERT INTO users VALUES(1)'));
      expect(r, isNotNull);
      expect(r!.suggestedQuery, isEmpty);
      expect(r.warnings, contains('Write/DDL query rejected by AI safety policy'));
    });

    test('DROP TABLE → refusal', () {
      expect(
        AiPromptBuilder.preflight(make('drop table users')),
        isNotNull,
      );
    });

    test('DELETE FROM → refusal', () {
      expect(
        AiPromptBuilder.preflight(make('delete from users')),
        isNotNull,
      );
    });

    test('UPDATE → refusal', () {
      expect(
        AiPromptBuilder.preflight(make('update users set active = false')),
        isNotNull,
      );
    });

    test('CREATE INDEX → refusal', () {
      expect(
        AiPromptBuilder.preflight(make('create index idx_users on users')),
        isNotNull,
      );
    });

    test('TRUNCATE → refusal', () {
      expect(
        AiPromptBuilder.preflight(make('truncate users')),
        isNotNull,
      );
    });

    test('updated (non-keyword) → allowed (false positive guard)', () {
      // "updated" kelimesi "updated" içeriyor ama "update " trailing space
      // guard ile elenmeli — AI context yorumlama serbest.
      expect(
        AiPromptBuilder.preflight(make('users updated last week')),
        isNull,
      );
    });
  });

  group('AiPromptBuilder — system prompt', () {
    const ctx = AiContext(
      providerHint: ProviderLanguageHint.sql,
      databases: [
        DatabaseSchemaSummary(
          name: 'shop',
          collections: [
            CollectionSchemaSummary(
              name: 'products',
              fields: [
                FieldSchemaSummary(name: 'id', type: 'int'),
                FieldSchemaSummary(
                  name: 'name',
                  type: 'string',
                  isNullable: false,
                ),
              ],
              indexes: ['pk_id', 'idx_name'],
            ),
          ],
        ),
      ],
    );

    test('contains SQL hint + schema + HARD RULES', () {
      const prompt = AiPromptBuilder; // dummy to keep group name
      final p = AiPromptBuilder.systemPrompt(
        const AiRequest(task: AiTask.generate, context: ctx, userMessage: 'x'),
      );
      expect(p, contains('SQL'));
      expect(p, contains('Database: shop'));
      expect(p, contains('Collection: products'));
      expect(p, contains('id: int'));
      expect(p, contains('name: string'));
      expect(p, contains('Indexes: pk_id, idx_name'));
      expect(p, contains('NEVER generate INSERT'));
      expect(p, contains('NEVER add credentials'));
      expect(prompt, isNotNull);
    });

    test('redisCmd hint → Redis syntax mention', () {
      const c = AiContext(
        providerHint: ProviderLanguageHint.redisCmd,
        databases: [],
      );
      final p = AiPromptBuilder.systemPrompt(
        const AiRequest(task: AiTask.generate, context: c, userMessage: 'x'),
      );
      expect(p, contains('Redis commands'));
    });

    test('elasticDsl hint → Elasticsearch DSL mention', () {
      const c = AiContext(
        providerHint: ProviderLanguageHint.elasticDsl,
        databases: [],
      );
      final p = AiPromptBuilder.systemPrompt(
        const AiRequest(task: AiTask.generate, context: c, userMessage: 'x'),
      );
      expect(p, contains('Elasticsearch DSL'));
    });

    test('mongoShell hint → MongoDB syntax mention', () {
      const c = AiContext(
        providerHint: ProviderLanguageHint.mongoShell,
        databases: [],
      );
      final p = AiPromptBuilder.systemPrompt(
        const AiRequest(task: AiTask.generate, context: c, userMessage: 'x'),
      );
      expect(p, contains('MongoDB shell'));
    });
  });

  group('AiPromptBuilder — user prompt per task', () {
    const ctx = AiContext(
      providerHint: ProviderLanguageHint.mongoShell,
      databases: [],
    );

    test('generate → "Generate a query for..."', () {
      final p = AiPromptBuilder.userPrompt(
        const AiRequest(task: AiTask.generate, context: ctx, userMessage: 'hello'),
      );
      expect(p, contains('Generate a query'));
      expect(p, contains('hello'));
    });

    test('modify → existing query + masked userMessage', () {
      final p = AiPromptBuilder.userPrompt(
        const AiRequest(
          task: AiTask.modify,
          context: ctx,
          userMessage: 'add limit 10',
          existingQuery: 'db.users.find()',
        ),
      );
      expect(p, contains('Modify this existing query'));
      expect(p, contains('db.users.find()'));
      expect(p, contains('add limit 10'));
    });

    test('fix → existing query + error message + userMessage', () {
      final p = AiPromptBuilder.userPrompt(
        const AiRequest(
          task: AiTask.fix,
          context: ctx,
          userMessage: 'now delte users',
          existingQuery: 'db.users.find()',
          errorMessage: 'SyntaxError: Unexpected token',
        ),
      );
      expect(p, contains('Fix this query'));
      expect(p, contains('db.users.find()'));
      expect(p, contains('SyntaxError: Unexpected token'));
    });
  });

  group('AiPromptBuilder — buildChatMessages (llm_core)', () {
    const ctx = AiContext(
      providerHint: ProviderLanguageHint.mongoShell,
      databases: [
        DatabaseSchemaSummary(
          name: 'appdb',
          collections: [
            CollectionSchemaSummary(
              name: 'users',
              fields: [FieldSchemaSummary(name: 'name', type: 'string')],
            ),
          ],
        ),
      ],
    );

    test('returns [system, user]', () {
      final msgs = AiPromptBuilder.buildChatMessages(
        const AiRequest(
          task: AiTask.generate,
          context: ctx,
          userMessage: 'list users',
        ),
      );
      expect(msgs.length, 2);
      expect(msgs[0].role, LLMRole.system);
      expect(msgs[1].role, LLMRole.user);
      expect(msgs[0].content, isNotNull);
      expect(msgs[1].content, contains('list users'));
    });
  });

  group('AiPromptBuilder — parseCompletion', () {
    const ctx = AiContext(
      providerHint: ProviderLanguageHint.sql,
      databases: [],
    );

    AiRequest req() => const AiRequest(
          task: AiTask.generate,
          context: ctx,
          userMessage: 'x',
        );

    test('code block extracted + explanation outside', () {
      const raw = 'Counts active users.\n\n```sql\nSELECT COUNT(*) FROM users WHERE active = TRUE;\n```\nEpilogue line.';
      final c = AiPromptBuilder.parseCompletion(raw, req());
      expect(c.suggestedQuery, 'SELECT COUNT(*) FROM users WHERE active = TRUE;');
      expect(c.explanation, contains('Counts active users'));
      expect(c.explanation, contains('Epilogue line'));
      expect(c.message, 'Generated query:');
    });

    test('no code block → entire text is explanation', () {
      final c = AiPromptBuilder.parseCompletion('No code here.', req());
      expect(c.suggestedQuery, isEmpty);
      expect(c.explanation, 'No code here.');
      expect(c.message, contains('no code block'));
    });

    test('empty response → explicit warning', () {
      final c = AiPromptBuilder.parseCompletion('', req());
      expect(c.suggestedQuery, isEmpty);
      expect(c.warnings, contains('Empty AI response'));
    });

    test('defense-in-depth: write/DDL in output → rejected', () {
      const raw = 'Malicious model:\n\n```sql\nDROP TABLE users;\n```';
      final c = AiPromptBuilder.parseCompletion(raw, req());
      expect(c.suggestedQuery, isEmpty);
      expect(c.warnings, contains('Post-generation write/DDL rejected'));
    });

    test('defense-in-depth: INSERT in output → rejected', () {
      const raw = "```sql\nINSERT INTO users VALUES (1, 'a');\n```";
      final c = AiPromptBuilder.parseCompletion(raw, req());
      expect(c.suggestedQuery, isEmpty);
    });
  });

  group('AiPromptBuilder — sensitive pattern masking', () {
    setUp(() {
      AiPromptBuilder.setSensitivePatterns([
        RegExp(r'\b\d{4}-\d{4}-\d{4}-\d{4}\b'), // credit card
        RegExp(r'\b\d{3}-\d{2}-\d{4}\b'), // SSN
      ]);
    });

    tearDown(() {
      AiPromptBuilder.setSensitivePatterns(const []);
    });

    const ctx = AiContext(
      providerHint: ProviderLanguageHint.sql,
      databases: [],
    );

    test('credit card + SSN are masked in user prompt', () {
      final p = AiPromptBuilder.userPrompt(
        const AiRequest(
          task: AiTask.generate,
          context: ctx,
          userMessage: 'find user with card 4532-1234-5678-9010 or SSN 123-45-6789',
        ),
      );
      expect(p, isNot(contains('4532-1234-5678-9010')));
      expect(p, isNot(contains('123-45-6789')));
      expect(p, contains('[REDACTED]'));
    });
  });
}