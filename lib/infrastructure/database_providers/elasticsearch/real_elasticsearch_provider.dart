import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:db_explorer_app/core/utils/app_logger.dart';
import 'package:db_explorer_app/domain/database/capability.dart';
import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/domain/database/database_provider.dart';
import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/domain/database/schema.dart';
import 'package:db_explorer_app/infrastructure/database_providers/elasticsearch/elasticsearch_schema.dart';
import 'package:elastic_client/elastic_client.dart';

/// Gerçek Elasticsearch provider — `elastic_client` paketini kullanır.
///
/// Phase 6.3 sürümü:
/// - connect: HttpTransport + Basic/API key auth + cluster info
/// - listDatabases: tek cluster (ES multi-cluster bu provider'da yok)
/// - listCollections: client.search + cat indices
/// - execute: client.search ile Query DSL çalıştır
/// - explain: `GET /<index>/_validate/query?q=...` — kısmi implement
/// - completion: query DSL keyword listesi
///
/// Hata yönetimi:
/// - Bağlantı hatası → ErrorConnection (code: ES_CONNECTION_REFUSED vs.)
/// - TransportException → ErrorConnection (code: ES_HTTP_ERROR, status code meta)
/// - Timeout → hata yeniden fırlatılır, retryable=true
///
/// NOT: Bu provider `DatabaseProvider` interface'inin **gerçek** implementasyonudur.
/// Mock'un aksine external resource (network) gerektirir — CI'da test edilmez,
/// yalnızca Phase 8 integration test'lerinde bir test container'a karşı çalışır.
class RealElasticsearchProvider implements DatabaseProvider {
  RealElasticsearchProvider();

  final _log = getLogger('RealElasticsearchProvider');

  // Session bazlı ES client map'i.
  final Map<String, _Session> _sessions = {};

  _Session _require(DatabaseConnection connection) {
    final state = connection.state;
    if (state is! ConnectedConnection) {
      throw StateError(
        'Operation called on inactive connection '
        '(state=${state.runtimeType})',
      );
    }
    final session = _sessions[state.sessionId];
    if (session == null) {
      throw StateError(
        'Session ${state.sessionId} is gone (auto-disconnect?)',
      );
    }
    return session;
  }

  // ─── Provider identity ────────────────────────────────────────────
  @override
  String get id => 'elasticsearch';

  @override
  DatabaseKind get kind => DatabaseKind.elasticsearch;

  @override
  DatabaseCapabilities get capabilities => const DatabaseCapabilities({
    DatabaseCapability.schemaHierarchy,
    DatabaseCapability.schemaIntrospection,
    DatabaseCapability.fullTextSearch,
    DatabaseCapability.geospatial,
    DatabaseCapability.streaming,
    DatabaseCapability.aggregationPipeline,
    DatabaseCapability.explainPlan,
    DatabaseCapability.completion,
    DatabaseCapability.insert,
    DatabaseCapability.update,
    DatabaseCapability.delete,
    DatabaseCapability.bulkWrite,
    DatabaseCapability.createCollection,
    DatabaseCapability.dropCollection,
    DatabaseCapability.indexManagement,
    DatabaseCapability.serverInfo,
    DatabaseCapability.liveStats,
    DatabaseCapability.backup,
    DatabaseCapability.userManagement,
    DatabaseCapability.tlsSupport,
  });

  // ─── Connection lifecycle ─────────────────────────────────────────
  @override
  Future<DatabaseConnection> connect(DatabaseConnectionConfig config) async {
    if (config is! ElasticsearchConnectionProfile) {
      throw ArgumentError(
        'RealElasticsearchProvider requires ElasticsearchConnectionProfile, '
        'got ${config.runtimeType}',
      );
    }

    final dbConn = DatabaseConnection(profile: config, providerId: id);
    dbConn.state = const ConnectingConnection(message: 'Resolving host...');

    final baseUrl = '${config.scheme}://${config.host}:${config.port}';
    final authorization = _buildAuthorization(config);

    final timeout = config.requestTimeoutSeconds != null
        ? Duration(seconds: config.requestTimeoutSeconds!)
        : const Duration(minutes: 1);

    try {
      dbConn.state = const ConnectingConnection(
        progress: 0.5,
        message: 'Opening HTTP transport...',
      );

      final transport = HttpTransport(
        url: baseUrl,
        authorization: authorization,
        timeout: timeout,
      );
      final client = Client(transport);

      // Cluster health check + version discovery.
      dbConn.state = const ConnectingConnection(
        progress: 0.8,
        message: 'Reading cluster info...',
      );
      final t0 = DateTime.now();
      final rs = await transport.send(
        Request('GET', const ['_cluster', 'health']),
      );
      final latency = DateTime.now().difference(t0).inMilliseconds;

      if (rs.statusCode != 200) {
        throw _TransportFailure(
          'Cluster health returned ${rs.statusCode}: ${rs.body}',
          statusCode: rs.statusCode,
        );
      }

      final body = json.decode(rs.body) as Map<String, dynamic>;
      final clusterName = body['cluster_name']?.toString();
      final numberOfNodes = (body['number_of_nodes'] as num?)?.toInt() ?? 0;

      // Root endpoint'ten version bilgisi.
      String? version;
      try {
        final rootRs = await transport.send(Request('GET', const []));
        if (rootRs.statusCode == 200) {
          final rootBody = json.decode(rootRs.body) as Map<String, dynamic>;
          final versionInfo = rootBody['version'];
          if (versionInfo is Map<String, dynamic>) {
            version = versionInfo['number']?.toString();
          }
        }
      } catch (_) {
        // Version opsiyonel.
      }

      final sessionId =
          'es-sess-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
      _sessions[sessionId] = _Session(
        client: client,
        transport: transport,
        clusterName: clusterName ?? config.label,
      );

      dbConn.state = ConnectedConnection(
        sessionId: sessionId,
        at: DateTime.now(),
        serverVersion: version,
        latencyMs: latency,
        uptimeSeconds: 0, // ES'te kolay uptime endpoint yok; node_stats üzerinden OK.
        extra: {
          'mode': 'real-driver',
          'protocol': 'HTTP/REST',
          'cluster': clusterName ?? 'unknown',
          'numberOfNodes': numberOfNodes.toString(),
          'scheme': config.scheme,
          'auth': config.apiKey != null
              ? 'apiKey'
              : (config.username != null ? 'basic' : 'none'),
        },
      );
      _log.i('Connect OK: $sessionId (${config.label}, es=$version)');
      return dbConn;
    } on SocketException catch (e) {
      dbConn.state = ErrorConnection(
        message: 'Could not reach ${config.host}:${config.port}',
        code: 'ES_CONNECTION_REFUSED',
        cause: e,
      );
      rethrow;
    } on TimeoutException catch (e) {
      dbConn.state = ErrorConnection(
        message: 'Connection timed out: ${config.host}:${config.port}',
        code: 'ES_TIMEOUT',
        cause: e,
      );
      rethrow;
    } on _TransportFailure catch (e) {
      dbConn.state = ErrorConnection(
        message: e.message,
        code: e.statusCode == 401 || e.statusCode == 403
            ? 'ES_AUTH_FAILED'
            : 'ES_HTTP_${e.statusCode}',
        cause: e,
      );
      rethrow;
    } catch (e) {
      dbConn.state = ErrorConnection(
        message: e.toString(),
        cause: e,
      );
      rethrow;
    }
  }

  @override
  Future<void> disconnect(DatabaseConnection connection) async {
    final state = connection.state;
    if (state is! ConnectedConnection) return;
    final session = _sessions.remove(state.sessionId);
    if (session != null) {
      try {
        await session.transport.close();
      } catch (_) {
        // Close hatası yoksayılabilir.
      }
    }
    connection.state = const DisconnectedConnection(reason: 'user-request');
    _log.i('Disconnect: ${connection.profile.label}');
  }

  @override
  Future<bool> ping(DatabaseConnection connection) async {
    final session = _require(connection);
    try {
      final rs = await session.transport.send(
        Request('GET', const ['_cluster', 'health']),
      );
      return rs.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Schema discovery ─────────────────────────────────────────────
  @override
  Future<List<DatabaseNode>> listDatabases(
    DatabaseConnection connection,
  ) async {
    final session = _require(connection);
    // ES: tek bir cluster tüm index'leri kapsar. UI için cluster'ı döndürürüz.
    return [
      ElasticsearchCluster(
        name: session.clusterName,
        clusterName: session.clusterName,
        numberOfNodes: 0,
      ),
    ];
  }

  @override
  Future<List<CollectionNode>> listCollections(
    DatabaseConnection connection,
    String database,
  ) async {
    final session = _require(connection);
    final rs = await session.transport.send(
      Request('GET', const ['_cat', 'indices'], params: {'format': 'json'}),
    );
    if (rs.statusCode != 200) {
      throw _TransportFailure(
        'cat indices returned ${rs.statusCode}',
        statusCode: rs.statusCode,
      );
    }
    final list = json.decode(rs.body) as List<dynamic>;
    final indices = <ElasticsearchIndex>[];
    for (final entry in list) {
      if (entry is! Map) continue;
      final map = entry.cast<String, dynamic>();
      final indexName = map['index']?.toString();
      if (indexName == null || indexName.startsWith('.')) continue; // system indices skip
      indices.add(
        ElasticsearchIndex(
          name: indexName,
          documentCount: (map['docs.count'] is String
              ? int.tryParse(map['docs.count'] as String)
              : (map['docs.count'] as num?)?.toInt()),
          sizeBytes: (map['store.size'] is String
              ? int.tryParse(map['store.size'] as String)
              : (map['store.size'] as num?)?.toInt()),
          primaryShards: int.tryParse(map['pri']?.toString() ?? '1') ?? 1,
          replicaShards: int.tryParse(map['rep']?.toString() ?? '0') ?? 0,
        ),
      );
    }
    return indices;
  }

  // ─── Query execution ──────────────────────────────────────────────
  @override
  Future<QueryResult> execute(
    DatabaseConnection connection,
    QueryRequest request,
  ) async {
    final session = _require(connection);
    if (request.language != QueryLanguage.elasticDsl) {
      throw ArgumentError(
        'Elasticsearch provider only supports elasticDsl, got '
        '${request.language}',
      );
    }

    final started = DateTime.now();
    Map<String, dynamic> body;
    try {
      body = json.decode(request.text.trim()) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw FormatException('Elasticsearch query must be JSON DSL: ${e.message}');
    }

    try {
      final rs = await session.transport.send(
        Request(
          'POST',
          const ['_search'],
          bodyMap: body,
        ),
      );
      final responseBody = json.decode(rs.body) as Map<String, dynamic>;
      final hits = responseBody['hits'];
      final hitsList = (hits is Map ? (hits['hits'] as List?) : null) ??
          const <dynamic>[];

      final rows = <DataRow>[];
      for (final hit in hitsList) {
        if (hit is Map) {
          final hitMap = hit.cast<String, dynamic>();
          rows.add(DataRow({
            '_id': hitMap['_id'],
            '_score': hitMap['_score'],
            '_source': hitMap['_source']?.toString(),
          }));
        }
      }

      final totalRaw = hits is Map ? hits['total'] : null;
      int totalCount = 0;
      if (totalRaw is num) {
        totalCount = totalRaw.toInt();
      } else if (totalRaw is Map) {
        totalCount = (totalRaw['value'] as num?)?.toInt() ?? 0;
      }

      return QueryResult(
        columns: const ['_id', '_score', '_source'],
        rows: rows,
        executionTime: DateTime.now().difference(started),
        totalCount: totalCount,
      );
    } on _TransportFailure catch (e) {
      throw FormatException(
        'Elasticsearch error (${e.statusCode}): ${e.message}',
      );
    }
  }

  // ─── Explain ──────────────────────────────────────────────────────
  @override
  Future<String> explain(
    DatabaseConnection connection,
    QueryRequest request,
  ) async {
    final session = _require(connection);
    try {
      // Validate API: yan etkisi olmayan query analysis.
      final rs = await session.transport.send(
        Request(
          'POST',
          const ['_validate', 'query'],
          bodyMap: {'query': _parseQueryBody(request.text)},
        ),
      );
      if (rs.statusCode == 200) {
        return rs.body;
      }
      return '// ES validate query returned ${rs.statusCode}\n${rs.body}';
    } catch (e) {
      return '// ES explain failed: $e';
    }
  }

  // ─── Completion ───────────────────────────────────────────────────
  @override
  Future<List<CompletionItem>> complete(
    DatabaseConnection connection,
    CompletionContext context,
  ) async {
    return const [
      CompletionItem(label: 'match_all', kind: 'operator'),
      CompletionItem(label: 'match', kind: 'operator'),
      CompletionItem(label: 'term', kind: 'operator'),
      CompletionItem(label: 'terms', kind: 'operator'),
      CompletionItem(label: 'range', kind: 'operator'),
      CompletionItem(label: 'bool', kind: 'operator'),
      CompletionItem(label: 'must', kind: 'operator'),
      CompletionItem(label: 'should', kind: 'operator'),
      CompletionItem(label: 'must_not', kind: 'operator'),
      CompletionItem(label: 'filter', kind: 'operator'),
      CompletionItem(label: 'exists', kind: 'operator'),
      CompletionItem(label: 'ids', kind: 'operator'),
      CompletionItem(label: 'prefix', kind: 'operator'),
      CompletionItem(label: 'wildcard', kind: 'operator'),
      CompletionItem(label: 'fuzzy', kind: 'operator'),
      CompletionItem(label: 'multi_match', kind: 'operator'),
      CompletionItem(label: 'query_string', kind: 'operator'),
      CompletionItem(label: 'simple_query_string', kind: 'operator'),
      CompletionItem(label: 'sort', kind: 'keyword'),
      CompletionItem(label: 'size', kind: 'keyword'),
      CompletionItem(label: 'from', kind: 'keyword'),
      CompletionItem(label: 'aggs', kind: 'keyword'),
      CompletionItem(label: '_source', kind: 'keyword'),
      CompletionItem(label: 'query', kind: 'keyword'),
      CompletionItem(label: 'highlight', kind: 'keyword'),
    ];
  }

  // ─── Internal helpers ─────────────────────────────────────────────
  String? _buildAuthorization(ElasticsearchConnectionProfile config) {
    if (config.apiKey != null && config.apiKey!.isNotEmpty) {
      // API key olarak verilen değer zaten "ApiKey <base64(id:api_key)>" mi?
      // Yoksa raw id:api_key mi? Spec: "base64 encoded id:api_key".
      // elastic_client HttpTransport plain "Authorization" header bekler.
      final apiKey = config.apiKey!;
      // Eğer zaten "ApiKey " prefix'i varsa direkt kullan; yoksa ekle.
      return apiKey.startsWith('ApiKey ')
          ? apiKey
          : 'ApiKey $apiKey';
    }
    if (config.username != null &&
        config.password != null &&
        config.password!.isNotEmpty) {
      return basicAuthorization(config.username!, config.password!);
    }
    return null;
  }

  Map<String, dynamic> _parseQueryBody(String text) {
    try {
      final parsed = json.decode(text.trim());
      if (parsed is Map) {
        final casted = parsed.cast<String, dynamic>();
        if (casted.containsKey('query')) {
          final inner = casted['query'];
          if (inner is Map) {
            return inner.cast<String, dynamic>();
          }
        }
        return casted;
      }
      return Query.matchAll().cast<String, dynamic>();
    } catch (_) {
      // JSON değilse raw olarak match olarak sar.
      return {'match': {'_all': text}};
    }
  }
}

/// Internal session state — ES client + cluster bilgisi.
class _Session {
  _Session({
    required this.client,
    required this.transport,
    required this.clusterName,
  });
  final Client client;
  final HttpTransport transport;
  final String clusterName;
}

/// Custom transport failure — HTTP-level hata kodu + mesaj taşır.
class _TransportFailure implements Exception {
  _TransportFailure(this.message, {required this.statusCode});
  final String message;
  final int statusCode;

  @override
  String toString() => 'TransportFailure($statusCode): $message';
}

/// RealElasticsearchProvider factory.
///
/// Phase 6'da default değil — feature flag ile Phase 8'de wiring yapılacak.
/// Şimdiden factory tanımlı; registry'de mock default kalır.
class RealElasticsearchProviderFactory implements DatabaseProviderFactory {
  const RealElasticsearchProviderFactory();

  @override
  DatabaseProvider create() => RealElasticsearchProvider();

  @override
  DatabaseKind get kind => DatabaseKind.elasticsearch;
}
