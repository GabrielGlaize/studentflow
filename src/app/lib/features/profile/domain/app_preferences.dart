import 'package:flutter/material.dart';

class RemoteAppPreferences {
  const RemoteAppPreferences({
    required this.themeMode,
    required this.hasCompany,
    this.companyName,
    this.professionalMode = ProfessionalMode.apprenticeship,
  });

  final ThemeMode themeMode;
  final bool hasCompany;
  final String? companyName;
  final ProfessionalMode professionalMode;

  factory RemoteAppPreferences.fromJson(Map<String, Object?> json) {
    return RemoteAppPreferences(
      themeMode: _themeModeFromApi(json['theme'] as String?),
      hasCompany: json['hasCompany'] as bool? ?? false,
      companyName: json['companyName'] as String?,
      professionalMode: _professionalModeFromApi(
        json['professionalMode'] as String?,
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'theme': themeMode.name,
      'hasCompany': hasCompany,
      'companyName': companyName,
      'professionalMode': professionalMode.name,
    };
  }

  static ThemeMode _themeModeFromApi(String? value) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }

  static ProfessionalMode _professionalModeFromApi(String? value) {
    return ProfessionalMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ProfessionalMode.apprenticeship,
    );
  }
}

enum ProfessionalMode { apprenticeship, company }
