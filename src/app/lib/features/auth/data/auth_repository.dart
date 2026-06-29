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

  Future<void> logout(AuthSession session);
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
