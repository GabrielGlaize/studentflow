import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/groups/domain/group_models.dart';
import 'package:studyflow_app/features/groups/presentation/group_page.dart';
import 'package:studyflow_app/features/groups/presentation/group_widgets.dart';
import 'package:studyflow_app/features/groups/presentation/groups_page.dart';

/// Accueil : invitations, groupes en cours (avancement, non-lus) et prochaine
/// réunion confirmée.
class GroupsDashboardSection extends StatefulWidget {
  const GroupsDashboardSection({required this.refreshedAt, super.key});

  /// Change quand l'accueil est rechargé.
  final DateTime refreshedAt;

  @override
  State<GroupsDashboardSection> createState() => _GroupsDashboardSectionState();
}

class _GroupsDashboardSectionState extends State<GroupsDashboardSection> {
  Future<(List<StudyGroupSummary>, GroupAgenda)>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  void didUpdateWidget(covariant GroupsDashboardSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshedAt != widget.refreshedAt) _future = _load();
  }

  Future<(List<StudyGroupSummary>, GroupAgenda)> _load() async {
    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final groups = await appScope.groupRepository.listGroups(
        accessToken: accessToken,
      );
      final agenda = groups.any((x) => !x.isInvitation)
          ? await appScope.groupRepository.agenda(accessToken: accessToken)
          : GroupAgenda.empty;
      return (groups, agenda);
    } on Exception {
      // Section facultative : sans réseau, l'accueil reste utilisable.
      return (const <StudyGroupSummary>[], GroupAgenda.empty);
    }
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<StudyGroupSummary>, GroupAgenda)>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final (groups, agenda) = data;
        final current = groups.where((x) => !x.isArchived).toList();
        final now = DateTime.now();
        final nextMeeting = agenda.meetings
            .where((x) => x.endsAt.isAfter(now))
            .firstOrNull;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 8),
                child: ProtoSectionHeading(
                  overline: 'Travail de groupe',
                  title: 'Mes groupes',
                  trailing: TextButton(
                    key: const ValueKey('dashboard-groups-all'),
                    onPressed: () async {
                      await GroupsPage.open(context);
                      _reload();
                    },
                    child: Text(current.isEmpty ? 'Créer' : 'Tout voir'),
                  ),
                ),
              ),
              if (current.isEmpty)
                ProtoCard(
                  key: const ValueKey('dashboard-groups-empty'),
                  onTap: () async {
                    await GroupsPage.open(context);
                    _reload();
                  },
                  child: Row(
                    children: [
                      ProtoIconBox(
                        icon: Icons.diversity_3_outlined,
                        backgroundColor: context.sfGroupSoft,
                        foregroundColor: context.sfGroup,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: ProtoMutedText(
                          'Un projet à plusieurs ? Crée un groupe privé : '
                          'discussion, tâches, réunions et fichiers.',
                        ),
                      ),
                    ],
                  ),
                ),
              if (nextMeeting != null)
                ProtoCard(
                  key: const ValueKey('dashboard-next-meeting'),
                  onTap: () async {
                    await GroupPage.open(
                      context,
                      groupId: nextMeeting.groupId,
                      initialTab: GroupPage.tabPlanning,
                    );
                    _reload();
                  },
                  backgroundColor: context.sfGroupSoft,
                  borderColor: context.sfGroupSoft,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.event_available, color: context.sfGroup),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Réunion « ${nextMeeting.groupName} » · '
                          '${meetingWhen(nextMeeting.startsAt, nextMeeting.endsAt)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.sfGroup,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              for (final group in current.take(3))
                GroupCard(
                  group: group,
                  onTap: () async {
                    if (group.isInvitation) {
                      await GroupsPage.open(context);
                    } else {
                      await GroupPage.open(context, groupId: group.id);
                    }
                    _reload();
                  },
                  onAccept: () => _accept(group),
                  onDecline: () async {
                    await GroupsPage.open(context);
                    _reload();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _accept(StudyGroupSummary group) async {
    final appScope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.groupRepository.acceptInvitation(
        groupId: group.id,
        accessToken: accessToken,
      );
      if (!mounted) return;
      await GroupPage.open(context, groupId: group.id);
      _reload();
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: AppColors.danger),
      );
    }
  }
}
