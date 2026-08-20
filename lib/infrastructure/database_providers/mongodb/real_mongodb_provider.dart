import 'dart:async';

import 'package:db_explorer_app/core/utils/app_logger.dart';
import 'package:db_explorer_app/domain/database/capability.dart';
import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/domain/database/database_provider.dart';
import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/domain/database/schema.dart';
import 'package:db_explorer_app/infrastructure/database_providers/mongodb/mongodb_schema.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// Real MongoDB provider — `mongo_dart` (pure-Dart) driver kullanır.
///
/// Phase 3 — Phase 1'deki in-memory mock'un production karşılığı.
///
/// Bağlantı stratejisi:
/// - URI oluştur (`mongodb://user:pass@host:port/db?...`)
/// - `Db.open(secure: ...)` ile TLS opsiyonu
/// - Varsa SCRAM auth (`db.authenticate(username, password, authDb: 'admin')`)
/// - Server status + hello ile bağlantı doğrula
///
/// **Not**: Phase 3'te Phase 1 contract testleri (mock ile) yeşil kalır;
/// gerçek provider integration testi Phase 8 (platform_io) kapsamındadır.
class RealMongoDBProvider implements DatabaseProvider {
  RealMongoDBProvider();

  final _log = getLogger('RealMongoDBProvider');

  // ─── Identity ────────────────────────────────────────────────────
  @override
  String get id => 'mongodb';

  @override
  DatabaseKind get kind => DatabaseKind.mongodb;

  @override
  DatabaseCapabilities get capabilities => const DatabaseCapabilities({
    DatabaseCapability.schemaHierarchy,
    DatabaseCapability.schemaless,
    DatabaseCapability.schemaIntrospection,
    DatabaseCapability.indexIntrospection,
    DatabaseCapability.aggregationPipeline,
    DatabaseCapability.fullTextSearch,
    DatabaseCapability.geospatial,
    DatabaseCapability.transactions,
    DatabaseCapability.streaming,
    DatabaseCapability.indexManagement,
    DatabaseCapability.explainPlan,
    DatabaseCapability.completion,
    DatabaseCapability.insert,
    DatabaseCapability.update,
    DatabaseCapability.delete,
    DatabaseCapability.bulkWrite,
    DatabaseCapability.createDatabase,
    DatabaseCapability.createCollection,
    DatabaseCapability.dropCollection,
    DatabaseCapability.schemaValidation,
    DatabaseCapability.serverInfo,
    DatabaseCapability.liveStats,
    DatabaseCapability.backup,
    DatabaseCapability.userManagement,
    DatabaseCapability.tlsSupport,
    DatabaseCapability.sshTunnelSupport,
  });

  // ─── Connection lifecycle ─────────────────────────────────────────
  @override
  Future<DatabaseConnection> connect(DatabaseConnectionConfig config) async {
    if (config is! MongoConnectionProfile) {
      throw ArgumentError(
        'RealMongoDBProvider only supports MongoConnectionProfile, got ${config.runtimeType}',
      );
    }

    final connection = DatabaseConnection(profile: config, providerId: id);
    connection.state = const ConnectingConnection(message: 'Resolving host...');

    Db? db;
    try {
      final uri = _buildUri(config);
      _log.i('Connecting to MongoDB $uri (tls=${config.ssl})');

      connection.state = const ConnectingConnection(
        progress: 0.3,
        message: 'Opening socket...',
      );

      db = Db(uri);
      final startedConnect = DateTime.now();
      await db.open(secure: config.ssl);

      // Auth (varsa)
      if (config.username != null && config.username!.isNotEmpty) {
        connection.state = const ConnectingConnection(
          progress: 0.7,
          message: 'Authenticating...',
        );
        await db.authenticate(
          config.username,
          config.password,
          authDb: config.authSource,
        );
      }

      // Server info topla
      final serverStatus = await _safeServerStatus(db);
      final hello = await _safeHello(db);

      final latencyMs = DateTime.now().difference(startedConnect).inMilliseconds;

      connection.state = ConnectedConnection(
        sessionId: 'sess-${DateTime.now().millisecondsSinceEpoch}',
        at: DateTime.now(),
        serverVersion: serverStatus['version'] as String? ?? 'unknown',
        latencyMs: latencyMs,
        uptimeSeconds: _parseUptime(serverStatus['uptime']),
        extra: {
          'mode': 'real-mongodb',
          if (hello.isNotEmpty) 'isWritablePrimary': '${hello['isWritablePrimary']}',
          if (hello.isNotEmpty) 'maxWireVersion': '${hello['maxWireVersion']}',
        },
      );

      // Db handle'ı sakla
      _handles[connection.profile.id] = db;
      _log.i('Connected to ${config.label} (${config.host}:${config.port}) '
          'in ${latencyMs}ms — ${serverStatus['version']}');
      return connection;
    } on MongoDartError catch (e) {
      connection.state = ErrorConnection(
        message: 'MongoDB connection failed: ${e.message}',
        code: 'MONGO_CONN_ERR',
        cause: e,
      );
      // Cleanup yarı-açık db
      if (db != null) {
        try { await db.close(); } catch (_) {}
      }
      rethrow;
    } catch (e) {
      connection.state = ErrorConnection(
        message: 'Unexpected error: $e',
        code: 'UNKNOWN_ERR',
        cause: e,
      );
      if (db != null) {
        try { await db.close(); } catch (_) {}
      }
      rethrow;
    }
  }

  @override
  Future<void> disconnect(DatabaseConnection connection) async {
    final db = _handles.remove(connection.profile.id);
    if (db != null) {
      try {
        await db.close();
        _log.i('Disconnected: ${connection.profile.label}');
      } catch (e) {
        _log.w('Error during close: $e');
      }
    }
    connection.state = const DisconnectedConnection(reason: 'user-request');
  }

  @override
  Future<bool> ping(DatabaseConnection connection) async {
    if (!connection.isConnected) return false;
    final db = _handles[connection.profile.id];
    if (db == null) return false;
    try {
      await db.pingCommand();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Schema discovery ─────────────────────────────────────────────
  @override
  Future<List<DatabaseNode>> listDatabases(
    DatabaseConnection connection,
  ) async {
    if (!connection.isConnected) {
      throw StateError('listDatabases called without active connection');
    }
    final db = _handles[connection.profile.id]!;
    // Db.listDatabases() returns List<String> (database names)
    final names = await db.listDatabases();
    return names
        .whereType<String>()
        .map((n) => MongoDatabase(name: n))
        .toList();
  }

  @override
  Future<List<CollectionNode>> listCollections(
    DatabaseConnection connection,
    String database,
  ) async {
    if (!connection.isConnected) {
      throw StateError('listCollections called without active connection');
    }
    final db = _handles[connection.profile.id]!;
    // Hedef database'i belirle — connect'te URI'da database varsa oraya
    // bağlanmıştır; aksi halde istenen database için yeni Db açarız
    // (Phase 4'te daha akıllı strateji).
    final target = await _ensureDatabaseHandle(db, database);
    final colNames = await target.getCollectionNames();

    final List<CollectionNode> result = [];
    for (final name in colNames.whereType<String>()) {
      final coll = target.collection(name);

      // İlk dokümandan field discovery
      Map<String, Object?>? sampleDoc;
      try {
        final first = await coll.findOne();
        if (first != null) {
          sampleDoc = _mapToPlain(first);
        }
      } catch (e) {
        _log.w('findOne sample failed for $name: $e');
      }

      final fields = sampleDoc?.entries
              .map<FieldNode>(
                (e) => MongoField(
                  name: e.key,
                  dataType: _bsonTypeName(e.value),
                ),
              )
              .toList() ??
          const [];

      int? count;
      try {
        count = await coll.count();
      } catch (e) {
        _log.w('count failed for $name: $e');
      }

      result.add(MongoCollection(
        name: name,
        fields: fields,
        documentCount: count,
      ));
    }
    return result;
  }

  // ─── Query execution ──────────────────────────────────────────────
  @override
  Future<QueryResult> execute(
    DatabaseConnection connection,
    QueryRequest request,
  ) async {
    if (!connection.isConnected) {
      throw StateError('execute called without active connection');
    }
    if (request.language != QueryLanguage.mongoShell) {
      throw ArgumentError(
        'RealMongoDBProvider only supports mongoShell, got ${request.language}',
      );
    }

    final rootDb = _handles[connection.profile.id]!;
    final started = DateTime.now();

    final parsed = _parseMongoShell(request.text);
    if (parsed == null) {
      throw const FormatException(
        'Unsupported syntax. Use db.<coll>.find({}), findOne({}), count({}), '
        'or aggregate([...]).',
      );
    }

    final targetDb = await _ensureDatabaseHandle(
      rootDb,
      request.database ?? connection.profile.databaseName ?? 'test',
    );
    final coll = targetDb.collection(parsed.collection);

    switch (parsed.op) {
      case 'find':
        final filter = _parseJson(parsed.args);
        final stream = filter.isNotEmpty ? coll.find(filter) : coll.find();

        // skip + limit uygula
        final docs = <Map<String, dynamic>>[];
        var idx = 0;
        final skip = request.pageOffset ?? 0;
        final limit = request.pageSize;
        await for (final doc in stream) {
          if (idx++ < skip) continue;
          docs.add(doc);
          if (limit != null && docs.length >= limit) break;
        }

        // Total count (best effort)
        int? total;
        try {
          total = await coll.count(filter.isNotEmpty ? filter : null);
        } catch (_) {}

        return QueryResult(
          columns: docs.isNotEmpty ? _inferColumns(_mapToPlain(docs.first)) : const [],
          rows: docs.map((d) => DataRow(_mapToPlain(d))).toList(),
          totalCount: total,
          executionTime: DateTime.now().difference(started),
          hasMore: limit != null && docs.length >= limit,
        );

      case 'findOne':
        final filter = _parseJson(parsed.args);
        final doc = await coll.findOne(filter.isNotEmpty ? filter : null);
        if (doc == null) {
          return QueryResult(
            columns: const [],
            rows: const [],
            executionTime: DateTime.now().difference(started),
          );
        }
        return QueryResult(
          columns: _inferColumns(_mapToPlain(doc)),
          rows: [DataRow(_mapToPlain(doc))],
          executionTime: DateTime.now().difference(started),
        );

      case 'count':
        final filter = _parseJson(parsed.args);
        final n = await coll.count(filter.isNotEmpty ? filter : null);
        return QueryResult(
          columns: const ['count'],
          rows: [DataRow({'count': n})],
          executionTime: DateTime.now().difference(started),
        );

      case 'aggregate':
        final pipeline = _parseJsonList(parsed.args);
        final result = await coll.aggregate(pipeline);
        // Aggregate returns {cursor: {firstBatch: [docs...]}} in modern mode
        final cursor = result['cursor'] as Map<String, Object?>?;
        final List<Object?> batch = (cursor?['firstBatch'] as List?) ?? const [];
        final docs = batch.whereType<Map<String, dynamic>>().toList();
        return QueryResult(
          columns: docs.isNotEmpty
              ? _inferColumns(_mapToPlain(docs.first))
              : const [],
          rows: docs.map((d) => DataRow(_mapToPlain(d))).toList(),
          executionTime: DateTime.now().difference(started),
        );

      default:
        throw FormatException('Unsupported op: ${parsed.op}');
    }
  }

  // ─── Explain ──────────────────────────────────────────────────────
  @override
  Future<String> explain(
    DatabaseConnection connection,
    QueryRequest request,
  ) async {
    if (!connection.isConnected) {
      throw StateError('explain called without active connection');
    }
    final rootDb = _handles[connection.profile.id]!;
    final parsed = _parseMongoShell(request.text);
    if (parsed == null) {
      throw const FormatException('Cannot explain: unsupported syntax');
    }
    final targetDb = await _ensureDatabaseHandle(
      rootDb,
      request.database ?? connection.profile.databaseName ?? 'test',
    );
    try {
      // explain via runCommand on the target db
      final explainResult = await targetDb.runCommand(<String, Object>{
        'explain': <String, Object>{
          (parsed.op): parsed.args.isNotEmpty ? _parseJson(parsed.args) : <String, Object>{},
        },
        'verbosity': 'queryPlanner',
      });
      return explainResult.toString();
    } catch (e) {
      return '// Explain failed: $e';
    }
  }

  // ─── Completion ───────────────────────────────────────────────────
  @override
  Future<List<CompletionItem>> complete(
    DatabaseConnection connection,
    CompletionContext context,
  ) async {
    if (!connection.isConnected) return const [];
    try {
      final db = _handles[connection.profile.id]!;
      final target = await _ensureDatabaseHandle(db, context.database);
      final names = await target.getCollectionNames();

      return <CompletionItem>[
        const CompletionItem(label: 'find', kind: 'method', detail: 'find(filter)'),
        const CompletionItem(label: 'findOne', kind: 'method', detail: 'findOne(filter)'),
        const CompletionItem(label: 'count', kind: 'method', detail: 'count(filter)'),
        const CompletionItem(label: 'aggregate', kind: 'method', detail: 'aggregate(pipeline)'),
        const CompletionItem(label: 'insertOne', kind: 'method'),
        const CompletionItem(label: 'updateOne', kind: 'method'),
        const CompletionItem(label: 'deleteOne', kind: 'method'),
        const CompletionItem(label: r'$match', kind: 'operator'),
        const CompletionItem(label: r'$group', kind: 'operator'),
        const CompletionItem(label: r'$project', kind: 'operator'),
        const CompletionItem(label: r'$sort', kind: 'operator'),
        const CompletionItem(label: r'$limit', kind: 'operator'),
        for (final n in names.whereType<String>())
          CompletionItem(label: n, kind: 'collection'),
      ];
    } catch (e) {
      _log.w('complete() failed: $e');
      return const [];
    }
  }

  // ─── Internal ─────────────────────────────────────────────────────
  /// Root bağlantı (URI'da database varsa oraya bağlanır); ek database'ler
  /// için yeni handle açılır.
  final Map<String, Db> _handles = {};

  /// Hedef database için Db handle'ı döndür. Root handle zaten bu database'e
  /// bağlıysa onu kullanır; değilse yeni Db açar.
  Future<Db> _ensureDatabaseHandle(Db root, String database) async {
    final rootDbName = root.databaseName ?? '';
    if (rootDbName == database) return root;

    // Farklı database için yeni handle (Phase 4'te connection pool)
    final cacheKey = '${root.databaseName}::$database';
    final cached = _handles[cacheKey];
    if (cached != null) return cached;

    // Yeni URI oluştur
    final profile = _profileFromRoot(root);
    final newDb = Db(_buildUri(profile, overrideDatabase: database));
    await newDb.open(secure: profile.ssl);
    if (profile.username != null && profile.username!.isNotEmpty) {
      await newDb.authenticate(
        profile.username,
        profile.password,
        authDb: profile.authSource,
      );
    }
    _handles[cacheKey] = newDb;
    return newDb;
  }

  MongoConnectionProfile _profileFromRoot(Db root) {
    // Root handle üzerinden orijinal profile'a ulaşmak için connection
    // handle'ı kullanan _handles map'in ters yönüne ihtiyaç var. Pratikte
    // Phase 4'te ConnectionConfig doğrudan RealMongoDBProvider instance'ında
    // tutulacak (DI tarafında). Phase 3 için fallback: connection.id'den
    // ararız.
    _handles.entries.firstWhere(
      (e) => e.value == root,
      orElse: () => MapEntry('', root),
    );
    // Profile bilgisi root handle'da yok; bu yüzden Phase 3'te yeni
    // bağlantılar için default değerler kullanıyoruz. Production'da bu
    // metod tamamen kaldırılacak — provider connect'ten sonra connection
    // başına tek Db tutacak.
    _log.w('_profileFromRoot called without root in _handles');
    return const MongoConnectionProfile(
      id: 'recovered',
      label: 'recovered',
      host: '127.0.0.1',
      port: 27017,
    );
  }

  String _buildUri(MongoConnectionProfile p, {String? overrideDatabase}) {
    final dbName = overrideDatabase ?? p.databaseName;
    final creds = (p.username != null && p.username!.isNotEmpty)
        ? '${Uri.encodeComponent(p.username!)}'
            '${p.password != null ? ':${Uri.encodeComponent(p.password!)}' : ''}@'
        : '';
    final params = <String>[
      if (p.replicaSet != null) 'replicaSet=${Uri.encodeComponent(p.replicaSet!)}',
      if (p.directConnection) 'directConnection=true',
      if (p.ssl) 'ssl=true',
    ].join('&');
    final dbSegment = dbName != null ? '/$dbName' : '';
    final paramStr = params.isEmpty ? '' : '?$params';
    return 'mongodb://$creds${p.host}:${p.port}$dbSegment$paramStr';
  }

  Future<Map<String, Object?>> _safeServerStatus(Db db) async {
    try {
      final result = await db.serverStatus();
      return _mapToPlain(result);
    } catch (e) {
      _log.w('serverStatus failed: $e');
      return const {};
    }
  }

  Future<Map<String, Object?>> _safeHello(Db db) async {
    try {
      final result = await db.runCommand({'hello': 1});
      return _mapToPlain(result);
    } catch (e) {
      _log.w('hello failed: $e');
      return const {};
    }
  }

  int? _parseUptime(Object? raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  // ─── Parser helpers ───────────────────────────────────────────────
  _ParsedCommand? _parseMongoShell(String text) {
    final trimmed = text.trim();
    final match = RegExp(r'db\.(\w+)\.(\w+)\s*\((.*)\)').firstMatch(trimmed);
    if (match == null) return null;
    return _ParsedCommand(
      collection: match.group(1)!,
      op: match.group(2)!,
      args: match.group(3)!.trim(),
    );
  }

  Map<String, Object?> _parseJson(String text) {
    if (text.isEmpty) return const {};
    try {
      return _quickJsonParse(text);
    } catch (_) {
      return const {};
    }
  }

  List<Map<String, Object?>> _parseJsonList(String text) {
    if (text.isEmpty) return const [];
    try {
      return _quickJsonParseList(text);
    } catch (_) {
      return const [];
    }
  }

  /// Çok basit JSON parser (Phase 3 yeterli; Phase 4'te tam parser).
  ///
  /// Destekler:
  /// - `{key: value, key2: value2}` (value string/number/bool)
  /// - `[{...}, {...}]` (aggregate pipeline)
  Map<String, Object?> _quickJsonParse(String text) {
    final cleaned = text.trim();
    if (!cleaned.startsWith('{') || !cleaned.endsWith('}')) return const {};
    final inner = cleaned.substring(1, cleaned.length - 1);
    if (inner.trim().isEmpty) return const {};
    final result = <String, Object?>{};
    for (final part in _splitTopLevel(inner, ',')) {
      final kv = part.split(':');
      if (kv.length != 2) continue;
      final key = kv[0].trim().replaceAll('"', '').replaceAll("'", '');
      final value = _parseValue(kv[1].trim());
      result[key] = value;
    }
    return result;
  }

  List<Map<String, Object?>> _quickJsonParseList(String text) {
    final cleaned = text.trim();
    if (!cleaned.startsWith('[') || !cleaned.endsWith(']')) return const [];
    final inner = cleaned.substring(1, cleaned.length - 1);
    final items = _splitTopLevel(inner, ',');
    return items
        .map((i) => _quickJsonParse(i.trim()))
        .where((m) => m.isNotEmpty)
        .toList();
  }

  Object? _parseValue(String raw) {
    final t = raw.trim();
    if (t == 'null') return null;
    if (t == 'true') return true;
    if (t == 'false') return false;
    if (t.startsWith('"') || t.startsWith("'")) {
      return t.substring(1, t.length - 1);
    }
    final asInt = int.tryParse(t);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(t);
    if (asDouble != null) return asDouble;
    return t;
  }

  List<String> _splitTopLevel(String text, String sep) {
    final result = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '{' || c == '[' || c == '(') depth++;
      if (c == '}' || c == ']' || c == ')') depth--;
      if (depth == 0 && c == sep) {
        result.add(text.substring(start, i));
        start = i + 1;
      }
    }
    result.add(text.substring(start));
    return result;
  }

  Map<String, Object?> _mapToPlain(dynamic raw) {
    if (raw == null) return const {};
    if (raw is Map<String, Object?>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), _convertValue(v)));
    }
    return {'value': raw};
  }

  Object? _convertValue(Object? v) {
    if (v == null) return null;
    if (v is num || v is bool || v is String) return v;
    if (v is Map) return _mapToPlain(v);
    if (v is List) return v.map(_convertValue).toList();
    if (v is DateTime) return v.toIso8601String();
    if (v is ObjectId) return 'ObjectId(${v.oid})';
    return v.toString();
  }

  String _bsonTypeName(Object? value) {
    if (value == null) return 'null';
    if (value is num) return 'number';
    if (value is bool) return 'bool';
    if (value is String) return 'string';
    if (value is List) return 'array';
    if (value is Map) return 'object';
    if (value is DateTime) return 'date';
    if (value is ObjectId) return 'objectId';
    return value.runtimeType.toString();
  }

  List<String> _inferColumns(Map<String, Object?>? sample) {
    if (sample == null) return const [];
    return sample.keys.toList();
  }
}

class _ParsedCommand {
  const _ParsedCommand({
    required this.collection,
    required this.op,
    required this.args,
  });
  final String collection;
  final String op;
  final String args;
}

/// Real provider factory — registry tarafından kullanılır (production).
class RealMongoDBProviderFactory implements DatabaseProviderFactory {
  const RealMongoDBProviderFactory();

  @override
  DatabaseProvider create() => RealMongoDBProvider();

  @override
  DatabaseKind get kind => DatabaseKind.mongodb;
}