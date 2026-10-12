import 'package:flutter/material.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';
import 'package:studyflow_app/features/groups/domain/group_models.dart';
import 'package:studyflow_app/features/groups/presentation/group_page.dart';
import 'package:studyflow_app/features/groups/presentation/group_widgets.dart';

/// Dans l'agenda : les tâches de groupe qu'on m'a confiées et les réunions
/// confirmées. Rien n'est affiché s'il n'y a rien.
class GroupAgendaItems extends StatelessWidget {
  const GroupAgendaItems({
    required this.agenda,
    this.day,
    this.onOpened,
    this.before,
    super.key,
  });

  final GroupAgenda agenda;

  /// Limite aux éléments de ce jour (vue calendrier).
  final DateTime? day;

  /// Appelé au retour de l'écran du groupe (pour recharger).
  final VoidCallback? onOpened;

  /// Appelé avant d'ouvrir le groupe (fermer une feuille, par exemple).
  final VoidCallback? before;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final tasks = agenda.tasks
        .where(
          (x) =>
              day == null ||
              (x.dueOn != null && DateUtils.isSameDay(x.dueOn, day)),
        )
        .toList();
    final meetings = agenda.meetings
        .where(
          (x) => day == null
              ? x.endsAt.isAfter(now)
              : DateUtils.isSameDay(x.startsAt, day),
        )
        .toList();
    if (tasks.isEmpty && meetings.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
          child: Row(
            children: [
              Icon(
                Icons.diversity_3_outlined,
                size: 18,
                color: context.sfGroup,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Travail de groupe',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: context.sfText,
                    fontSize: 17,
                  ),
                ),
              ),
              ProtoChip(
                label: '${tasks.length + meetings.length}',
                backgroundColor: context.sfGroupSoft,
                foregroundColor: context.sfGroup,
              ),
            ],
          ),
        ),
        for (final meeting in meetings)
          _Item(
            key: ValueKey('agenda-group-meeting-${meeting.id}'),
            icon: meeting.mode == MeetingMode.onSite
                ? Icons.school_outlined
                : Icons.videocam_outlined,
            title: 'Réunion · ${meeting.groupName}',
            subtitle: [
              meetingWhen(meeting.startsAt, meeting.endsAt),
              ?meeting.place,
            ].join(' · '),
            onTap: () => _open(context, meeting.groupId, GroupPage.tabPlanning),
          ),
        for (final task in tasks)
          _Item(
            key: ValueKey('agenda-group-task-${task.id}'),
            icon: task.status == GroupTaskStatus.doing
                ? Icons.timelapse
                : Icons.radio_button_unchecked,
            title: task.title,
            subtitle: [
              task.groupName,
              if (task.dueOn case final due?)
                'pour le ${StudyFlowFormat.shortDay(due)}',
            ].join(' · '),
            late:
                task.dueOn != null &&
                task.dueOn!.isBefore(DateUtils.dateOnly(now)),
            onTap: () => _open(context, task.groupId, GroupPage.tabTasks),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _open(BuildContext context, String groupId, int tab) async {
    before?.call();
    await GroupPage.open(context, groupId: groupId, initialTab: tab);
    onOpened?.call();
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.late = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool late;

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      borderColor: context.sfGroup.withValues(alpha: 0.35),
      child: Row(
        children: [
          Icon(icon, color: context.sfGroup),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.sfText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: late ? AppColors.danger : context.sfMuted,
                    fontSize: 12,
                    fontWeight: late ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.sfChevron),
        ],
      ),
    );
  }
}
