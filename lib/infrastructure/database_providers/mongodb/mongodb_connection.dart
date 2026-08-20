/// MongoDB connection wrapper — Phase 0 stub.
///
/// Gerçek `mongo_dart_flutter` Db handle yönetimi Faz 3'te yapılacak.
/// Phase 0'da bu sınıf sadece compile-clean skeleton.
class MongoDbConnection {
  MongoDbConnection();

  bool _open = false;
  bool get isOpen => _open;

  // TODO(Phase 3): import 'package:mongo_dart_flutter/mongo_dart_flutter.dart';
  // late Db _db;

  Future<void> open({
    required String host,
    required int port,
    String? databaseName,
    String? username,
    String? password,
    String? authSource,
  }) async {
    // Phase 0 stub.
    _open = true;
  }

  Future<void> close() async {
    _open = false;
  }
}
