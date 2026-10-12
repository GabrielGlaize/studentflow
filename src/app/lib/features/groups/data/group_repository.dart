import 'dart:typed_data';

import 'package:studyflow_app/features/groups/domain/group_models.dart';

abstract interface class GroupRepository {
  /// Mes groupes et les invitations reçues.
  Future<List<StudyGroupSummary>> listGroups({String? accessToken});

  Future<StudyGroupDetail> getGroup({
    required String groupId,
    String? accessToken,
  });

  Future<StudyGroupDetail> createGroup({
    required StudyGroupDraft draft,
    String? accessToken,
  });

  Future<StudyGroupDetail> updateGroup({
    required String groupId,
    required StudyGroupDraft draft,
    String? accessToken,
  });

  Future<void> deleteGroup({required String groupId, String? accessToken});

  Future<StudyGroupDetail> invite({
    required String groupId,
    required List<String> userIds,
    String? accessToken,
  });

  Future<StudyGroupDetail> acceptInvitation({
    required String groupId,
    String? accessToken,
  });

  Future<void> declineInvitation({
    required String groupId,
    String? accessToken,
  });

  Future<void> leaveGroup({required String groupId, String? accessToken});

  Future<void> removeMember({
    required String groupId,
    required String userId,
    String? accessToken,
  });

  Future<StudyGroupDetail> makeOrganizer({
    required String groupId,
    required String userId,
    String? accessToken,
  });

  Future<StudyGroupDetail> setMyRole({
    required String groupId,
    String? roleLabel,
    String? accessToken,
  });

  Future<List<Classmate>> classmates({
    String? homeworkId,
    String? groupId,
    String? accessToken,
  });

  Future<HomeworkGroupsOverview> homeworkOverview({
    required String homeworkId,
    String? accessToken,
  });

  Future<GroupAgenda> agenda({String? accessToken});

  Future<void> markRead({required String groupId, String? accessToken});

  Future<List<GroupTask>> listTasks({
    required String groupId,
    String? accessToken,
  });

  Future<GroupTask> createTask({
    required String groupId,
    required GroupTaskDraft draft,
    String? accessToken,
  });

  Future<GroupTask> updateTask({
    required String taskId,
    required GroupTaskDraft draft,
    String? accessToken,
  });

  Future<GroupTask> setTaskStatus({
    required String taskId,
    required GroupTaskStatus status,
    String? accessToken,
  });

  Future<void> deleteTask({required String taskId, String? accessToken});

  /// Messages les plus récents, ou ceux d'avant [before].
  Future<List<GroupMessage>> listMessages({
    required String groupId,
    DateTime? before,
    DateTime? after,
    String? accessToken,
  });

  Future<GroupMessage> sendMessage({
    required String groupId,
    required String text,
    String? accessToken,
  });

  Future<void> deleteMessage({required String messageId, String? accessToken});

  Future<List<GroupResource>> listResources({
    required String groupId,
    String? accessToken,
  });

  Future<GroupResource> addLink({
    required String groupId,
    required String url,
    String? title,
    String? accessToken,
  });

  Future<GroupResource> addFile({
    required String groupId,
    required String fileName,
    required List<int> bytes,
    String? title,
    String? accessToken,
  });

  Future<Uint8List> downloadFile({
    required String resourceId,
    String? accessToken,
  });

  Future<void> deleteResource({
    required String resourceId,
    String? accessToken,
  });

  Future<GroupAvailability> getAvailability({String? accessToken});

  Future<GroupAvailability> saveAvailability({
    required GroupAvailability availability,
    String? accessToken,
  });

  Future<GroupSlots> findSlots({
    required String groupId,
    int durationMinutes = 60,
    String? accessToken,
  });

  Future<List<GroupMeeting>> listMeetings({
    required String groupId,
    String? accessToken,
  });

  Future<GroupMeeting> proposeMeeting({
    required String groupId,
    required DateTime startsAt,
    required DateTime endsAt,
    required MeetingMode mode,
    String? place,
    String? accessToken,
  });

  Future<GroupMeeting> voteMeeting({
    required String meetingId,
    required bool isAvailable,
    String? accessToken,
  });

  Future<void> cancelMeeting({required String meetingId, String? accessToken});
}
