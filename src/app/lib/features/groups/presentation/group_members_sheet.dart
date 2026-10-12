import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/groups/data/group_repository.dart';
import 'package:studyflow_app/features/groups/domain/group_models.dart';
import 'package:studyflow_app/features/groups/presentation/group_widgets.dart';
import 'package:studyflow_app/features/groups/presentation/invite_classmates_sheet.dart';

/// Membres du groupe : rôles, avancement de chacun, invitations. L'organisateur
/// invite, retire et peut passer la main.
class GroupMembersSheet extends StatefulWidget {
  const GroupMembersSheet({required this.group, super.key});

  final StudyGroupDetail group;

  static Future<void> show(
    BuildContext context, {
    required StudyGroupDetail group,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => GroupMembersSheet(group: group),
    );
  }

  @override
  State<GroupMembersSheet> createState() => _GroupMembersSheetState();
}

class _GroupMembersSheetState extends State<GroupMembersSheet> {
  late StudyGroupDetail _group = widget.group;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final active = group.activeMembers;
    final invited = group.members.where((x) => x.isInvited).toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            ProtoSectionHeading(
              overline:
                  '${active.length} membre${active.length > 1 ? 's' : ''}',
              title: 'Qui fait quoi',
              trailing: group.canManage && !group.summary.isArchived
                  ? TextButton.icon(
                      key: const ValueKey('group-members-invite'),
                      onPressed: _busy ? null : _invite,
                      icon: const Icon(Icons.person_add_alt, size: 18),
                      label: const Text('Inviter'),
                    )
                  : null,
            ),
            const SizedBox(height: 10),
            for (final member in active) _memberTile(member),
            if (invited.isNotEmpty) ...[
              const SizedBox(height: 8),
              const ProtoOverline('En attente de réponse'),
              const SizedBox(height: 6),
              for (final member in invited) _memberTile(member),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('group-my-role'),
              onPressed: _busy ? null : _editMyRole,
              icon: const Icon(Icons.badge_outlined, size: 18),
              label: Text(
                group.me?.roleLabel == null
                    ? 'Choisir mon rôle'
                    : 'Mon rôle : ${group.me!.roleLabel}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberTile(GroupMember member) {
    final total = member.openTaskCount + member.doneTaskCount;
    final details = [
      if (member.isOrganizer) 'Organise le groupe',
      ?member.roleLabel,
      if (member.isInvited)
        'Invité'
      else if (total > 0)
        '${member.doneTaskCount}/$total tâche${total > 1 ? 's' : ''} faite${total > 1 ? 's' : ''}',
    ].join(' · ');

    return ListTile(
      key: ValueKey('group-member-${member.userId}'),
      contentPadding: EdgeInsets.zero,
      leading: GroupAvatar(
        initials: member.initials,
        size: 38,
        highlighted: member.isMe,
      ),
      title: Text(member.isMe ? '${member.name} (moi)' : member.name),
      subtitle: details.isEmpty ? null : Text(details),
      trailing: _group.canManage && !member.isMe
          ? PopupMenuButton<String>(
              onSelected: (value) => switch (value) {
                'organizer' => _makeOrganizer(member),
                'remove' => _remove(member),
                _ => null,
              },
              itemBuilder: (context) => [
                if (!member.isInvited)
                  const PopupMenuItem(
                    value: 'organizer',
                    child: Text('Lui confier l’organisation'),
                  ),
                PopupMenuItem(
                  value: 'remove',
                  child: Text(
                    member.isInvited
                        ? 'Annuler l’invitation'
                        : 'Retirer du groupe',
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ],
            )
          : null,
    );
  }

  Future<void> _invite() async {
    final picked = await InviteClassmatesSheet.show(
      context,
      homeworkId: _group.summary.homeworkId,
      groupId: _group.summary.id,
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    await _update(
      (repository, token) => repository.invite(
        groupId: _group.summary.id,
        userIds: picked.map((x) => x.userId).toList(),
        accessToken: token,
      ),
    );
  }

  Future<void> _editMyRole() async {
    final controller = TextEditingController(text: _group.me?.roleLabel ?? '');
    final role = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mon rôle dans le groupe'),
        content: TextField(
          key: const ValueKey('group-role-field'),
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Rédaction, Diapos, Partie SQL…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const ValueKey('group-role-save'),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (role == null || !mounted) return;
    await _update(
      (repository, token) => repository.setMyRole(
        groupId: _group.summary.id,
        roleLabel: role,
        accessToken: token,
      ),
    );
  }

  Future<void> _makeOrganizer(GroupMember member) async {
    await _update(
      (repository, token) => repository.makeOrganizer(
        groupId: _group.summary.id,
        userId: member.userId,
        accessToken: token,
      ),
    );
  }

  Future<void> _remove(GroupMember member) async {
    await _update((repository, token) async {
      await repository.removeMember(
        groupId: _group.summary.id,
        userId: member.userId,
        accessToken: token,
      );
      return repository.getGroup(
        groupId: _group.summary.id,
        accessToken: token,
      );
    });
  }

  Future<void> _update(
    Future<StudyGroupDetail> Function(GroupRepository repository, String? token)
    action,
  ) async {
    final appScope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final updated = await action(appScope.groupRepository, accessToken);
      if (mounted) setState(() => _group = updated);
    } on Exception catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
