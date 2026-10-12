import 'dart:async';

import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/network/api_client.dart';
import 'package:studyflow_app/features/groups/data/group_realtime.dart';
import 'package:studyflow_app/features/groups/data/group_repository.dart';
import 'package:studyflow_app/features/groups/domain/group_models.dart';
import 'package:studyflow_app/features/groups/presentation/group_chat_tab.dart';
import 'package:studyflow_app/features/groups/presentation/group_form_page.dart';
import 'package:studyflow_app/features/groups/presentation/group_members_sheet.dart';
import 'package:studyflow_app/features/groups/presentation/group_planning_tab.dart';
import 'package:studyflow_app/features/groups/presentation/group_resources_tab.dart';
import 'package:studyflow_app/features/groups/presentation/group_tasks_tab.dart';
import 'package:studyflow_app/features/groups/presentation/group_widgets.dart';

/// Un groupe de travail : discussion en temps réel, tâches, organisation des
/// réunions et fichiers partagés.
class GroupPage extends StatefulWidget {
  const GroupPage({required this.groupId, this.initialTab = 0, super.key});

  final String groupId;
  final int initialTab;

  static const tabTasks = 1;
  static const tabPlanning = 2;

  static Future<void> open(
    BuildContext context, {
    required String groupId,
    int initialTab = 0,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            GroupPage(groupId: groupId, initialTab: initialTab),
      ),
    );
  }

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 4,
    vsync: this,
    initialIndex: widget.initialTab,
  );
  StudyGroupDetail? _group;
  Object? _error;
  StreamSubscription<GroupRealtimeEvent>? _subscription;
  GroupRealtime? _realtime;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_realtime != null) return;
    final realtime = _realtime = AppScope.of(context).groupRealtime;
    _subscription = realtime.events
        .where((x) => x.groupId == widget.groupId)
        .listen(_onEvent);
    unawaited(realtime.watch(widget.groupId));
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_realtime?.unwatch(widget.groupId));
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final group = await appScope.groupRepository.getGroup(
        groupId: widget.groupId,
        accessToken: accessToken,
      );
      if (mounted) {
        setState(() {
          _group = group;
          _error = null;
        });
      }
    } on Exception catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 404 && _group != null) {
        // Groupe supprimé, ou on en a été retiré pendant qu'il était ouvert.
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce groupe n’est plus accessible.')),
        );
        return;
      }
      setState(() => _error = error);
    }
  }

  void _onEvent(GroupRealtimeEvent event) {
    switch (event) {
      case GroupChangedEvent(:final area)
          when area == 'group' || area == 'members' || area == 'reconnected':
        unawaited(_load());
      case GroupReadEvent(:final userId, :final readAt):
        final group = _group;
        if (group == null) return;
        setState(() {
          _group = StudyGroupDetail(
            summary: group.summary,
            description: group.description,
            canManage: group.canManage,
            members: [
              for (final member in group.members)
                member.userId == userId
                    ? GroupMember(
                        userId: member.userId,
                        name: member.name,
                        isOrganizer: member.isOrganizer,
                        isInvited: member.isInvited,
                        isMe: member.isMe,
                        roleLabel: member.roleLabel,
                        lastReadAt: readAt,
                        openTaskCount: member.openTaskCount,
                        doneTaskCount: member.doneTaskCount,
                      )
                    : member,
            ],
          );
        });
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Groupe')),
        body: _error == null
            ? const ProtoPageLoader(label: 'Groupe')
            : ProtoStateCard(
                icon: Icons.cloud_off_outlined,
                title: 'Groupe indisponible',
                message: '$_error',
                actionLabel: 'Réessayer',
                onAction: _load,
              ),
      );
    }

    final summary = group.summary;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            Text(
              [
                ?summary.subjectName,
                groupDueLabel(summary, DateTime.now()),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.sfMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: AppScope.of(context).groupRealtime.connected,
            builder: (context, connected, _) => _MembersButton(
              members: group.activeMembers,
              live: connected,
              onTap: () => _showMembers(group),
            ),
          ),
          PopupMenuButton<String>(
            key: const ValueKey('group-menu'),
            onSelected: (value) => switch (value) {
              'edit' => _edit(group),
              'leave' => _leave(group),
              'delete' => _delete(group),
              _ => null,
            },
            itemBuilder: (context) => [
              if (group.canManage)
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Modifier le groupe'),
                  ),
                ),
              const PopupMenuItem(
                value: 'leave',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Quitter le groupe'),
                ),
              ),
              if (group.canManage)
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                    title: Text('Supprimer le groupe'),
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: context.sfGroup,
          indicatorColor: context.sfGroup,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
          tabs: const [
            Tab(key: ValueKey('group-tab-chat'), text: 'Discussion'),
            Tab(key: ValueKey('group-tab-tasks'), text: 'Tâches'),
            Tab(key: ValueKey('group-tab-planning'), text: 'Organiser'),
            Tab(key: ValueKey('group-tab-files'), text: 'Fichiers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          GroupChatTab(group: group),
          GroupTasksTab(group: group, onChanged: _load),
          GroupPlanningTab(group: group),
          GroupResourcesTab(group: group),
        ],
      ),
    );
  }

  Future<void> _showMembers(StudyGroupDetail group) async {
    await GroupMembersSheet.show(context, group: group);
    if (mounted) await _load();
  }

  Future<void> _edit(StudyGroupDetail group) async {
    final saved = await GroupFormPage.open(context, group: group);
    if (saved != null && mounted) setState(() => _group = saved);
  }

  Future<void> _leave(StudyGroupDetail group) async {
    final alone = group.activeMembers.length <= 1;
    final confirmed = await _confirm(
      title: 'Quitter « ${group.summary.name} » ?',
      message: alone
          ? 'Tu es le dernier membre : le groupe et tout son contenu seront supprimés.'
          : group.canManage
          ? 'Le membre le plus ancien deviendra organisateur. Tes tâches restent au groupe.'
          : 'Tes tâches restent au groupe pour que quelqu’un les reprenne.',
      action: 'Quitter',
    );
    if (!confirmed || !mounted) return;
    await _run(
      (repository, token) =>
          repository.leaveGroup(groupId: group.summary.id, accessToken: token),
      closeAfter: true,
    );
  }

  Future<void> _delete(StudyGroupDetail group) async {
    final confirmed = await _confirm(
      title: 'Supprimer le groupe ?',
      message:
          'La discussion, les tâches, les réunions et les fichiers seront '
          'supprimés pour tous les membres.',
      action: 'Supprimer',
    );
    if (!confirmed || !mounted) return;
    await _run(
      (repository, token) =>
          repository.deleteGroup(groupId: group.summary.id, accessToken: token),
      closeAfter: true,
    );
  }

  Future<void> _run(
    Future<void> Function(GroupRepository repository, String? token) action, {
    bool closeAfter = false,
  }) async {
    final appScope = AppScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await action(appScope.groupRepository, accessToken);
      if (closeAfter) navigator.pop();
    } on Exception catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const ValueKey('group-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

/// Avatars des membres en haut à droite, avec un point vert quand le temps
/// réel est actif.
class _MembersButton extends StatelessWidget {
  const _MembersButton({
    required this.members,
    required this.live,
    required this.onTap,
  });

  final List<GroupMember> members;
  final bool live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shown = members.take(3).toList();
    return InkWell(
      key: const ValueKey('group-members-button'),
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28.0 + 22 * (shown.length - 1).clamp(0, 2),
              height: 28,
              child: Stack(
                children: [
                  for (var index = 0; index < shown.length; index++)
                    Positioned(
                      left: index * 22.0,
                      child: GroupAvatar(
                        initials: shown[index].initials,
                        size: 28,
                        highlighted: shown[index].isMe,
                      ),
                    ),
                ],
              ),
            ),
            if (live)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Tooltip(
                  message: 'En direct',
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
