abstract class SmartRequestException implements Exception {
  const SmartRequestException(
    this.message, {
    this.uri,
    this.cause,
    this.stackTrace,
  });

  final String message;
  final Uri? uri;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() {
    final buffer = StringBuffer(runtimeType)
      ..write(': ')
      ..write(message);
    if (uri != null) buffer.write(' ($uri)');
    if (cause != null) buffer.write(' Cause: $cause');
    return buffer.toString();
  }
}

final class NetworkRequestException extends SmartRequestException {
  const NetworkRequestException(
    super.message, {
    super.uri,
    super.cause,
    super.stackTrace,
  });
}

final class RequestTimeoutException extends SmartRequestException {
  const RequestTimeoutException(
    super.message, {
    super.uri,
    super.cause,
    super.stackTrace,
  });
}

final class HttpStatusRequestException extends SmartRequestException {
  const HttpStatusRequestException(
    super.message, {
    required this.statusCode,
    required this.headers,
    this.body,
    super.uri,
    super.cause,
    super.stackTrace,
  });

  final int statusCode;
  final Map<String, String> headers;
  final String? body;

  bool get isServerError => statusCode >= 500 && statusCode <= 599;
}

final class ResponseParseRequestException extends SmartRequestException {
  const ResponseParseRequestException(
    super.message, {
    super.uri,
    super.cause,
    super.stackTrace,
  });
}

final class CacheRequestException extends SmartRequestException {
  const CacheRequestException(
    super.message, {
    super.uri,
    super.cause,
    super.stackTrace,
  });
}
