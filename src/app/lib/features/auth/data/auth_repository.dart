import 'package:studyflow_app/features/auth/domain/auth_models.dart';

abstract interface class AuthRepository {
  Future<AuthSession> login({required String email, required String password});

  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  });

  Future<AuthSession> registerAndCreateClass({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String schoolClassName,
    required String schoolYear,
  });

  Future<AuthTokenPair> refresh(String refreshToken);

  /// Profil actuel côté serveur (classe et rôles à jour).
  Future<UserSummary> currentUser(String accessToken);

  Future<PasswordResetRequestResult> requestPasswordReset({
    required String email,
  });

  Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  });

  Future<void> logout(AuthSession session);

  Future<void> deleteAccount(AuthSession session);
}

class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode = 0});

  final String message;

  /// Code HTTP renvoyé par l'API, ou 0 si le serveur n'a pas pu être joint.
  final int statusCode;

  /// Le serveur a explicitement refusé la session (jeton invalide, révoqué ou
  /// expiré). Les autres erreurs (réseau, 429, 5xx) sont temporaires.
  bool get isSessionRejected => statusCode == 400 || statusCode == 401;

  @override
  String toString() => message;
}
