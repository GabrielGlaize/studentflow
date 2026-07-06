import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/features/profile/domain/app_preferences.dart';

void main() {
  test('RemoteAppPreferences lit et écrit le JSON API', () {
    final preferences = RemoteAppPreferences.fromJson({
      'theme': 'dark',
      'hasCompany': true,
      'companyName': 'Atelier Numérique',
      'professionalMode': 'company',
    });

    expect(preferences.themeMode, ThemeMode.dark);
    expect(preferences.hasCompany, isTrue);
    expect(preferences.companyName, 'Atelier Numérique');
    expect(preferences.professionalMode, ProfessionalMode.company);
    expect(preferences.toJson(), {
      'theme': 'dark',
      'hasCompany': true,
      'companyName': 'Atelier Numérique',
      'professionalMode': 'company',
    });
  });
}
