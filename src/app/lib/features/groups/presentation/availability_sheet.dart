import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';
import 'package:studyflow_app/features/groups/domain/group_models.dart';

/// Mes disponibilités pour les créneaux communs, réglées une fois pour toutes.
/// Les jours de cours viennent du planning de la classe ; un jour de semaine
/// sans cours est un jour en entreprise.
class AvailabilitySheet extends StatefulWidget {
  const AvailabilitySheet({super.key});

  /// Vrai si l'élève a enregistré ses disponibilités.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const AvailabilitySheet(),
    );
  }

  @override
  State<AvailabilitySheet> createState() => _AvailabilitySheetState();
}

class _AvailabilitySheetState extends State<AvailabilitySheet> {
  GroupAvailability? _value;
  bool _saving = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_value == null) _load();
  }

  Future<void> _load() async {
    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final value = await appScope.groupRepository.getAvailability(
        accessToken: accessToken,
      );
      if (mounted) setState(() => _value = value);
    } on Exception {
      if (mounted) setState(() => _value = GroupAvailability.defaults);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: value == null
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ProtoSectionHeading(
                    overline: 'Créneaux communs',
                    title: 'Mes disponibilités',
                  ),
                  const SizedBox(height: 6),
                  const ProtoMutedText(
                    'Les jours de cours, Swikko suit le planning de la classe. '
                    'Un jour de semaine sans cours, tu es en entreprise : '
                    'tu n’es libre qu’après le travail et le trajet.',
                  ),
                  const SizedBox(height: 16),
                  ProtoPickerField(
                    keyValue: 'availability-company-end',
                    icon: Icons.work_outline,
                    label: 'En entreprise, je finis vers',
                    value: _format(value.companyEndsAt),
                    onTap: () => _pickTime(
                      value.companyEndsAt,
                      'Fin de journée en entreprise',
                      (time) => value.copyWith(companyEndsAt: time),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ProtoPickerField(
                    keyValue: 'availability-until',
                    icon: Icons.nightlight_outlined,
                    label: 'Le soir, dispo jusqu’à',
                    value: _format(value.availableUntil),
                    onTap: () => _pickTime(
                      value.availableUntil,
                      'Fin des réunions le soir',
                      (time) => value.copyWith(availableUntil: time),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    key: const ValueKey('availability-weekend'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Dispo le week-end'),
                    subtitle: const Text('En visio, à partir de 10 h'),
                    value: value.weekendAvailable,
                    onChanged: (weekend) => setState(
                      () => _value = value.copyWith(weekendAvailable: weekend),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tenir compte de mon agenda perso'),
                    subtitle: const Text(
                      'Le groupe voit seulement « occupé », jamais le détail.',
                    ),
                    value: value.usePersonalAgenda,
                    onChanged: (use) => setState(
                      () => _value = value.copyWith(usePersonalAgenda: use),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const ValueKey('availability-save'),
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _pickTime(
    ({int hour, int minute}) current,
    String title,
    GroupAvailability Function(({int hour, int minute})) apply,
  ) async {
    final picked = await StudyFlowPickers.pickTime(
      context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      title: title,
    );
    if (picked == null || !mounted) return;
    setState(() => _value = apply((hour: picked.hour, minute: picked.minute)));
  }

  Future<void> _save() async {
    final value = _value;
    if (value == null) return;
    final appScope = AppScope.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.groupRepository.saveAvailability(
        availability: value,
        accessToken: accessToken,
      );
      navigator.pop(true);
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$error';
        });
      }
    }
  }

  static String _format(({int hour, int minute}) time) =>
      StudyFlowFormat.time(TimeOfDay(hour: time.hour, minute: time.minute));
}
