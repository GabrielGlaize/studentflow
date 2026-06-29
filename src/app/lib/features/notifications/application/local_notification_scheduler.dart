import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:studyflow_app/features/notifications/domain/notification_models.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

/// Contract used by the UI to register reminders.
///
/// Today, [MemoryLocalNotificationScheduler] only stores reminders so students
/// can verify the planning logic. Later, a native implementation can delegate
/// to `flutter_local_notifications` or push tokens without changing callers.
abstract interface class LocalNotificationScheduler implements Listenable {
  List<ScheduledReminder> get scheduledReminders;

  Future<void> replaceAll(List<ScheduledReminder> reminders);
}

class MemoryLocalNotificationScheduler extends ChangeNotifier
    implements LocalNotificationScheduler {
  final List<ScheduledReminder> _scheduledReminders = [];

  @override
  List<ScheduledReminder> get scheduledReminders =>
      List.unmodifiable(_scheduledReminders);

  @override
  Future<void> replaceAll(List<ScheduledReminder> reminders) async {
    _scheduledReminders
      ..clear()
      ..addAll(
        reminders.toList()..sort(
          (left, right) => left.scheduledAt.compareTo(right.scheduledAt),
        ),
      );
    notifyListeners();
  }
}

class NativeLocalNotificationScheduler extends ChangeNotifier
    implements LocalNotificationScheduler {
  NativeLocalNotificationScheduler({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  }) : _notificationsPlugin =
           notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'studyflow_reminders';
  static const _channelName = 'Rappels StudyFlow';
  static const _channelDescription =
      'Notifications avant les cours et les devoirs importants.';

  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final List<ScheduledReminder> _scheduledReminders = [];
  bool _isInitialized = false;

  @override
  List<ScheduledReminder> get scheduledReminders =>
      List.unmodifiable(_scheduledReminders);

  @override
  Future<void> replaceAll(List<ScheduledReminder> reminders) async {
    _scheduledReminders
      ..clear()
      ..addAll(
        reminders.toList()..sort(
          (left, right) => left.scheduledAt.compareTo(right.scheduledAt),
        ),
      );
    notifyListeners();

    if (kIsWeb) return;

    try {
      await _ensureInitialized();
      await _notificationsPlugin.cancelAll();

      for (final reminder in _scheduledReminders) {
        if (!reminder.scheduledAt.isAfter(DateTime.now())) continue;
        await _notificationsPlugin.zonedSchedule(
          id: _notificationId(reminder.id),
          title: reminder.title,
          body: reminder.body,
          scheduledDate: timezone.TZDateTime.from(
            reminder.scheduledAt,
            timezone.local,
          ),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } on Object {
      // The in-memory list remains the source of truth if native permissions or
      // platform channels are unavailable, for example during widget tests.
    }
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    timezone_data.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _notificationsPlugin.initialize(settings: settings);
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _isInitialized = true;
  }

  int _notificationId(String value) {
    return value.codeUnits.fold<int>(
      0,
      (hash, unit) => (hash * 31 + unit) & 0x7fffffff,
    );
  }
}
