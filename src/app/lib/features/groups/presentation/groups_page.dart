import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/groups/domain/group_models.dart';
import 'package:studyflow_app/features/groups/presentation/availability_sheet.dart';
import 'package:studyflow_app/features/groups/presentation/group_form_page.dart';
import 'package:studyflow_app/features/groups/presentation/group_page.dart';
import 'package:studyflow_app/features/groups/presentation/group_widgets.dart';

/// Mes groupes de travail et les invitations reçues.
class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => const GroupsPage()));
  }

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  Future<List<StudyGroupSummary>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<StudyGroupSummary>> _load() async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    return appScope.groupRepository.listGroups(accessToken: accessToken);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travail de groupe'),
        actions: [
          IconButton(
            key: const ValueKey('groups-availability'),
            tooltip: 'Mes disponibilités',
            onPressed: () => AvailabilitySheet.show(context),
            icon: const Icon(Icons.event_available_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'groups-fab',
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        key: const ValueKey('groups-create'),
        backgroundColor: context.sfGroup,
        foregroundColor: context.sfCard,
        onPressed: _create,
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Nouveau groupe'),
      ),
      body: FutureBuilder<List<StudyGroupSummary>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const ProtoPageLoader(label: 'Groupes');
          }
          if (snapshot.hasError) {
            return ProtoStateCard(
              icon: Icons.cloud_off_outlined,
              title: 'Groupes indisponibles',
              message: 'Impossible de charger tes groupes.',
              actionLabel: 'Réessayer',
              onAction: _refresh,
            );
          }

          final groups = snapshot.requireData;
          final invitations = groups.where((x) => x.isInvitation).toList();
          final active = groups
              .where((x) => !x.isInvitation && !x.isArchived)
              .toList();
          final archived = groups
              .where((x) => !x.isInvitation && x.isArchived)
              .toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 96),
              children: [
                const _Intro(),
                if (groups.isEmpty)
                  const ProtoStateCard(
                    icon: Icons.diversity_3_outlined,
                    title: 'Aucun groupe pour l’instant',
                    message:
                        'Crée un groupe pour un devoir à plusieurs : discussion, '
                        'tâches réparties, réunions et fichiers au même endroit.',
                    compact: true,
                  ),
                if (invitations.isNotEmpty) ...[
                  const ProtoSectionHeading(title: 'Invitations'),
                  const SizedBox(height: 10),
                  for (final group in invitations)
                    GroupCard(
                      group: group,
                      onTap: () => _open(group),
                      onAccept: () => _answer(group, accept: true),
                      onDecline: () => _answer(group, accept: false),
                    ),
                  const SizedBox(height: 8),
                ],
                if (active.isNotEmpty) ...[
                  const ProtoSectionHeading(title: 'En cours'),
                  const SizedBox(height: 10),
                  for (final group in active)
                    GroupCard(group: group, onTap: () => _open(group)),
                ],
                if (archived.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const ProtoSectionHeading(title: 'Archives'),
                  const SizedBox(height: 10),
                  for (final group in archived)
                    GroupCard(group: group, onTap: () => _open(group)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _create() async {
    final created = await GroupFormPage.open(context);
    if (created == null || !mounted) return;
    await GroupPage.open(context, groupId: created.summary.id);
    if (mounted) await _refresh();
  }

  Future<void> _open(StudyGroupSummary group) async {
    if (group.isInvitation) return;
    await GroupPage.open(context, groupId: group.id);
    if (mounted) await _refresh();
  }

  Future<void> _answer(StudyGroupSummary group, {required bool accept}) async {
    final appScope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      if (accept) {
        await appScope.groupRepository.acceptInvitation(
          groupId: group.id,
          accessToken: accessToken,
        );
      } else {
        await appScope.groupRepository.declineInvitation(
          groupId: group.id,
          accessToken: accessToken,
        );
      }
      if (!mounted) return;
      if (accept) {
        await GroupPage.open(context, groupId: group.id);
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('Invitation à « ${group.name} » refusée.')),
        );
      }
      if (mounted) await _refresh();
    } on Exception catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: GroupPrivacyBanner(
        text:
            'Chaque groupe est privé : seuls ses membres voient la discussion, '
            'les tâches et les fichiers.',
      ),
    );
  }
}
