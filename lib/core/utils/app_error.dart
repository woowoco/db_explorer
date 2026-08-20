/// Tip güvenli hata kategorileri — sealed class pattern.
///
/// db_explorer'da hataları kategorize etmek için kullanılır:
/// - network: HTTP / bağlantı sorunları
/// - auth: yetkilendirme / kimlik doğrulama
/// - db: veritabanı sorgu hataları (yetki, syntax, timeout, vs.)
/// - ai: AI provider hataları (model yüklenmedi, inference timeout)
/// - config: kullanıcı yapılandırma hatası (connection string malformed, vb.)
/// - storage: Hive / secure storage hataları
/// - unknown: catch-all (sadece defensive code'da kullanılmalı)
///
/// Phase 0'da sadece tip tanımları var; gerçek error handling sonraki
/// fazlarda (Phase 2+ Storage, Phase 3 MongoDB, Phase 7 AI).
sealed class AppFailure implements Exception {
  const AppFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    final causePart = cause == null ? '' : ' (cause: $cause)';
    return '$runtimeType: $message$causePart';
  }
}

class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.cause});
}

class AuthFailure extends AppFailure {
  const AuthFailure(super.message, {super.cause});
}

class DbFailure extends AppFailure {
  const DbFailure(super.message, {super.cause});
}

class AiFailure extends AppFailure {
  const AiFailure(super.message, {super.cause});
}

class ConfigFailure extends AppFailure {
  const ConfigFailure(super.message, {super.cause});
}

class StorageFailure extends AppFailure {
  const StorageFailure(super.message, {super.cause});
}

class UnknownFailure extends AppFailure {
  const UnknownFailure(super.message, {super.cause});
}
