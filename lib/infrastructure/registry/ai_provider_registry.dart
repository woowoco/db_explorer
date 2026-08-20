import 'package:db_explorer_app/domain/ai/ai_provider.dart';

/// AI provider registry — sıralı liste, ilk available olan kullanılır.
///
/// Singleton; uygulama ömrü boyunca bir kez init edilir (AppBootstrap).
///
/// Kullanıcı `AiMode`'u değiştirdiğinde registry sırası da güncellenir;
/// Phase 0'da tek bir default provider var (DisabledProvider).
class AiProviderRegistry {
  AiProviderRegistry._();

  static final AiProviderRegistry _instance = AiProviderRegistry._();
  static AiProviderRegistry get instance => _instance;

  final List<AiQueryProvider> _providers = [];

  void register(AiQueryProvider provider) {
    _providers.add(provider);
  }

  /// Kullanılabilir (available) provider'ları sırayla döndürür.
  Future<List<AiQueryProvider>> available() async {
    final results = <AiQueryProvider>[];
    for (final p in _providers) {
      try {
        if (await p.isAvailable()) {
          results.add(p);
        }
      } catch (_) {
        // provider.isAvailable() hata fırlatırsa skip
      }
    }
    return results;
  }

  /// İlk available provider'ı getir (default).
  Future<AiQueryProvider?> defaultProvider() async {
    final available = await this.available();
    if (available.isEmpty) return null;
    return available.first;
  }

  /// ID ile provider bul.
  AiQueryProvider? byId(String id) {
    for (final p in _providers) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Tüm kayıtlı provider'lar (availability kontrolü yapılmaz).
  List<AiQueryProvider> get all => List.unmodifiable(_providers);

  /// Test/debug için tüm registry'yi temizle.
  void clear() => _providers.clear();
}
