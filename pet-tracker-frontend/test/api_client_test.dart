import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pettrack/core/config/api_config.dart';
import 'package:pettrack/core/network/api_client.dart';
import 'package:pettrack/core/network/api_exception.dart';

void main() {
  test('retries once with fresh token on 401', () async {
    var calls = 0;
    final client = ApiClient(
      config: const ApiConfig(baseUrl: 'http://example.test'),
      authTokenProvider: () async => 'expired-token',
      refreshAuthTokenProvider: () async => 'fresh-token',
      httpClient: MockClient((request) async {
        calls++;
        if (calls == 1) {
          expect(request.headers['Authorization'], 'Bearer expired-token');
          return http.Response('{"detail":"expired"}', 401);
        }
        expect(request.headers['Authorization'], 'Bearer fresh-token');
        return http.Response('{"ok":true}', 200);
      }),
    );

    final response = await client.getJson('/api/v1/auth/me');

    expect(response['ok'], true);
    expect(calls, 2);
  });

  test('calls unauthorized handler after refresh also fails', () async {
    var unauthorizedCalls = 0;
    final client = ApiClient(
      config: const ApiConfig(baseUrl: 'http://example.test'),
      authTokenProvider: () async => 'expired-token',
      refreshAuthTokenProvider: () async => 'fresh-token',
      onUnauthorized: () => unauthorizedCalls++,
      httpClient: MockClient((request) async {
        return http.Response('{"detail":"still unauthorized"}', 401);
      }),
    );

    await expectLater(
      client.getJson('/api/v1/auth/me'),
      throwsA(isA<ApiException>()),
    );
    expect(unauthorizedCalls, 1);
  });
}
