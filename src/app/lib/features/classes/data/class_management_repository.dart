import 'package:studyflow_app/features/classes/domain/class_models.dart';
import 'package:studyflow_app/features/auth/domain/auth_models.dart';

abstract interface class ClassManagementRepository {
  Future<CurrentClassInfo?> getCurrentClass({String? accessToken});

  Future<AuthSession> createClass({
    required String schoolClassName,
    required String schoolYear,
    String? accessToken,
  });

  Future<void> requestToJoinClass({required String code, String? accessToken});

  Future<List<PendingMembershipRequest>> listPendingRequests({
    String? accessToken,
  });

  Future<List<ClassMember>> listMembers({String? accessToken});

  Future<void> approveRequest({required String requestId, String? accessToken});

  Future<void> rejectRequest({required String requestId, String? accessToken});

  Future<CurrentClassInfo> updateCurrentClass({
    required String name,
    required String schoolYear,
    String? accessToken,
  });

  Future<ClassAccessCode> regenerateAccessCode({String? accessToken});

  Future<void> makeDelegate({required String memberId, String? accessToken});

  Future<void> removeMember({required String memberId, String? accessToken});

  Future<void> leaveDelegateRole({String? accessToken});

  Future<AuthSession> leaveClass({String? accessToken});
}
