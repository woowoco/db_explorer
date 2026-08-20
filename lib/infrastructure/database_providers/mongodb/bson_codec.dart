/// BSON value type system — Phase 0 stub.
///
/// mongo_dart_flutter'ın kendi BSON type'ları var (bson.BsonValue
/// hierarchy); Phase 0'da sadece bizim jenerik type'ımızı declare
/// ediyoruz. Phase 3'te mongo_dart_flutter'ın BsonValue ile adapt edilecek.
enum BsonValueType {
  double,
  string,
  bool,
  date,
  int,
  objectId,
  decimal128,
  binary,
  nullValue,
  document,
  array,
  regex,
  dbPointer,
  javascript,
  symbol,
  javascriptWithScope,
  timestamp,
  minKey,
  maxKey,
}
