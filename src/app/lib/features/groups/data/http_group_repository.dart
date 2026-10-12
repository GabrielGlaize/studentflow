import 'dart:typed_data';

import 'package:studyflow_app/core/network/api_client.dart';
import 'package:studyflow_app/features/groups/data/group_repository.dart';
import 'package:studyflow_app/features/groups/domain/group_models.dart';

class HttpGroupRepository implements GroupRepository {
  const HttpGroupRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  static const _base = '/api/v1/groups';

  @override
  Future<List<StudyGroupSummary>> listGroups({String? accessToken}) async {
    final json = await _apiClient.getJsonList(_base, accessToken: accessToken);
    return json.map(StudyGroupSummary.fromJson).toList(growable: false);
  }

  @override
  Future<StudyGroupDetail> getGroup({
    required String groupId,
    String? accessToken,
  }) async {
    return StudyGroupDetail.fromJson(
      await _apiClient.getJson('$_base/$groupId', accessToken: accessToken),
    );
  }

  @override
  Future<StudyGroupDetail> createGroup({
    required StudyGroupDraft draft,
    String? accessToken,
  }) async {
    return StudyGroupDetail.fromJson(
      await _apiClient.postJson(
        _base,
        body: draft.toJson(),
        accessToken: accessToken,
      ),
    );
  }

  @override
  Future<StudyGroupDetail> updateGroup({
    required String groupId,
    required StudyGroupDraft draft,
    String? accessToken,
  }) async {
    return StudyGroupDetail.fromJson(
      await _apiClient.putJson(
        '$_base/$groupId',
        body: draft.toJson(),
        accessToken: accessToken,
      ),
    );
  }

  @override
  Future<void> deleteGroup({required String groupId, String? accessToken}) {
    return _apiClient.deleteNoContent(
      '$_base/$groupId',
      accessToken: accessToken,
    );
  }

  @override
  Future<StudyGroupDetail> invite({
    required String groupId,
    required List<String> userIds,
    String? accessToken,
  }) async {
    return StudyGroupDetail.fromJson(
      await _apiClient.postJson(
        '$_base/$groupId/invitations',
        body: {'userIds': userIds},
        accessToken: accessToken,
      ),
    );
  }

  @override
  Future<StudyGroupDetail> acceptInvitation({
    required String groupId,
    String? accessToken,
  }) async {
    return StudyGroupDetail.fromJson(
      await _apiClient.postJson(
        '$_base/$groupId/accept',
        body: const {},
        accessToken: accessToken,
      ),
    );
  }

  @override
  Future<void> declineInvitation({
    required String groupId,
    String? accessToken,
  }) {
    return _apiClient.postNoContent(
      '$_base/$groupId/decline',
      body: const {},
      accessToken: accessToken,
    );
  }

  @override
  Future<void> leaveGroup({required String groupId, String? accessToken}) {
    return _apiClient.postNoContent(
      '$_base/$groupId/leave',
      body: const {},
      accessToken: accessToken,
    );
  }

  @override
  Future<void> removeMember({
    required String groupId,
    required String userId,
    String? accessToken,
  }) {
    return _apiClient.deleteNoContent(
      '$_base/$groupId/members/$userId',
      accessToken: accessToken,
    );
  }

  @override
  Future<StudyGroupDetail> makeOrganizer({
    required String groupId,
    required String userId,
    String? accessToken,
  }) async {
    return StudyGroupDetail.fromJson(
      await _apiClient.putJson(
        '$_base/$groupId/members/$userId/organizer',
        body: const {},
        accessToken: accessToken,
      ),
    );
  }

  @override
  Future<StudyGroupDetail> setMyRole({
    required String groupId,
    String? roleLabel,
    String? accessToken,
  }) async {
    return StudyGroupDetail.fromJson(
      await _apiClient.putJson(
        '$_base/$groupId/me/role',
        body: {'roleLabel': roleLabel?.trim()},
        accessToken: accessToken,
      ),
    );
  }

  @override
  Future<List<Classmate>> classmates({
    String? homeworkId,
    String? groupId,
    String? accessToken,
  }) async {
    final query = [
      if (homeworkId != null) 'homeworkId=$homeworkId',
      if (groupId != null) 'groupId=$groupId',
    ].join('&');
    final json = await _apiClient.getJsonList(
      query.isEmpty ? '$_base/classmates' : '$_base/classmates?$query',
      accessToken: accessToken,
    );
    return json.map(Classmate.fromJson).toList(growable: false);
  }

  @override
  Future<HomeworkGroupsOverview> homeworkOverview({
    required String homeworkId,
    String? accessToken,
  }) async {
    return HomeworkGroupsOverview.fromJson(
      await _apiClient.getJson(
        '$_base/homework/$homeworkId/overview',
        accessToken: accessToken,
      ),
    );
  }

  @override
  Future<GroupAgenda> agenda({String? accessToken}) async {
    return GroupAgenda.fromJson(
      await _apiClient.getJson('$_base/agenda', accessToken: accessToken),
    );
  }

  @override
  Future<void> markRead({required String groupId, String? accessToken}) {
    return _apiClient.putNoContent(
      '$_base/$groupId/read',
      body: const {},
      accessToken: accessToken,
    );
  }

  @override
  Future<List<GroupTask>> listTasks({
    required String groupId,
    String? accessToken,
  }) async {
    final json = await _apiClient.getJsonList(
      '$_base/$groupId/tasks',
      accessToken: accessToken,
    );
    return json.map(GroupTask.fromJson).toList(growable: false);
  }

  @override
  Future<GroupTask> createTask({
    required String groupId,
    required GroupTaskDraft draft,
    String? accessToken,
  }) async {
    return GroupTask.fromJson(
      await _apiClient.postJson(
        '$_base/$groupId/tasks',
        body: draft.toJson(),
        accessToken: accessToken,
      ),
    );
  }

  @override
  Future<GroupTask> updateTask({
    required String taskId,
    required GroupTaskDraft draft,
    String? accessToken,
  }) async {
    return GroupTask.fromJson(
      await _apiClient.putJson(
        '$_base/tasks/$taskId',
        body: draft.toJson(),
        accessToken: accessToken,
      ),
    );
  }

  @override
  Future<GroupTask> setTaskStatus({
    required String taskId,
    required GroupTaskStatus status,
    String? accessToken,
  }) async {
    return GroupTask.fromJson(
      await _apiClient.putJson(
        '$_base/tasks/$taskId/status',
        body: {'status': status.apiValue},
        accessToken: accessToken,
      ),
    );
  }

  @override
  Future<void> deleteTask({required String taskId, String? accessToken}) {
    return _apiClient.deleteNoContent(
      '$_base/tasks/$taskId',
      accessToken: accessToken,
    );
  }

  @override
  Future<List<GroupMessage>> listMessages({
    required String groupId,
    DateTime? before,
    DateTime? after,
    String? accessToken,
  }) async {
    final query = [
      if (before != null)
        'before=${Uri.encodeQueryComponent(before.toUtc().toIso8601String())}',
      if (after != null)
        'after=${Uri.encodeQueryComponent(after.toUtc().toIso8601String())}',
    ].join('&');
    final json = await _apiClient.getJsonList(
      query.isEmpty
          ? '$_base/$groupId/messages'
          : '$_base/$groupId/messages?$query',
      accessToken: accessToken,
    );
    return json.map(GroupMessage.fromJson).toList(growable: false);
  }

  @override
  Future<GroupMessage> sendMessage({
    required String groupId,
    required String text,
    String? accessToken,
  }) async {
    return GroupMessage.fromJson(
      await _apiClient.postJson(
        '$_base/$groupId/messages',
        body: {'text': text.trim()},
        accessToken: accessToken,
      ),
    );
  }

  @override
  Future<void> deleteMessage({required String messageId, String? accessToken}) {
    return _apiClient.deleteNoContent(
      '$_base/messages/$messageId',
      accessToken: accessToken,
    );
  }

  @override
  Future<List<GroupResource>> listResources({
    required String groupId,
    String? accessToken,
  }) async {
    final json = await _apiClient.getJsonList(
      '$_base/$groupId/resources',
      accessToken: accessToken,
    );
    return json.map(GroupResource.fromJson).toList(growable: false);
  }

  @override
  Future<GroupResource> addLink({
    required String groupId,
    required String url,
    String? title,
    String? accessToken,
  }) async {
    return GroupResource.fromJson(
      await _apiClient.postJson(
        '$_base/$groupId/links',
        body: {'url': url.trim(), 'title': _clean(title)},
        accessToken: accessToken,
      ),
    );
  }

  @override
  Future<GroupResource> addFile({
    required String groupId,
    required String fileName,
    required List<int> bytes,
    String? title,
    String? accessToken,
  }) async {
    return GroupResource.fromJson(
      await _apiClient.postFile(
        '$_base/$groupId/files',
        fileName: fileName,
        bytes: bytes,
        fields: {'title': ?_clean(title)},
        accessToken: accessToken,
      ),
    );
  }

  @override
  Future<Uint8List> downloadFile({
    required String resourceId,
    String? accessToken,
  }) {
    return _apiClient.getBytes(
      '$_base/resources/$resourceId/file',
      accessToken: accessToken,
    );
  }

  @override
  Future<void> deleteResource({
    required String resourceId,
    String? accessToken,
  }) {
    return _apiClient.deleteNoContent(
      '$_base/resources/$resourceId',
      accessToken: accessToken,
    );
  }

  @override
  Future<GroupAvailability> getAvailability({String? accessToken}) async {
    return GroupAvailability.fromJson(
      await _apiClient.getJson('$_base/availability', accessToken: accessToken),
    );
  }

  @override
  Future<GroupAvailability> saveAvailability({
    required GroupAvailability availability,
    String? accessToken,
  }) async {
    return GroupAvailability.fromJson(
      await _apiClient.putJson(
        '$_base/availability',
        body: availability.toJson(),
        accessToken: accessToken,
      ),
    );
  }

  @override
  Future<GroupSlots> findSlots({
    required String groupId,
    int durationMinutes = 60,
    String? accessToken,
  }) async {
    return GroupSlots.fromJson(
      await _apiClient.getJson(
        '$_base/$groupId/slots?durationMinutes=$durationMinutes',
        accessToken: accessToken,
      ),
    );
  }

  @override
  Future<List<GroupMeeting>> listMeetings({
    required String groupId,
    String? accessToken,
  }) async {
    final json = await _apiClient.getJsonList(
      '$_base/$groupId/meetings',
      accessToken: accessToken,
    );
    return json.map(GroupMeeting.fromJson).toList(growable: false);
  }

  @override
  Future<GroupMeeting> proposeMeeting({
    required String groupId,
    required DateTime startsAt,
    required DateTime endsAt,
    required MeetingMode mode,
    String? place,
    String? accessToken,
  }) async {
    return GroupMeeting.fromJson(
      await _apiClient.postJson(
        '$_base/$groupId/meetings',
        body: {
          'startsAt': startsAt.toUtc().toIso8601String(),
          'endsAt': endsAt.toUtc().toIso8601String(),
          'mode': mode.apiValue,
          'place': _clean(place),
        },
        accessToken: accessToken,
      ),
    );
  }

  @override
  Future<GroupMeeting> voteMeeting({
    required String meetingId,
    required bool isAvailable,
    String? accessToken,
  }) async {
    return GroupMeeting.fromJson(
      await _apiClient.putJson(
        '$_base/meetings/$meetingId/vote',
        body: {'isAvailable': isAvailable},
        accessToken: accessToken,
      ),
    );
  }

  @override
  Future<void> cancelMeeting({required String meetingId, String? accessToken}) {
    return _apiClient.deleteNoContent(
      '$_base/meetings/$meetingId',
      accessToken: accessToken,
    );
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
