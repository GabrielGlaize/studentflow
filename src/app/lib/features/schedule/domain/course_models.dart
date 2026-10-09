class CourseItem {
  const CourseItem({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.day,
    required this.startsAt,
    required this.endsAt,
    required this.room,
    required this.isCancelled,
    required this.version,
    this.teacherId,
    this.teacherName,
  });

  final String id;
  final String subjectId;
  final String subjectName;
  final String? teacherId;
  final String? teacherName;
  final DateTime day;
  final String startsAt;
  final String endsAt;
  final String room;
  final bool isCancelled;
  final int version;

  factory CourseItem.fromJson(Map<String, Object?> json) {
    return CourseItem(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      subjectName: json['subjectName'] as String,
      teacherId: json['teacherId'] as String?,
      teacherName: json['teacherName'] as String?,
      day: DateTime.parse(json['day'] as String),
      startsAt: _shortTime(json['startsAt'] as String),
      endsAt: _shortTime(json['endsAt'] as String),
      room: json['room'] as String,
      isCancelled: json['isCancelled'] as bool? ?? false,
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }

  CourseFormData toFormData() {
    return CourseFormData(
      subjectId: subjectId,
      subjectName: subjectName,
      teacherId: teacherId,
      teacherName: teacherName,
      day: day,
      startsAt: startsAt,
      endsAt: endsAt,
      room: room,
      isCancelled: isCancelled,
      version: version,
    );
  }

  DateTime get startDateTime => _at(day, startsAt);

  DateTime get endDateTime => _at(day, endsAt);
}

/// Ce que l'élève saisit pour un cours. La matière et l'intervenant sont choisis
/// dans les listes de la classe : on transmet leurs identifiants, les noms ne
/// servent qu'à l'affichage.
class CourseFormData {
  const CourseFormData({
    required this.subjectId,
    required this.subjectName,
    required this.day,
    required this.startsAt,
    required this.endsAt,
    required this.room,
    this.teacherId,
    this.teacherName,
    this.isCancelled = false,
    this.version,
  });

  final String subjectId;
  final String subjectName;
  final String? teacherId;
  final String? teacherName;
  final DateTime day;
  final String startsAt;
  final String endsAt;
  final String room;
  final bool isCancelled;
  final int? version;

  CourseFormData copyWith({
    DateTime? day,
    String? startsAt,
    String? endsAt,
    bool? isCancelled,
  }) {
    return CourseFormData(
      subjectId: subjectId,
      subjectName: subjectName,
      teacherId: teacherId,
      teacherName: teacherName,
      day: day ?? this.day,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      room: room,
      isCancelled: isCancelled ?? this.isCancelled,
      version: version,
    );
  }
}

class CourseRevisionItem {
  const CourseRevisionItem({
    required this.id,
    required this.action,
    required this.authorName,
    required this.createdAt,
    required this.version,
  });

  final String id;
  final String action;
  final String authorName;
  final DateTime createdAt;
  final int version;

  factory CourseRevisionItem.fromJson(Map<String, Object?> json) {
    return CourseRevisionItem(
      id: json['id'] as String,
      action: json['action'] as String,
      authorName: json['authorName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }
}

DateTime _at(DateTime day, String time) {
  final parts = time.split(':');
  return DateTime(
    day.year,
    day.month,
    day.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
}

String _shortTime(String value) {
  return value.length >= 5 ? value.substring(0, 5) : value;
}
