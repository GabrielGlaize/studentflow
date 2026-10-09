/// Note libre d'une journée (une seule par jour).
class DailyNote {
  const DailyNote({
    required this.day,
    required this.text,
    required this.updatedAt,
    this.reviewedAt,
    this.pendingSync = false,
  });

  /// Jour seul, sans heure.
  final DateTime day;
  final String text;
  final DateTime updatedAt;

  /// Relue le soir (l'accueil arrête alors de la mettre en avant).
  final DateTime? reviewedAt;

  /// Modifiée sur ce téléphone et pas encore envoyée au serveur (hors
  /// connexion, par exemple). Une note vidée reste ainsi le temps d'effacer
  /// la version du serveur.
  final bool pendingSync;

  bool get isEmpty => text.trim().isEmpty;

  /// Première ligne non vide, pour l'historique et la notification du soir.
  String get preview {
    final line = text
        .split('\n')
        .map((x) => x.trim())
        .firstWhere((x) => x.isNotEmpty, orElse: () => '');
    return line.length <= 90 ? line : '${line.substring(0, 89)}…';
  }

  static DateTime dayOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DailyNote copyWith({
    String? text,
    DateTime? updatedAt,
    DateTime? reviewedAt,
    bool? pendingSync,
  }) {
    return DailyNote(
      day: day,
      text: text ?? this.text,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  factory DailyNote.fromJson(Map<String, Object?> json) {
    return DailyNote(
      day: dayOf(DateTime.parse(json['day'] as String)),
      text: json['text'] as String? ?? '',
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      reviewedAt: switch (json['reviewedAt']) {
        final String value => DateTime.parse(value),
        _ => null,
      },
      pendingSync: json['pendingSync'] as bool? ?? false,
    );
  }

  /// « 2026-10-10 » : le jour tel que l'API l'attend (`DateOnly`).
  String get dayKey {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${day.year}-${two(day.month)}-${two(day.day)}';
  }

  /// Copie locale (fichier du téléphone).
  Map<String, Object?> toJson() {
    return {
      'day': dayKey,
      'text': text,
      'updatedAt': updatedAt.toIso8601String(),
      'reviewedAt': reviewedAt?.toIso8601String(),
      'pendingSync': pendingSync,
    };
  }

  /// Corps envoyé à l'API (le jour est dans l'adresse).
  Map<String, Object?> toApiJson() {
    return {
      'text': text,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'reviewedAt': reviewedAt?.toUtc().toIso8601String(),
    };
  }
}
