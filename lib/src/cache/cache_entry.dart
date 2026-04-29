class CacheEntry<T> {
  CacheEntry({required this.value, DateTime? createdAt, this.expiresAt})
    : createdAt = createdAt ?? DateTime.now();

  final T value;
  final DateTime createdAt;
  final DateTime? expiresAt;

  bool get isExpired {
    final expiresAt = this.expiresAt;
    return expiresAt != null && !DateTime.now().isBefore(expiresAt);
  }

  Duration? get remainingTtl {
    final expiresAt = this.expiresAt;
    if (expiresAt == null) return null;

    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
