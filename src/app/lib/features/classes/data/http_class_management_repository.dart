import 'package:studyflow_app/core/network/api_client.dart';
import 'package:studyflow_app/features/classes/data/class_management_repository.dart';
import 'package:studyflow_app/features/classes/domain/class_models.dart';
import 'package:studyflow_app/features/auth/domain/auth_models.dart';

class HttpClassManagementRepository implements ClassManagementRepository {
  const HttpClassManagementRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<CurrentClassInfo?> getCurrentClass({String? accessToken}) async {
    try {
      final json = await _apiClient.getJson(
        '/api/v1/classes/current',
        accessToken: accessToken,
      );
      return CurrentClassInfo.fromJson(json);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<AuthSession> createClass({
    required String schoolClassName,
    required String schoolYear,
    String? accessToken,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/classes',
      body: {
        'schoolClassName': schoolClassName.trim(),
        'schoolYear': schoolYear.trim(),
      },
      accessToken: accessToken,
    );

    return AuthSession.fromJson(json);
  }

  @override
  Future<void> requestToJoinClass({required String code, String? accessToken}) {
    return _apiClient.postNoContent(
      '/api/v1/classes/join',
      body: {'code': code.trim()},
      accessToken: accessToken,
    );
  }

  @override
  Future<List<PendingMembershipRequest>> listPendingRequests({
    String? accessToken,
  }) async {
    final json = await _apiClient.getJsonList(
      '/api/v1/delegate/membership-requests',
      accessToken: accessToken,
    );
    return json.map(PendingMembershipRequest.fromJson).toList(growable: false);
  }

  @override
  Future<List<ClassMember>> listMembers({String? accessToken}) async {
    final json = await _apiClient.getJsonList(
      '/api/v1/classes/current/members',
      accessToken: accessToken,
    );
    return json.map(ClassMember.fromJson).toList(growable: false);
  }

  @override
  Future<void> approveRequest({
    required String requestId,
    String? accessToken,
  }) {
    return _apiClient.postNoContent(
      '/api/v1/delegate/membership-requests/$requestId/approve',
      body: const {},
      accessToken: accessToken,
    );
  }

  @override
  Future<void> rejectRequest({required String requestId, String? accessToken}) {
    return _apiClient.postNoContent(
      '/api/v1/delegate/membership-requests/$requestId/reject',
      body: const {},
      accessToken: accessToken,
    );
  }

  @override
  Future<CurrentClassInfo> updateCurrentClass({
    required String name,
    required String schoolYear,
    String? accessToken,
  }) async {
    final json = await _apiClient.putJson(
      '/api/v1/classes/current',
      body: {'name': name.trim(), 'schoolYear': schoolYear.trim()},
      accessToken: accessToken,
    );
    return CurrentClassInfo.fromJson(json);
  }

  @override
  Future<ClassAccessCode> regenerateAccessCode({String? accessToken}) async {
    final json = await _apiClient.postJson(
      '/api/v1/classes/current/access-code/regenerate',
      body: const {},
      accessToken: accessToken,
    );
    return ClassAccessCode.fromJson(json);
  }

  @override
  Future<void> makeDelegate({required String memberId, String? accessToken}) {
    return _apiClient.postNoContent(
      '/api/v1/classes/current/members/$memberId/make-delegate',
      body: const {},
      accessToken: accessToken,
    );
  }

  @override
  Future<void> removeMember({required String memberId, String? accessToken}) {
    return _apiClient.deleteNoContent(
      '/api/v1/classes/current/members/$memberId',
      accessToken: accessToken,
    );
  }

  @override
  Future<void> leaveDelegateRole({String? accessToken}) {
    return _apiClient.postNoContent(
      '/api/v1/classes/current/delegate-role/leave',
      body: const {},
      accessToken: accessToken,
    );
  }

  @override
  Future<AuthSession> leaveClass({String? accessToken}) async {
    final json = await _apiClient.postJson(
      '/api/v1/classes/current/leave',
      body: const {},
      accessToken: accessToken,
    );
    return AuthSession.fromJson(json);
  }
}
