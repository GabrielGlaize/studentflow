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

  test(
    'restoreSession récupère la classe validée depuis un autre appareil',
    () async {
      final storage = MemorySessionStorage();
      await storage.save(_session);

      final controller = SessionController(
        authRepository: _JoinedClassAuthRepository(),
        sessionStorage: storage,
      );

      await controller.restoreSession();

      expect(controller.session?.user.schoolClassId, 'class-1');
      expect((await storage.read())?.user.schoolClassId, 'class-1');
    },
  );

  test(
    'reloadUser garde le profil stocké si le serveur est injoignable',
    () async {
      final storage = MemorySessionStorage();
      await storage.save(_session);

      final controller = SessionController(
        authRepository: _OfflineProfileAuthRepository(),
        sessionStorage: storage,
      );

      await controller.restoreSession();

      expect(controller.status, SessionStatus.signedIn);
      expect(controller.session?.user.schoolClassId, isNull);
    },
  );

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

  test(
    'une coupure réseau pendant le renouvellement garde la session',
    () async {
      final storage = MemorySessionStorage();
      await storage.save(_expiredSession);

      final controller = SessionController(
        authRepository: _ScriptedRefreshAuthRepository(
          failure: const AuthException('Impossible de joindre le serveur.'),
        ),
        sessionStorage: storage,
      );

      await controller.restoreSession();

      expect(controller.status, SessionStatus.signedIn);
      expect(controller.session, isNotNull);
      expect(await storage.read(), isNotNull);
      await expectLater(
        controller.accessTokenForApi(),
        throwsA(isA<AuthException>()),
      );
      expect(controller.isSignedIn, isTrue);
    },
  );

  test('trop de requêtes (429) ne déconnecte pas', () async {
    final storage = MemorySessionStorage();
    await storage.save(_expiredSession);

    final controller = SessionController(
      authRepository: _ScriptedRefreshAuthRepository(
        failure: const AuthException('Trop de tentatives.', statusCode: 429),
      ),
      sessionStorage: storage,
    );

    await controller.restoreSession();

    expect(controller.status, SessionStatus.signedIn);
  });

  test(
    'des appels simultanés ne renouvellent la session qu\'une fois',
    () async {
      final storage = MemorySessionStorage();
      await storage.save(_expiredSession);
      final repository = _ScriptedRefreshAuthRepository();

      final controller = SessionController(
        authRepository: repository,
        sessionStorage: storage,
      );
      await controller.replaceSession(_expiredSession);

      final tokens = await Future.wait([
        controller.accessTokenForApi(),
        controller.accessTokenForApi(),
        controller.accessTokenForApi(),
      ]);

      expect(repository.refreshCalls, 1);
      expect(tokens.toSet(), {'fresh-access-token'});
      expect(controller.isSignedIn, isTrue);
    },
  );

  test('un jeton refusé par le serveur est renouvelé une seule fois', () async {
    final storage = MemorySessionStorage();
    await storage.save(_session);
    final repository = _ScriptedRefreshAuthRepository();

    final controller = SessionController(
      authRepository: repository,
      sessionStorage: storage,
    );
    await controller.restoreSession();

    final renewed = await controller.renewRejectedAccessToken('access-token');
    final renewedAgain = await controller.renewRejectedAccessToken(
      'access-token',
    );

    expect(renewed, 'fresh-access-token');
    expect(renewedAgain, 'fresh-access-token');
    expect(repository.refreshCalls, 1);
  });

  test('logout retire l’appareil avant de révoquer la session', () async {
    final storage = MemorySessionStorage();
    await storage.save(_session);
    final controller = SessionController(
      authRepository: _FakeAuthRepository(),
      sessionStorage: storage,
    );
    await controller.restoreSession();

    String? tokenSeenByHook;
    controller.beforeLogout = (accessToken) async {
      tokenSeenByHook = accessToken;
    };
    await controller.logout();

    expect(tokenSeenByHook, 'access-token');
    expect(controller.isSignedIn, isFalse);
  });
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

  @override
  Future<UserSummary> currentUser(String accessToken) async => _session.user;
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

  @override
  Future<UserSummary> currentUser(String accessToken) async => _session.user;
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

  @override
  Future<UserSummary> currentUser(String accessToken) async => _session.user;
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
    throw const AuthException('Refresh invalide.', statusCode: 401);
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

  @override
  Future<UserSummary> currentUser(String accessToken) async => _session.user;
}

class _ScriptedRefreshAuthRepository extends _FakeAuthRepository {
  _ScriptedRefreshAuthRepository({this.failure});

  final AuthException? failure;
  int refreshCalls = 0;

  @override
  Future<AuthTokenPair> refresh(String refreshToken) async {
    refreshCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final error = failure;
    if (error != null) throw error;

    return AuthTokenPair(
      accessToken: 'fresh-access-token',
      accessTokenExpiresAt: _futureDate,
      refreshToken: 'fresh-refresh-token-$refreshCalls',
      refreshTokenExpiresAt: _futureDate,
    );
  }
}

class _JoinedClassAuthRepository extends _FakeAuthRepository {
  @override
  Future<UserSummary> currentUser(String accessToken) async {
    return const UserSummary(
      id: 'user-1',
      email: 'gabriel@example.com',
      firstName: 'Gabriel',
      lastName: 'Demo',
      schoolClassId: 'class-1',
      roles: ['Eleve'],
    );
  }
}

class _OfflineProfileAuthRepository extends _FakeAuthRepository {
  @override
  Future<UserSummary> currentUser(String accessToken) async {
    throw const AuthException('Serveur injoignable.');
  }
}
