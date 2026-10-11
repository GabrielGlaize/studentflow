import 'package:flutter/material.dart';

class RemoteAppPreferences {
  const RemoteAppPreferences({
    required this.themeMode,
    required this.hasCompany,
    this.companyName,
    this.professionalMode = ProfessionalMode.apprenticeship,
    this.updatedAt,
  });

  final ThemeMode themeMode;
  final bool hasCompany;
  final String? companyName;
  final ProfessionalMode professionalMode;

  /// Dernier enregistrement par l'élève ; nul si le serveur n'a que les valeurs
  /// par défaut (jamais enregistrées) : l'app garde alors ses propres réglages.
  final DateTime? updatedAt;

  factory RemoteAppPreferences.fromJson(Map<String, Object?> json) {
    return RemoteAppPreferences(
      themeMode: _themeModeFromApi(json['theme'] as String?),
      hasCompany: json['hasCompany'] as bool? ?? false,
      companyName: json['companyName'] as String?,
      professionalMode: _professionalModeFromApi(
        json['professionalMode'] as String?,
      ),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
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
