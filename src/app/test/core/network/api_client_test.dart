import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyflow_app/core/network/api_client.dart';

void main() {
  test('ApiClient affiche le premier message de validation', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:5028',
      httpClient: MockClient(
        (_) async => http.Response(
          '{"errors":{"Password":["Le mot de passe est trop court."]}}',
          400,
        ),
      ),
    );

    expect(
      () => client.postJson('/api/v1/auth/register', body: const {}),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Le mot de passe est trop court.',
        ),
      ),
    );
  });

  test(
    'ApiClient rejoue une fois la requête avec un jeton renouvelé',
    () async {
      final seenTokens = <String?>[];
      final client = ApiClient(
        baseUrl: 'http://localhost:5028',
        httpClient: MockClient((request) async {
          final token = request.headers['Authorization'];
          seenTokens.add(token);
          return token == 'Bearer nouveau'
              ? http.Response('{"ok":true}', 200)
              : http.Response('', 401);
        }),
      )..onAccessTokenRejected = (rejected) async => 'nouveau';

      final json = await client.getJson(
        '/api/v1/dashboard',
        accessToken: 'ancien',
      );

      expect(json['ok'], isTrue);
      expect(seenTokens, ['Bearer ancien', 'Bearer nouveau']);
    },
  );

  test(
    'ApiClient ne rejoue pas si la session ne peut pas être renouvelée',
    () async {
      var calls = 0;
      final client = ApiClient(
        baseUrl: 'http://localhost:5028',
        httpClient: MockClient((_) async {
          calls++;
          return http.Response('{"title":"Non autorisé"}', 401);
        }),
      )..onAccessTokenRejected = (_) async => null;

      await expectLater(
        client.getJson('/api/v1/dashboard', accessToken: 'ancien'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
      expect(calls, 1);
    },
  );

  test('ApiClient transforme un serveur muet en erreur lisible', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:5028',
      timeout: const Duration(milliseconds: 20),
      httpClient: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      client.getJson('/api/status'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 0)),
    );
  });
}
