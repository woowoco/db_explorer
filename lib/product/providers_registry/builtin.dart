import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/disabled.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/local_llamacpp.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/ollama_remote.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/openai_compatible.dart';
import 'package:db_explorer_app/infrastructure/database_providers/mongodb/mongodb_provider.dart';
import 'package:db_explorer_app/infrastructure/registry/ai_provider_registry.dart';
import 'package:db_explorer_app/infrastructure/registry/database_provider_registry.dart';

/// Built-in provider factory registrations.
///
/// MongoDB MVP için sadece MongoDBProviderFactory.
/// Diğer provider factory'leri ileriki fazlarda (PostgresPhase 5, Redis
/// Phase 6) eklenecek.
void registerBuiltinProviders() {
  _registerDatabase();
  _registerAi();
}

/// Database provider factory kayıtları.
void _registerDatabase() {
  final dbRegistry = DatabaseProviderRegistry.instance;
  if (!dbRegistry.isRegistered(DatabaseKind.mongodb)) {
    dbRegistry.register(const MongoDBProviderFactory());
  }
}

/// AI provider factory kayıtları.
void _registerAi() {
  final aiRegistry = AiProviderRegistry.instance;
  aiRegistry.register(const DisabledProvider()); // default — AI kapalı
  aiRegistry.register(LocalLlamaCppProvider()); // Phase 7+
  aiRegistry.register(OllamaRemoteProvider()); // Phase 7+
  aiRegistry.register(OpenAiCompatibleProvider()); // Phase 7+
}
