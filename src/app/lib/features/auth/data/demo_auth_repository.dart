import 'package:studyflow_app/features/auth/data/auth_repository.dart';
import 'package:studyflow_app/features/auth/domain/auth_models.dart';
import 'package:studyflow_app/core/demo/demo_session_state.dart';

/// Temporary authentication repository.
///
/// It lets us build the Flutter flow before connecting `/api/v1/auth/login`.
/// The password only needs to be non-empty.
class DemoAuthRepository implements AuthRepository {
  const DemoAuthRepository();

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    if (email.trim().isEmpty || !email.contains('@')) {
      throw const AuthException('Entre une adresse e-mail valide.');
    }

    if (password.trim().isEmpty) {
      throw const AuthException('Entre ton mot de passe.');
    }

    final now = DateTime.now().toUtc();
    return AuthSession(
      tokens: AuthTokenPair(
        accessToken: DemoSessionState.classMemberToken,
        accessTokenExpiresAt: now.add(const Duration(minutes: 15)),
        refreshToken: 'demo-refresh-token',
        refreshTokenExpiresAt: now.add(const Duration(days: 30)),
      ),
      user: UserSummary(
        id: 'demo-user-1',
        email: email.trim(),
        firstName: 'Gabriel',
        lastName: 'Demo',
        schoolClassId: 'demo-class-1',
        roles: const ['Eleve', 'Delegue'],
      ),
    );
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _validateAccount(email: email, password: password);

    return _buildSession(
      email: email,
      firstName: firstName,
      lastName: lastName,
      schoolClassId: null,
      roles: const [],
    );
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
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _validateAccount(email: email, password: password);

    if (schoolClassName.trim().isEmpty) {
      throw const AuthException('Entre le nom de ta classe.');
    }

    if (schoolYear.trim().isEmpty) {
      throw const AuthException('Entre l’année scolaire.');
    }

    return _buildSession(
      email: email,
      firstName: firstName,
      lastName: lastName,
      schoolClassId: 'demo-class-created',
      roles: const ['Eleve', 'Delegue'],
    );
  }

  @override
  Future<AuthTokenPair> refresh(String refreshToken) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final now = DateTime.now().toUtc();

    return AuthTokenPair(
      accessToken: DemoSessionState.classMemberToken,
      accessTokenExpiresAt: now.add(const Duration(minutes: 15)),
      refreshToken: 'demo-refresh-token-refreshed',
      refreshTokenExpiresAt: now.add(const Duration(days: 30)),
    );
  }

  @override
  Future<PasswordResetRequestResult> requestPasswordReset({
    required String email,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (email.trim().isEmpty || !email.contains('@')) {
      throw const AuthException('Entre une adresse e-mail valide.');
    }

    return PasswordResetRequestResult(
      message: 'Code de démonstration généré.',
      developmentToken: 'DEMO-RESET',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 30)),
    );
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _validateAccount(email: email, password: newPassword);
    if (token.trim().isEmpty) {
      throw const AuthException('Entre le code de réinitialisation.');
    }
  }

  @override
  Future<void> logout(AuthSession session) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  @override
  Future<void> deleteAccount(AuthSession session) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
  }

  void _validateAccount({required String email, required String password}) {
    if (email.trim().isEmpty || !email.contains('@')) {
      throw const AuthException('Entre une adresse e-mail valide.');
    }

    if (password.trim().isEmpty) {
      throw const AuthException('Entre ton mot de passe.');
    }
  }

  AuthSession _buildSession({
    required String email,
    required String firstName,
    required String lastName,
    required String? schoolClassId,
    required List<String> roles,
  }) {
    final now = DateTime.now().toUtc();
    return AuthSession(
      tokens: AuthTokenPair(
        accessToken: schoolClassId == null
            ? DemoSessionState.noClassToken
            : schoolClassId == 'demo-class-created'
            ? DemoSessionState.createdClassToken
            : DemoSessionState.classMemberToken,
        accessTokenExpiresAt: now.add(const Duration(minutes: 15)),
        refreshToken: 'demo-refresh-token',
        refreshTokenExpiresAt: now.add(const Duration(days: 30)),
      ),
      user: UserSummary(
        id: 'demo-user-${email.hashCode.abs()}',
        email: email.trim(),
        firstName: firstName.trim().isEmpty ? 'Futur' : firstName.trim(),
        lastName: lastName.trim().isEmpty ? 'Élève' : lastName.trim(),
        schoolClassId: schoolClassId,
        roles: roles,
      ),
    );
  }
}
