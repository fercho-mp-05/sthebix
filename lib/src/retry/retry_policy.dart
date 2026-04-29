import '../errors/sthebix_exception.dart';

typedef RetryPredicate = bool Function(Object error, StackTrace stackTrace);

class RetryPolicy {
  const RetryPolicy({
    this.maxRetries = 2,
    this.initialDelay = const Duration(milliseconds: 300),
    this.maxDelay = const Duration(seconds: 5),
    this.backoffFactor = 2,
    this.shouldRetry,
  }) : assert(maxRetries >= 0, 'maxRetries must be greater than or equal to 0'),
       assert(
         backoffFactor >= 1,
         'backoffFactor must be greater than or equal to 1',
       );

  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffFactor;
  final RetryPredicate? shouldRetry;

  bool canRetry(int retriesSoFar, Object error, StackTrace stackTrace) {
    if (retriesSoFar >= maxRetries) return false;

    final predicate = shouldRetry ?? defaultShouldRetry;
    return predicate(error, stackTrace);
  }

  Duration delayForRetry(int retryAttempt) {
    if (retryAttempt <= 0) return Duration.zero;

    final multiplier = _pow(backoffFactor, retryAttempt - 1);
    final milliseconds = (initialDelay.inMilliseconds * multiplier).round();

    return Duration(
      milliseconds: milliseconds.clamp(0, maxDelay.inMilliseconds),
    );
  }

  static bool defaultShouldRetry(Object error, StackTrace stackTrace) {
    return error is NetworkRequestException ||
        error is RequestTimeoutException ||
        error is HttpStatusRequestException && error.isServerError;
  }

  double _pow(double base, int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i += 1) {
      result *= base;
    }
    return result;
  }
}
