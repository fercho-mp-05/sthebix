import 'package:sthebix/sthebix.dart';

class User {
  const User({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }
}

Future<void> main() async {
  final api = RequestClient(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    headers: const {'accept': 'application/json'},
    timeout: const Duration(seconds: 10),
    retryPolicy: const RetryPolicy(
      maxRetries: 2,
      initialDelay: Duration(milliseconds: 250),
    ),
  );

  try {
    final user = await api.smartGet<User>(
      '/users/1',
      options: const RequestOptions(
        cache: true,
        retry: true,
        ttl: Duration(minutes: 5),
      ),
      parser: (data) => User.fromJson(data as Map<String, dynamic>),
    );

    assert(user.id == 1);
  } finally {
    api.close();
  }
}
