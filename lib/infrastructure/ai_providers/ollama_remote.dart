// ignore_for_file: prefer_initializing_formals
//
// Private field `_clientFactory` cannot be referenced via
// `this._clientFactory` in an initializing formal (Dart limitation).

import 'dart:async';

import 'package:db_explorer_app/core/utils/app_error.dart';
import 'package:db_explorer_app/core/utils/app_logger.dart';
import 'package:db_explorer_app/domain/ai/ai_provider.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/ai_prompt_builder.dart';
import 'package:ollama_dart/ollama_dart.dart';

/// Remote Ollama provider — Phase 7 real implementation.
///
/// `ollama_dart` paketi ile Ollama HTTP API'sine (`POST /api/chat`) bağlanır.
/// Streaming NDJSON desteği vardır; SSE benzeri event'ler ile token-by-token
/// çıktı alıp birleştiririz.
///
/// Güvenlik (brief 11, 14):
/// - AI asla write/DDL sorgu önermez (shared `AiPromptBuilder.preflight`).
/// - AI context = schema-only (NO document values, NO credentials).
/// - Bearer token asla loglanmaz (redactionList).
class OllamaRemoteProvider implements AiQueryProvider {
  OllamaRemoteProvider({
    this.endpoint,
    this.modelName,
    this.bearerToken,
    this.temperature = 0.2,
    this.requestTimeoutSeconds = 120,
    Future<OllamaClient> Function()? clientFactory,
  }) : _clientFactory = clientFactory;

  /// Örn. `http://localhost:11434` veya `https://remote-ollama.example.com`.
  final String? endpoint;

  /// Örn. `qwen2.5-coder:3b`, `llama3.1:8b`.
  final String? modelName;

  /// Ollama cloud / remote proxy için bearer token (opsiyonel).
  final String? bearerToken;

  /// Sampling temperature.
  final double temperature;

  /// Request timeout (saniye).
  final int requestTimeoutSeconds;

  /// Test seam — gerçek istemciyi değiştirir.
  final Future<OllamaClient> Function()? _clientFactory;

  final _log = getLogger('OllamaRemote');

  OllamaClient? _client;

  @override
  String get id => 'ollama_remote';

  @override
  String get label => 'Ollama (remote)';

  @override
  Future<bool> isAvailable() async {
    if (endpoint == null || endpoint!.isEmpty) return false;
    if (modelName == null || modelName!.isEmpty) return false;
    return true;
  }

  Future<OllamaClient> _ensureClient() async {
    final cached = _client;
    if (cached != null) return cached;
    if (endpoint == null || endpoint!.isEmpty) {
      throw const AiFailure(
        'Ollama endpoint not configured. Set endpoint in Settings.',
      );
    }
    final factory = _clientFactory;
    final client = factory != null
        ? await factory()
        : OllamaClient(
            config: OllamaConfig(
              baseUrl: endpoint!,
              authProvider: bearerToken != null && bearerToken!.isNotEmpty
                  ? BearerTokenProvider(bearerToken!)
                  : null,
              timeout: Duration(seconds: requestTimeoutSeconds),
              redactionList: const ['authorization', 'bearer', 'token'],
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
        'Ollama endpoint not configured. Set endpoint in Settings.',
      );
    }
    if (modelName == null || modelName!.isEmpty) {
      throw const AiFailure(
        'Ollama model not configured. Set model name in Settings.',
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
      final stream = client.chat.createStream(
        request: ChatRequest(
          model: modelName!,
          messages: messages,
          options: ModelOptions(
            temperature: temperature,
          ),
        ),
      );
      await for (final event in stream) {
        final delta = event.message?.content;
        if (delta != null && delta.isNotEmpty) {
          buffer.write(delta);
        }
      }
    } on ApiException catch (e) {
      throw AiFailure('Ollama API error: ${e.message}', cause: e);
    } on TimeoutException catch (e) {
      throw AiFailure(
        'Ollama request timed out after ${requestTimeoutSeconds}s',
        cause: e,
      );
    } catch (e) {
      throw AiFailure('Ollama request failed: $e', cause: e);
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
    _log.i('Ollama client disposed.');
  }
}
