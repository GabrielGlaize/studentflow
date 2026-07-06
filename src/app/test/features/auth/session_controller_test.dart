import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/features/auth/application/session_controller.dart';
import 'package:studyflow_app/features/auth/data/auth_repository.dart';
import 'package:studyflow_app/features/auth/data/session_storage.dart';
import 'package:studyflow_app/features/auth/domain/auth_models.dart';

void main() {
  test('restoreSession recharge une session stockée', () async {
    final storage = MemorySessionStorage();
    await storage.save(_session);

    final controller = SessionController(
      authRepository: _FakeAuthRepository(),
      sessionStorage: storage,
    );

    await controller.restoreSession();

    expect(controller.status, SessionStatus.signedIn);
    expect(controller.session?.user.email, 'gabriel@example.com');
  });

  test('logout efface la session stockée', () async {
    final storage = MemorySessionStorage();
    await storage.save(_session);

    final controller = SessionController(
      authRepository: _FakeAuthRepository(),
      sessionStorage: storage,
    );

    await controller.restoreSession();
    await controller.logout();

    expect(controller.status, SessionStatus.signedOut);
    expect(controller.session, isNull);
    expect(await storage.read(), isNull);
  });

  test('logout efface aussi la session locale si le serveur échoue', () async {
    final storage = MemorySessionStorage();
    await storage.save(_session);

    final controller = SessionController(
      authRepository: _FailingLogoutAuthRepository(),
      sessionStorage: storage,
    );

    await controller.restoreSession();
    await controller.logout();

    expect(controller.status, SessionStatus.signedOut);
    expect(controller.session, isNull);
    expect(await storage.read(), isNull);
  });

  test('accessTokenForApi renouvelle un access token presque expiré', () async {
    final storage = MemorySessionStorage();
    await storage.save(_expiredSession);

    final controller = SessionController(
      authRepository: _RefreshingAuthRepository(),
      sessionStorage: storage,
    );

    await controller.restoreSession();
    final accessToken = await controller.accessTokenForApi();

    expect(accessToken, 'fresh-access-token');
    expect(controller.session?.refreshToken, 'fresh-refresh-token');
    expect((await storage.read())?.accessToken, 'fresh-access-token');
  });

  test(
    'restoreSession efface une session expirée impossible à renouveler',
    () async {
      final storage = MemorySessionStorage();
      await storage.save(_expiredSession);

      final controller = SessionController(
        authRepository: _FailingRefreshAuthRepository(),
        sessionStorage: storage,
      );

      await controller.restoreSession();

      expect(controller.status, SessionStatus.signedOut);
      expect(controller.session, isNull);
      expect(await storage.read(), isNull);
    },
  );
}

final _futureDate = DateTime.utc(2099);
final _pastDate = DateTime.utc(2020);

final _session = AuthSession(
  tokens: AuthTokenPair(
    accessToken: 'access-token',
    accessTokenExpiresAt: _futureDate,
    refreshToken: 'refresh-token',
    refreshTokenExpiresAt: _futureDate,
  ),
  user: UserSummary(
    id: 'user-1',
    email: 'gabriel@example.com',
    firstName: 'Gabriel',
    lastName: 'Demo',
    roles: ['Eleve'],
  ),
);

final _expiredSession = AuthSession(
  tokens: AuthTokenPair(
    accessToken: 'expired-access-token',
    accessTokenExpiresAt: _pastDate,
    refreshToken: 'refresh-token',
    refreshTokenExpiresAt: _futureDate,
  ),
  user: UserSummary(
    id: 'user-1',
    email: 'gabriel@example.com',
    firstName: 'Gabriel',
    lastName: 'Demo',
    roles: ['Eleve'],
  ),
);

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return _session;
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    return _session;
  }

  @override
  Future<AuthSession> registerAndCreateClass({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String schoolClassName,
    required String schoolYear,
  }) async {
    return _session;
  }

  @override
  Future<AuthTokenPair> refresh(String refreshToken) async {
    return _session.tokens;
  }

  @override
  Future<PasswordResetRequestResult> requestPasswordReset({
    required String email,
  }) async {
    return const PasswordResetRequestResult(message: 'OK');
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {}

  @override
  Future<void> logout(AuthSession session) async {}

  @override
  Future<void> deleteAccount(AuthSession session) async {}
}

class _FailingLogoutAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return _session;
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    return _session;
  }

  @override
  Future<AuthSession> registerAndCreateClass({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String schoolClassName,
    required String schoolYear,
  }) async {
    return _session;
  }

  @override
  Future<AuthTokenPair> refresh(String refreshToken) async {
    return _session.tokens;
  }

  @override
  Future<PasswordResetRequestResult> requestPasswordReset({
    required String email,
  }) async {
    return const PasswordResetRequestResult(message: 'OK');
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {}

  @override
  Future<void> logout(AuthSession session) async {
    throw const AuthException('Serveur indisponible.');
  }

  @override
  Future<void> deleteAccount(AuthSession session) async {}
}

class _RefreshingAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return _session;
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    return _session;
  }

  @override
  Future<AuthSession> registerAndCreateClass({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String schoolClassName,
    required String schoolYear,
  }) async {
    return _session;
  }

  @override
  Future<AuthTokenPair> refresh(String refreshToken) async {
    return AuthTokenPair(
      accessToken: 'fresh-access-token',
      accessTokenExpiresAt: _futureDate,
      refreshToken: 'fresh-refresh-token',
      refreshTokenExpiresAt: _futureDate,
    );
  }

  @override
  Future<PasswordResetRequestResult> requestPasswordReset({
    required String email,
  }) async {
    return const PasswordResetRequestResult(message: 'OK');
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {}

  @override
  Future<void> logout(AuthSession session) async {}

  @override
  Future<void> deleteAccount(AuthSession session) async {}
}

class _FailingRefreshAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return _session;
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    return _session;
  }

  @override
  Future<AuthSession> registerAndCreateClass({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String schoolClassName,
    required String schoolYear,
  }) async {
    return _session;
  }

  @override
  Future<AuthTokenPair> refresh(String refreshToken) async {
    throw const AuthException('Refresh invalide.');
  }

  @override
  Future<PasswordResetRequestResult> requestPasswordReset({
    required String email,
  }) async {
    return const PasswordResetRequestResult(message: 'OK');
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {}

  @override
  Future<void> logout(AuthSession session) async {}

  @override
  Future<void> deleteAccount(AuthSession session) async {}
}
