import 'package:db_explorer_app/domain/database/schema.dart';

/// Redis schema node'ları.
///
/// Redis'te "schema" yok — key-value yapı. Ama capability-driven UI için
/// schema tree abstraction'ı gerekli (Explorer panel). Bu yüzden:
/// - `RedisDatabase`: Redis'in logical database index'i (0-15 default).
///   `RedisDBProvider.listDatabases()` her zaman 16 db döner (fixed).
/// - `RedisKey`: Bir key (ve type'ı: string/list/hash/set/sortedset/stream).
///   CollectionNode olarak modelliyoruz çünkü Explorer'da tree altında
///   görünüyor.
/// - `RedisField`: Hash field'i (sadece hash type key'ler için anlamlı).
///   FieldNode olarak modelliyoruz.

/// Redis logical database.
class RedisDatabase extends DatabaseNode {
  const RedisDatabase({
    required super.name,
    this.keyCount = 0,
  });

  /// Bu db'deki toplam key sayısı (DBSIZE estimate).
  final int keyCount;
}

/// Redis key. MongoDB collection gibi düşünülebilir ama "type" field'ı ile.
class RedisKey extends CollectionNode {
  const RedisKey({
    required super.name,
    required this.keyType,
    this.ttlSeconds,
    this.sizeBytes,
    super.fields = const [],
  });

  /// Redis type: string / list / hash / set / sortedset / stream.
  final String keyType;

  /// Kalan TTL (saniye). -1 = no TTL, -2 = key yok.
  final int? ttlSeconds;

  /// Approximate size (bytes).
  final int? sizeBytes;
}

/// Redis hash field (sadece hash type key'ler için).
class RedisField extends FieldNode {
  const RedisField({
    required super.name,
    required super.dataType,
    super.isIndexed = false,
  });
}
