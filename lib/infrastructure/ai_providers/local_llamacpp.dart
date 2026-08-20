// ignore_for_file: prefer_initializing_formals
//
// `prefer_initializing_formals` cannot be satisfied for private fields
// (Dart requires the constructor parameter to start with `this.` which
// must match a public-or-private field; private fields like
// `_repositoryFactory` can't be referenced via `this._repositoryFactory`
// in an initializing formal).

import 'dart:async';
import 'dart:io';

import 'package:db_explorer_app/core/utils/app_error.dart';
import 'package:db_explorer_app/core/utils/app_logger.dart';
import 'package:db_explorer_app/domain/ai/ai_provider.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/ai_prompt_builder.dart';
import 'package:llm_llamacpp/llm_llamacpp.dart';

/// Local llama.cpp provider — Phase 7 real implementation.
///
/// `llm_llamacpp` paketi ile cross-platform (Android/iOS/macOS/Windows/Linux)
/// GGUF inference yapar. Model dosyası (`modelPath`) zorunludur; isolation-
/// based inference sayesinde UI thread bloklanmaz.
///
/// Güvenlik (brief 11, 14):
/// - AI asla write/DDL sorgu önermez (write-intent guard).
/// - AI context = schema-only (NO document values, NO credentials).
/// - Api key / endpoint OLMAYAN local provider; DÖH (data-on-host) riski az.
class LocalLlamaCppProvider implements AiQueryProvider {
  LocalLlamaCppProvider({
    this.modelPath,
    this.contextSize = 2048,
    this.nGpuLayers = 0,
    this.temperature = 0.2,
    this.maxTokens = 1024,
    Future<LlamaCppChatRepository> Function()? repositoryFactory,
  }) : _repositoryFactory = repositoryFactory;

  /// GGUF model dosya yolu (örn. `/models/qwen2.5-coder-3b-q4_k_m.gguf`).
  final String? modelPath;

  /// Context size (token). Varsayılan 2048 — küçük modeller için güvenli.
  final int contextSize;

  /// GPU'ya offload edilen layer sayısı (0 = CPU-only).
  final int nGpuLayers;

  /// Sampling temperature (0.0 = deterministic, yüksek = yaratıcı).
  /// Kod üretimi için düşük (0.2) tercih edildi.
  final double temperature;

  /// Üretilecek maksimum token sayısı.
  final int maxTokens;

  /// Test seam — gerçek implementasyonu değiştirir.
  final Future<LlamaCppChatRepository> Function()? _repositoryFactory;

  final _log = getLogger('LocalLlamaCpp');

  LlamaCppChatRepository? _repository;
  bool _isLoading = false;
  bool _disposed = false;

  @override
  String get id => 'local_llamacpp';

  @override
  String get label => 'Local (llama.cpp)';

  @override
  Future<bool> isAvailable() async {
    if (modelPath == null || modelPath!.isEmpty) return false;
    final file = File(modelPath!);
    return file.existsSync();
  }

  Future<LlamaCppChatRepository> _ensureRepository() async {
    if (_disposed) {
      throw const AiFailure('Local model provider is disposed.');
    }
    final cached = _repository;
    if (cached != null) return cached;
    if (_isLoading) {
      // Concurrent load isteği — bekle.
      while (_isLoading && _repository == null) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      final loaded = _repository;
      if (loaded != null) return loaded;
    }
    _isLoading = true;
    try {
      _log.i('Loading local model: $modelPath '
          '(contextSize=$contextSize, nGpuLayers=$nGpuLayers)');
      final repo = _repositoryFactory != null
          ? await _repositoryFactory()
          : LlamaCppChatRepository(
              contextSize: contextSize,
              nGpuLayers: nGpuLayers,
            );
      // ignore: deprecated_member_use
      // The deprecated `loadModel` is the simpler self-contained path; the
      // replacement (`LlamaCppRepository.loadModel()` + `withModel`) requires
      // additional lifecycle management that we don't need for unit tests.
      // ignore: deprecated_member_use
      await repo.loadModel(modelPath!);
      _repository = repo;
      _log.i('Local model loaded successfully.');
      return repo;
    } on ModelLoadException catch (e) {
      throw AiFailure('Failed to load GGUF model: ${e.message}', cause: e);
    } on BackendInitException catch (e) {
      throw AiFailure('llama.cpp backend init failed: ${e.message}', cause: e);
    } catch (e) {
      throw AiFailure('Unexpected error loading local model: $e', cause: e);
    } finally {
      _isLoading = false;
    }
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
    if (!File(modelPath!).existsSync()) {
      throw AiFailure(
        'GGUF model file not found at: $modelPath. '
        'Download a model or update Settings.',
      );
    }

    // 1. Write-intent guard.
    final guard = AiPromptBuilder.preflight(request);
    if (guard != null) return guard;

    // 2. Model yükle (lazy).
    final repo = await _ensureRepository();

    // 3. Chat messages kur.
    final messages = AiPromptBuilder.buildChatMessages(request);

    // 4. Stream → accumulate.
    final buffer = StringBuffer();
    try {
      final stream = repo.streamChatWithGenerationOptions(
        modelPath!,
        messages: messages,
        generationOptions: GenerationOptions(
          temperature: temperature,
          maxTokens: maxTokens,
        ),
      );
      await for (final chunk in stream) {
        final delta = chunk.message?.content;
        if (delta != null && delta.isNotEmpty) {
          buffer.write(delta);
        }
      }
    } on InferenceException catch (e) {
      throw AiFailure('Local inference failed: ${e.message}', cause: e);
    } catch (e) {
      throw AiFailure('Local model error: $e', cause: e);
    }

    final raw = buffer.toString();
    return AiPromptBuilder.parseCompletion(raw, request);
  }

  /// Model'i bellekten boşalt (kullanıcı AI provider'ı değiştirdiğinde).
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    try {
      _repository?.dispose();
    } catch (e) {
      _log.w('dispose failed: $e');
    }
    _repository = null;
    _log.i('Local model disposed.');
  }
}
