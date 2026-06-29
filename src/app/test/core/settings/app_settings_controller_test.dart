import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/core/settings/app_settings_controller.dart';

void main() {
  test('restore recharge les réglages sauvegardés', () async {
    final storage = MemoryAppSettingsStorage();
    await storage.save(
      const AppSettings(
        themeMode: ThemeMode.dark,
        hasCompany: true,
        companyName: 'Atelier Numérique',
        courseNotificationsEnabled: false,
        homeworkNotificationsEnabled: true,
        apprenticeshipNotificationsEnabled: false,
        courseReminderMinutes: 15,
      ),
    );

    final controller = AppSettingsController(storage: storage);
    await controller.restore();

    expect(controller.themeMode, ThemeMode.dark);
    expect(controller.hasCompany, isTrue);
    expect(controller.companyName, 'Atelier Numérique');
    expect(controller.courseNotificationsEnabled, isFalse);
    expect(controller.homeworkNotificationsEnabled, isTrue);
    expect(controller.apprenticeshipNotificationsEnabled, isFalse);
    expect(controller.courseReminderMinutes, 15);
  });

  test('modifier un réglage le sauvegarde', () async {
    final storage = MemoryAppSettingsStorage();
    final controller = AppSettingsController(storage: storage);

    controller.setHasCompany(true);
    controller.setThemeMode(ThemeMode.light);

    final savedSettings = await storage.read();
    expect(savedSettings?.hasCompany, isTrue);
    expect(savedSettings?.themeMode, ThemeMode.light);
  });

  test('appliquer les préférences notifications les sauvegarde', () async {
    final storage = MemoryAppSettingsStorage();
    final controller = AppSettingsController(storage: storage);

    controller.applyNotificationPreferences(
      coursesEnabled: false,
      homeworkEnabled: true,
      apprenticeshipsEnabled: false,
      courseReminderMinutes: 30,
    );

    final savedSettings = await storage.read();
    expect(savedSettings?.courseNotificationsEnabled, isFalse);
    expect(savedSettings?.homeworkNotificationsEnabled, isTrue);
    expect(savedSettings?.apprenticeshipNotificationsEnabled, isFalse);
    expect(savedSettings?.courseReminderMinutes, 30);
  });

  test('appliquer les préférences application les sauvegarde', () async {
    final storage = MemoryAppSettingsStorage();
    final controller = AppSettingsController(storage: storage);

    controller.applyAppPreferences(themeMode: ThemeMode.dark, hasCompany: true);
    controller.setCompanyName(' Atelier Numérique ');

    final savedSettings = await storage.read();
    expect(savedSettings?.themeMode, ThemeMode.dark);
    expect(savedSettings?.hasCompany, isTrue);
    expect(savedSettings?.companyName, 'Atelier Numérique');
  });
}
