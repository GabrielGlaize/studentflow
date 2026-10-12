import 'dart:convert';
import 'dart:typed_data';

import 'package:studyflow_app/core/demo/demo_session_state.dart';
import 'package:studyflow_app/features/groups/data/group_repository.dart';
import 'package:studyflow_app/features/groups/domain/group_models.dart';

/// Groupes de démonstration : un projet en cours avec Garance et Liam, et une
/// invitation de Nina. L'élève connecté est « Gabriel D. » (demo-user-1).
class DemoGroupRepository implements GroupRepository {
  const DemoGroupRepository();

  static const meId = 'demo-user-1';
  static const _latency = Duration(milliseconds: 120);

  static final Map<String, _DemoGroup> _groups = {};
  static final Map<String, Uint8List> _files = {};
  static GroupAvailability _availability = GroupAvailability.defaults;
  static bool _seeded = false;
  static int _nextId = 1;

  static const _classmates = {
    'demo-user-2': 'Garance L.',
    'demo-user-3': 'Liam M.',
    'demo-user-4': 'Nina B.',
    'demo-user-5': 'Yanis K.',
  };

  /// Remet les données de démonstration à zéro (tests).
  static void reset() {
    _groups.clear();
    _files.clear();
    _availability = GroupAvailability.defaults;
    _seeded = false;
    _nextId = 1;
  }

  @override
  Future<List<StudyGroupSummary>> listGroups({String? accessToken}) async {
    await Future<void>.delayed(_latency);
    if (DemoSessionState.hasNoClass(accessToken)) return const [];
    _seed();
    final groups = _groups.values.map((x) => x.summary()).toList()
      ..sort((a, b) {
        if (a.isInvitation != b.isInvitation) return a.isInvitation ? -1 : 1;
        return (b.lastActivityAt ?? DateTime(2000)).compareTo(
          a.lastActivityAt ?? DateTime(2000),
        );
      });
    return groups;
  }

  @override
  Future<StudyGroupDetail> getGroup({
    required String groupId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    _seed();
    return _group(groupId).detail();
  }

  @override
  Future<StudyGroupDetail> createGroup({
    required StudyGroupDraft draft,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    _seed();
    final name = draft.name.trim();
    if (name.isEmpty) throw StateError('Donne un nom au groupe.');
    final group = _DemoGroup(
      id: 'group-${_nextId++}',
      name: name,
      description: draft.description,
      subjectId: draft.subjectId,
      homeworkId: draft.homeworkId,
      dueAt: draft.dueAt,
      members: [
        _DemoMember(meId, 'Gabriel D.', organizer: true),
        for (final id in draft.inviteeIds)
          _DemoMember(id, _classmates[id] ?? 'Camarade', invited: true),
      ],
    );
    group.system('Gabriel D. a créé le groupe.');
    _groups[group.id] = group;
    return group.detail();
  }

  @override
  Future<StudyGroupDetail> updateGroup({
    required String groupId,
    required StudyGroupDraft draft,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    final group = _group(groupId)
      ..name = draft.name.trim()
      ..description = draft.description
      ..subjectId = draft.subjectId
      ..homeworkId = draft.homeworkId
      ..dueAt = draft.dueAt;
    return group.detail();
  }

  @override
  Future<void> deleteGroup({
    required String groupId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    _groups.remove(groupId);
  }

  @override
  Future<StudyGroupDetail> invite({
    required String groupId,
    required List<String> userIds,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    final group = _group(groupId);
    for (final id in userIds) {
      if (group.members.any((x) => x.userId == id)) continue;
      group.members.add(
        _DemoMember(id, _classmates[id] ?? 'Camarade', invited: true),
      );
    }
    return group.detail();
  }

  @override
  Future<StudyGroupDetail> acceptInvitation({
    required String groupId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    final group = _group(groupId);
    group.me.invited = false;
    group.system('Gabriel D. a rejoint le groupe.');
    return group.detail();
  }

  @override
  Future<void> declineInvitation({
    required String groupId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    _groups.remove(groupId);
  }

  @override
  Future<void> leaveGroup({
    required String groupId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    _groups.remove(groupId);
  }

  @override
  Future<void> removeMember({
    required String groupId,
    required String userId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    _group(groupId).members.removeWhere((x) => x.userId == userId);
  }

  @override
  Future<StudyGroupDetail> makeOrganizer({
    required String groupId,
    required String userId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    final group = _group(groupId);
    for (final member in group.members) {
      member.organizer = member.userId == userId;
    }
    return group.detail();
  }

  @override
  Future<StudyGroupDetail> setMyRole({
    required String groupId,
    String? roleLabel,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    final group = _group(groupId);
    final cleaned = roleLabel?.trim();
    group.me.roleLabel = cleaned == null || cleaned.isEmpty ? null : cleaned;
    return group.detail();
  }

  @override
  Future<List<Classmate>> classmates({
    String? homeworkId,
    String? groupId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    final here = groupId == null
        ? const <String>{}
        : _group(groupId).members.map((x) => x.userId).toSet();
    return [
      for (final entry in _classmates.entries)
        Classmate(
          userId: entry.key,
          name: entry.value,
          isInvitedHere: here.contains(entry.key),
        ),
    ];
  }

  @override
  Future<HomeworkGroupsOverview> homeworkOverview({
    required String homeworkId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    _seed();
    final groups = _groups.values
        .where((x) => x.homeworkId == homeworkId)
        .toList();
    final grouped = {
      for (final group in groups)
        for (final member in group.members)
          if (!member.invited) member.userId,
    };
    return HomeworkGroupsOverview(
      groups: [
        for (final group in groups)
          (
            id: group.id,
            name: group.name,
            memberNames: [
              for (final member in group.members)
                if (!member.invited) member.name,
            ],
            isMine: !group.me.invited,
          ),
      ],
      studentsWithoutGroup: [
        if (!grouped.contains(meId)) 'Gabriel D.',
        for (final entry in _classmates.entries)
          if (!grouped.contains(entry.key)) entry.value,
      ],
    );
  }

  @override
  Future<GroupAgenda> agenda({String? accessToken}) async {
    await Future<void>.delayed(_latency);
    if (DemoSessionState.hasNoClass(accessToken)) return GroupAgenda.empty;
    _seed();
    final active = _groups.values.where((x) => !x.me.invited);
    return GroupAgenda(
      tasks: [
        for (final group in active)
          for (final task in group.tasks)
            if (task.assigneeIds.contains(meId) && !task.isDone)
              GroupAgendaTask(
                id: task.id,
                groupId: group.id,
                groupName: group.name,
                title: task.title,
                status: task.status,
                dueOn: task.dueOn,
              ),
      ],
      meetings: [
        for (final group in active)
          for (final meeting in group.meetings)
            if (meeting.isConfirmed)
              GroupAgendaMeeting(
                id: meeting.id,
                groupId: group.id,
                groupName: group.name,
                startsAt: meeting.startsAt,
                endsAt: meeting.endsAt,
                mode: meeting.mode,
                place: meeting.place,
              ),
      ],
    );
  }

  @override
  Future<void> markRead({required String groupId, String? accessToken}) async {
    _group(groupId).me.lastReadAt = DateTime.now();
  }

  @override
  Future<List<GroupTask>> listTasks({
    required String groupId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    final tasks = [..._group(groupId).tasks]
      ..sort((a, b) {
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        return (a.dueOn ?? DateTime(2100)).compareTo(b.dueOn ?? DateTime(2100));
      });
    return tasks;
  }

  @override
  Future<GroupTask> createTask({
    required String groupId,
    required GroupTaskDraft draft,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    final group = _group(groupId);
    final task = group.task(
      'task-${_nextId++}',
      draft.title.trim(),
      draft.assigneeIds,
      dueOn: draft.dueOn,
      notes: draft.notes,
      status: draft.status ?? GroupTaskStatus.todo,
    );
    group.tasks.add(task);
    return task;
  }

  @override
  Future<GroupTask> updateTask({
    required String taskId,
    required GroupTaskDraft draft,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    final (group, index) = _taskIndex(taskId);
    final previous = group.tasks[index];
    final task = group.task(
      taskId,
      draft.title.trim(),
      draft.assigneeIds,
      dueOn: draft.dueOn,
      notes: draft.notes,
      status: draft.status ?? previous.status,
    );
    group.tasks[index] = task;
    return task;
  }

  @override
  Future<GroupTask> setTaskStatus({
    required String taskId,
    required GroupTaskStatus status,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    final (group, index) = _taskIndex(taskId);
    final task = group.tasks[index].copyWith(status: status);
    group.tasks[index] = task;
    return task;
  }

  @override
  Future<void> deleteTask({required String taskId, String? accessToken}) async {
    await Future<void>.delayed(_latency);
    final (group, index) = _taskIndex(taskId);
    group.tasks.removeAt(index);
  }

  @override
  Future<List<GroupMessage>> listMessages({
    required String groupId,
    DateTime? before,
    DateTime? after,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    return _group(groupId).messages
        .where((x) => before == null || x.createdAt.isBefore(before))
        .where((x) => after == null || x.createdAt.isAfter(after))
        .toList();
  }

  @override
  Future<GroupMessage> sendMessage({
    required String groupId,
    required String text,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    final message = GroupMessage(
      id: 'message-${_nextId++}',
      groupId: groupId,
      authorId: meId,
      authorName: 'Gabriel D.',
      text: text.trim(),
      isMine: true,
      isDeleted: false,
      createdAt: DateTime.now(),
    );
    _group(groupId).messages.add(message);
    return message;
  }

  @override
  Future<void> deleteMessage({
    required String messageId,
    String? accessToken,
  }) async {
    for (final group in _groups.values) {
      final index = group.messages.indexWhere((x) => x.id == messageId);
      if (index >= 0) group.messages[index] = group.messages[index].deleted();
    }
  }

  @override
  Future<List<GroupResource>> listResources({
    required String groupId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    return [..._group(groupId).resources.reversed];
  }

  @override
  Future<GroupResource> addLink({
    required String groupId,
    required String url,
    String? title,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https') {
      throw StateError('Utilise un lien sécurisé, qui commence par https://');
    }
    final resource = GroupResource(
      id: 'resource-${_nextId++}',
      isLink: true,
      title: (title?.trim().isNotEmpty ?? false) ? title!.trim() : uri.host,
      url: uri.toString(),
      authorName: 'Gabriel D.',
      isMine: true,
      canDelete: true,
      createdAt: DateTime.now(),
    );
    _group(groupId).resources.add(resource);
    return resource;
  }

  @override
  Future<GroupResource> addFile({
    required String groupId,
    required String fileName,
    required List<int> bytes,
    String? title,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    final id = 'resource-${_nextId++}';
    _files[id] = Uint8List.fromList(bytes);
    final extension = fileName.split('.').last.toLowerCase();
    final resource = GroupResource(
      id: id,
      isLink: false,
      title: (title?.trim().isNotEmpty ?? false)
          ? title!.trim()
          : fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
      fileName: fileName,
      fileType: switch (extension) {
        'pdf' => 'pdf',
        'png' || 'jpg' || 'jpeg' || 'webp' => 'image',
        'html' || 'htm' => 'html',
        _ => 'text',
      },
      sizeBytes: bytes.length,
      authorName: 'Gabriel D.',
      isMine: true,
      canDelete: true,
      createdAt: DateTime.now(),
    );
    _group(groupId).resources.add(resource);
    return resource;
  }

  @override
  Future<Uint8List> downloadFile({
    required String resourceId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    return _files[resourceId] ??
        Uint8List.fromList(utf8.encode('Fichier de démonstration'));
  }

  @override
  Future<void> deleteResource({
    required String resourceId,
    String? accessToken,
  }) async {
    for (final group in _groups.values) {
      group.resources.removeWhere((x) => x.id == resourceId);
    }
    _files.remove(resourceId);
  }

  @override
  Future<GroupAvailability> getAvailability({String? accessToken}) async {
    await Future<void>.delayed(_latency);
    return _availability;
  }

  @override
  Future<GroupAvailability> saveAvailability({
    required GroupAvailability availability,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    return _availability = availability.copyWith();
  }

  @override
  Future<GroupSlots> findSlots({
    required String groupId,
    int durationMinutes = 60,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    final today = DateTime.now();
    DateTime weekday(int offset) {
      var day = DateTime(today.year, today.month, today.day + offset);
      while (day.weekday > 5) {
        day = day.add(const Duration(days: 1));
      }
      return day;
    }

    return GroupSlots(
      durationMinutes: durationMinutes,
      slots: [
        GroupSlot(
          day: weekday(1),
          startsAt: (hour: 12, minute: 0),
          endsAt: (hour: 13, minute: 30),
          mode: MeetingMode.onSite,
        ),
        GroupSlot(
          day: weekday(1),
          startsAt: (hour: 16, minute: 30),
          endsAt: (hour: 18, minute: 0),
          mode: MeetingMode.onSite,
        ),
        GroupSlot(
          day: weekday(2),
          startsAt: (hour: 18, minute: 15),
          endsAt: (hour: 21, minute: 0),
          mode: MeetingMode.remote,
        ),
      ],
      membersWithDefaultAvailability: _availability.isDefault
          ? const ['Gabriel D.']
          : const [],
    );
  }

  @override
  Future<List<GroupMeeting>> listMeetings({
    required String groupId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    return [..._group(groupId).meetings]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
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
    await Future<void>.delayed(_latency);
    final group = _group(groupId);
    final meeting = group.meeting(
      'meeting-${_nextId++}',
      startsAt,
      endsAt,
      mode,
      place: place,
      answers: {meId: true},
    );
    group.meetings.add(meeting);
    return meeting;
  }

  @override
  Future<GroupMeeting> voteMeeting({
    required String meetingId,
    required bool isAvailable,
    String? accessToken,
  }) async {
    await Future<void>.delayed(_latency);
    for (final group in _groups.values) {
      final index = group.meetings.indexWhere((x) => x.id == meetingId);
      if (index < 0) continue;
      final previous = group.meetings[index];
      final answers = {
        for (final vote in previous.votes)
          if (vote.isAvailable != null) vote.userId: vote.isAvailable!,
        meId: isAvailable,
      };
      final meeting = group.meeting(
        meetingId,
        previous.startsAt,
        previous.endsAt,
        previous.mode,
        place: previous.place,
        answers: answers,
      );
      group.meetings[index] = meeting;
      return meeting;
    }
    throw StateError('Réunion introuvable.');
  }

  @override
  Future<void> cancelMeeting({
    required String meetingId,
    String? accessToken,
  }) async {
    for (final group in _groups.values) {
      group.meetings.removeWhere((x) => x.id == meetingId);
    }
  }

  _DemoGroup _group(String id) {
    _seed();
    final group = _groups[id];
    if (group == null) throw StateError('Ce groupe n’existe plus.');
    return group;
  }

  (_DemoGroup, int) _taskIndex(String taskId) {
    for (final group in _groups.values) {
      final index = group.tasks.indexWhere((x) => x.id == taskId);
      if (index >= 0) return (group, index);
    }
    throw StateError('Tâche introuvable.');
  }

  static void _seed() {
    if (_seeded) return;
    _seeded = true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final project = _DemoGroup(
      id: 'group-demo-bdd',
      name: 'Projet BDD — équipe 2',
      description:
          'Modéliser la base de la médiathèque : MCD, MLD, script SQL et '
          'soutenance de 10 minutes.',
      subjectId: 'subject-bdd',
      subjectName: 'Base de données',
      dueAt: today.add(const Duration(days: 9, hours: 18)),
      members: [
        _DemoMember(meId, 'Gabriel D.', organizer: true, roleLabel: 'SQL'),
        _DemoMember('demo-user-2', 'Garance L.', roleLabel: 'Rédaction'),
        _DemoMember('demo-user-3', 'Liam M.', roleLabel: 'Diapos'),
      ],
    );
    project.tasks.addAll([
      project.task('task-demo-1', 'MCD validé par le prof', const [
        'demo-user-2',
        meId,
      ], status: GroupTaskStatus.done),
      project.task(
        'task-demo-2',
        'Script SQL de création',
        const [meId],
        dueOn: today.add(const Duration(days: 3)),
        status: GroupTaskStatus.doing,
      ),
      project.task(
        'task-demo-3',
        'Diapos de la soutenance',
        const ['demo-user-3'],
        dueOn: today.add(const Duration(days: 7)),
      ),
      project.task(
        'task-demo-4',
        'Jeu de données de test',
        const ['demo-user-2'],
        dueOn: today.add(const Duration(days: 5)),
      ),
    ]);
    project.messages.addAll([
      project.message(
        'Gabriel D. a créé le groupe.',
        now.subtract(const Duration(days: 4)),
      ),
      project.message(
        'J’ai mis le MCD dans les ressources, dites-moi si ça vous va',
        now.subtract(const Duration(hours: 20)),
        author: ('demo-user-2', 'Garance L.'),
      ),
      project.message(
        'Top ! Je commence le script SQL ce soir',
        now.subtract(const Duration(hours: 19)),
        author: (meId, 'Gabriel D.'),
      ),
      project.message(
        'On se cale un point jeudi midi pour les diapos ?',
        now.subtract(const Duration(minutes: 40)),
        author: ('demo-user-3', 'Liam M.'),
      ),
    ]);
    project.me.lastReadAt = now.subtract(const Duration(hours: 2));
    project.resources.add(
      GroupResource(
        id: 'resource-demo-1',
        isLink: true,
        title: 'MCD sur draw.io',
        url: 'https://app.diagrams.net/',
        authorName: 'Garance L.',
        isMine: false,
        canDelete: true,
        createdAt: now.subtract(const Duration(hours: 20)),
      ),
    );

    final invitation = _DemoGroup(
      id: 'group-demo-reseau',
      name: 'Dossier réseau',
      subjectName: 'Administration Windows',
      dueAt: today.add(const Duration(days: 16, hours: 18)),
      invitedBy: 'Nina B.',
      members: [
        _DemoMember('demo-user-4', 'Nina B.', organizer: true),
        _DemoMember(meId, 'Gabriel D.', invited: true),
      ],
    );

    _groups[project.id] = project;
    _groups[invitation.id] = invitation;
  }
}

class _DemoMember {
  _DemoMember(
    this.userId,
    this.name, {
    this.organizer = false,
    this.invited = false,
    this.roleLabel,
  });

  final String userId;
  final String name;
  bool organizer;
  bool invited;
  String? roleLabel;
  DateTime? lastReadAt;
}

class _DemoGroup {
  _DemoGroup({
    required this.id,
    required this.name,
    required this.members,
    this.description,
    this.subjectId,
    this.subjectName,
    this.homeworkId,
    this.dueAt,
    this.invitedBy,
  });

  final String id;
  String name;
  String? description;
  String? subjectId;
  String? subjectName;
  String? homeworkId;
  DateTime? dueAt;
  final String? invitedBy;
  final List<_DemoMember> members;
  final List<GroupTask> tasks = [];
  final List<GroupMessage> messages = [];
  final List<GroupResource> resources = [];
  final List<GroupMeeting> meetings = [];

  _DemoMember get me =>
      members.firstWhere((x) => x.userId == DemoGroupRepository.meId);

  void system(String text) => messages.add(message(text, DateTime.now()));

  GroupMessage message(String text, DateTime at, {(String, String)? author}) =>
      GroupMessage(
        id: 'message-${id.hashCode}-${messages.length}',
        groupId: id,
        authorId: author?.$1,
        authorName: author?.$2,
        text: text,
        isMine: author?.$1 == DemoGroupRepository.meId,
        isDeleted: false,
        createdAt: at,
      );

  GroupTask task(
    String taskId,
    String title,
    List<String> assigneeIds, {
    DateTime? dueOn,
    String? notes,
    GroupTaskStatus status = GroupTaskStatus.todo,
  }) => GroupTask(
    id: taskId,
    groupId: id,
    title: title,
    notes: notes,
    status: status,
    dueOn: dueOn,
    assigneeIds: assigneeIds,
    assigneeNames: [
      for (final userId in assigneeIds)
        members.where((x) => x.userId == userId).firstOrNull?.name ??
            'Camarade',
    ],
    isMine: assigneeIds.contains(DemoGroupRepository.meId),
  );

  GroupMeeting meeting(
    String meetingId,
    DateTime startsAt,
    DateTime endsAt,
    MeetingMode mode, {
    required Map<String, bool> answers,
    String? place,
  }) {
    final active = members.where((x) => !x.invited).toList();
    return GroupMeeting(
      id: meetingId,
      groupId: id,
      startsAt: startsAt,
      endsAt: endsAt,
      mode: mode,
      place: place,
      isConfirmed: active.every((x) => answers[x.userId] == true),
      proposedByName: 'Gabriel D.',
      canCancel: true,
      myAnswer: answers[DemoGroupRepository.meId],
      votes: [
        for (final member in active)
          MeetingVote(
            userId: member.userId,
            name: member.name,
            isAvailable: answers[member.userId],
          ),
      ],
    );
  }

  StudyGroupSummary summary() {
    final since = me.lastReadAt ?? DateTime(2000);
    return StudyGroupSummary(
      id: id,
      name: name,
      subjectId: subjectId,
      subjectName: subjectName,
      homeworkId: homeworkId,
      dueAt: dueAt,
      isInvitation: me.invited,
      isOrganizer: me.organizer,
      isArchived: false,
      invitedByName: invitedBy,
      memberCount: members.where((x) => !x.invited).length,
      taskCount: tasks.length,
      doneTaskCount: tasks.where((x) => x.isDone).length,
      myOpenTaskCount: tasks.where((x) => x.isMine && !x.isDone).length,
      unreadCount: me.invited
          ? 0
          : messages
                .where((x) => !x.isMine && x.createdAt.isAfter(since))
                .length,
      lastActivityAt: messages.isEmpty ? null : messages.last.createdAt,
    );
  }

  StudyGroupDetail detail() => StudyGroupDetail(
    summary: summary(),
    description: description,
    canManage: me.organizer && !me.invited,
    members: [
      for (final member in members)
        GroupMember(
          userId: member.userId,
          name: member.name,
          isOrganizer: member.organizer,
          isInvited: member.invited,
          isMe: member.userId == DemoGroupRepository.meId,
          roleLabel: member.roleLabel,
          lastReadAt: member.lastReadAt,
          openTaskCount: tasks
              .where((x) => x.assigneeIds.contains(member.userId) && !x.isDone)
              .length,
          doneTaskCount: tasks
              .where((x) => x.assigneeIds.contains(member.userId) && x.isDone)
              .length,
        ),
    ],
  );
}
