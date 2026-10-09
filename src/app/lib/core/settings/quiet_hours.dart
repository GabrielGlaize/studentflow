/// « Ne pas déranger » : une plage calme quotidienne (22 h → 7 h par défaut)
/// et une pause ponctuelle (« pendant 2 heures », « jusqu'à demain »…).
///
/// Mêmes règles que le serveur : une notification prévue dans la plage calme
/// ou pendant la pause n'est pas envoyée.
class QuietHours {
  const QuietHours({
    this.enabled = false,
    this.startMinutes = 22 * 60,
    this.endMinutes = 7 * 60,
    this.mutedUntil,
  });

  final bool enabled;

  /// Minutes depuis minuit (heure locale).
  final int startMinutes;
  final int endMinutes;

  /// Pause en cours jusqu'à cet instant, ou `null`.
  final DateTime? mutedUntil;

  bool isMuted(DateTime now) =>
      mutedUntil != null && now.isBefore(mutedUntil!.toLocal());

  /// Vrai si une notification à cet instant (heure locale) dérangerait.
  /// La plage peut passer minuit (22 h → 7 h).
  bool isQuietAt(DateTime moment) {
    if (isMuted(moment)) return true;
    if (!enabled || startMinutes == endMinutes) return false;

    final local = moment.toLocal();
    final minutes = local.hour * 60 + local.minute;
    return startMinutes < endMinutes
        ? minutes >= startMinutes && minutes < endMinutes
        : minutes >= startMinutes || minutes < endMinutes;
  }

  QuietHours copyWith({
    bool? enabled,
    int? startMinutes,
    int? endMinutes,
    DateTime? mutedUntil,
    bool clearMute = false,
  }) {
    return QuietHours(
      enabled: enabled ?? this.enabled,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      mutedUntil: clearMute ? null : mutedUntil ?? this.mutedUntil,
    );
  }

  factory QuietHours.fromJson(Map<String, Object?> json) {
    return QuietHours(
      enabled: json['quietHoursEnabled'] as bool? ?? false,
      startMinutes: parseTime(json['quietHoursStart'] as String?) ?? 22 * 60,
      endMinutes: parseTime(json['quietHoursEnd'] as String?) ?? 7 * 60,
      mutedUntil: switch (json['mutedUntil']) {
        final String value => DateTime.tryParse(value),
        _ => null,
      },
    );
  }

  /// Format attendu par l'API (`TimeOnly`) : « 22:00:00 ».
  Map<String, Object?> toJson() {
    return {
      'quietHoursEnabled': enabled,
      'quietHoursStart': formatTime(startMinutes, withSeconds: true),
      'quietHoursEnd': formatTime(endMinutes, withSeconds: true),
      'mutedUntil': mutedUntil?.toUtc().toIso8601String(),
    };
  }

  /// « 22:00 » ou « 22:00:00 » → minutes depuis minuit.
  static int? parseTime(String? value) {
    final parts = value?.split(':');
    if (parts == null || parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  static String formatTime(int minutes, {bool withSeconds = false}) {
    String two(int value) => value.toString().padLeft(2, '0');
    final text = '${two(minutes ~/ 60)}:${two(minutes % 60)}';
    return withSeconds ? '$text:00' : text;
  }

  @override
  bool operator ==(Object other) =>
      other is QuietHours &&
      other.enabled == enabled &&
      other.startMinutes == startMinutes &&
      other.endMinutes == endMinutes &&
      other.mutedUntil == mutedUntil;

  @override
  int get hashCode =>
      Object.hash(enabled, startMinutes, endMinutes, mutedUntil);
}
