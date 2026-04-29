abstract interface class RequestLogger {
  void log(String message);
}

class CallbackRequestLogger implements RequestLogger {
  const CallbackRequestLogger(this.onLog);

  final void Function(String message) onLog;

  @override
  void log(String message) => onLog(message);
}

class NoopRequestLogger implements RequestLogger {
  const NoopRequestLogger();

  @override
  void log(String message) {}
}
