import 'package:studyflow_app/core/network/api_client.dart';
import 'package:studyflow_app/features/auth/data/auth_repository.dart';
import 'package:studyflow_app/features/auth/domain/auth_models.dart';

class HttpAuthRepository implements AuthRepository {
  const HttpAuthRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final json = await _apiClient.postJson(
        '/api/v1/auth/login',
        body: {'email': email.trim(), 'password': password},
      );

      return AuthSession.fromJson(json);
    } on ApiException catch (error) {
      throw AuthException(error.message);
    }
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final json = await _apiClient.postJson(
        '/api/v1/auth/register',
        body: {
          'email': email.trim(),
          'password': password,
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
        },
      );

      return AuthSession.fromJson(json);
    } on ApiException catch (error) {
      throw AuthException(error.message);
    }
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
    try {
      final json = await _apiClient.postJson(
        '/api/v1/auth/register-and-create-class',
        body: {
          'email': email.trim(),
          'password': password,
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'schoolClassName': schoolClassName.trim(),
          'schoolYear': schoolYear.trim(),
        },
      );

      return AuthSession.fromJson(json);
    } on ApiException catch (error) {
      throw AuthException(error.message);
    }
  }

  @override
  Future<AuthTokenPair> refresh(String refreshToken) async {
    try {
      final json = await _apiClient.postJson(
        '/api/v1/auth/refresh',
        body: {'refreshToken': refreshToken},
      );

      return AuthTokenPair.fromJson(json);
    } on ApiException catch (error) {
      throw AuthException(error.message);
    }
  }

  @override
  Future<PasswordResetRequestResult> requestPasswordReset({
    required String email,
  }) async {
    try {
      final json = await _apiClient.postJson(
        '/api/v1/auth/forgot-password',
        body: {'email': email.trim()},
      );

      return PasswordResetRequestResult.fromJson(json);
    } on ApiException catch (error) {
      throw AuthException(error.message);
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      await _apiClient.postNoContent(
        '/api/v1/auth/reset-password',
        body: {
          'email': email.trim(),
          'token': token.trim(),
          'newPassword': newPassword,
        },
      );
    } on ApiException catch (error) {
      throw AuthException(error.message);
    }
  }

  @override
  Future<void> logout(AuthSession session) async {
    try {
      await _apiClient.postNoContent(
        '/api/v1/auth/logout',
        accessToken: session.accessToken,
        body: {'refreshToken': session.refreshToken},
      );
    } on ApiException catch (error) {
      throw AuthException(error.message);
    }
  }

  @override
  Future<void> deleteAccount(AuthSession session) async {
    try {
      await _apiClient.deleteNoContent(
        '/api/v1/auth/me',
        accessToken: session.accessToken,
      );
    } on ApiException catch (error) {
      throw AuthException(error.message);
    }
  }
}
