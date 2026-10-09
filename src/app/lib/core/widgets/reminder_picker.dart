import 'package:flutter/material.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';

/// Délais de rappel : choix rapides et libellés lisibles (« La veille »).
abstract final class ReminderFormat {
  static const _day = 24 * 60;
  static const maxMinutes = 30 * _day;

  /// Choix proposés, en minutes avant l'échéance ou le début.
  static const presets = <int>[0, 15, 60, 180, _day, 2 * _day, 7 * _day];

  /// « La veille », « 1 h avant », ou [atMoment] pour 0.
  static String label(int minutes, {String atMoment = 'Au moment même'}) {
    if (minutes <= 0) return atMoment;
    if (minutes == _day) return 'La veille';
    if (minutes == 7 * _day) return '1 semaine avant';
    if (minutes < _day) return '${StudyFlowFormat.duration(minutes)} avant';

    final days = minutes ~/ _day;
    final hours = minutes % _day ~/ 60;
    final dayLabel = days == 1 ? '1 jour' : '$days jours';
    return hours == 0 ? '$dayLabel avant' : '$dayLabel et $hours h avant';
  }

  /// Moment exact du rappel : « mar. 13/10 à 18:00 ».
  static String moment(DateTime at) =>
      '${StudyFlowFormat.shortDay(at)} à ${StudyFlowFormat.timeOf(at)}';

  /// « La veille · mar. 13/10 à 18:00 » quand l'échéance est connue.
  static String detailed(
    int minutes,
    DateTime? reference, {
    String atMoment = 'Au moment même',
  }) {
    final text = label(minutes, atMoment: atMoment);
    if (reference == null) return text;
    return '$text · ${moment(reference.subtract(Duration(minutes: minutes)))}';
  }
}

/// Ouvre le choix du délai. Renvoie le nombre de minutes avant [reference],
/// ou null si l'élève ferme sans choisir.
Future<int?> pickReminderDelay(
  BuildContext context, {
  required int current,
  DateTime? reference,
  String referenceLabel = 'Échéance',
  String atMoment = 'Au moment même',
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ReminderSheet(
      current: current,
      reference: reference,
      referenceLabel: referenceLabel,
      atMoment: atMoment,
    ),
  );
}

class _ReminderSheet extends StatelessWidget {
  const _ReminderSheet({
    required this.current,
    required this.reference,
    required this.referenceLabel,
    required this.atMoment,
  });

  final int current;
  final DateTime? reference;
  final String referenceLabel;
  final String atMoment;

  @override
  Widget build(BuildContext context) {
    final options = [
      if (!ReminderFormat.presets.contains(current)) current,
      ...ReminderFormat.presets,
    ];
    final now = DateTime.now();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Quand veux-tu le rappel ?',
              style: TextStyle(
                color: context.sfText,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (reference case final at?) ...[
              const SizedBox(height: 4),
              ProtoMutedText('$referenceLabel : ${ReminderFormat.moment(at)}'),
            ],
            const SizedBox(height: 12),
            for (final minutes in options)
              _ReminderOption(
                key: ValueKey('reminder-option-$minutes'),
                title: ReminderFormat.label(minutes, atMoment: atMoment),
                subtitle: reference == null
                    ? null
                    : ReminderFormat.moment(
                        reference!.subtract(Duration(minutes: minutes)),
                      ),
                selected: minutes == current,
                isPast:
                    reference != null &&
                    reference!
                        .subtract(Duration(minutes: minutes))
                        .isBefore(now),
                onTap: () => Navigator.pop(context, minutes),
              ),
            const SizedBox(height: 4),
            if (reference != null)
              OutlinedButton.icon(
                key: const ValueKey('reminder-custom'),
                onPressed: () => _pickCustom(context),
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: const Text('Choisir un autre moment'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustom(BuildContext context) async {
    final target = reference!;
    final now = DateTime.now();
    final suggested = target.subtract(Duration(minutes: current));
    final day = await StudyFlowPickers.pickDate(
      context,
      initialDate: suggested.isBefore(now) ? now : suggested,
      firstDate: DateUtils.dateOnly(now),
      lastDate: DateUtils.dateOnly(target),
      helpText: 'Jour du rappel',
    );
    if (day == null || !context.mounted) return;

    final time = await StudyFlowPickers.pickTime(
      context,
      initialTime: TimeOfDay.fromDateTime(suggested),
      title: 'Heure du rappel',
    );
    if (time == null || !context.mounted) return;

    final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    final minutes = target.difference(at).inMinutes;
    String? problem;
    if (minutes < 0) {
      problem = 'Choisis un moment avant ${referenceLabel.toLowerCase()}.';
    } else if (minutes > ReminderFormat.maxMinutes) {
      problem = 'Un rappel se programme au plus 30 jours avant.';
    } else if (at.isBefore(now)) {
      problem = 'Ce moment est déjà passé.';
    }

    if (problem != null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(problem)));
      return;
    }

    Navigator.pop(context, minutes);
  }
}

class _ReminderOption extends StatelessWidget {
  const _ReminderOption({
    required this.title,
    required this.selected,
    required this.isPast,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final bool isPast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.sfAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? accent.withValues(alpha: 0.1) : context.sfCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? accent : context.sfLine),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isPast ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isPast ? context.sfLine : accent,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isPast ? context.sfMuted : context.sfText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    isPast ? 'déjà passé' : subtitle!,
                    style: TextStyle(color: context.sfMuted, fontSize: 13),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bloc « Me le rappeler » des formulaires : un interrupteur, puis le moment
/// choisi (« La veille · mar. 13/10 à 18:00 ») modifiable d'un geste.
class ReminderSetting extends StatelessWidget {
  const ReminderSetting({
    required this.enabled,
    required this.minutesBefore,
    required this.onChanged,
    this.reference,
    this.referenceLabel = 'Échéance',
    this.atMoment = 'Au moment même',
    this.unavailableReason,
    super.key,
  });

  final bool enabled;
  final int minutesBefore;

  /// Échéance ou début de l'événement, pour afficher l'heure exacte.
  final DateTime? reference;
  final String referenceLabel;
  final String atMoment;

  /// Rappel impossible (par exemple sans échéance) : l'interrupteur est grisé.
  final String? unavailableReason;
  final void Function(bool enabled, int minutesBefore) onChanged;

  @override
  Widget build(BuildContext context) {
    final available = unavailableReason == null;
    final active = enabled && available;

    return ProtoCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(14, 2, 8, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            key: const ValueKey('reminder-switch'),
            contentPadding: const EdgeInsets.only(right: 6),
            value: active,
            onChanged: available
                ? (value) => onChanged(value, minutesBefore)
                : null,
            secondary: Icon(
              active
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              color: active ? context.sfAccent : context.sfMuted,
            ),
            title: const Text('Me le rappeler'),
            subtitle: Text(unavailableReason ?? (active ? 'Activé' : 'Non')),
          ),
          if (active) ...[
            Divider(height: 1, color: context.sfLine),
            InkWell(
              key: const ValueKey('reminder-when'),
              onTap: () async {
                final picked = await pickReminderDelay(
                  context,
                  current: minutesBefore,
                  reference: reference,
                  referenceLabel: referenceLabel,
                  atMoment: atMoment,
                );
                if (picked != null) onChanged(true, picked);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 6, 12),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 20, color: context.sfMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quand',
                            style: TextStyle(
                              color: context.sfMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ReminderFormat.detailed(
                              minutesBefore,
                              reference,
                              atMoment: atMoment,
                            ),
                            style: TextStyle(
                              color: context.sfText,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: context.sfChevron),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
