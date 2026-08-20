import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/disabled.dart';
import 'package:db_explorer_app/infrastructure/registry/ai_provider_registry.dart';
import 'package:db_explorer_app/infrastructure/registry/database_provider_registry.dart';
import 'package:db_explorer_app/infrastructure/storage/settings.dart';
import 'package:db_explorer_app/product/providers_registry/builtin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Phase 0 / 8 Skeleton Smoke', () {
    late AppSettings settings;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      settings = AppSettings(prefs);
      // Default aiMode = disabled → registry yalnızca DisabledProvider
      // içerecek + active provider seçilmeyecek.
      registerBuiltinProviders(settings);
    });

    test('All 4 kind provider factories registered', () {
      final registry = DatabaseProviderRegistry.instance;
      expect(registry.isRegistered(DatabaseKind.mongodb), isTrue);
      // Phase 5: PostgreSQL mock factory de kayıtlı (Phase 8'de real override).
      expect(registry.isRegistered(DatabaseKind.postgres), isTrue);
      // Phase 6: Redis + Elasticsearch mock factory'ler.
      expect(registry.isRegistered(DatabaseKind.redis), isTrue);
      expect(registry.isRegistered(DatabaseKind.elasticsearch), isTrue);
      expect(registry.all.length, 4);
    });

    test('MongoDB provider has correct capabilities', () {
      final registry = DatabaseProviderRegistry.instance;
      final provider = registry.create(DatabaseKind.mongodb);
      expect(provider.id, 'mongodb');
      expect(provider.kind, DatabaseKind.mongodb);
      expect(provider.capabilities.hasAggregationPipeline, isTrue);
      expect(provider.capabilities.hasStreaming, isTrue);
      expect(provider.capabilities.hasTransactions, isTrue);
      expect(provider.capabilities.isReadOnly, isFalse);
    });

    test('AI provider registry has DisabledProvider (default available)', () {
      final registry = AiProviderRegistry.instance;
      // Default aiMode = disabled → registry 1 kayıt içerir.
      expect(registry.all.length, 1);
      expect(registry.byId('disabled'), isNotNull);
      // Aktif provider seçilmemiş (mode = disabled).
      expect(
        registry.byId('local_llamacpp'),
        isNull,
        reason: 'When aiMode=disabled, real providers must NOT be registered',
      );
    });

    test('Disabled AI provider is always available (default)', () async {
      final registry = AiProviderRegistry.instance;
      final disabled = registry.byId('disabled')!;
      expect(disabled, isA<DisabledProvider>());
      expect(await disabled.isAvailable(), isTrue);
    });

    test('AppSettings can be constructed from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final settings = AppSettings(prefs);
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.aiMode, AiMode.disabled);
      expect(settings.telemetryOptIn, isFalse);
      expect(settings.historyTtlDays, 30);
    });

    test('MongoConnectionProfile carries credentials safely', () {
      const profile = MongoConnectionProfile(
        id: 'test-1',
        label: 'Local Mongo',
        host: 'localhost',
        port: 27017,
        databaseName: 'appdb',
        username: 'admin',
        password: 'secret-password',
        authSource: 'admin',
      );
      expect(profile.kind, DatabaseKind.mongodb);
      expect(profile.password, 'secret-password');
      expect(profile.id, 'test-1');
    });

    test('ConnectionState lifecycle transitions', () {
      const idle = IdleConnection();
      const connecting = ConnectingConnection();
      final connected = ConnectedConnection(
        sessionId: 'sess-1',
        at: DateTime.fromMillisecondsSinceEpoch(0),
      );
      const error = ErrorConnection(message: 'boom');
      expect(idle, isA<IdleConnection>());
      expect(connecting, isA<ConnectingConnection>());
      expect(connected, isA<ConnectedConnection>());
      expect(error, isA<ErrorConnection>());
    });
  });
}
