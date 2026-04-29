class SmartResponse<T> {
  const SmartResponse({
    required this.data,
    required this.statusCode,
    required this.headers,
    required this.fromCache,
    required this.isStale,
    required this.cacheKey,
  });

  final T data;
  final int statusCode;
  final Map<String, String> headers;
  final bool fromCache;
  final bool isStale;
  final String cacheKey;
}
