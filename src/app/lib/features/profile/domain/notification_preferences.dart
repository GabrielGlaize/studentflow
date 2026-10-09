import 'package:studyflow_app/core/settings/quiet_hours.dart';

class NotificationPreferences {
  const NotificationPreferences({
    required this.coursesEnabled,
    required this.homeworkEnabled,
    required this.apprenticeshipsEnabled,
    required this.courseReminderMinutes,
    this.quietHours = const QuietHours(),
  });

  final bool coursesEnabled;
  final bool homeworkEnabled;
  final bool apprenticeshipsEnabled;
  final int courseReminderMinutes;
  final QuietHours quietHours;

  factory NotificationPreferences.fromJson(Map<String, Object?> json) {
    return NotificationPreferences(
      coursesEnabled: json['coursesEnabled'] as bool? ?? true,
      homeworkEnabled: json['homeworkEnabled'] as bool? ?? true,
      apprenticeshipsEnabled: json['apprenticeshipsEnabled'] as bool? ?? true,
      courseReminderMinutes: json['courseReminderMinutes'] as int? ?? 5,
      quietHours: QuietHours.fromJson(json),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'coursesEnabled': coursesEnabled,
      'homeworkEnabled': homeworkEnabled,
      'apprenticeshipsEnabled': apprenticeshipsEnabled,
      'courseReminderMinutes': courseReminderMinutes,
      ...quietHours.toJson(),
      // Pour l'API, une pause absente veut dire « inchangée » : un instant
      // passé l'arrête explicitement.
      'mutedUntil':
          quietHours.mutedUntil?.toUtc().toIso8601String() ??
          DateTime.utc(1970).toIso8601String(),
    };
  }
}
