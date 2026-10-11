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
      throw AuthException(error.message, statusCode: error.statusCode);
    }
  }

  @override
  Future<EmailVerificationResult> requestEmailVerification({
    required String email,
  }) async {
    try {
      final json = await _apiClient.postJson(
        '/api/v1/auth/email-verification',
        body: {'email': email.trim()},
      );

      return EmailVerificationResult.fromJson(json);
    } on ApiException catch (error) {
      // Serveur pas encore mis à jour : il crée le compte sans code.
      if (error.statusCode == 404) {
        return const EmailVerificationResult(
          isRequired: false,
          message: 'Aucun code nécessaire.',
        );
      }
      throw AuthException(error.message, statusCode: error.statusCode);
    }
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? emailCode,
  }) async {
    try {
      final json = await _apiClient.postJson(
        '/api/v1/auth/register',
        body: {
          'email': email.trim(),
          'password': password,
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          if (emailCode != null) 'emailCode': emailCode.trim(),
        },
      );

      return AuthSession.fromJson(json);
    } on ApiException catch (error) {
      throw AuthException(error.message, statusCode: error.statusCode);
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
    String? emailCode,
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
          if (emailCode != null) 'emailCode': emailCode.trim(),
        },
      );

      return AuthSession.fromJson(json);
    } on ApiException catch (error) {
      throw AuthException(error.message, statusCode: error.statusCode);
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
      throw AuthException(error.message, statusCode: error.statusCode);
    }
  }

  @override
  Future<UserSummary> currentUser(String accessToken) async {
    try {
      final json = await _apiClient.getJson(
        '/api/v1/auth/me',
        accessToken: accessToken,
      );

      return UserSummary.fromJson(json);
    } on ApiException catch (error) {
      throw AuthException(error.message, statusCode: error.statusCode);
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
      throw AuthException(error.message, statusCode: error.statusCode);
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
      throw AuthException(error.message, statusCode: error.statusCode);
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
      throw AuthException(error.message, statusCode: error.statusCode);
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
      throw AuthException(error.message, statusCode: error.statusCode);
    }
  }
}
