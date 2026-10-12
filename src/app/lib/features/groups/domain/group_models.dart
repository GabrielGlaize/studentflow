/// Groupes de travail : un espace privé entre quelques élèves d'une classe,
/// avec discussion, tâches, réunions et ressources.
library;

enum GroupTaskStatus {
  todo('todo', 'À faire'),
  doing('doing', 'En cours'),
  done('done', 'Fait');

  const GroupTaskStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  GroupTaskStatus get next => switch (this) {
    GroupTaskStatus.todo => GroupTaskStatus.doing,
    GroupTaskStatus.doing => GroupTaskStatus.done,
    GroupTaskStatus.done => GroupTaskStatus.todo,
  };

  static GroupTaskStatus parse(Object? value) =>
      GroupTaskStatus.values.firstWhere(
        (x) => x.apiValue == value,
        orElse: () => GroupTaskStatus.todo,
      );
}

enum MeetingMode {
  onSite('onsite', 'Sur place'),
  remote('remote', 'À distance');

  const MeetingMode(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MeetingMode parse(Object? value) =>
      value == 'onsite' ? MeetingMode.onSite : MeetingMode.remote;
}

class StudyGroupSummary {
  const StudyGroupSummary({
    required this.id,
    required this.name,
    required this.isInvitation,
    required this.isOrganizer,
    required this.isArchived,
    required this.memberCount,
    required this.taskCount,
    required this.doneTaskCount,
    required this.myOpenTaskCount,
    required this.unreadCount,
    this.subjectId,
    this.subjectName,
    this.homeworkId,
    this.homeworkTitle,
    this.dueAt,
    this.invitedByName,
    this.lastActivityAt,
  });

  final String id;
  final String name;
  final String? subjectId;

  /// Cours (matière) auquel le groupe est rattaché.
  final String? subjectName;
  final String? homeworkId;
  final String? homeworkTitle;
  final DateTime? dueAt;

  /// Invitation reçue, pas encore acceptée.
  final bool isInvitation;
  final bool isOrganizer;
  final bool isArchived;
  final String? invitedByName;
  final int memberCount;
  final int taskCount;
  final int doneTaskCount;
  final int myOpenTaskCount;
  final int unreadCount;
  final DateTime? lastActivityAt;

  double get progress => taskCount == 0 ? 0 : doneTaskCount / taskCount;

  /// Jours avant le rendu (0 le jour même, négatif une fois passé).
  int? daysUntilDue(DateTime now) {
    final due = dueAt?.toLocal();
    if (due == null) return null;
    return DateTime(
      due.year,
      due.month,
      due.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  factory StudyGroupSummary.fromJson(Map<String, Object?> json) {
    return StudyGroupSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      subjectId: json['subjectId'] as String?,
      subjectName: json['subjectName'] as String?,
      homeworkId: json['homeworkId'] as String?,
      homeworkTitle: json['homeworkTitle'] as String?,
      dueAt: _dateTime(json['dueAt']),
      isArchived: json['isArchived'] as bool? ?? false,
      isInvitation: json['status'] == 'invited',
      isOrganizer: json['myRole'] == 'organizer',
      invitedByName: json['invitedByName'] as String?,
      memberCount: _int(json['memberCount']),
      taskCount: _int(json['taskCount']),
      doneTaskCount: _int(json['doneTaskCount']),
      myOpenTaskCount: _int(json['myOpenTaskCount']),
      unreadCount: _int(json['unreadCount']),
      lastActivityAt: _dateTime(json['lastActivityAt']),
    );
  }
}

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.name,
    required this.isOrganizer,
    required this.isInvited,
    required this.isMe,
    this.roleLabel,
    this.lastReadAt,
    this.openTaskCount = 0,
    this.doneTaskCount = 0,
  });

  final String userId;
  final String name;
  final bool isOrganizer;
  final bool isInvited;
  final bool isMe;

  /// Rôle libre : « Rédaction », « Diapos »…
  final String? roleLabel;
  final DateTime? lastReadAt;
  final int openTaskCount;
  final int doneTaskCount;

  String get initials {
    final parts = name.split(' ').where((x) => x.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((x) => x[0].toUpperCase()).join();
  }

  factory GroupMember.fromJson(Map<String, Object?> json) {
    return GroupMember(
      userId: json['userId'] as String,
      name: json['name'] as String,
      isOrganizer: json['role'] == 'organizer',
      isInvited: json['status'] == 'invited',
      roleLabel: json['roleLabel'] as String?,
      isMe: json['isMe'] as bool? ?? false,
      lastReadAt: _dateTime(json['lastReadAt']),
      openTaskCount: _int(json['openTaskCount']),
      doneTaskCount: _int(json['doneTaskCount']),
    );
  }
}

class StudyGroupDetail {
  const StudyGroupDetail({
    required this.summary,
    required this.canManage,
    required this.members,
    this.description,
  });

  final StudyGroupSummary summary;
  final String? description;
  final bool canManage;
  final List<GroupMember> members;

  List<GroupMember> get activeMembers =>
      members.where((x) => !x.isInvited).toList(growable: false);

  GroupMember? get me => members.where((x) => x.isMe).firstOrNull;

  factory StudyGroupDetail.fromJson(Map<String, Object?> json) {
    return StudyGroupDetail(
      summary: StudyGroupSummary.fromJson(
        json['summary'] as Map<String, Object?>,
      ),
      description: json['description'] as String?,
      canManage: json['canManage'] as bool? ?? false,
      members: _list(json['members'], GroupMember.fromJson),
    );
  }
}

/// Ce qu'on saisit pour créer ou modifier un groupe.
class StudyGroupDraft {
  const StudyGroupDraft({
    required this.name,
    this.description,
    this.subjectId,
    this.homeworkId,
    this.dueAt,
    this.inviteeIds = const [],
  });

  final String name;
  final String? description;
  final String? subjectId;
  final String? homeworkId;
  final DateTime? dueAt;
  final List<String> inviteeIds;

  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'description': _clean(description),
    'subjectId': subjectId,
    'homeworkId': homeworkId,
    'dueAt': dueAt?.toUtc().toIso8601String(),
    'inviteeIds': inviteeIds,
  };
}

class GroupTask {
  const GroupTask({
    required this.id,
    required this.groupId,
    required this.title,
    required this.status,
    required this.assigneeIds,
    required this.assigneeNames,
    required this.isMine,
    this.notes,
    this.dueOn,
    this.completedAt,
  });

  final String id;
  final String groupId;
  final String title;
  final String? notes;
  final GroupTaskStatus status;
  final DateTime? dueOn;
  final List<String> assigneeIds;
  final List<String> assigneeNames;
  final bool isMine;
  final DateTime? completedAt;

  bool get isDone => status == GroupTaskStatus.done;

  bool isLate(DateTime now) {
    final due = dueOn;
    if (due == null || isDone) return false;
    return due.isBefore(DateTime(now.year, now.month, now.day));
  }

  GroupTask copyWith({GroupTaskStatus? status}) => GroupTask(
    id: id,
    groupId: groupId,
    title: title,
    notes: notes,
    status: status ?? this.status,
    dueOn: dueOn,
    assigneeIds: assigneeIds,
    assigneeNames: assigneeNames,
    isMine: isMine,
    completedAt: completedAt,
  );

  factory GroupTask.fromJson(Map<String, Object?> json) {
    return GroupTask(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      title: json['title'] as String,
      notes: json['notes'] as String?,
      status: GroupTaskStatus.parse(json['status']),
      dueOn: _date(json['dueOn']),
      assigneeIds: _strings(json['assigneeIds']),
      assigneeNames: _strings(json['assigneeNames']),
      isMine: json['isMine'] as bool? ?? false,
      completedAt: _dateTime(json['completedAt']),
    );
  }
}

class GroupTaskDraft {
  const GroupTaskDraft({
    required this.title,
    this.notes,
    this.dueOn,
    this.assigneeIds = const [],
    this.status,
  });

  final String title;
  final String? notes;
  final DateTime? dueOn;
  final List<String> assigneeIds;
  final GroupTaskStatus? status;

  Map<String, Object?> toJson() => {
    'title': title.trim(),
    'notes': _clean(notes),
    'dueOn': dueOn == null ? null : _dateOnly(dueOn!),
    'assigneeIds': assigneeIds,
    'status': status?.apiValue,
  };
}

class GroupMessage {
  const GroupMessage({
    required this.id,
    required this.groupId,
    required this.text,
    required this.isMine,
    required this.isDeleted,
    required this.createdAt,
    this.authorId,
    this.authorName,
    this.isPending = false,
  });

  final String id;
  final String groupId;
  final String? authorId;
  final String? authorName;
  final String text;
  final bool isMine;
  final bool isDeleted;
  final DateTime createdAt;

  /// Envoi en cours : affiché tout de suite, confirmé par le serveur.
  final bool isPending;

  bool get isSystem => authorId == null;

  GroupMessage asSeenBy(String? userId) => GroupMessage(
    id: id,
    groupId: groupId,
    authorId: authorId,
    authorName: authorName,
    text: text,
    isMine: authorId != null && authorId == userId,
    isDeleted: isDeleted,
    createdAt: createdAt,
  );

  GroupMessage deleted() => GroupMessage(
    id: id,
    groupId: groupId,
    authorId: authorId,
    authorName: authorName,
    text: '',
    isMine: isMine,
    isDeleted: true,
    createdAt: createdAt,
  );

  factory GroupMessage.fromJson(Map<String, Object?> json) {
    return GroupMessage(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      authorId: json['authorId'] as String?,
      authorName: json['authorName'] as String?,
      text: json['text'] as String? ?? '',
      isMine: json['isMine'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }
}

class GroupResource {
  const GroupResource({
    required this.id,
    required this.isLink,
    required this.title,
    required this.authorName,
    required this.isMine,
    required this.canDelete,
    required this.createdAt,
    this.url,
    this.fileName,
    this.fileType,
    this.sizeBytes,
  });

  final String id;
  final bool isLink;
  final String title;
  final String? url;
  final String? fileName;

  /// pdf, image, html ou text (reconnu par le serveur).
  final String? fileType;
  final int? sizeBytes;
  final String authorName;
  final bool isMine;
  final bool canDelete;
  final DateTime createdAt;

  factory GroupResource.fromJson(Map<String, Object?> json) {
    return GroupResource(
      id: json['id'] as String,
      isLink: json['kind'] == 'link',
      title: json['title'] as String,
      url: json['url'] as String?,
      fileName: json['fileName'] as String?,
      fileType: json['fileType'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      authorName: json['authorName'] as String? ?? 'Ancien élève',
      isMine: json['isMine'] as bool? ?? false,
      canDelete: json['canDelete'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }
}

/// Disponibilités déclarées une fois pour toutes, pour les créneaux communs.
class GroupAvailability {
  const GroupAvailability({
    required this.companyEndsAt,
    required this.availableUntil,
    required this.weekendAvailable,
    required this.usePersonalAgenda,
    required this.isDefault,
  });

  static const defaults = GroupAvailability(
    companyEndsAt: (hour: 17, minute: 30),
    availableUntil: (hour: 21, minute: 0),
    weekendAvailable: false,
    usePersonalAgenda: true,
    isDefault: true,
  );

  /// Heure de fin en entreprise, les jours sans cours.
  final ({int hour, int minute}) companyEndsAt;

  /// Heure à laquelle une réunion doit être finie le soir.
  final ({int hour, int minute}) availableUntil;
  final bool weekendAvailable;
  final bool usePersonalAgenda;
  final bool isDefault;

  GroupAvailability copyWith({
    ({int hour, int minute})? companyEndsAt,
    ({int hour, int minute})? availableUntil,
    bool? weekendAvailable,
    bool? usePersonalAgenda,
  }) => GroupAvailability(
    companyEndsAt: companyEndsAt ?? this.companyEndsAt,
    availableUntil: availableUntil ?? this.availableUntil,
    weekendAvailable: weekendAvailable ?? this.weekendAvailable,
    usePersonalAgenda: usePersonalAgenda ?? this.usePersonalAgenda,
    isDefault: false,
  );

  Map<String, Object?> toJson() => {
    'companyEndsAt': _timeJson(companyEndsAt),
    'availableUntil': _timeJson(availableUntil),
    'weekendAvailable': weekendAvailable,
    'usePersonalAgenda': usePersonalAgenda,
  };

  factory GroupAvailability.fromJson(Map<String, Object?> json) {
    return GroupAvailability(
      companyEndsAt: _time(json['companyEndsAt']) ?? defaults.companyEndsAt,
      availableUntil: _time(json['availableUntil']) ?? defaults.availableUntil,
      weekendAvailable: json['weekendAvailable'] as bool? ?? false,
      usePersonalAgenda: json['usePersonalAgenda'] as bool? ?? true,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

class GroupSlot {
  const GroupSlot({
    required this.day,
    required this.startsAt,
    required this.endsAt,
    required this.mode,
    this.missingNames = const [],
  });

  final DateTime day;
  final ({int hour, int minute}) startsAt;
  final ({int hour, int minute}) endsAt;
  final MeetingMode mode;

  /// Sans créneau commun, ceux où il ne manque qu'une personne.
  final List<String> missingNames;

  DateTime get start =>
      DateTime(day.year, day.month, day.day, startsAt.hour, startsAt.minute);

  DateTime get end =>
      DateTime(day.year, day.month, day.day, endsAt.hour, endsAt.minute);

  factory GroupSlot.fromJson(Map<String, Object?> json) {
    return GroupSlot(
      day: _date(json['day'])!,
      startsAt: _time(json['startsAt'])!,
      endsAt: _time(json['endsAt'])!,
      mode: MeetingMode.parse(json['mode']),
      missingNames: _strings(json['missingNames']),
    );
  }
}

class GroupSlots {
  const GroupSlots({
    required this.durationMinutes,
    required this.slots,
    required this.membersWithDefaultAvailability,
  });

  final int durationMinutes;
  final List<GroupSlot> slots;

  /// Membres qui n'ont pas encore indiqué leurs disponibilités.
  final List<String> membersWithDefaultAvailability;

  factory GroupSlots.fromJson(Map<String, Object?> json) {
    return GroupSlots(
      durationMinutes: _int(json['durationMinutes'], 60),
      slots: _list(json['slots'], GroupSlot.fromJson),
      membersWithDefaultAvailability: _strings(
        json['membersWithDefaultAvailability'],
      ),
    );
  }
}

class MeetingVote {
  const MeetingVote({
    required this.userId,
    required this.name,
    this.isAvailable,
  });

  final String userId;
  final String name;

  /// Nul tant que le membre n'a pas répondu.
  final bool? isAvailable;

  factory MeetingVote.fromJson(Map<String, Object?> json) {
    return MeetingVote(
      userId: json['userId'] as String,
      name: json['name'] as String,
      isAvailable: json['isAvailable'] as bool?,
    );
  }
}

class GroupMeeting {
  const GroupMeeting({
    required this.id,
    required this.groupId,
    required this.startsAt,
    required this.endsAt,
    required this.mode,
    required this.isConfirmed,
    required this.canCancel,
    required this.votes,
    this.place,
    this.proposedByName,
    this.myAnswer,
  });

  final String id;
  final String groupId;
  final DateTime startsAt;
  final DateTime endsAt;
  final MeetingMode mode;
  final String? place;
  final bool isConfirmed;
  final String? proposedByName;
  final bool canCancel;
  final bool? myAnswer;
  final List<MeetingVote> votes;

  int get yesCount => votes.where((x) => x.isAvailable == true).length;

  factory GroupMeeting.fromJson(Map<String, Object?> json) {
    return GroupMeeting(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String).toLocal(),
      endsAt: DateTime.parse(json['endsAt'] as String).toLocal(),
      mode: MeetingMode.parse(json['mode']),
      place: json['place'] as String?,
      isConfirmed: json['status'] == 'confirmed',
      proposedByName: json['proposedByName'] as String?,
      canCancel: json['canCancel'] as bool? ?? false,
      myAnswer: json['myAnswer'] as bool?,
      votes: _list(json['votes'], MeetingVote.fromJson),
    );
  }
}

class GroupAgendaTask {
  const GroupAgendaTask({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.title,
    required this.status,
    this.dueOn,
  });

  final String id;
  final String groupId;
  final String groupName;
  final String title;
  final GroupTaskStatus status;
  final DateTime? dueOn;

  factory GroupAgendaTask.fromJson(Map<String, Object?> json) {
    return GroupAgendaTask(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      groupName: json['groupName'] as String,
      title: json['title'] as String,
      status: GroupTaskStatus.parse(json['status']),
      dueOn: _date(json['dueOn']),
    );
  }
}

class GroupAgendaMeeting {
  const GroupAgendaMeeting({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.startsAt,
    required this.endsAt,
    required this.mode,
    this.place,
  });

  final String id;
  final String groupId;
  final String groupName;
  final DateTime startsAt;
  final DateTime endsAt;
  final MeetingMode mode;
  final String? place;

  factory GroupAgendaMeeting.fromJson(Map<String, Object?> json) {
    return GroupAgendaMeeting(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      groupName: json['groupName'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String).toLocal(),
      endsAt: DateTime.parse(json['endsAt'] as String).toLocal(),
      mode: MeetingMode.parse(json['mode']),
      place: json['place'] as String?,
    );
  }
}

/// Ce qui concerne l'élève dans tous ses groupes (accueil, agenda, rappels).
class GroupAgenda {
  const GroupAgenda({required this.tasks, required this.meetings});

  static const empty = GroupAgenda(tasks: [], meetings: []);

  final List<GroupAgendaTask> tasks;
  final List<GroupAgendaMeeting> meetings;

  factory GroupAgenda.fromJson(Map<String, Object?> json) {
    return GroupAgenda(
      tasks: _list(json['tasks'], GroupAgendaTask.fromJson),
      meetings: _list(json['meetings'], GroupAgendaMeeting.fromJson),
    );
  }
}

class Classmate {
  const Classmate({
    required this.userId,
    required this.name,
    required this.isInvitedHere,
    this.groupName,
  });

  final String userId;
  final String name;

  /// Groupe déjà formé pour ce devoir.
  final String? groupName;

  /// Déjà membre ou invité dans le groupe courant.
  final bool isInvitedHere;

  factory Classmate.fromJson(Map<String, Object?> json) {
    return Classmate(
      userId: json['userId'] as String,
      name: json['name'] as String,
      groupName: json['groupName'] as String?,
      isInvitedHere: json['isInvitedHere'] as bool? ?? false,
    );
  }
}

class HomeworkGroupsOverview {
  const HomeworkGroupsOverview({
    required this.groups,
    required this.studentsWithoutGroup,
  });

  final List<({String id, String name, List<String> memberNames, bool isMine})>
  groups;
  final List<String> studentsWithoutGroup;

  ({String id, String name, List<String> memberNames, bool isMine})?
  get myGroup => groups.where((x) => x.isMine).firstOrNull;

  factory HomeworkGroupsOverview.fromJson(Map<String, Object?> json) {
    return HomeworkGroupsOverview(
      groups: (json['groups'] as List<Object?>? ?? const [])
          .whereType<Map<String, Object?>>()
          .map(
            (x) => (
              id: x['id'] as String,
              name: x['name'] as String,
              memberNames: _strings(x['memberNames']),
              isMine: x['isMine'] as bool? ?? false,
            ),
          )
          .toList(growable: false),
      studentsWithoutGroup: _strings(json['studentsWithoutGroup']),
    );
  }
}

List<T> _list<T>(Object? value, T Function(Map<String, Object?>) parse) =>
    (value as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(parse)
        .toList(growable: false);

List<String> _strings(Object? value) =>
    (value as List<Object?>? ?? const []).whereType<String>().toList();

int _int(Object? value, [int fallback = 0]) =>
    (value as num?)?.toInt() ?? fallback;

DateTime? _dateTime(Object? value) =>
    value is String ? DateTime.parse(value).toLocal() : null;

DateTime? _date(Object? value) {
  if (value is! String) return null;
  final parsed = DateTime.parse(value);
  return DateTime(parsed.year, parsed.month, parsed.day);
}

({int hour, int minute})? _time(Object? value) {
  if (value is! String) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  return (hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

String _timeJson(({int hour, int minute}) time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

String _dateOnly(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

String? _clean(String? value) {
  final cleaned = value?.trim();
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}
