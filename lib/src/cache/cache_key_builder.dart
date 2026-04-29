import 'dart:collection';
import 'dart:convert';

typedef CacheKeyBuilder = String Function(CacheKeyParts parts);

class CacheKeyParts {
  const CacheKeyParts({required this.method, required this.uri, this.body});

  final String method;
  final Uri uri;
  final Object? body;
}

String defaultCacheKeyBuilder(CacheKeyParts parts) {
  final uri = _normalizeUri(parts.uri);
  final body = parts.body == null ? '' : ':${_canonicalize(parts.body)}';

  return '${parts.method.toUpperCase()} $uri$body';
}

Uri _normalizeUri(Uri uri) {
  final query = uri.queryParametersAll.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  final normalizedPairs = <MapEntry<String, String>>[];
  for (final entry in query) {
    final values = [...entry.value]..sort();
    for (final value in values) {
      normalizedPairs.add(MapEntry(entry.key, value));
    }
  }

  final normalizedQuery = normalizedPairs
      .map(
        (entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
      )
      .join('&');

  return uri.replace(query: normalizedQuery.isEmpty ? null : normalizedQuery);
}

String _canonicalize(Object? value) {
  if (value == null) return 'null';
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();

  try {
    return jsonEncode(_normalizeJson(value));
  } on Object {
    return value.toString();
  }
}

Object? _normalizeJson(Object? value) {
  if (value is Map) {
    final sorted = SplayTreeMap<String, Object?>();
    for (final entry in value.entries) {
      sorted[entry.key.toString()] = _normalizeJson(entry.value);
    }
    return sorted;
  }

  if (value is Iterable) {
    return value.map(_normalizeJson).toList(growable: false);
  }

  return value;
}
