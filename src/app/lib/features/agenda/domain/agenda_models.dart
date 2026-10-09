class HomeworkItem {
  const HomeworkItem({
    required this.id,
    required this.title,
    required this.deadline,
    required this.isDone,
    required this.notificationsEnabled,
    this.description,
    this.courseId,
    this.subjectName,
    this.courseDay,
    this.reminderMinutesBefore = ReminderDelays.homeworkDefault,
    this.isEvaluation = false,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime deadline;

  /// Devoir noté (contrôle, oral…), mis en avant dans l'agenda.
  final bool isEvaluation;
  final String? courseId;

  /// Matière du cours lié, pour afficher « Mathématiques » sur le devoir.
  final String? subjectName;
  final DateTime? courseDay;
  final bool isDone;
  final bool notificationsEnabled;

  /// Délai du rappel avant l'échéance, propre à chaque élève.
  final int reminderMinutesBefore;

  factory HomeworkItem.fromJson(Map<String, Object?> json) {
    return HomeworkItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      deadline: DateTime.parse(json['deadline'] as String),
      courseId: json['courseId'] as String?,
      subjectName: json['subjectName'] as String?,
      courseDay: json['courseDay'] == null
          ? null
          : DateTime.parse(json['courseDay'] as String),
      isDone: json['isDone'] as bool? ?? false,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      reminderMinutesBefore:
          (json['reminderMinutesBefore'] as num?)?.toInt() ??
          ReminderDelays.homeworkDefault,
      isEvaluation: json['isEvaluation'] as bool? ?? false,
    );
  }

  HomeworkItem copyWith({
    bool? isDone,
    bool? notificationsEnabled,
    int? reminderMinutesBefore,
  }) {
    return HomeworkItem(
      id: id,
      title: title,
      description: description,
      deadline: deadline,
      courseId: courseId,
      subjectName: subjectName,
      courseDay: courseDay,
      isDone: isDone ?? this.isDone,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      isEvaluation: isEvaluation,
    );
  }

  CreateHomeworkRequest toRequest() {
    return CreateHomeworkRequest(
      title: title,
      description: description,
      deadline: deadline,
      courseId: courseId,
      subjectName: subjectName,
      courseDay: courseDay,
      isEvaluation: isEvaluation,
    );
  }
}

class CreateHomeworkRequest {
  const CreateHomeworkRequest({
    required this.title,
    required this.deadline,
    this.description,
    this.courseId,
    this.subjectName,
    this.courseDay,
    this.isEvaluation = false,
  });

  final String title;
  final String? description;
  final DateTime deadline;
  final String? courseId;
  final bool isEvaluation;

  /// Affichage seulement (mode démo) : le serveur les déduit du cours lié.
  final String? subjectName;
  final DateTime? courseDay;

  Map<String, Object?> toJson() {
    return {
      'title': title.trim(),
      'description': _cleanOptional(description),
      'deadline': deadline.toUtc().toIso8601String(),
      'courseId': courseId,
      'isEvaluation': isEvaluation,
    };
  }

  static String? _cleanOptional(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}

class AgendaTaskItem {
  const AgendaTaskItem({
    required this.id,
    required this.title,
    required this.category,
    required this.isDone,
    required this.notificationsEnabled,
    this.description,
    this.deadline,
    this.courseId,
    this.reminderMinutesBefore = ReminderDelays.taskDefault,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime? deadline;
  final String category;
  final bool isDone;
  final bool notificationsEnabled;
  final String? courseId;
  final int reminderMinutesBefore;

  factory AgendaTaskItem.fromJson(Map<String, Object?> json) {
    return AgendaTaskItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      deadline: json['deadline'] == null
          ? null
          : DateTime.parse(json['deadline'] as String),
      category: json['category'] as String,
      isDone: json['isDone'] as bool? ?? false,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      courseId: json['courseId'] as String?,
      reminderMinutesBefore:
          (json['reminderMinutesBefore'] as num?)?.toInt() ??
          ReminderDelays.taskDefault,
    );
  }

  Map<String, Object?> toUpdateJson({required bool isDone}) {
    return {
      'title': title,
      'description': description,
      'deadline': deadline?.toUtc().toIso8601String(),
      'category': category,
      'isDone': isDone,
      'notificationsEnabled': notificationsEnabled,
      'courseId': courseId,
      'reminderMinutesBefore': reminderMinutesBefore,
    };
  }

  AgendaTaskItem copyWith({
    bool? isDone,
    bool? notificationsEnabled,
    int? reminderMinutesBefore,
  }) {
    return AgendaTaskItem(
      id: id,
      title: title,
      description: description,
      deadline: deadline,
      category: category,
      isDone: isDone ?? this.isDone,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      courseId: courseId,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
    );
  }
}

class PersonalEventItem {
  const PersonalEventItem({
    required this.id,
    required this.title,
    required this.day,
    required this.startsAt,
    required this.endsAt,
    required this.category,
    required this.notificationsEnabled,
    this.location,
    this.notes,
    this.reminderMinutesBefore = ReminderDelays.eventDefault,
  });

  final String id;
  final String title;
  final DateTime day;
  final String startsAt;
  final String endsAt;
  final String category;
  final String? location;
  final String? notes;
  final bool notificationsEnabled;
  final int reminderMinutesBefore;

  factory PersonalEventItem.fromJson(Map<String, Object?> json) {
    return PersonalEventItem(
      id: json['id'] as String,
      title: json['title'] as String,
      day: DateTime.parse(json['day'] as String),
      startsAt: json['startsAt'] as String,
      endsAt: json['endsAt'] as String,
      category: json['category'] as String,
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      reminderMinutesBefore:
          (json['reminderMinutesBefore'] as num?)?.toInt() ??
          ReminderDelays.eventDefault,
    );
  }

  DateTime get startDateTime {
    final parts = startsAt.split(':');
    return DateTime(
      day.year,
      day.month,
      day.day,
      int.tryParse(parts.first) ?? 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  CreatePersonalEventRequest toRequest() {
    return CreatePersonalEventRequest(
      title: title,
      day: day,
      startsAt: startsAt,
      endsAt: endsAt,
      category: category,
      location: location,
      notes: notes,
      notificationsEnabled: notificationsEnabled,
      reminderMinutesBefore: reminderMinutesBefore,
    );
  }
}

class CreatePersonalEventRequest {
  const CreatePersonalEventRequest({
    required this.title,
    required this.day,
    required this.startsAt,
    required this.endsAt,
    required this.category,
    this.location,
    this.notes,
    this.notificationsEnabled = false,
    this.reminderMinutesBefore = ReminderDelays.eventDefault,
  });

  final String title;
  final DateTime day;
  final String startsAt;
  final String endsAt;
  final String category;
  final String? location;
  final String? notes;
  final bool notificationsEnabled;
  final int reminderMinutesBefore;

  Map<String, Object?> toJson() {
    return {
      'title': title.trim(),
      'day': _dateOnly(day),
      'startsAt': startsAt,
      'endsAt': endsAt,
      'category': category,
      'location': _cleanOptional(location),
      'notes': _cleanOptional(notes),
      'notificationsEnabled': notificationsEnabled,
      'reminderMinutesBefore': reminderMinutesBefore,
    };
  }

  static String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static String? _cleanOptional(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}

class CreateAgendaTaskRequest {
  const CreateAgendaTaskRequest({
    required this.title,
    required this.category,
    this.description,
    this.deadline,
    this.notificationsEnabled = false,
    this.reminderMinutesBefore = ReminderDelays.taskDefault,
  });

  final String title;
  final String category;
  final String? description;
  final DateTime? deadline;
  final bool notificationsEnabled;
  final int reminderMinutesBefore;

  Map<String, Object?> toJson() {
    return {
      'title': title,
      'description': description,
      'deadline': deadline?.toUtc().toIso8601String(),
      'category': category,
      'notificationsEnabled': notificationsEnabled,
      'courseId': null,
      'reminderMinutesBefore': reminderMinutesBefore,
    };
  }
}

class AgendaSummary {
  const AgendaSummary({
    required this.homework,
    required this.tasks,
    required this.events,
  });

  final List<HomeworkItem> homework;
  final List<AgendaTaskItem> tasks;
  final List<PersonalEventItem> events;
}

/// Délais de rappel par défaut, en minutes (alignés sur le serveur).
abstract final class ReminderDelays {
  static const homeworkDefault = 24 * 60;
  static const taskDefault = 24 * 60;
  static const eventDefault = 60;
  static const max = 30 * 24 * 60;
}
