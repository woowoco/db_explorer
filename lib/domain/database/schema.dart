import 'package:equatable/equatable.dart';

/// Şema ağacı marker interface'leri.
///
/// Her provider kendi concrete sınıflarını yazar (örn. `MongoCollection`,
/// `MongoField`); UI provider-agnostic olarak bu interface'lerle çalışır.
abstract class SchemaNode {
  const SchemaNode({required this.name});
  final String name;
}

/// Bir veritabanı instance'ı (provider terminolojisinde; SQL'de "schema").
abstract class DatabaseNode extends SchemaNode {
  const DatabaseNode({required super.name});
}

/// Collection / table / index — provider'a göre concrete tip.
abstract class CollectionNode extends SchemaNode {
  const CollectionNode({required super.name, this.fields = const []});
  final List<FieldNode> fields;
}

/// Field / column — provider'a göre concrete tip.
abstract class FieldNode extends SchemaNode {
  const FieldNode({
    required super.name,
    required this.dataType,
    this.isNullable = true,
    this.isIndexed = false,
  });

  final String dataType;
  final bool isNullable;
  final bool isIndexed;
}

/// Marker — bir query'nin sonuç satırı.
class DataRow extends Equatable {
  const DataRow(this.values);

  final Map<String, Object?> values;

  @override
  List<Object?> get props => [values];

  @override
  bool operator ==(Object other) =>
      other is DataRow && _mapEquals(other.values, values);

  @override
  int get hashCode => Object.hashAll(values.entries);

  static bool _mapEquals(
    Map<String, Object?> a,
    Map<String, Object?> b,
  ) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
