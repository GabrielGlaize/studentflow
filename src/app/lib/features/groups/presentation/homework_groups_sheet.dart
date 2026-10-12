import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/agenda/domain/agenda_models.dart';
import 'package:studyflow_app/features/groups/domain/group_models.dart';
import 'package:studyflow_app/features/groups/presentation/group_form_page.dart';
import 'package:studyflow_app/features/groups/presentation/group_page.dart';

/// Depuis un devoir de groupe : ouvrir mon groupe ou en former un, et voir
/// qui n'a pas encore de groupe (pour que personne ne reste seul). Le contenu
/// des autres groupes reste privé.
class HomeworkGroupsSheet extends StatefulWidget {
  const HomeworkGroupsSheet({required this.homework, super.key});

  final HomeworkItem homework;

  static Future<void> show(BuildContext context, HomeworkItem homework) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => HomeworkGroupsSheet(homework: homework),
    );
  }

  @override
  State<HomeworkGroupsSheet> createState() => _HomeworkGroupsSheetState();
}

class _HomeworkGroupsSheetState extends State<HomeworkGroupsSheet> {
  Future<HomeworkGroupsOverview>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<HomeworkGroupsOverview> _load() async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    return appScope.groupRepository.homeworkOverview(
      homeworkId: widget.homework.id,
      accessToken: accessToken,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: FutureBuilder<HomeworkGroupsOverview>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: ProtoMutedText('Impossible de charger les groupes.'),
              );
            }

            final overview = snapshot.requireData;
            final mine = overview.myGroup;
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              children: [
                ProtoSectionHeading(
                  overline: 'Travail de groupe',
                  title: widget.homework.title,
                ),
                const SizedBox(height: 14),
                if (mine != null)
                  FilledButton.icon(
                    key: const ValueKey('homework-open-my-group'),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.sfGroup,
                    ),
                    onPressed: () => _openGroup(mine.id),
                    icon: const Icon(Icons.forum_outlined),
                    label: Text('Ouvrir « ${mine.name} »'),
                  )
                else
                  FilledButton.icon(
                    key: const ValueKey('homework-create-group'),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.sfGroup,
                    ),
                    onPressed: _create,
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Former un groupe'),
                  ),
                const SizedBox(height: 18),
                ProtoOverline(
                  overview.groups.isEmpty
                      ? 'Aucun groupe pour l’instant'
                      : '${overview.groups.length} groupe${overview.groups.length > 1 ? 's' : ''}',
                ),
                const SizedBox(height: 8),
                for (final group in overview.groups)
                  ProtoCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    borderColor: group.isMine
                        ? context.sfGroup
                        : AppColors.line,
                    child: Row(
                      children: [
                        Icon(
                          group.isMine
                              ? Icons.star_rounded
                              : Icons.lock_outline,
                          size: 18,
                          color: group.isMine
                              ? context.sfGroup
                              : context.sfMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                style: TextStyle(
                                  color: context.sfText,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              ProtoMutedText(group.memberNames.join(', ')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (overview.studentsWithoutGroup.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const ProtoOverline('Encore sans groupe'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final name in overview.studentsWithoutGroup)
                        ProtoChip(
                          label: name,
                          backgroundColor: context.sfSoftCard,
                          foregroundColor: context.sfMuted,
                        ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openGroup(String groupId) async {
    final navigator = Navigator.of(context);
    navigator.pop();
    await GroupPage.open(navigator.context, groupId: groupId);
  }

  Future<void> _create() async {
    final navigator = Navigator.of(context);
    navigator.pop();
    final created = await GroupFormPage.open(
      navigator.context,
      homework: widget.homework,
    );
    if (created != null && navigator.mounted) {
      await GroupPage.open(navigator.context, groupId: created.summary.id);
    }
  }
}
