import 'package:flutter/material.dart';

/// Palette StudyFlow : pétrole, menthe, ciel et rose.
///
/// Le pétrole sert aux actions et aux titres, pas aux grandes surfaces : les
/// fonds restent neutres (gris très clair, ou anthracite en mode sombre) pour
/// que les accents ressortent et que l'écran respire.
abstract final class AppColors {
  static const Color petrol = Color(0xFF073B4C);
  static const Color petrolDark = Color(0xFF052D3A);
  static const Color muted = Color(0xFF55676F);
  static const Color line = Color(0xFFE1E8EC);
  static const Color mint = Color(0xFF84DCCF);
  static const Color sky = Color(0xFFA6D9F7);
  static const Color blueGray = Color(0xFFBCCCE0);
  static const Color rose = Color(0xFFBF98A0);
  static const Color roseSoft = Color(0xFFF7EEF0);
  static const Color primarySoft = Color(0xFFE3EFF4);
  static const Color green = Color(0xFF347F76);
  static const Color greenSoft = Color(0xFFE3F5F2);
  static const Color sandSoft = Color(0xFFEAF5FC);
  static const Color background = Color(0xFFF4F7F9);
  static const Color ink = Color(0xFF14272E);
  static const Color danger = Color(0xFFB4485A);

  // Mode sombre : surfaces anthracite légèrement teintées, jamais bleu pétrole plein.
  static const Color darkBackground = Color(0xFF0F1416);
  static const Color darkSurface = Color(0xFF182023);
  static const Color darkSurfaceHigh = Color(0xFF212B2F);
  static const Color darkLine = Color(0xFF2C383D);
  static const Color darkText = Color(0xFFEAF0F2);
  static const Color darkMuted = Color(0xFF9DAEB4);

  /// Ce qui est partagé avec toute la classe (cours, devoirs, annonces).
  static const Color shared = Color(0xFF2F6F8A);
  static const Color sharedSoft = Color(0xFFE4F1F7);

  /// Ce qui n'est visible que par l'élève (tâches et événements perso).
  static const Color personal = green;
  static const Color personalSoft = greenSoft;

  /// Évaluations (devoirs notés, partiels) : ambre, distinct du bleu « classe »
  /// et du vert « perso ».
  static const Color evaluation = Color(0xFFB0701A);
  static const Color evaluationSoft = Color(0xFFFCF2E3);
  static const Color evaluationLight = Color(0xFFF2C27D);
}

extension StudyFlowThemeColors on BuildContext {
  bool get sfIsDark => Theme.of(this).brightness == Brightness.dark;

  Color get sfText => sfIsDark ? AppColors.darkText : AppColors.ink;

  Color get sfMuted => sfIsDark ? AppColors.darkMuted : AppColors.muted;

  Color get sfSubtle =>
      sfIsDark ? AppColors.darkMuted.withValues(alpha: 0.8) : AppColors.muted;

  Color get sfCard => sfIsDark ? AppColors.darkSurface : Colors.white;

  Color get sfSoftCard =>
      sfIsDark ? AppColors.darkSurfaceHigh : AppColors.background;

  Color get sfLine => sfIsDark ? AppColors.darkLine : AppColors.line;

  Color get sfIcon => sfIsDark ? AppColors.darkText : AppColors.petrol;

  Color get sfChevron => sfIsDark ? AppColors.darkMuted : AppColors.muted;

  /// Couleur d'action principale : pétrole en clair, menthe en sombre.
  Color get sfAccent => sfIsDark ? AppColors.mint : AppColors.petrol;

  /// Texte posé sur [sfAccent].
  Color get sfOnAccent => sfIsDark ? AppColors.petrolDark : Colors.white;

  Color get sfShared => sfIsDark ? AppColors.sky : AppColors.shared;

  Color get sfSharedSoft =>
      sfIsDark ? AppColors.sky.withValues(alpha: 0.12) : AppColors.sharedSoft;

  Color get sfPersonal => sfIsDark ? AppColors.mint : AppColors.personal;

  Color get sfPersonalSoft => sfIsDark
      ? AppColors.mint.withValues(alpha: 0.12)
      : AppColors.personalSoft;

  Color get sfEvaluation =>
      sfIsDark ? AppColors.evaluationLight : AppColors.evaluation;

  Color get sfEvaluationSoft => sfIsDark
      ? AppColors.evaluationLight.withValues(alpha: 0.13)
      : AppColors.evaluationSoft;
}
