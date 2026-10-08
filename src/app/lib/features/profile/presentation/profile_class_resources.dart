part of 'profile_page.dart';

class _ClassResourcesEntryCard extends StatelessWidget {
  const _ClassResourcesEntryCard({
    required this.subjects,
    required this.teachers,
    required this.isDelegate,
    required this.onOpen,
  });

  final List<ClassSubject> subjects;
  final List<ClassTeacher> teachers;
  final bool isDelegate;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final summary = [
      subjects.length <= 1
          ? '${subjects.length} matière'
          : '${subjects.length} matières',
      teachers.length <= 1
          ? '${teachers.length} intervenant'
          : '${teachers.length} intervenants',
    ].join(' · ');

    return ProtoCard(
      onTap: onOpen,
      child: Row(
        children: [
          ProtoIconBox(
            icon: Icons.menu_book_outlined,
            backgroundColor: context.sfSharedSoft,
            foregroundColor: context.sfShared,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              key: const ValueKey('class-resources-entry'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Matières et intervenants',
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                ProtoMutedText(isDelegate ? '$summary · à gérer' : summary),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.sfChevron),
        ],
      ),
    );
  }
}

class _ClassMembersCard extends StatelessWidget {
  const _ClassMembersCard({
    required this.members,
    required this.isDelegate,
    required this.onMakeDelegate,
    required this.onRemoveMember,
    required this.onLeaveDelegateRole,
  });

  final List<ClassMember> members;
  final bool isDelegate;
  final ValueChanged<ClassMember> onMakeDelegate;
  final ValueChanged<ClassMember> onRemoveMember;
  final VoidCallback onLeaveDelegateRole;

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoSectionHeading(
            overline: isDelegate ? 'Délégué' : 'Classe',
            title: 'Membres de la classe',
            trailing: isDelegate
                ? TextButton.icon(
                    onPressed: onLeaveDelegateRole,
                    icon: const Icon(Icons.remove_moderator_outlined, size: 16),
                    label: const Text('Quitter'),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          ProtoMutedText(
            isDelegate
                ? 'Tu peux retirer un élève ou nommer un autre délégué. Tu ne retires jamais le rôle délégué d’un autre élève.'
                : 'Liste des élèves approuvés dans ta classe.',
          ),
          const SizedBox(height: 10),
          if (members.isEmpty)
            const ProtoStateCard(
              icon: Icons.groups_outlined,
              title: 'Aucun membre affiché',
              message: 'Les membres apparaîtront ici après approbation.',
              compact: true,
            )
          else
            ...members.map(
              (member) => _ClassMemberRow(
                member: member,
                isDelegateMode: isDelegate,
                onMakeDelegate: () => onMakeDelegate(member),
                onRemoveMember: () => onRemoveMember(member),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClassMemberRow extends StatelessWidget {
  const _ClassMemberRow({
    required this.member,
    required this.isDelegateMode,
    required this.onMakeDelegate,
    required this.onRemoveMember,
  });

  final ClassMember member;
  final bool isDelegateMode;
  final VoidCallback onMakeDelegate;
  final VoidCallback onRemoveMember;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 11),
      margin: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoIconBox(
            icon: member.isDelegate
                ? Icons.verified_user_outlined
                : Icons.person_outline,
            backgroundColor: member.isDelegate
                ? AppColors.mint
                : AppColors.primarySoft,
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.displayName,
                        style: TextStyle(
                          color: context.sfText,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (member.isDelegate) const ProtoChip(label: 'Délégué'),
                  ],
                ),
                if (member.email case final email?) ...[
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: TextStyle(color: context.sfMuted, fontSize: 11),
                  ),
                ],
                if (isDelegateMode) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!member.isDelegate)
                        OutlinedButton.icon(
                          onPressed: onMakeDelegate,
                          icon: const Icon(
                            Icons.add_moderator_outlined,
                            size: 16,
                          ),
                          label: const Text('Nommer délégué'),
                        ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8D5C66),
                          side: const BorderSide(color: Color(0xFFD9BDC3)),
                        ),
                        onPressed: onRemoveMember,
                        icon: const Icon(
                          Icons.person_remove_outlined,
                          size: 16,
                        ),
                        label: const Text('Retirer'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingRequestRow extends StatelessWidget {
  const _PendingRequestRow({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final PendingMembershipRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 11),
      margin: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProtoIconBox(icon: Icons.person_add_alt_1_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  request.displayName,
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  request.email,
                  style: TextStyle(color: context.sfMuted, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton(
                      onPressed: onApprove,
                      child: const Text('Approuver'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: onReject,
                      child: const Text('Refuser'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
