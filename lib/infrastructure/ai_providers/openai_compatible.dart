// ignore_for_file: prefer_initializing_formals
//
// Private field `_clientFactory` cannot be referenced via
// `this._clientFactory` in an initializing formal (Dart limitation).

import 'dart:async';

import 'package:db_explorer_app/core/utils/app_error.dart';
import 'package:db_explorer_app/core/utils/app_logger.dart';
import 'package:db_explorer_app/domain/ai/ai_provider.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/ai_prompt_builder.dart';
import 'package:openai_dart/openai_dart.dart';

/// OpenAI-compatible provider — Phase 7 real implementation.
///
/// `openai_dart` (trevorwang flavour) paketi ile OpenAI API'sine ve OAuth
/// uyumlu tüm endpoint'lere (Azure OpenAI, Together AI, Groq, LM Studio,
/// vLLM, Ollama'nın OpenAI-compatible mode'u, vs.) bağlanır.
///
/// Güvenlik (brief 11, 14):
/// - AI asla write/DDL sorgu önermez (shared `AiPromptBuilder.preflight`).
/// - AI context = schema-only (NO document values, NO credentials).
/// - API key asla loglanmaz (redactionList).
class OpenAiCompatibleProvider implements AiQueryProvider {
  OpenAiCompatibleProvider({
    this.endpoint,
    this.apiKey,
    this.modelName,
    this.temperature = 0.2,
    this.maxTokens = 1024,
    this.requestTimeoutSeconds = 60,
    Future<OpenAIClient> Function()? clientFactory,
  }) : _clientFactory = clientFactory;

  /// Örn. `https://api.openai.com/v1`, `https://api.groq.com/openai/v1`,
  /// `http://localhost:1234/v1` (LM Studio).
  final String? endpoint;

  /// Bearer API key. Endpoint default `api.openai.com` ise zorunlu,
  /// local LM Studio için boş bırakılabilir.
  final String? apiKey;

  /// Örn. `gpt-4o-mini`, `qwen2.5-coder:7b`, `llama-3.1-8b-instant`.
  final String? modelName;

  /// Sampling temperature.
  final double temperature;

  /// Üretilecek maksimum token.
  final int maxTokens;

  /// Request timeout (saniye).
  final int requestTimeoutSeconds;

  /// Test seam — gerçek istemciyi değiştirir.
  final Future<OpenAIClient> Function()? _clientFactory;

  final _log = getLogger('OpenAICompat');

  OpenAIClient? _client;

  @override
  String get id => 'openai_compatible';

  @override
  String get label => 'OpenAI-compatible';

  @override
  Future<bool> isAvailable() async {
    if (endpoint == null || endpoint!.isEmpty) return false;
    if (modelName == null || modelName!.isEmpty) return false;
    return true;
  }

  Future<OpenAIClient> _ensureClient() async {
    final cached = _client;
    if (cached != null) return cached;
    if (endpoint == null || endpoint!.isEmpty) {
      throw const AiFailure(
        'OpenAI-compatible endpoint not configured. Set endpoint in Settings.',
      );
    }
    final factory = _clientFactory;
    final client = factory != null
        ? await factory()
        : OpenAIClient(
            config: OpenAIConfig(
              baseUrl: endpoint!,
              authProvider: apiKey != null && apiKey!.isNotEmpty
                  ? ApiKeyProvider(apiKey!)
                  : null,
              timeout: Duration(seconds: requestTimeoutSeconds),
            ),
          );
    _client = client;
    return client;
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
    if (modelName == null || modelName!.isEmpty) {
      throw const AiFailure(
        'OpenAI model not configured. Set model name in Settings.',
      );
    }

    // 1. Write-intent guard.
    final guard = AiPromptBuilder.preflight(request);
    if (guard != null) return guard;

    // 2. Client hazırla.
    final client = await _ensureClient();

    // 3. Chat messages kur.
    final messages = [
      ChatMessage.system(AiPromptBuilder.systemPrompt(request)),
      ChatMessage.user(AiPromptBuilder.userPrompt(request)),
    ];

    // 4. Streaming istek.
    final buffer = StringBuffer();
    try {
      final stream = client.chat.completions.createStream(
        ChatCompletionCreateRequest(
          model: modelName!,
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens,
        ),
      );
      await for (final event in stream) {
        final choices = event.choices;
        if (choices != null && choices.isNotEmpty) {
          final delta = choices.first.delta.content;
          if (delta != null && delta.isNotEmpty) {
            buffer.write(delta);
          }
        }
      }
    } on ApiException catch (e) {
      throw AiFailure('OpenAI API error: ${e.message}', cause: e);
    } on TimeoutException catch (e) {
      throw AiFailure(
        'OpenAI request timed out after ${requestTimeoutSeconds}s',
        cause: e,
      );
    } catch (e) {
      throw AiFailure('OpenAI request failed: $e', cause: e);
    }

    final raw = buffer.toString();
    return AiPromptBuilder.parseCompletion(raw, request);
  }

  /// HTTP client'ı kapat (kullanıcı provider değiştirdiğinde).
  void dispose() {
    try {
      _client?.close();
    } catch (e) {
      _log.w('dispose failed: $e');
    }
    _client = null;
    _log.i('OpenAI client disposed.');
  }
}
