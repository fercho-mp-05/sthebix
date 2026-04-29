class CachedResponse {
  const CachedResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final String body;

  Map<String, Object?> toJson() {
    return {'statusCode': statusCode, 'headers': headers, 'body': body};
  }

  factory CachedResponse.fromJson(Map<String, Object?> json) {
    return CachedResponse(
      statusCode: json['statusCode'] as int,
      headers: Map<String, String>.from(json['headers'] as Map),
      body: json['body'] as String,
    );
  }
}
