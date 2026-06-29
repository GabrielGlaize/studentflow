import 'package:flutter/material.dart';
import 'package:studyflow_app/features/profile/data/app_preferences_repository.dart';
import 'package:studyflow_app/features/profile/domain/app_preferences.dart';

class DemoAppPreferencesRepository implements AppPreferencesRepository {
  const DemoAppPreferencesRepository();

  static RemoteAppPreferences _preferences = const RemoteAppPreferences(
    themeMode: ThemeMode.system,
    hasCompany: false,
  );

  @override
  Future<RemoteAppPreferences> getPreferences({String? accessToken}) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return _preferences;
  }

  @override
  Future<RemoteAppPreferences> updatePreferences({
    required RemoteAppPreferences preferences,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _preferences = preferences;
    return _preferences;
  }
}
