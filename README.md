# sthebix

Pure Dart HTTP client focused on simple, resilient REST calls: cache in memory,
TTL, retry with exponential backoff, timeout, typed parsing, interceptors, and
custom errors.

> Name note: `sthebix` is useful as a local/provisional name. Before
> publishing, check package-name availability on pub.dev.

## Features

- GET, POST, PUT, and DELETE.
- Base URL, global headers, per-request headers, query parameters, and timeout.
- Memory cache with TTL and stale-cache fallback when the network fails.
- Extensible `CacheManager<T>` contract for future Hive, SQLite, Redis, file, or
  secure-storage implementations.
- Retry policy with configurable retry count, initial delay, max delay, and
  exponential factor.
- Default retry only for transient failures: network errors, timeout, and 5xx.
- Custom exceptions instead of generic `Exception`.
- Basic interceptors and callback-based logging.

## Install locally

From a Flutter app in the same repository:

```yaml
dependencies:
  sthebix:
    path: packages/sthebix
```

Then:

```bash
flutter pub get
```

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
```

## Typed models

Dart cannot infer how to build your custom model from JSON, so provide a parser:

```dart
class User {
  const User({required this.id, required this.name});

  final int id;
  final String name;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

final user = await api.smartGet<User>(
  '/users/1',
  parser: (data) => User.fromJson(data as Map<String, dynamic>),
);
```

## Architecture

The package is intentionally small:

- `client`: `RequestClient` and HTTP method abstractions.
- `cache`: `CacheManager`, `MemoryCacheManager`, entries, and cache-key builder.
- `retry`: `RetryPolicy` and `RetryExecutor`.
- `models`: request options, request/response snapshots, parser typedefs.
- `errors`: typed exceptions for network, timeout, HTTP status, parse, and cache
  errors.
- `interceptors`: extension points for auth headers, telemetry, logging, etc.

## Persistent cache strategy

Implement `CacheManager<CachedResponse>` and store `CacheEntry<CachedResponse>`
in your preferred backend. `CachedResponse` exposes `toJson` and `fromJson`, so
Hive, SQLite, Isar, files, or secure storage can persist the HTTP payload without
depending on your app models.

## Logging

```dart
final api = RequestClient(
  baseUrl: 'https://api.example.com',
  interceptors: [
    LoggingInterceptor(
      CallbackRequestLogger((message) {
        // Forward to your logger of choice.
      }),
    ),
  ],
);
```
