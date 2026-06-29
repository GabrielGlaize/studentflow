class HomeworkItem {
  const HomeworkItem({
    required this.id,
    required this.title,
    required this.deadline,
    required this.isDone,
    required this.notificationsEnabled,
    this.description,
    this.courseId,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime deadline;
  final String? courseId;
  final bool isDone;
  final bool notificationsEnabled;

  factory HomeworkItem.fromJson(Map<String, Object?> json) {
    return HomeworkItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      deadline: DateTime.parse(json['deadline'] as String),
      courseId: json['courseId'] as String?,
      isDone: json['isDone'] as bool? ?? false,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    );
  }

  CreateHomeworkRequest toRequest() {
    return CreateHomeworkRequest(
      title: title,
      description: description,
      deadline: deadline,
      courseId: courseId,
    );
  }
}

class CreateHomeworkRequest {
  const CreateHomeworkRequest({
    required this.title,
    required this.deadline,
    this.description,
    this.courseId,
  });

  final String title;
  final String? description;
  final DateTime deadline;
  final String? courseId;

  Map<String, Object?> toJson() {
    return {
      'title': title.trim(),
      'description': _cleanOptional(description),
      'deadline': deadline.toUtc().toIso8601String(),
      'courseId': courseId,
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
  });

  final String id;
  final String title;
  final String? description;
  final DateTime? deadline;
  final String category;
  final bool isDone;
  final bool notificationsEnabled;
  final String? courseId;

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
    };
  }

  AgendaTaskItem copyWith({bool? isDone}) {
    return AgendaTaskItem(
      id: id,
      title: title,
      description: description,
      deadline: deadline,
      category: category,
      isDone: isDone ?? this.isDone,
      notificationsEnabled: notificationsEnabled,
      courseId: courseId,
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
  });

  final String title;
  final DateTime day;
  final String startsAt;
  final String endsAt;
  final String category;
  final String? location;
  final String? notes;
  final bool notificationsEnabled;

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
  });

  final String title;
  final String category;
  final String? description;
  final DateTime? deadline;
  final bool notificationsEnabled;

  Map<String, Object?> toJson() {
    return {
      'title': title,
      'description': description,
      'deadline': deadline?.toUtc().toIso8601String(),
      'category': category,
      'notificationsEnabled': notificationsEnabled,
      'courseId': null,
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
