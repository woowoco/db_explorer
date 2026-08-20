/// MongoDB cursor stream wrapper — Phase 0 stub.
///
/// mongo_dart_flutter'ın cursor'ı `Stream<Document>` döndürür; bu sınıf
/// provider-agnostic bir streaming API sunar. Phase 3'te implemente edilecek.
class MongoCursorStream<T> {
  MongoCursorStream();

  /// Stream'i başlat (cursor aç).
  Stream<T> open() {
    // Phase 0 stub: boş stream.
    return Stream<T>.empty();
  }
}
