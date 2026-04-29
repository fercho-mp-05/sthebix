import 'cache_entry.dart';
import 'cache_manager.dart';

class MemoryCacheManager<T> implements CacheManager<T> {
  final Map<String, CacheEntry<T>> _entries = {};

  @override
  Future<CacheEntry<T>?> get(String key, {bool includeExpired = false}) async {
    final entry = _entries[key];
    if (entry == null) return null;
    if (entry.isExpired && !includeExpired) return null;

    return entry;
  }

  @override
  Future<void> set(String key, T value, {Duration? ttl}) async {
    _entries[key] = CacheEntry<T>(
      value: value,
      expiresAt: ttl == null ? null : DateTime.now().add(ttl),
    );
  }

  @override
  Future<void> delete(String key) async {
    _entries.remove(key);
  }

  @override
  Future<void> clear() async {
    _entries.clear();
  }

  Future<void> purgeExpired() async {
    _entries.removeWhere((_, entry) => entry.isExpired);
  }

  int get length => _entries.length;
}
