import '../logging/request_logger.dart';
import '../models/cached_response.dart';
import '../models/request_snapshot.dart';
import 'request_interceptor.dart';

class LoggingInterceptor extends RequestInterceptor {
  const LoggingInterceptor(this.logger);

  final RequestLogger logger;

  @override
  RequestSnapshot onRequest(RequestSnapshot request) {
    logger.log('HTTP ${request.method} ${request.uri}');
    return request;
  }

  @override
  CachedResponse onResponse(RequestSnapshot request, CachedResponse response) {
    logger.log(
      'HTTP ${request.method} ${request.uri} -> ${response.statusCode}',
    );
    return response;
  }

  @override
  void onError(RequestSnapshot request, Object error, StackTrace stackTrace) {
    logger.log('HTTP ${request.method} ${request.uri} failed: $error');
  }
}
