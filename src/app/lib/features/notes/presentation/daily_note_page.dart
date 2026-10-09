import 'dart:async';

import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/settings/quiet_hours.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';
import 'package:studyflow_app/features/notes/application/daily_notes_controller.dart';
import 'package:studyflow_app/features/notes/domain/daily_note.dart';
import 'package:studyflow_app/features/notes/presentation/numbered_text_editor.dart';
import 'package:studyflow_app/features/notifications/application/reminder_sync.dart';

/// Note du jour : on écrit au fil de la journée, l'enregistrement est
/// automatique. Les flèches et l'historique donnent accès aux jours passés.
class DailyNotePage extends StatefulWidget {
  const DailyNotePage({this.initialDay, super.key});

  final DateTime? initialDay;

  static Future<void> open(BuildContext context, {DateTime? day}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => DailyNotePage(initialDay: day),
      ),
    );
  }

  @override
  State<DailyNotePage> createState() => _DailyNotePageState();
}

class _DailyNotePageState extends State<DailyNotePage> {
  late DateTime _day;
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _saveTimer;
  bool _saved = true;
  late DailyNotesController _controller;
  late ReminderSync _reminderSync;
  bool _initialized = false;

  bool get _isToday => DateUtils.isSameDay(_day, DateTime.now());

  @override
  void initState() {
    super.initState();
    _day = DailyNote.dayOf(widget.initialDay ?? DateTime.now());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _controller = AppScope.of(context).dailyNotesController;
    _reminderSync = AppScope.of(context).reminderSync;
    _textController.text = _controller.noteFor(_day)?.text ?? '';
    // Après la première image : marquer « relue » prévient d'autres écrans.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _markReviewedIfEvening(),
    );
  }

  @override
  void dispose() {
    _flush(disposing: true);
    _saveTimer?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _load(DateTime day) {
    _flush();
    final note = _controller.noteFor(day);
    setState(() {
      _day = DailyNote.dayOf(day);
      _textController.text = note?.text ?? '';
      _saved = true;
    });
    _markReviewedIfEvening();
  }

  /// Ouverte le soir, la note du jour est considérée comme relue.
  void _markReviewedIfEvening() {
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    if (!mounted || !_isToday || minutes < _controller.reviewMinutes) return;
    _controller.markReviewed(_day, now: now);
    _reminderSync.requestSync();
  }

  void _onChanged(String _) {
    setState(() => _saved = false);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _flush);
  }

  void _flush({bool disposing = false}) {
    _saveTimer?.cancel();
    if (_saved || !_initialized) return;
    final hadNote = _controller.noteFor(_day)?.isEmpty == false;
    _controller.save(_day, _textController.text);
    final hasNote = _controller.noteFor(_day)?.isEmpty == false;
    _saved = true;
    if (!disposing && mounted) setState(() {});
    // Le rappel du soir n'existe que si la note du jour a du contenu.
    if (_isToday && hadNote != hasNote) _reminderSync.requestSync();
  }

  Future<void> _pickDay() async {
    final picked = await StudyFlowPickers.pickDate(
      context,
      initialDate: _day,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) _load(picked);
  }

  Future<void> _openHistory() async {
    _flush();
    final day = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => _HistorySheet(notes: _controller.history),
    );
    if (day != null && mounted) _load(day);
  }

  @override
  Widget build(BuildContext context) {
    final today = DailyNote.dayOf(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes du jour'),
        actions: [
          IconButton(
            tooltip: 'Choisir un jour',
            onPressed: _pickDay,
            icon: const Icon(Icons.calendar_today_outlined),
          ),
          IconButton(
            key: const ValueKey('daily-note-history'),
            tooltip: 'Historique',
            onPressed: _openHistory,
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Jour précédent',
                    onPressed: () => _load(StudyFlowDates.addDays(_day, -1)),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          _isToday
                              ? 'Aujourd’hui'
                              : _relativeLabel(_day, today),
                          style: TextStyle(
                            color: context.sfMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          StudyFlowFormat.longDay(_day),
                          style: TextStyle(
                            color: context.sfText,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Jour suivant',
                    onPressed: _day.isBefore(today)
                        ? () => _load(StudyFlowDates.addDays(_day, 1))
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                child: ProtoCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.fromLTRB(10, 14, 16, 14),
                  child: NumberedTextEditor(
                    fieldKey: const ValueKey('daily-note-field'),
                    controller: _textController,
                    focusNode: _focusNode,
                    autofocus: _isToday && _textController.text.isEmpty,
                    onChanged: _onChanged,
                    hintText: _isToday
                        ? 'Une idée, un truc à ne pas oublier, ce que le prof a dit…'
                        : 'Rien d’écrit ce jour-là.',
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
              child: Row(
                children: [
                  Icon(
                    _saved ? Icons.cloud_done_outlined : Icons.edit_outlined,
                    size: 16,
                    color: context.sfMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) => ProtoMutedText(_syncLabel()),
                    ),
                  ),
                  if (_isToday &&
                      AppScope.of(
                        context,
                      ).settingsController.dailyNoteReminderEnabled)
                    ProtoMutedText(
                      'Rappel à ${QuietHours.formatTime(_controller.reviewMinutes)}',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Où en est la note : en cours de frappe, en attente d'envoi (hors
  /// connexion), ou bien gardée chiffrée sur le serveur.
  String _syncLabel() {
    if (!_saved) return 'Enregistrement…';
    if (!_controller.syncsWithServer) return 'Enregistrée sur ce téléphone';
    if (_controller.noteFor(_day)?.pendingSync == true) {
      return 'Enregistrée · envoi en attente';
    }
    return 'Synchronisée et chiffrée';
  }

  String _relativeLabel(DateTime day, DateTime today) {
    final days = today.difference(day).inDays;
    if (days == 1) return 'Hier';
    return 'Il y a $days jours';
  }
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({required this.notes});

  final List<DailyNote> notes;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
        children: [
          ProtoSectionHeading(
            overline: 'Historique',
            title: notes.isEmpty
                ? 'Aucune note'
                : '${notes.length} jour${notes.length > 1 ? 's' : ''} notés',
          ),
          const SizedBox(height: 12),
          if (notes.isEmpty)
            const ProtoMutedText('Tes notes de chaque jour apparaîtront ici.'),
          for (final note in notes)
            ProtoCard(
              onTap: () => Navigator.pop(context, note.day),
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          StudyFlowFormat.longDay(note.day),
                          style: TextStyle(
                            color: context.sfText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        ProtoMutedText(note.preview, maxLines: 2),
                        const SizedBox(height: 2),
                        Text(
                          _lineCountLabel(note.text),
                          style: lineNumberStyle(context, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: context.sfChevron),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// « 1 ligne », « 12 lignes ».
String _lineCountLabel(String text) {
  final count = text.trimRight().split('\n').length;
  return '$count ligne${count > 1 ? 's' : ''}';
}
