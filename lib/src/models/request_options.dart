import '../retry/retry_policy.dart';

class RequestOptions {
  const RequestOptions({
    this.headers = const {},
    this.queryParameters = const {},
    this.cache = false,
    this.retry = true,
    this.ttl,
    this.timeout,
    this.retryPolicy,
    this.forceRefresh = false,
    this.staleCacheOnError = true,
    this.cacheKey,
  });

  static const smart = RequestOptions(cache: true, retry: true);

  final Map<String, String> headers;
  final Map<String, Object?> queryParameters;
  final bool cache;
  final bool retry;
  final Duration? ttl;
  final Duration? timeout;
  final RetryPolicy? retryPolicy;
  final bool forceRefresh;
  final bool staleCacheOnError;
  final String? cacheKey;

  RequestOptions copyWith({
    Map<String, String>? headers,
    Map<String, Object?>? queryParameters,
    bool? cache,
    bool? retry,
    Duration? ttl,
    Duration? timeout,
    RetryPolicy? retryPolicy,
    bool? forceRefresh,
    bool? staleCacheOnError,
    String? cacheKey,
  }) {
    return RequestOptions(
      headers: headers ?? this.headers,
      queryParameters: queryParameters ?? this.queryParameters,
      cache: cache ?? this.cache,
      retry: retry ?? this.retry,
      ttl: ttl ?? this.ttl,
      timeout: timeout ?? this.timeout,
      retryPolicy: retryPolicy ?? this.retryPolicy,
      forceRefresh: forceRefresh ?? this.forceRefresh,
      staleCacheOnError: staleCacheOnError ?? this.staleCacheOnError,
      cacheKey: cacheKey ?? this.cacheKey,
    );
  }
}
