class NotificationPreferences {
  const NotificationPreferences({
    required this.coursesEnabled,
    required this.homeworkEnabled,
    required this.apprenticeshipsEnabled,
    required this.courseReminderMinutes,
  });

  final bool coursesEnabled;
  final bool homeworkEnabled;
  final bool apprenticeshipsEnabled;
  final int courseReminderMinutes;

  factory NotificationPreferences.fromJson(Map<String, Object?> json) {
    return NotificationPreferences(
      coursesEnabled: json['coursesEnabled'] as bool? ?? true,
      homeworkEnabled: json['homeworkEnabled'] as bool? ?? true,
      apprenticeshipsEnabled: json['apprenticeshipsEnabled'] as bool? ?? true,
      courseReminderMinutes: json['courseReminderMinutes'] as int? ?? 5,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'coursesEnabled': coursesEnabled,
      'homeworkEnabled': homeworkEnabled,
      'apprenticeshipsEnabled': apprenticeshipsEnabled,
      'courseReminderMinutes': courseReminderMinutes,
    };
  }
}
