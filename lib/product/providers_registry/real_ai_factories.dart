import 'package:db_explorer_app/domain/ai/ai_provider.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/ai_prompt_builder.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/local_llamacpp.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/ollama_remote.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/openai_compatible.dart';
import 'package:db_explorer_app/infrastructure/storage/settings.dart';

/// Phase 8 — Settings-aware factory'ler.
///
/// `AppSettings`'i okuyup gerçek provider instance'ları üretir.
/// `AppBootstrap`'ta çağrılır; seçilen `AiMode`'a göre tek bir provider
/// `AiProviderRegistry`'ye eklenir. Diğer 3 mode pasif kalır (registry
/// `available()` sıralamasında görünmez).
///
/// Not: Bu factory'ler **DI container'da singleton değildir**; her
/// çağrıda yeni bir provider instance üretir. Çünkü provider'lar kendi
/// iç state'lerini (repository, http client, vb.) lazy kurar ve dispose
/// ile serbest bırakır. Kullanıcı Settings'i değiştirdiğinde factory
/// tekrar çağrılır ve yeni provider oluşturulur.
class RealAiProviderFactory {
  RealAiProviderFactory(this._settings);

  final AppSettings _settings;

  /// `AppSettings.aiMode`'a göre tek bir provider döndürür.
  /// `AiMode.disabled` → null (kullanıcı AI'ı kapatmış).
  AiQueryProvider? buildFromSettings() {
    return switch (_settings.aiMode) {
      AiMode.local => buildLocalLlamaCpp(),
      AiMode.ollamaRemote => buildOllamaRemote(),
      AiMode.openaiCompatible => buildOpenAiCompatible(),
      AiMode.disabled => null,
    };
  }

  /// Local llama.cpp provider — Settings'den konfigürasyonu okur.
  AiQueryProvider buildLocalLlamaCpp() {
    return LocalLlamaCppProvider(
      modelPath: _settings.aiLocalModelPath,
      contextSize: _settings.aiLocalContextSize,
      nGpuLayers: _settings.aiLocalNGpuLayers,
      temperature: _settings.aiLocalTemperature,
      maxTokens: _settings.aiLocalMaxTokens,
    );
  }

  /// Remote Ollama provider.
  AiQueryProvider buildOllamaRemote() {
    return OllamaRemoteProvider(
      endpoint: _settings.aiOllamaEndpoint,
      modelName: _settings.aiOllamaModel,
      bearerToken: _settings.aiOllamaBearerToken,
      temperature: _settings.aiOllamaTemperature,
      requestTimeoutSeconds: _settings.aiOllamaTimeoutSeconds,
    );
  }

  /// OpenAI-compatible provider.
  AiQueryProvider buildOpenAiCompatible() {
    return OpenAiCompatibleProvider(
      endpoint: _settings.aiOpenaiEndpoint,
      apiKey: _settings.aiOpenaiApiKey,
      modelName: _settings.aiOpenaiModel,
      temperature: _settings.aiOpenaiTemperature,
      maxTokens: _settings.aiOpenaiMaxTokens,
      requestTimeoutSeconds: _settings.aiOpenaiTimeoutSeconds,
    );
  }
}

/// Sensitive field pattern listesini `RegExp`'e çevirip
/// `AiPromptBuilder.setSensitivePatterns()` ile global olarak paylaşır.
/// Settings değiştiğinde (kullanıcı yeni regex eklediğinde) tekrar
/// çağrılmalı; mevcut pattern listesi tamamen değiştirilir.
void applySensitiveFieldPatterns(AppSettings settings) {
  final sources = settings.sensitiveFieldPatterns;
  if (sources.isEmpty) {
    AiPromptBuilder.setSensitivePatterns(const []);
    return;
  }
  final patterns = <RegExp>[];
  for (final src in sources) {
    try {
      patterns.add(RegExp(src));
    } on FormatException {
      // Geçersiz regex → skip (Settings UI'da validate edilecek).
    }
  }
  AiPromptBuilder.setSensitivePatterns(patterns);
}
