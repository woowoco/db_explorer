import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Local cache — Hive encrypted box wrapper.
///
/// Phase 0'da sadece cipher setup + smoke test. Gerçek cache (schema
/// metadata, query history, vs.) Phase 2+ storage implementasyonunda.
///
/// Encryption:
/// - AES-GCM 256-bit key Hive `HiveCipher` için.
/// - Key `flutter_secure_storage`'da saklanır (Keychain/KeyStore/DPAPI/libsecret).
class LocalCache {
  LocalCache({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  static const _cacheKeyKey = 'dbx_hive_cache_key';

  Future<HiveCipher> _resolveCipher() async {
    final existing = await _secureStorage.read(key: _cacheKeyKey);
    if (existing != null) {
      return HiveAesCipher(_decodeKey(existing));
    }
    final newKey = Hive.generateSecureKey();
    await _secureStorage.write(key: _cacheKeyKey, value: _encodeKey(newKey));
    return HiveAesCipher(newKey);
  }

  /// Test/cache box aç; smoke test için.
  Future<Box<dynamic>> openTestBox({String name = 'dbx_smoke_box'}) async {
    final cipher = await _resolveCipher();
    if (Hive.isBoxOpen(name)) {
      return Hive.box<dynamic>(name);
    }
    return Hive.openBox<dynamic>(name, encryptionCipher: cipher);
  }

  /// Tüm cache box'larını kapat (shutdown sırasında).
  Future<void> closeAll() async {
    await Hive.close();
  }

  String _encodeKey(List<int> key) {
    return key
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  List<int> _decodeKey(String hex) {
    final result = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
}
