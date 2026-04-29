import 'cache_entry.dart';

abstract interface class CacheManager<T> {
  Future<CacheEntry<T>?> get(String key, {bool includeExpired = false});

  Future<void> set(String key, T value, {Duration? ttl});

  Future<void> delete(String key);

  Future<void> clear();
}
