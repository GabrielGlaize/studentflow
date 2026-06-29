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
}
