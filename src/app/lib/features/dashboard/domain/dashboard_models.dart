class DashboardSummary {
  const DashboardSummary({
    required this.generatedAt,
    required this.hasClass,
    required this.nextCourse,
    required this.pinnedAnnouncements,
    required this.upcomingHomework,
    required this.personalTasks,
    required this.todayEvents,
  });

  final DateTime generatedAt;
  final bool hasClass;
  final CourseSummary? nextCourse;
  final List<ClassAnnouncementSummary> pinnedAnnouncements;
  final List<HomeworkSummary> upcomingHomework;
  final List<PersonalTaskSummary> personalTasks;
  final List<PersonalEventSummary> todayEvents;

  factory DashboardSummary.fromJson(Map<String, Object?> json) {
    return DashboardSummary(
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      hasClass: json['hasClass'] as bool? ?? false,
      nextCourse: json['nextCourse'] is Map<String, Object?>
          ? CourseSummary.fromJson(json['nextCourse']! as Map<String, Object?>)
          : null,
      pinnedAnnouncements: _readList(
        json['pinnedAnnouncements'],
        ClassAnnouncementSummary.fromJson,
      ),
      upcomingHomework: _readList(
        json['upcomingHomework'],
        HomeworkSummary.fromJson,
      ),
      personalTasks: _readList(
        json['personalTasks'],
        PersonalTaskSummary.fromJson,
      ),
      todayEvents: _readList(
        json['todayEvents'],
        PersonalEventSummary.fromJson,
      ),
    );
  }
}

class CourseSummary {
  const CourseSummary({
    required this.id,
    required this.subjectName,
    required this.day,
    required this.startsAt,
    required this.endsAt,
    required this.room,
    this.teacherName,
  });

  final String id;
  final String subjectName;
  final DateTime day;
  final String startsAt;
  final String endsAt;
  final String room;
  final String? teacherName;

  factory CourseSummary.fromJson(Map<String, Object?> json) {
    return CourseSummary(
      id: json['id'] as String,
      subjectName: json['subjectName'] as String,
      day: DateTime.parse(json['day'] as String),
      startsAt: _shortTime(json['startsAt'] as String),
      endsAt: _shortTime(json['endsAt'] as String),
      room: json['room'] as String,
      teacherName: json['teacherName'] as String?,
    );
  }
}

String _shortTime(String value) {
  return value.length >= 5 ? value.substring(0, 5) : value;
}

class HomeworkSummary {
  const HomeworkSummary({
    required this.id,
    required this.title,
    required this.deadline,
    required this.isDone,
    required this.notificationsEnabled,
  });

  final String id;
  final String title;
  final DateTime deadline;
  final bool isDone;
  final bool notificationsEnabled;

  factory HomeworkSummary.fromJson(Map<String, Object?> json) {
    return HomeworkSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      deadline: DateTime.parse(json['deadline'] as String),
      isDone: json['isDone'] as bool? ?? false,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    );
  }
}

class PersonalTaskSummary {
  const PersonalTaskSummary({
    required this.id,
    required this.title,
    required this.category,
    required this.isDone,
    this.deadline,
  });

  final String id;
  final String title;
  final String category;
  final bool isDone;
  final DateTime? deadline;

  factory PersonalTaskSummary.fromJson(Map<String, Object?> json) {
    return PersonalTaskSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      isDone: json['isDone'] as bool? ?? false,
      deadline: json['deadline'] == null
          ? null
          : DateTime.parse(json['deadline'] as String),
    );
  }
}

class PersonalEventSummary {
  const PersonalEventSummary({
    required this.id,
    required this.title,
    required this.day,
    required this.startsAt,
    required this.endsAt,
    required this.category,
  });

  final String id;
  final String title;
  final DateTime day;
  final String startsAt;
  final String endsAt;
  final String category;

  factory PersonalEventSummary.fromJson(Map<String, Object?> json) {
    return PersonalEventSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      day: DateTime.parse(json['day'] as String),
      startsAt: json['startsAt'] as String,
      endsAt: json['endsAt'] as String,
      category: json['category'] as String,
    );
  }
}

class ClassAnnouncementSummary {
  const ClassAnnouncementSummary({
    required this.id,
    required this.content,
    required this.authorName,
  });

  final String id;
  final String content;
  final String authorName;

  factory ClassAnnouncementSummary.fromJson(Map<String, Object?> json) {
    return ClassAnnouncementSummary(
      id: json['id'] as String,
      content: json['content'] as String,
      authorName: json['authorName'] as String,
    );
  }
}

List<T> _readList<T>(
  Object? value,
  T Function(Map<String, Object?> json) fromJson,
) {
  if (value is! List<Object?>) return [];

  return value
      .whereType<Map<String, Object?>>()
      .map(fromJson)
      .toList(growable: false);
}
