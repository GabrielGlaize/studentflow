import 'dart:async';

import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';
import 'package:studyflow_app/features/groups/data/group_realtime.dart';
import 'package:studyflow_app/features/groups/domain/group_models.dart';
import 'package:studyflow_app/features/groups/presentation/availability_sheet.dart';
import 'package:studyflow_app/features/groups/presentation/group_widgets.dart';

/// Organiser : les créneaux où tout le groupe est libre (planning de la classe,
/// jours en entreprise, agendas perso), puis les réunions à valider ensemble.
class GroupPlanningTab extends StatefulWidget {
  const GroupPlanningTab({required this.group, super.key});

  final StudyGroupDetail group;

  @override
  State<GroupPlanningTab> createState() => _GroupPlanningTabState();
}

class _GroupPlanningTabState extends State<GroupPlanningTab>
    with AutomaticKeepAliveClientMixin {
  static const _durations = [30, 60, 90, 120];

  int _duration = 60;
  GroupSlots? _slots;
  List<GroupMeeting>? _meetings;
  String? _error;
  StreamSubscription<GroupRealtimeEvent>? _subscription;

  String get _groupId => widget.group.summary.id;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscription != null) return;
    _subscription = AppScope.of(context).groupRealtime.events
        .where((x) => x.groupId == _groupId)
        .where(
          (x) =>
              x is GroupChangedEvent &&
              (x.area == 'meetings' ||
                  x.area == 'members' ||
                  x.area == 'reconnected'),
        )
        .listen((_) => unawaited(_load()));
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<String?> _token() =>
      AppScope.of(context).sessionController.accessTokenForApi();

  Future<void> _load() async {
    final repository = AppScope.of(context).groupRepository;
    try {
      final accessToken = await _token();
      final results = await Future.wait<Object>([
        repository.findSlots(
          groupId: _groupId,
          durationMinutes: _duration,
          accessToken: accessToken,
        ),
        repository.listMeetings(groupId: _groupId, accessToken: accessToken),
      ]);
      if (!mounted) return;
      setState(() {
        _slots = results[0] as GroupSlots;
        _meetings = results[1] as List<GroupMeeting>;
        _error = null;
      });
    } on Exception catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final slots = _slots;
    final meetings = _meetings;
    if (slots == null || meetings == null) {
      return _error == null
          ? const Center(child: CircularProgressIndicator())
          : ProtoStateCard(
              icon: Icons.cloud_off_outlined,
              title: 'Organisation indisponible',
              message: _error!,
              actionLabel: 'Réessayer',
              onAction: _load,
            );
    }

    final proposed = meetings.where((x) => !x.isConfirmed).toList();
    final confirmed = meetings.where((x) => x.isConfirmed).toList();
    final missing = slots.membersWithDefaultAvailability;
    final myName = widget.group.me?.name;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          if (proposed.isNotEmpty) ...[
            const ProtoSectionHeading(title: 'À valider'),
            const SizedBox(height: 10),
            for (final meeting in proposed)
              _MeetingCard(meeting: meeting, onVote: _vote, onCancel: _cancel),
            const SizedBox(height: 8),
          ],
          if (confirmed.isNotEmpty) ...[
            const ProtoSectionHeading(title: 'Réunions prévues'),
            const SizedBox(height: 10),
            for (final meeting in confirmed)
              _MeetingCard(meeting: meeting, onVote: _vote, onCancel: _cancel),
            const SizedBox(height: 8),
          ],
          ProtoSectionHeading(
            overline: 'Tout le monde est libre',
            title: 'Créneaux communs',
            trailing: TextButton.icon(
              key: const ValueKey('group-availability-button'),
              onPressed: _editAvailability,
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Mes dispos'),
            ),
          ),
          const SizedBox(height: 6),
          const ProtoMutedText(
            'Calculés sur 2 semaines avec le planning de la classe. Un jour sans '
            'cours compte comme un jour en entreprise.',
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 10),
            ProtoCard(
              margin: EdgeInsets.zero,
              backgroundColor: context.sfEvaluationSoft,
              borderColor: context.sfEvaluationSoft,
              padding: const EdgeInsets.all(12),
              onTap: missing.contains(myName) ? _editAvailability : null,
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: context.sfEvaluation,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      missing.contains(myName)
                          ? 'Indique tes horaires d’entreprise pour des créneaux plus justes.'
                          : 'Horaires par défaut pour ${missing.join(', ')} (fin du travail 17 h 30).',
                      style: TextStyle(
                        color: context.sfEvaluation,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final minutes in _durations)
                ChoiceChip(
                  key: ValueKey('group-slot-duration-$minutes'),
                  label: Text(StudyFlowFormat.duration(minutes)),
                  selected: _duration == minutes,
                  onSelected: (_) {
                    setState(() => _duration = minutes);
                    unawaited(_load());
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (slots.slots.isEmpty)
            const ProtoStateCard(
              icon: Icons.event_busy_outlined,
              title: 'Aucun créneau commun',
              message:
                  'Essayez une réunion plus courte, ou que chacun vérifie ses '
                  'disponibilités (soirs, week-end).',
              compact: true,
            )
          else ...[
            if (slots.slots.first.missingNames.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: ProtoMutedText(
                  'Personne n’est libre en même temps : voici les créneaux où il ne manque qu’une personne.',
                ),
              ),
            for (final slot in slots.slots)
              _SlotTile(slot: slot, onPropose: () => _propose(slot)),
          ],
        ],
      ),
    );
  }

  Future<void> _editAvailability() async {
    final saved = await AvailabilitySheet.show(context);
    if (saved == true && mounted) await _load();
  }

  Future<void> _propose(GroupSlot slot) async {
    final proposed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) =>
          _ProposeSheet(groupId: _groupId, slot: slot, duration: _duration),
    );
    if (proposed == true && mounted) await _load();
  }

  Future<void> _vote(GroupMeeting meeting, bool available) async {
    final repository = AppScope.of(context).groupRepository;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await repository.voteMeeting(
        meetingId: meeting.id,
        isAvailable: available,
        accessToken: await _token(),
      );
      if (!mounted) return;
      setState(() {
        _meetings = [
          for (final x in _meetings!) x.id == updated.id ? updated : x,
        ];
      });
      if (updated.isConfirmed && !meeting.isConfirmed) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Réunion confirmée : elle est dans l’agenda de chacun.',
            ),
          ),
        );
      }
    } on Exception catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _cancel(GroupMeeting meeting) async {
    final repository = AppScope.of(context).groupRepository;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repository.cancelMeeting(
        meetingId: meeting.id,
        accessToken: await _token(),
      );
      if (mounted) await _load();
    } on Exception catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, required this.onPropose});

  final GroupSlot slot;
  final VoidCallback onPropose;

  @override
  Widget build(BuildContext context) {
    final onSite = slot.mode == MeetingMode.onSite;
    return ProtoCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ProtoIconBox(
            icon: onSite ? Icons.school_outlined : Icons.videocam_outlined,
            size: 38,
            backgroundColor: onSite
                ? context.sfSharedSoft
                : context.sfGroupSoft,
            foregroundColor: onSite ? context.sfShared : context.sfGroup,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meetingWhen(slot.start, slot.end),
                  style: TextStyle(
                    color: context.sfText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  [
                    slot.mode.label,
                    if (slot.missingNames.isNotEmpty)
                      'sans ${slot.missingNames.join(', ')}',
                  ].join(' · '),
                  style: TextStyle(color: context.sfMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onPropose, child: const Text('Proposer')),
        ],
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({
    required this.meeting,
    required this.onVote,
    required this.onCancel,
  });

  final GroupMeeting meeting;
  final void Function(GroupMeeting meeting, bool available) onVote;
  final ValueChanged<GroupMeeting> onCancel;

  @override
  Widget build(BuildContext context) {
    final confirmed = meeting.isConfirmed;
    return ProtoCard(
      key: ValueKey('group-meeting-${meeting.id}'),
      borderColor: confirmed
          ? AppColors.green
          : context.sfGroup.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                confirmed ? Icons.event_available : Icons.how_to_vote_outlined,
                color: confirmed ? AppColors.green : context.sfGroup,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meetingWhen(meeting.startsAt, meeting.endsAt),
                      style: TextStyle(
                        color: context.sfText,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      [
                        meeting.mode.label,
                        ?meeting.place,
                        if (!confirmed && meeting.proposedByName != null)
                          'proposé par ${meeting.proposedByName}',
                      ].join(' · '),
                      style: TextStyle(color: context.sfMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (meeting.canCancel)
                IconButton(
                  tooltip: 'Annuler la réunion',
                  onPressed: () => onCancel(meeting),
                  icon: const Icon(Icons.close, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final vote in meeting.votes)
                ProtoChip(
                  icon: switch (vote.isAvailable) {
                    true => Icons.check,
                    false => Icons.close,
                    null => Icons.schedule,
                  },
                  label: vote.name.split(' ').first,
                  backgroundColor: switch (vote.isAvailable) {
                    true => AppColors.greenSoft,
                    false => AppColors.roseSoft,
                    null => context.sfSoftCard,
                  },
                  foregroundColor: switch (vote.isAvailable) {
                    true => AppColors.green,
                    false => AppColors.danger,
                    null => context.sfMuted,
                  },
                ),
            ],
          ),
          if (!confirmed || meeting.myAnswer != true) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: ValueKey('group-meeting-no-${meeting.id}'),
                    onPressed: meeting.myAnswer == false
                        ? null
                        : () => onVote(meeting, false),
                    child: const Text('Pas dispo'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: ValueKey('group-meeting-yes-${meeting.id}'),
                    onPressed: meeting.myAnswer == true
                        ? null
                        : () => onVote(meeting, true),
                    child: const Text('Je suis dispo'),
                  ),
                ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: () => onVote(meeting, false),
                child: const Text('Je ne peux plus venir'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Proposer une réunion dans un créneau commun : heure de début, lieu.
class _ProposeSheet extends StatefulWidget {
  const _ProposeSheet({
    required this.groupId,
    required this.slot,
    required this.duration,
  });

  final String groupId;
  final GroupSlot slot;
  final int duration;

  @override
  State<_ProposeSheet> createState() => _ProposeSheetState();
}

class _ProposeSheetState extends State<_ProposeSheet> {
  late DateTime _start = widget.slot.start;
  late final _place = TextEditingController(
    text: widget.slot.mode == MeetingMode.onSite ? 'À l’école' : 'Visio',
  );
  bool _saving = false;
  String? _error;

  DateTime get _end => _start.add(Duration(minutes: widget.duration));

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProtoSectionHeading(
              overline: slot.mode.label,
              title: StudyFlowFormat.longDay(slot.day),
            ),
            const SizedBox(height: 6),
            ProtoMutedText(
              'Libre de ${StudyFlowFormat.timeOf(slot.start)} à ${StudyFlowFormat.timeOf(slot.end)}. '
              'Chaque membre devra confirmer.',
            ),
            const SizedBox(height: 14),
            ProtoPickerField(
              keyValue: 'group-propose-start',
              icon: Icons.schedule,
              label: 'Début (${StudyFlowFormat.duration(widget.duration)})',
              value:
                  '${StudyFlowFormat.timeOf(_start)} – ${StudyFlowFormat.timeOf(_end)}',
              onTap: _pickStart,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _place,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Lieu ou lien de visio',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            FilledButton(
              key: const ValueKey('group-propose-confirm'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Envoi…' : 'Proposer au groupe'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStart() async {
    final picked = await StudyFlowPickers.pickTime(
      context,
      initialTime: TimeOfDay.fromDateTime(_start),
      title: 'Début de la réunion',
    );
    if (picked == null || !mounted) return;
    final slot = widget.slot;
    final start = DateTime(
      slot.day.year,
      slot.day.month,
      slot.day.day,
      picked.hour,
      picked.minute,
    );
    final end = start.add(Duration(minutes: widget.duration));
    if (start.isBefore(slot.start) || end.isAfter(slot.end)) {
      setState(() => _error = 'Choisis une heure dans le créneau libre.');
      return;
    }
    setState(() {
      _start = start;
      _error = null;
    });
  }

  Future<void> _save() async {
    final appScope = AppScope.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.groupRepository.proposeMeeting(
        groupId: widget.groupId,
        startsAt: _start,
        endsAt: _end,
        mode: widget.slot.mode,
        place: _place.text,
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
}
