import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  ThemeMode get themeMode => _themeMode;
  bool get hasCompany => _hasCompany;
  String? get companyName => _companyName;
  bool get courseNotificationsEnabled => _courseNotificationsEnabled;
  bool get homeworkNotificationsEnabled => _homeworkNotificationsEnabled;
  bool get apprenticeshipNotificationsEnabled =>
      _apprenticeshipNotificationsEnabled;
  int get courseReminderMinutes => _courseReminderMinutes;
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
    notifyListeners();
  }

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) return;

    _themeMode = value;
    _save();
    notifyListeners();
  }

  void setHasCompany(bool value) {
    if (_hasCompany == value) return;

    _hasCompany = value;
    if (!value) _companyName = null;
    _save();
    notifyListeners();
  }

  void applyAppPreferences({
    required ThemeMode themeMode,
    required bool hasCompany,
    String? companyName,
  }) {
    _themeMode = themeMode;
    _hasCompany = hasCompany;
    _companyName = hasCompany ? _cleanOptional(companyName) : null;
    _save();
    notifyListeners();
  }

  void setCompanyName(String? value) {
    final cleanedValue = _cleanOptional(value);
    if (_companyName == cleanedValue) return;

    _companyName = cleanedValue;
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

  void applyNotificationPreferences({
    required bool coursesEnabled,
    required bool homeworkEnabled,
    required bool apprenticeshipsEnabled,
    required int courseReminderMinutes,
  }) {
    _courseNotificationsEnabled = coursesEnabled;
    _homeworkNotificationsEnabled = homeworkEnabled;
    _apprenticeshipNotificationsEnabled = apprenticeshipsEnabled;
    _courseReminderMinutes = courseReminderMinutes;
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
  });

  final ThemeMode themeMode;
  final bool hasCompany;
  final String? companyName;
  final bool courseNotificationsEnabled;
  final bool homeworkNotificationsEnabled;
  final bool apprenticeshipNotificationsEnabled;
  final int courseReminderMinutes;

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
