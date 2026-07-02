import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color petrol = Color(0xFF073B4C);
  static const Color petrolDark = Color(0xFF052D3A);
  static const Color muted = Color(0xFF3F606C);
  static const Color line = Color(0xFFD7E3EA);
  static const Color mint = Color(0xFF84DCCF);
  static const Color sky = Color(0xFFA6D9F7);
  static const Color blueGray = Color(0xFFBCCCE0);
  static const Color rose = Color(0xFFBF98A0);
  static const Color roseSoft = Color(0xFFF5EDEF);
  static const Color primarySoft = Color(0xFFDFEEF3);
  static const Color green = Color(0xFF347F76);
  static const Color greenSoft = Color(0xFFE4F8F5);
  static const Color sandSoft = Color(0xFFE8F4FB);
  static const Color background = Color(0xFFF1F6F9);
}

extension StudyFlowThemeColors on BuildContext {
  bool get sfIsDark => Theme.of(this).brightness == Brightness.dark;

  Color get sfText => sfIsDark ? Colors.white : AppColors.petrol;

  Color get sfMuted =>
      sfIsDark ? Colors.white.withValues(alpha: 0.76) : AppColors.muted;

  Color get sfSubtle =>
      sfIsDark ? Colors.white.withValues(alpha: 0.56) : AppColors.muted;

  Color get sfCard => sfIsDark ? const Color(0xFF0A4658) : Colors.white;

  Color get sfSoftCard =>
      sfIsDark ? const Color(0xFF0E5163) : AppColors.background;

  Color get sfLine =>
      sfIsDark ? Colors.white.withValues(alpha: 0.16) : AppColors.line;

  Color get sfIcon =>
      sfIsDark ? Colors.white.withValues(alpha: 0.86) : AppColors.petrol;

  Color get sfChevron =>
      sfIsDark ? Colors.white.withValues(alpha: 0.70) : AppColors.muted;
}
