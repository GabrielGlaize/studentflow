import 'package:studyflow_app/core/demo/demo_session_state.dart';
import 'package:studyflow_app/features/classes/data/class_management_repository.dart';
import 'package:studyflow_app/features/classes/domain/class_models.dart';
import 'package:studyflow_app/features/auth/domain/auth_models.dart';

class DemoClassManagementRepository implements ClassManagementRepository {
  const DemoClassManagementRepository();

  static CurrentClassInfo _defaultClass = const CurrentClassInfo(
    id: 'demo-class-1',
    name: 'BTS SIO 1',
    schoolYear: '2026-2027',
    isDelegate: true,
    accessCode: 'SIO1-42',
  );

  static final List<PendingMembershipRequest> _pendingRequests = [
    const PendingMembershipRequest(
      id: 'request-1',
      firstName: 'Lina',
      lastName: 'Moreau',
      email: 'lina.moreau@example.com',
    ),
  ];

  static final List<ClassMember> _members = [
    const ClassMember(
      id: 'demo-user-gabriel',
      firstName: 'Gabriel',
      lastName: 'Dubois',
      email: 'gabriel@example.com',
      isDelegate: true,
    ),
    const ClassMember(
      id: 'demo-user-sarah',
      firstName: 'Sarah',
      lastName: 'Bernard',
      email: 'sarah.bernard@example.com',
      isDelegate: false,
    ),
    const ClassMember(
      id: 'demo-user-adam',
      firstName: 'Adam',
      lastName: 'Petit',
      email: 'adam.petit@example.com',
      isDelegate: false,
    ),
  ];

  @override
  Future<CurrentClassInfo?> getCurrentClass({String? accessToken}) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (DemoSessionState.hasNoClass(accessToken)) return null;
    if (DemoSessionState.hasCreatedClass(accessToken)) {
      return const CurrentClassInfo(
        id: 'demo-class-created',
        name: 'BTS SIO 1',
        schoolYear: '2026-2027',
        isDelegate: true,
        accessCode: 'NEW-42',
      );
    }

    return _defaultClass;
  }

  @override
  Future<AuthSession> createClass({
    required String schoolClassName,
    required String schoolYear,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    final now = DateTime.now().toUtc();
    return AuthSession(
      tokens: AuthTokenPair(
        accessToken: DemoSessionState.createdClassToken,
        accessTokenExpiresAt: now.add(const Duration(minutes: 15)),
        refreshToken: 'demo-refresh-token-created-class',
        refreshTokenExpiresAt: now.add(const Duration(days: 30)),
      ),
      user: const UserSummary(
        id: 'demo-user-created-class',
        email: 'demo@studyflow.dev',
        firstName: 'Futur',
        lastName: 'Délégué',
        schoolClassId: 'demo-class-created',
        roles: ['Eleve', 'Delegue'],
      ),
    );
  }

  @override
  Future<void> requestToJoinClass({
    required String code,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (code.trim().isEmpty) {
      throw ArgumentError('Le code de classe est obligatoire.');
    }
  }

  @override
  Future<List<PendingMembershipRequest>> listPendingRequests({
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return List.unmodifiable(_pendingRequests);
  }

  @override
  Future<List<ClassMember>> listMembers({String? accessToken}) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return List.unmodifiable(_members);
  }

  @override
  Future<void> approveRequest({
    required String requestId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    _pendingRequests.removeWhere((request) => request.id == requestId);
  }

  @override
  Future<void> rejectRequest({
    required String requestId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    _pendingRequests.removeWhere((request) => request.id == requestId);
  }

  @override
  Future<CurrentClassInfo> updateCurrentClass({
    required String name,
    required String schoolYear,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    _defaultClass = CurrentClassInfo(
      id: _defaultClass.id,
      name: name.trim(),
      schoolYear: schoolYear.trim(),
      isDelegate: true,
      accessCode: _defaultClass.accessCode,
      accessCodeUpdatedAt: _defaultClass.accessCodeUpdatedAt,
    );
    return _defaultClass;
  }

  @override
  Future<ClassAccessCode> regenerateAccessCode({String? accessToken}) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final updatedAt = DateTime.now();
    const code = 'SIO1-99';
    _defaultClass = CurrentClassInfo(
      id: _defaultClass.id,
      name: _defaultClass.name,
      schoolYear: _defaultClass.schoolYear,
      isDelegate: true,
      accessCode: code,
      accessCodeUpdatedAt: updatedAt,
    );
    return ClassAccessCode(accessCode: code, updatedAt: updatedAt);
  }

  @override
  Future<void> makeDelegate({
    required String memberId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    final index = _members.indexWhere((member) => member.id == memberId);
    if (index == -1) return;
    final member = _members[index];
    _members[index] = ClassMember(
      id: member.id,
      firstName: member.firstName,
      lastName: member.lastName,
      email: member.email,
      isDelegate: true,
    );
  }

  @override
  Future<void> removeMember({
    required String memberId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    _members.removeWhere((member) => member.id == memberId);
  }

  @override
  Future<void> leaveDelegateRole({String? accessToken}) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    final index = _members.indexWhere(
      (member) => member.id == 'demo-user-gabriel',
    );
    if (index == -1) return;
    final member = _members[index];
    _members[index] = ClassMember(
      id: member.id,
      firstName: member.firstName,
      lastName: member.lastName,
      email: member.email,
      isDelegate: false,
    );
    _defaultClass = CurrentClassInfo(
      id: _defaultClass.id,
      name: _defaultClass.name,
      schoolYear: _defaultClass.schoolYear,
      isDelegate: false,
      accessCode: null,
      accessCodeUpdatedAt: _defaultClass.accessCodeUpdatedAt,
    );
  }

  @override
  Future<AuthSession> leaveClass({String? accessToken}) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final now = DateTime.now().toUtc();
    return AuthSession(
      tokens: AuthTokenPair(
        accessToken: DemoSessionState.noClassToken,
        accessTokenExpiresAt: now.add(const Duration(minutes: 15)),
        refreshToken: 'demo-refresh-token-no-class',
        refreshTokenExpiresAt: now.add(const Duration(days: 30)),
      ),
      user: const UserSummary(
        id: 'demo-user-left-class',
        email: 'demo@studyflow.dev',
        firstName: 'Futur',
        lastName: 'Élève',
        schoolClassId: null,
        roles: [],
      ),
    );
  }
}
