import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sthebix/sthebix.dart';
import 'package:test/test.dart';

class User {
  const User({required this.id, required this.name});

  final int id;
  final String name;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(id: json['id'] as int, name: json['name'] as String);
  }
}

void main() {
  group('RequestClient', () {
    test('GET parses JSON and reuses valid cache', () async {
      var calls = 0;
      final client = RequestClient(
        baseUrl: 'https://api.example.com',
        retryPolicy: const RetryPolicy(maxRetries: 0),
        httpClient: MockClient((request) async {
          calls += 1;
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            'https://api.example.com/users?page=1',
          );

          return http.Response(
            jsonEncode([
              {'id': 1, 'name': 'Ada'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final options = RequestOptions(
        cache: true,
        ttl: const Duration(minutes: 1),
        queryParameters: const {'page': 1},
      );

      final first = await client.get<List<dynamic>>('/users', options: options);
      final second = await client.get<List<dynamic>>(
        '/users',
        options: options,
      );

      expect(first, [
        {'id': 1, 'name': 'Ada'},
      ]);
      expect(second, first);
      expect(calls, 1);

      client.close();
    });

    test('smartGet maps JSON to a custom model with parser', () async {
      final client = RequestClient(
        baseUrl: 'https://api.example.com',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'id': 7, 'name': 'Grace'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final user = await client.smartGet<User>(
        '/users/7',
        parser: (data) => User.fromJson(data as Map<String, dynamic>),
      );

      expect(user.id, 7);
      expect(user.name, 'Grace');

      client.close();
    });

    test('retries network errors with exponential policy', () async {
      var calls = 0;
      final client = RequestClient(
        baseUrl: 'https://api.example.com',
        retryPolicy: const RetryPolicy(
          maxRetries: 2,
          initialDelay: Duration.zero,
        ),
        httpClient: MockClient((request) async {
          calls += 1;
          if (calls < 3) {
            throw http.ClientException('offline', request.url);
          }

          return http.Response(
            jsonEncode({'ok': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final response = await client.get<Map<String, dynamic>>('/health');

      expect(response, {'ok': true});
      expect(calls, 3);

      client.close();
    });

    test('returns stale cache when network fails after TTL expires', () async {
      var calls = 0;
      final client = RequestClient(
        baseUrl: 'https://api.example.com',
        httpClient: MockClient((request) async {
          calls += 1;
          if (calls == 1) {
            return http.Response(
              jsonEncode({'version': 1}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          throw http.ClientException('offline', request.url);
        }),
      );

      const options = RequestOptions(
        cache: true,
        retry: false,
        ttl: Duration(milliseconds: 1),
      );

      final first = await client.getResponse<Map<String, dynamic>>(
        '/config',
        options: options,
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = await client.getResponse<Map<String, dynamic>>(
        '/config',
        options: options,
      );

      expect(first.fromCache, isFalse);
      expect(second.fromCache, isTrue);
      expect(second.isStale, isTrue);
      expect(second.data, {'version': 1});
      expect(calls, 2);

      client.close();
    });

    test('does not retry client HTTP errors by default', () async {
      var calls = 0;
      final client = RequestClient(
        baseUrl: 'https://api.example.com',
        retryPolicy: const RetryPolicy(
          maxRetries: 2,
          initialDelay: Duration.zero,
        ),
        httpClient: MockClient((request) async {
          calls += 1;
          return http.Response('bad request', 400);
        }),
      );

      await expectLater(
        client.get<String>('/bad-request'),
        throwsA(isA<HttpStatusRequestException>()),
      );
      expect(calls, 1);

      client.close();
    });
  });
}
