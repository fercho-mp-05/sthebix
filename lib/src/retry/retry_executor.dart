import 'dart:async';

import 'retry_policy.dart';

class RetryExecutor {
  const RetryExecutor();

  Future<T> run<T>(
    Future<T> Function() action, {
    required RetryPolicy policy,
    FutureOr<void> Function(
      int retryAttempt,
      Duration nextDelay,
      Object error,
      StackTrace stackTrace,
    )?
    onRetry,
  }) async {
    var retries = 0;

    while (true) {
      try {
        return await action();
      } on Object catch (error, stackTrace) {
        if (!policy.canRetry(retries, error, stackTrace)) {
          Error.throwWithStackTrace(error, stackTrace);
        }

        retries += 1;
        final delay = policy.delayForRetry(retries);
        await onRetry?.call(retries, delay, error, stackTrace);

        if (delay > Duration.zero) {
          await Future<void>.delayed(delay);
        }
      }
    }
  }
}
