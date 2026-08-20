import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/domain/database/database_provider.dart';

/// Database provider registry — tüm provider factory'leri burada toplanır.
///
/// Singleton; uygulama ömrü boyunca bir kez init edilir (AppBootstrap).
/// Yeni provider eklemek için registry'e factory kaydetmek yeterli.
class DatabaseProviderRegistry {
  DatabaseProviderRegistry._();

  static final DatabaseProviderRegistry _instance = DatabaseProviderRegistry._();
  static DatabaseProviderRegistry get instance => _instance;

  final Map<DatabaseKind, DatabaseProviderFactory> _factories = {};

  void register(DatabaseProviderFactory factory) {
    _factories[factory.kind] = factory;
  }

  /// Factory üzerinden provider instance oluştur.
  ///
  /// Hata: factory kayıtlı değilse [ArgumentError] fırlatır.
  DatabaseProvider create(DatabaseKind kind) {
    final factory = _factories[kind];
    if (factory == null) {
      throw ArgumentError(
        'No factory registered for kind=$kind. '
        'Available: ${_factories.keys.map((k) => k.name).join(', ')}',
      );
    }
    return factory.create();
  }

  /// Kayıtlı tüm provider factory'ler.
  List<DatabaseProviderFactory> get all => _factories.values.toList();

  /// Belirli bir kind için factory kayıtlı mı?
  bool isRegistered(DatabaseKind kind) => _factories.containsKey(kind);

  /// Test/debug için tüm registry'yi temizle.
  void clear() => _factories.clear();
}
