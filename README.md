# Sthebix

Sthebix: intelligent HTTP requests for Dart — cache, retry, and resilience out of the box.

Pure Dart HTTP client focused on simple, resilient REST calls: cache in memory,
TTL, retry with exponential backoff, timeout, typed parsing, interceptors, and
custom errors.

---

## Features

- GET, POST, PUT, and DELETE.
- Base URL, global headers, per-request headers, query parameters, and timeout.
- Memory cache with TTL and stale-cache fallback when the network fails.
- Extensible `CacheManager<T>` contract for future Hive, SQLite, Redis, file, or secure-storage implementations.
- Retry policy with configurable retry count, initial delay, max delay, and exponential factor.
- Default retry only for transient failures: network errors, timeout, and 5xx.
- Custom exceptions instead of generic `Exception`.
- Basic interceptors and callback-based logging.

---

## Quick start

```dart
import 'package:sthebix/sthebix.dart';

final api = RequestClient(
  baseUrl: 'https://api.example.com',
  headers: const {'accept': 'application/json'},
);

final users = await api.get<List<dynamic>>(
  '/users',
  options: const RequestOptions(
    cache: true,
    retry: true,
    ttl: Duration(minutes: 5),
  ),
);

api.close();
