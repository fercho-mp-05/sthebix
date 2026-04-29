import 'dart:async';

import '../models/cached_response.dart';
import '../models/request_snapshot.dart';

abstract class RequestInterceptor {
  const RequestInterceptor();

  FutureOr<RequestSnapshot> onRequest(RequestSnapshot request) => request;

  FutureOr<CachedResponse> onResponse(
    RequestSnapshot request,
    CachedResponse response,
  ) => response;

  FutureOr<void> onError(
    RequestSnapshot request,
    Object error,
    StackTrace stackTrace,
  ) {}
}
