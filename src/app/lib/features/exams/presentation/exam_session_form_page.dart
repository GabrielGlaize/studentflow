import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';
import 'package:studyflow_app/features/classes/presentation/class_resources_page.dart';
import 'package:studyflow_app/features/exams/domain/exam_models.dart';

/// Formulaire des délégués : dates des partiels et matières concernées.
class ExamSessionFormPage extends StatefulWidget {
  const ExamSessionFormPage({this.session, super.key});

  final ExamSession? session;

  /// Renvoie les partiels enregistrés, ou null (fermé ou supprimés).
  static Future<ExamSession?> open(
    BuildContext context, {
    ExamSession? session,
  }) {
    return Navigator.of(context).push<ExamSession>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ExamSessionFormPage(session: session),
      ),
    );
  }

  @override
  State<ExamSessionFormPage> createState() => _ExamSessionFormPageState();
}

class _SubjectChoice {
  _SubjectChoice({
    required this.name,
    this.examDay,
    this.startsAt,
    String? details,
  }) : details = TextEditingController(text: details ?? '');

  final String name;
  DateTime? examDay;
  String? startsAt;
  final TextEditingController details;
}

class _ExamSessionFormPageState extends State<ExamSessionFormPage> {
  late final TextEditingController _title;
  late DateTime _startsOn;
  late DateTime _endsOn;
  final Map<String, _SubjectChoice> _chosen = {};
  Future<ClassResources>? _resources;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.session != null;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    final today = DateUtils.dateOnly(DateTime.now());
    _title = TextEditingController(
      text: session?.title ?? 'Partiels du semestre',
    );
    _startsOn = session?.startsOn ?? StudyFlowDates.addDays(today, 21);
    _endsOn = session?.endsOn ?? StudyFlowDates.addDays(_startsOn, 4);
    for (final subject in session?.subjects ?? const <ExamSubjectSummary>[]) {
      _chosen[subject.subjectId] = _SubjectChoice(
        name: subject.name,
        examDay: subject.examDay,
        startsAt: subject.startsAt,
        details: subject.details,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resources ??= ClassResources.load(context);
  }

  @override
  void dispose() {
    _title.dispose();
    for (final choice in _chosen.values) {
      choice.details.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opensOn = StudyFlowDates.addDays(_startsOn, -14);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Modifier les partiels' : 'Préparer les partiels',
        ),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Supprimer les partiels',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: FutureBuilder<ClassResources>(
        future: _resources,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const ProtoPageLoader(label: 'Matières de la classe');
          }
          final resources = snapshot.data;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              const ProtoVisibilityBanner(shared: true),
              const SizedBox(height: 20),
              const ProtoFormLabel('Nom'),
              TextField(
                key: const ValueKey('exam-title-field'),
                controller: _title,
                maxLength: 80,
                decoration: const InputDecoration(
                  hintText: 'Partiels du semestre 1',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 20),
              const ProtoFormLabel('Dates'),
              Row(
                children: [
                  Expanded(
                    child: ProtoPickerField(
                      keyValue: 'exam-start-field',
                      icon: Icons.event_outlined,
                      label: 'Première épreuve',
                      value: StudyFlowFormat.shortDay(_startsOn),
                      onTap: () => _pickPeriod(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ProtoPickerField(
                      icon: Icons.event,
                      label: 'Dernière épreuve',
                      value: StudyFlowFormat.shortDay(_endsOn),
                      onTap: () => _pickPeriod(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ProtoMutedText(
                'La fiche de révision s’ouvrira à toute la classe le ${StudyFlowFormat.longDay(opensOn).toLowerCase()}.',
              ),
              const SizedBox(height: 20),
              const ProtoFormLabel('Matières'),
              if (resources == null || resources.subjects.isEmpty)
                const ProtoMutedText(
                  'Ajoute d’abord les matières de la classe.',
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final subject in resources.subjects)
                      FilterChip(
                        key: ValueKey('exam-subject-chip-${subject.id}'),
                        label: Text(subject.name),
                        selected: _chosen.containsKey(subject.id),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _chosen[subject.id] = _SubjectChoice(
                              name: subject.name,
                            );
                          } else {
                            _chosen.remove(subject.id)?.details.dispose();
                          }
                        }),
                      ),
                  ],
                ),
              for (final entry in _chosen.entries) ...[
                const SizedBox(height: 12),
                _SubjectCard(
                  choice: entry.value,
                  onPickDay: () => _pickExamDay(entry.value),
                  onPickTime: () => _pickExamTime(entry.value),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: FilledButton(
          key: const ValueKey('exam-save-button'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
        ),
      ),
    );
  }

  Future<void> _pickPeriod({required bool isStart}) async {
    final picked = await StudyFlowPickers.pickDate(
      context,
      initialDate: isStart ? _startsOn : _endsOn,
      firstDate: isStart ? null : _startsOn,
      helpText: isStart ? 'Première épreuve' : 'Dernière épreuve',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        final length = _endsOn.difference(_startsOn).inDays;
        _startsOn = DateUtils.dateOnly(picked);
        _endsOn = StudyFlowDates.addDays(_startsOn, length < 0 ? 0 : length);
      } else {
        _endsOn = DateUtils.dateOnly(picked);
      }
    });
  }

  Future<void> _pickExamDay(_SubjectChoice choice) async {
    final picked = await StudyFlowPickers.pickDate(
      context,
      initialDate: choice.examDay ?? _startsOn,
      firstDate: _startsOn,
      lastDate: _endsOn,
      helpText: 'Jour de l’épreuve',
    );
    if (picked != null) {
      setState(() => choice.examDay = DateUtils.dateOnly(picked));
    }
  }

  Future<void> _pickExamTime(_SubjectChoice choice) async {
    final picked = await StudyFlowPickers.pickTime(
      context,
      initialTime:
          StudyFlowFormat.parseTime(choice.startsAt) ??
          const TimeOfDay(hour: 9, minute: 0),
      title: 'Heure de l’épreuve',
    );
    if (picked != null) {
      setState(() => choice.startsAt = StudyFlowFormat.time(picked));
    }
  }

  Future<void> _save() async {
    String? problem;
    if (_title.text.trim().isEmpty) {
      problem = 'Donne un nom aux partiels.';
    } else if (_endsOn.isBefore(_startsOn)) {
      problem = 'La dernière épreuve doit être après la première.';
    } else if (_chosen.isEmpty) {
      problem = 'Choisis au moins une matière.';
    } else if (_chosen.values.any(
      (x) =>
          x.examDay != null &&
          (x.examDay!.isBefore(_startsOn) || x.examDay!.isAfter(_endsOn)),
    )) {
      problem = 'Une épreuve est en dehors des dates des partiels.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    final draft = ExamSessionDraft(
      title: _title.text,
      startsOn: _startsOn,
      endsOn: _endsOn,
      subjects: [
        for (final entry in _chosen.entries)
          ExamSubjectDraft(
            subjectId: entry.key,
            name: entry.value.name,
            examDay: entry.value.examDay,
            startsAt: entry.value.startsAt,
            details: entry.value.details.text,
          ),
      ],
    );

    setState(() {
      _saving = true;
      _error = null;
    });
    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final session = widget.session;
      final saved = session == null
          ? await appScope.examRepository.createSession(
              draft: draft,
              accessToken: accessToken,
            )
          : await appScope.examRepository.updateSession(
              sessionId: session.id,
              draft: draft,
              accessToken: accessToken,
            );
      if (mounted) Navigator.pop(context, saved);
    } on Exception catch (error) {
      final text = error.toString();
      if (mounted) {
        setState(
          () => _error = text.startsWith('Bad state: ')
              ? text.substring(11)
              : text,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ces partiels ?'),
        content: const Text(
          'Les fiches de révision, points et ressources partagés seront effacés pour toute la classe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.examRepository.deleteSession(
      sessionId: widget.session!.id,
      accessToken: accessToken,
    );
    if (mounted) Navigator.pop(context);
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.choice,
    required this.onPickDay,
    required this.onPickTime,
  });

  final _SubjectChoice choice;
  final VoidCallback onPickDay;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            choice.name,
            style: TextStyle(
              color: context.sfText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ProtoPickerField(
                  icon: Icons.calendar_today_outlined,
                  label: 'Jour',
                  value: choice.examDay == null
                      ? 'À préciser'
                      : StudyFlowFormat.shortDay(choice.examDay!),
                  onTap: onPickDay,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ProtoPickerField(
                  icon: Icons.schedule_outlined,
                  label: 'Heure',
                  value: choice.startsAt ?? 'À préciser',
                  onTap: onPickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: choice.details,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: 'Format, durée, documents autorisés…',
              counterText: '',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
