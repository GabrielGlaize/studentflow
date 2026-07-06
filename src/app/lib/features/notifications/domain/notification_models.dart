/// Describes a reminder computed by the app before it is sent to the device.
///
/// The MVP keeps this model independent from iOS/Android plugins. This makes
/// the reminder logic testable now, and allows us to replace the in-memory
/// scheduler with a native notification adapter later.
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.sourceId,
  });

  final String id;
  final ReminderType type;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String sourceId;
}

enum ReminderType { course, homework }
