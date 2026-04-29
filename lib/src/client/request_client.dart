import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cache/cache_entry.dart';
import '../cache/cache_key_builder.dart';
import '../cache/cache_manager.dart';
import '../cache/memory_cache_manager.dart';
import '../errors/sthebix_exception.dart';
import '../interceptors/request_interceptor.dart';
import '../models/cached_response.dart';
import '../models/request_options.dart';
import '../models/request_snapshot.dart';
import '../models/response_parser.dart';
import '../models/sthebix_response.dart';
import '../retry/retry_executor.dart';
import '../retry/retry_policy.dart';
import 'http_method.dart';

class RequestClient {
  RequestClient({
    required String baseUrl,
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 30),
    RetryPolicy retryPolicy = const RetryPolicy(),
    CacheManager<CachedResponse>? cacheManager,
    CacheKeyBuilder cacheKeyBuilder = defaultCacheKeyBuilder,
    http.Client? httpClient,
    List<RequestInterceptor> interceptors = const [],
  }) : _baseUri = Uri.parse(baseUrl),
       _defaultHeaders = Map.unmodifiable(headers),
       _timeout = timeout,
       _retryPolicy = retryPolicy,
       _cacheManager = cacheManager ?? MemoryCacheManager<CachedResponse>(),
       _cacheKeyBuilder = cacheKeyBuilder,
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _interceptors = List.unmodifiable(interceptors);

  final Uri _baseUri;
  final Map<String, String> _defaultHeaders;
  final Duration _timeout;
  final RetryPolicy _retryPolicy;
  final CacheManager<CachedResponse> _cacheManager;
  final CacheKeyBuilder _cacheKeyBuilder;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final List<RequestInterceptor> _interceptors;
  final RetryExecutor _retryExecutor = const RetryExecutor();

  Future<T> get<T>(
    String endpoint, {
    RequestOptions options = const RequestOptions(),
    ResponseParser<T>? parser,
  }) async {
    final response = await getResponse<T>(
      endpoint,
      options: options,
      parser: parser,
    );
    return response.data;
  }

  Future<T> smartGet<T>(
    String endpoint, {
    RequestOptions options = RequestOptions.smart,
    ResponseParser<T>? parser,
  }) {
    return get<T>(endpoint, options: options, parser: parser);
  }

  Future<T> post<T>(
    String endpoint, {
    Object? body,
    RequestOptions options = const RequestOptions(),
    ResponseParser<T>? parser,
  }) async {
    final response = await send<T>(
      HttpMethod.post,
      endpoint,
      body: body,
      options: options,
      parser: parser,
    );
    return response.data;
  }

  Future<T> put<T>(
    String endpoint, {
    Object? body,
    RequestOptions options = const RequestOptions(),
    ResponseParser<T>? parser,
  }) async {
    final response = await send<T>(
      HttpMethod.put,
      endpoint,
      body: body,
      options: options,
      parser: parser,
    );
    return response.data;
  }

  Future<T> delete<T>(
    String endpoint, {
    Object? body,
    RequestOptions options = const RequestOptions(),
    ResponseParser<T>? parser,
  }) async {
    final response = await send<T>(
      HttpMethod.delete,
      endpoint,
      body: body,
      options: options,
      parser: parser,
    );
    return response.data;
  }

  Future<SmartResponse<T>> getResponse<T>(
    String endpoint, {
    RequestOptions options = const RequestOptions(),
    ResponseParser<T>? parser,
  }) {
    return send<T>(HttpMethod.get, endpoint, options: options, parser: parser);
  }

  Future<SmartResponse<T>> send<T>(
    HttpMethod method,
    String endpoint, {
    Object? body,
    RequestOptions options = const RequestOptions(),
    ResponseParser<T>? parser,
  }) async {
    final request = _createRequest(method, endpoint, body, options);
    final cacheKey =
        options.cacheKey ??
        _cacheKeyBuilder(
          CacheKeyParts(method: request.method, uri: request.uri, body: body),
        );

    if (options.cache && !options.forceRefresh) {
      final cached = await _cacheManager.get(cacheKey);
      if (cached != null) {
        return _fromCache<T>(
          cached,
          parser: parser,
          cacheKey: cacheKey,
          isStale: false,
        );
      }
    }

    try {
      final response = await _executeWithPolicy(request, options);

      if (options.cache) {
        await _cacheManager.set(cacheKey, response, ttl: options.ttl);
      }

      return _fromNetwork<T>(response, parser: parser, cacheKey: cacheKey);
    } on SmartRequestException catch (error, stackTrace) {
      if (options.cache && options.staleCacheOnError) {
        final cached = await _cacheManager.get(cacheKey, includeExpired: true);
        if (cached != null) {
          return _fromCache<T>(
            cached,
            parser: parser,
            cacheKey: cacheKey,
            isStale: cached.isExpired,
          );
        }
      }

      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> clearCache() => _cacheManager.clear();

  Future<void> deleteCacheEntry(String cacheKey) =>
      _cacheManager.delete(cacheKey);

  void close() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  RequestSnapshot _createRequest(
    HttpMethod method,
    String endpoint,
    Object? body,
    RequestOptions options,
  ) {
    final headers = {..._defaultHeaders, ...options.headers};

    if (body != null &&
        !_hasHeader(headers, 'content-type') &&
        body is! String &&
        body is! List<int>) {
      headers['content-type'] = 'application/json';
    }

    return RequestSnapshot(
      method: method.value,
      uri: _buildUri(endpoint, options.queryParameters),
      headers: headers,
      body: body,
    );
  }

  Future<CachedResponse> _executeWithPolicy(
    RequestSnapshot request,
    RequestOptions options,
  ) {
    final timeout = options.timeout ?? _timeout;
    final policy = options.retry
        ? options.retryPolicy ?? _retryPolicy
        : const RetryPolicy(maxRetries: 0);

    return _retryExecutor.run(
      () => _performRequest(request, timeout: timeout),
      policy: policy,
    );
  }

  Future<CachedResponse> _performRequest(
    RequestSnapshot request, {
    required Duration timeout,
  }) async {
    var currentRequest = request;

    try {
      for (final interceptor in _interceptors) {
        currentRequest = await interceptor.onRequest(currentRequest);
      }

      final httpRequest = http.Request(
        currentRequest.method,
        currentRequest.uri,
      )..headers.addAll(currentRequest.headers);

      _writeBody(httpRequest, currentRequest.body);

      final streamedResponse = await _httpClient
          .send(httpRequest)
          .timeout(timeout);
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(timeout);

      var cachedResponse = CachedResponse(
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
      );

      for (final interceptor in _interceptors) {
        cachedResponse = await interceptor.onResponse(
          currentRequest,
          cachedResponse,
        );
      }

      if (cachedResponse.statusCode < 200 || cachedResponse.statusCode >= 300) {
        throw HttpStatusRequestException(
          'HTTP ${cachedResponse.statusCode} returned for ${currentRequest.uri}',
          uri: currentRequest.uri,
          statusCode: cachedResponse.statusCode,
          headers: cachedResponse.headers,
          body: cachedResponse.body,
        );
      }

      return cachedResponse;
    } on Object catch (error, stackTrace) {
      final exception = _normalizeException(
        error,
        uri: currentRequest.uri,
        stackTrace: stackTrace,
      );
      await _notifyError(currentRequest, exception, stackTrace);
      Error.throwWithStackTrace(exception, stackTrace);
    }
  }

  Future<void> _notifyError(
    RequestSnapshot request,
    Object error,
    StackTrace stackTrace,
  ) async {
    for (final interceptor in _interceptors) {
      await interceptor.onError(request, error, stackTrace);
    }
  }

  SmartResponse<T> _fromNetwork<T>(
    CachedResponse response, {
    required ResponseParser<T>? parser,
    required String cacheKey,
  }) {
    return SmartResponse<T>(
      data: _parseBody<T>(response, parser),
      statusCode: response.statusCode,
      headers: response.headers,
      fromCache: false,
      isStale: false,
      cacheKey: cacheKey,
    );
  }

  SmartResponse<T> _fromCache<T>(
    CacheEntry<CachedResponse> entry, {
    required ResponseParser<T>? parser,
    required String cacheKey,
    required bool isStale,
  }) {
    final response = entry.value;
    return SmartResponse<T>(
      data: _parseBody<T>(response, parser),
      statusCode: response.statusCode,
      headers: response.headers,
      fromCache: true,
      isStale: isStale,
      cacheKey: cacheKey,
    );
  }

  T _parseBody<T>(CachedResponse response, ResponseParser<T>? parser) {
    try {
      if (T == String) {
        return response.body as T;
      }

      final decoded = _decodeResponseBody(response.body, response.headers);
      if (parser != null) {
        return parser(decoded);
      }

      return decoded as T;
    } on Object catch (error, stackTrace) {
      throw ResponseParseRequestException(
        'Could not parse response as $T. Provide a parser for custom models.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Uri _buildUri(String endpoint, Map<String, Object?> queryParameters) {
    final endpointUri = Uri.parse(endpoint);
    final resolved = endpointUri.hasScheme
        ? endpointUri
        : _baseUri.replace(path: _joinPaths(_baseUri.path, endpoint));

    return _mergeQuery(resolved, queryParameters);
  }

  Uri _mergeQuery(Uri uri, Map<String, Object?> queryParameters) {
    if (queryParameters.isEmpty) return uri;

    final pairs = <MapEntry<String, String>>[];
    for (final entry in uri.queryParametersAll.entries) {
      for (final value in entry.value) {
        pairs.add(MapEntry(entry.key, value));
      }
    }

    for (final entry in queryParameters.entries) {
      final value = entry.value;
      if (value == null) continue;

      if (value is Iterable) {
        for (final item in value) {
          pairs.add(MapEntry(entry.key, item.toString()));
        }
      } else {
        pairs.add(MapEntry(entry.key, value.toString()));
      }
    }

    final query = pairs
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');

    return uri.replace(query: query.isEmpty ? null : query);
  }

  String _joinPaths(String basePath, String endpoint) {
    final left = basePath.endsWith('/')
        ? basePath.substring(0, basePath.length - 1)
        : basePath;
    final right = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;

    if (left.isEmpty) return '/$right';
    if (right.isEmpty) return left;
    return '$left/$right';
  }

  void _writeBody(http.Request request, Object? body) {
    if (body == null) return;

    if (body is String) {
      request.body = body;
      return;
    }

    if (body is List<int>) {
      request.bodyBytes = body;
      return;
    }

    request.body = jsonEncode(body);
  }

  Object? _decodeResponseBody(String body, Map<String, String> headers) {
    if (body.isEmpty) return null;

    final contentType = _headerValue(headers, 'content-type');
    final looksLikeJson = body.startsWith('{') || body.startsWith('[');
    final shouldDecodeJson =
        contentType?.contains('application/json') == true || looksLikeJson;

    if (shouldDecodeJson) {
      return jsonDecode(body);
    }

    return body;
  }

  SmartRequestException _normalizeException(
    Object error, {
    required Uri uri,
    required StackTrace stackTrace,
  }) {
    if (error is SmartRequestException) return error;

    if (error is TimeoutException) {
      return RequestTimeoutException(
        'Request timed out for $uri',
        uri: uri,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is http.ClientException) {
      return NetworkRequestException(
        error.message,
        uri: uri,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return NetworkRequestException(
      'Request failed for $uri',
      uri: uri,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  bool _hasHeader(Map<String, String> headers, String name) {
    return _headerValue(headers, name) != null;
  }

  String? _headerValue(Map<String, String> headers, String name) {
    final lowerName = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lowerName) {
        return entry.value.toLowerCase();
      }
    }
    return null;
  }
}
