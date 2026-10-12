import 'package:flutter/material.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';
import 'package:studyflow_app/features/groups/domain/group_models.dart';

/// « Rendu dans 9 jours », « Rendu demain », « Rendu passé ».
String groupDueLabel(StudyGroupSummary group, DateTime now) {
  final days = group.daysUntilDue(now);
  if (days == null) return 'Pas de date de rendu';
  if (days < 0) return 'Rendu passé';
  if (days == 0) return 'Rendu aujourd’hui';
  if (days == 1) return 'Rendu demain';
  return 'Rendu dans $days jours';
}

/// Pastille ronde aux initiales d'un membre.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({
    required this.initials,
    this.size = 30,
    this.highlighted = false,
    super.key,
  });

  final String initials;
  final double size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlighted ? context.sfGroup : context.sfGroupSoft,
        shape: BoxShape.circle,
        border: Border.all(color: context.sfCard, width: 2),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: highlighted ? context.sfCard : context.sfGroup,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String initialsOf(String name) {
  final parts = name.split(' ').where((x) => x.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((x) => x[0].toUpperCase()).join();
}

/// Barre d'avancement des tâches du groupe.
class GroupProgressBar extends StatelessWidget {
  const GroupProgressBar({required this.done, required this.total, super.key});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : done / total;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 7,
              backgroundColor: context.sfGroupSoft,
              valueColor: AlwaysStoppedAnimation(context.sfGroup),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          total == 0 ? 'Aucune tâche' : '$done/$total',
          style: TextStyle(
            color: context.sfMuted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Carte d'un groupe dans les listes (accueil, mes groupes).
class GroupCard extends StatelessWidget {
  const GroupCard({
    required this.group,
    required this.onTap,
    this.onAccept,
    this.onDecline,
    super.key,
  });

  final StudyGroupSummary group;
  final VoidCallback onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = group.daysUntilDue(now);
    final urgent = days != null && days >= 0 && days <= 2;
    final link = [?group.subjectName, ?group.homeworkTitle].join(' · ');

    return ProtoCard(
      key: ValueKey('group-card-${group.id}'),
      onTap: onTap,
      borderColor: group.isInvitation ? context.sfGroup : AppColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProtoIconBox(
                icon: group.isInvitation
                    ? Icons.mark_email_unread_outlined
                    : Icons.diversity_3_outlined,
                backgroundColor: context.sfGroupSoft,
                foregroundColor: context.sfGroup,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (link.isNotEmpty)
                      Text(
                        link.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.sfGroup,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    Text(
                      group.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.sfText,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (group.unreadCount > 0)
                Container(
                  key: ValueKey('group-unread-${group.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: context.sfGroup,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${group.unreadCount}',
                    style: TextStyle(
                      color: context.sfCard,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (group.isInvitation) ...[
            ProtoMutedText(
              '${group.invitedByName ?? 'Un camarade'} t’invite dans ce groupe privé.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: ValueKey('group-decline-${group.id}'),
                    onPressed: onDecline,
                    child: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: ValueKey('group-accept-${group.id}'),
                    onPressed: onAccept,
                    child: const Text('Rejoindre'),
                  ),
                ),
              ],
            ),
          ] else ...[
            GroupProgressBar(done: group.doneTaskCount, total: group.taskCount),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ProtoChip(
                  icon: Icons.event_outlined,
                  label: group.isArchived
                      ? 'Archivé'
                      : groupDueLabel(group, now),
                  backgroundColor: urgent
                      ? context.sfEvaluationSoft
                      : context.sfSoftCard,
                  foregroundColor: urgent
                      ? context.sfEvaluation
                      : context.sfMuted,
                ),
                ProtoChip(
                  icon: Icons.people_outline,
                  label: '${group.memberCount}',
                  backgroundColor: context.sfSoftCard,
                  foregroundColor: context.sfMuted,
                ),
                if (group.myOpenTaskCount > 0)
                  ProtoChip(
                    icon: Icons.assignment_ind_outlined,
                    label: group.myOpenTaskCount == 1
                        ? '1 tâche pour toi'
                        : '${group.myOpenTaskCount} tâches pour toi',
                    backgroundColor: context.sfGroupSoft,
                    foregroundColor: context.sfGroup,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// « Mar. 14/10 · 12:00 – 13:30 ».
String meetingWhen(DateTime start, DateTime end) =>
    '${StudyFlowFormat.shortDay(start)} · ${StudyFlowFormat.timeOf(start)} – ${StudyFlowFormat.timeOf(end)}';

/// Bandeau en tête des formulaires de groupe : rappelle que c'est privé.
class GroupPrivacyBanner extends StatelessWidget {
  const GroupPrivacyBanner({this.text, super.key});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.sfGroupSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_person_outlined, size: 18, color: context.sfGroup),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text ?? 'Visible seulement par les membres du groupe',
              style: TextStyle(
                color: context.sfGroup,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
