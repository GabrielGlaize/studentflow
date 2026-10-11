import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:studyflow_app/core/settings/quiet_hours.dart';

/// Stores user-facing application preferences.
///
/// Settings are persisted locally so the app remembers important choices like
/// theme and company mode after a restart.
class AppSettingsController extends ChangeNotifier {
  AppSettingsController({required AppSettingsStorage storage})
    : _storage = storage;

  final AppSettingsStorage _storage;

  ThemeMode _themeMode = ThemeMode.system;
  bool _hasCompany = false;
  String? _companyName;
  bool _courseNotificationsEnabled = true;
  bool _homeworkNotificationsEnabled = true;
  bool _apprenticeshipNotificationsEnabled = true;
  int _courseReminderMinutes = 5;
  QuietHours _quietHours = const QuietHours();
  bool _dailyNotesEnabled = true;
  bool _dailyNoteReminderEnabled = true;
  int _dailyNoteReminderMinutes = 19 * 60;
  bool _tutorialPending = false;
  bool _scheduleWeekView = true;
  DateTime? _appPreferencesUpdatedAt;

  ThemeMode get themeMode => _themeMode;
  bool get hasCompany => _hasCompany;
  String? get companyName => _companyName;
  bool get courseNotificationsEnabled => _courseNotificationsEnabled;
  bool get homeworkNotificationsEnabled => _homeworkNotificationsEnabled;
  bool get apprenticeshipNotificationsEnabled =>
      _apprenticeshipNotificationsEnabled;
  int get courseReminderMinutes => _courseReminderMinutes;
  QuietHours get quietHours => _quietHours;

  /// Coin note de l'accueil (facultatif, propre à ce téléphone).
  bool get dailyNotesEnabled => _dailyNotesEnabled;

  /// Rappel du soir pour relire la note du jour.
  bool get dailyNoteReminderEnabled =>
      _dailyNotesEnabled && _dailyNoteReminderEnabled;

  /// Planning ouvert en vue semaine (par défaut) ou jour : le dernier choix.
  bool get scheduleWeekView => _scheduleWeekView;

  /// Dernière modification du thème ou de l'entreprise, sur ce téléphone ou
  /// reprise du serveur : la plus récente des deux versions l'emporte.
  DateTime? get appPreferencesUpdatedAt => _appPreferencesUpdatedAt;

  /// Présentation à montrer (compte tout juste créé sur ce téléphone).
  bool get tutorialPending => _tutorialPending;

  void requestTutorial() {
    if (_tutorialPending) return;
    _tutorialPending = true;
    _save();
    notifyListeners();
  }

  void completeTutorial() {
    if (!_tutorialPending) return;
    _tutorialPending = false;
    _save();
    notifyListeners();
  }

  /// Heure du rappel du soir, en minutes depuis minuit.
  int get dailyNoteReminderMinutes => _dailyNoteReminderMinutes;
  AppSettings get currentSettings => _currentSettings();

  Future<void> restore() async {
    final settings = await _storage.read();
    if (settings == null) return;

    _themeMode = settings.themeMode;
    _hasCompany = settings.hasCompany;
    _companyName = settings.companyName;
    _courseNotificationsEnabled = settings.courseNotificationsEnabled;
    _homeworkNotificationsEnabled = settings.homeworkNotificationsEnabled;
    _apprenticeshipNotificationsEnabled =
        settings.apprenticeshipNotificationsEnabled;
    _courseReminderMinutes = settings.courseReminderMinutes;
    _quietHours = settings.quietHours;
    _dailyNotesEnabled = settings.dailyNotesEnabled;
    _dailyNoteReminderEnabled = settings.dailyNoteReminderEnabled;
    _dailyNoteReminderMinutes = settings.dailyNoteReminderMinutes;
    _tutorialPending = _tutorialPending || settings.tutorialPending;
    _scheduleWeekView = settings.scheduleWeekView;
    _appPreferencesUpdatedAt = settings.appPreferencesUpdatedAt;
    notifyListeners();
  }

  void setScheduleWeekView(bool value) {
    if (_scheduleWeekView == value) return;

    _scheduleWeekView = value;
    _save();
    notifyListeners();
  }

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) return;

    _themeMode = value;
    _touchAppPreferences();
    _save();
    notifyListeners();
  }

  void setHasCompany(bool value) {
    if (_hasCompany == value) return;

    _hasCompany = value;
    if (!value) _companyName = null;
    _touchAppPreferences();
    _save();
    notifyListeners();
  }

  /// Réglages repris du serveur, plus récents que ceux du téléphone.
  void applyAppPreferences({
    required ThemeMode themeMode,
    required bool hasCompany,
    String? companyName,
    DateTime? updatedAt,
  }) {
    _themeMode = themeMode;
    _hasCompany = hasCompany;
    _companyName = hasCompany ? _cleanOptional(companyName) : null;
    _appPreferencesUpdatedAt = updatedAt ?? _appPreferencesUpdatedAt;
    _save();
    notifyListeners();
  }

  /// Le serveur a enregistré les réglages : son horodatage devient la référence.
  void markAppPreferencesSynced(DateTime? updatedAt) {
    if (updatedAt == null || updatedAt == _appPreferencesUpdatedAt) return;
    _appPreferencesUpdatedAt = updatedAt;
    _save();
  }

  void _touchAppPreferences() {
    _appPreferencesUpdatedAt = DateTime.now().toUtc();
  }

  void setCompanyName(String? value) {
    final cleanedValue = _cleanOptional(value);
    if (_companyName == cleanedValue) return;

    _companyName = cleanedValue;
    _touchAppPreferences();
    _save();
    notifyListeners();
  }

  void setCourseNotificationsEnabled(bool value) {
    if (_courseNotificationsEnabled == value) return;

    _courseNotificationsEnabled = value;
    _save();
    notifyListeners();
  }

  void setHomeworkNotificationsEnabled(bool value) {
    if (_homeworkNotificationsEnabled == value) return;

    _homeworkNotificationsEnabled = value;
    _save();
    notifyListeners();
  }

  void setApprenticeshipNotificationsEnabled(bool value) {
    if (_apprenticeshipNotificationsEnabled == value) return;

    _apprenticeshipNotificationsEnabled = value;
    _save();
    notifyListeners();
  }

  void setCourseReminderMinutes(int value) {
    if (_courseReminderMinutes == value) return;

    _courseReminderMinutes = value;
    _save();
    notifyListeners();
  }

  void setDailyNotesEnabled(bool value) {
    if (_dailyNotesEnabled == value) return;

    _dailyNotesEnabled = value;
    _save();
    notifyListeners();
  }

  void setDailyNoteReminderEnabled(bool value) {
    if (_dailyNoteReminderEnabled == value) return;

    _dailyNoteReminderEnabled = value;
    _save();
    notifyListeners();
  }

  void setDailyNoteReminderMinutes(int value) {
    if (_dailyNoteReminderMinutes == value) return;

    _dailyNoteReminderMinutes = value;
    _save();
    notifyListeners();
  }

  void setQuietHours(QuietHours value) {
    if (_quietHours == value) return;

    _quietHours = value;
    _save();
    notifyListeners();
  }

  void applyNotificationPreferences({
    required bool coursesEnabled,
    required bool homeworkEnabled,
    required bool apprenticeshipsEnabled,
    required int courseReminderMinutes,
    QuietHours? quietHours,
  }) {
    _courseNotificationsEnabled = coursesEnabled;
    _homeworkNotificationsEnabled = homeworkEnabled;
    _apprenticeshipNotificationsEnabled = apprenticeshipsEnabled;
    _courseReminderMinutes = courseReminderMinutes;
    if (quietHours != null) _quietHours = quietHours;
    _save();
    notifyListeners();
  }

  void _save() {
    unawaited(_storage.save(_currentSettings()));
  }

  AppSettings _currentSettings() {
    return AppSettings(
      themeMode: _themeMode,
      hasCompany: _hasCompany,
      companyName: _companyName,
      courseNotificationsEnabled: _courseNotificationsEnabled,
      homeworkNotificationsEnabled: _homeworkNotificationsEnabled,
      apprenticeshipNotificationsEnabled: _apprenticeshipNotificationsEnabled,
      courseReminderMinutes: _courseReminderMinutes,
      quietHours: _quietHours,
      dailyNotesEnabled: _dailyNotesEnabled,
      dailyNoteReminderEnabled: _dailyNoteReminderEnabled,
      dailyNoteReminderMinutes: _dailyNoteReminderMinutes,
      tutorialPending: _tutorialPending,
      scheduleWeekView: _scheduleWeekView,
      appPreferencesUpdatedAt: _appPreferencesUpdatedAt,
    );
  }

  String? _cleanOptional(String? value) {
    final cleanedValue = value?.trim();
    return cleanedValue == null || cleanedValue.isEmpty ? null : cleanedValue;
  }
}

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.hasCompany,
    this.companyName,
    required this.courseNotificationsEnabled,
    required this.homeworkNotificationsEnabled,
    this.apprenticeshipNotificationsEnabled = true,
    this.courseReminderMinutes = 5,
    this.quietHours = const QuietHours(),
    this.dailyNotesEnabled = true,
    this.dailyNoteReminderEnabled = true,
    this.dailyNoteReminderMinutes = 19 * 60,
    this.tutorialPending = false,
    this.scheduleWeekView = true,
    this.appPreferencesUpdatedAt,
  });

  final ThemeMode themeMode;
  final bool hasCompany;
  final String? companyName;
  final bool courseNotificationsEnabled;
  final bool homeworkNotificationsEnabled;
  final bool apprenticeshipNotificationsEnabled;
  final int courseReminderMinutes;
  final QuietHours quietHours;
  final bool dailyNotesEnabled;
  final bool dailyNoteReminderEnabled;
  final int dailyNoteReminderMinutes;
  final bool tutorialPending;
  final bool scheduleWeekView;
  final DateTime? appPreferencesUpdatedAt;

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      themeMode: _themeModeFromName(json['themeMode'] as String?),
      hasCompany: json['hasCompany'] as bool? ?? false,
      companyName: json['companyName'] as String?,
      courseNotificationsEnabled:
          json['courseNotificationsEnabled'] as bool? ?? true,
      homeworkNotificationsEnabled:
          json['homeworkNotificationsEnabled'] as bool? ?? true,
      apprenticeshipNotificationsEnabled:
          json['apprenticeshipNotificationsEnabled'] as bool? ?? true,
      courseReminderMinutes: json['courseReminderMinutes'] as int? ?? 5,
      quietHours: QuietHours.fromJson(json),
      dailyNotesEnabled: json['dailyNotesEnabled'] as bool? ?? true,
      dailyNoteReminderEnabled:
          json['dailyNoteReminderEnabled'] as bool? ?? true,
      dailyNoteReminderMinutes:
          (json['dailyNoteReminderMinutes'] as num?)?.toInt() ?? 19 * 60,
      tutorialPending: json['tutorialPending'] as bool? ?? false,
      scheduleWeekView: json['scheduleWeekView'] as bool? ?? true,
      appPreferencesUpdatedAt: DateTime.tryParse(
        json['appPreferencesUpdatedAt'] as String? ?? '',
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'themeMode': themeMode.name,
      'hasCompany': hasCompany,
      'companyName': companyName,
      'courseNotificationsEnabled': courseNotificationsEnabled,
      'homeworkNotificationsEnabled': homeworkNotificationsEnabled,
      'apprenticeshipNotificationsEnabled': apprenticeshipNotificationsEnabled,
      'courseReminderMinutes': courseReminderMinutes,
      ...quietHours.toJson(),
      'dailyNotesEnabled': dailyNotesEnabled,
      'dailyNoteReminderEnabled': dailyNoteReminderEnabled,
      'dailyNoteReminderMinutes': dailyNoteReminderMinutes,
      'tutorialPending': tutorialPending,
      'scheduleWeekView': scheduleWeekView,
      'appPreferencesUpdatedAt': appPreferencesUpdatedAt?.toIso8601String(),
    };
  }

  static ThemeMode _themeModeFromName(String? value) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }
}

abstract interface class AppSettingsStorage {
  Future<AppSettings?> read();

  Future<void> save(AppSettings settings);
}

class SecureAppSettingsStorage implements AppSettingsStorage {
  SecureAppSettingsStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _settingsKey = 'studyflow.settings';

  final FlutterSecureStorage _storage;

  @override
  Future<AppSettings?> read() async {
    final rawSettings = await _storage.read(key: _settingsKey);
    if (rawSettings == null) return null;

    final decoded = jsonDecode(rawSettings);
    if (decoded is! Map<String, Object?>) return null;

    return AppSettings.fromJson(decoded);
  }

  @override
  Future<void> save(AppSettings settings) {
    return _storage.write(
      key: _settingsKey,
      value: jsonEncode(settings.toJson()),
    );
  }
}

class MemoryAppSettingsStorage implements AppSettingsStorage {
  AppSettings? _settings;

  @override
  Future<AppSettings?> read() async => _settings;

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
  }
}
