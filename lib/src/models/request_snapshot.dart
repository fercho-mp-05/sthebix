class RequestSnapshot {
  const RequestSnapshot({
    required this.method,
    required this.uri,
    required this.headers,
    this.body,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final Object? body;

  RequestSnapshot copyWith({
    String? method,
    Uri? uri,
    Map<String, String>? headers,
    Object? body,
  }) {
    return RequestSnapshot(
      method: method ?? this.method,
      uri: uri ?? this.uri,
      headers: headers ?? this.headers,
      body: body ?? this.body,
    );
  }
}
