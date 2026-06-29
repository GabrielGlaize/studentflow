import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/features/auth/domain/auth_models.dart';

void main() {
  test('AuthSession.fromJson lit la réponse du backend', () {
    final session = AuthSession.fromJson({
      'tokens': {
        'accessToken': 'access-token',
        'accessTokenExpiresAt': '2026-06-24T10:00:00Z',
        'refreshToken': 'refresh-token',
        'refreshTokenExpiresAt': '2026-07-24T10:00:00Z',
      },
      'user': {
        'id': 'user-1',
        'email': 'gabriel@example.com',
        'firstName': 'Gabriel',
        'lastName': 'Demo',
        'schoolClassId': 'class-1',
        'roles': ['Eleve', 'Delegue'],
      },
    });

    expect(session.accessToken, 'access-token');
    expect(session.tokens.accessTokenExpiresAt, DateTime.utc(2026, 6, 24, 10));
    expect(session.refreshToken, 'refresh-token');
    expect(session.user.displayName, 'Gabriel Demo');
    expect(session.user.isDelegate, isTrue);
  });
}
