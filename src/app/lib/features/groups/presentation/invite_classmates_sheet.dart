import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/groups/domain/group_models.dart';
import 'package:studyflow_app/features/groups/presentation/group_widgets.dart';

/// Choisir des camarades de classe à inviter. Ceux qui ont déjà un groupe pour
/// le devoir sont affichés mais pas sélectionnables.
class InviteClassmatesSheet extends StatefulWidget {
  const InviteClassmatesSheet({
    this.homeworkId,
    this.groupId,
    this.alreadySelected = const {},
    super.key,
  });

  final String? homeworkId;
  final String? groupId;
  final Set<String> alreadySelected;

  static Future<List<Classmate>?> show(
    BuildContext context, {
    String? homeworkId,
    String? groupId,
    Set<String> alreadySelected = const {},
  }) {
    return showModalBottomSheet<List<Classmate>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => InviteClassmatesSheet(
        homeworkId: homeworkId,
        groupId: groupId,
        alreadySelected: alreadySelected,
      ),
    );
  }

  @override
  State<InviteClassmatesSheet> createState() => _InviteClassmatesSheetState();
}

class _InviteClassmatesSheetState extends State<InviteClassmatesSheet> {
  Future<List<Classmate>>? _future;
  late final Set<String> _selected = {...widget.alreadySelected};
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<Classmate>> _load() async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    return appScope.groupRepository.classmates(
      homeworkId: widget.homeworkId,
      groupId: widget.groupId,
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
        child: FutureBuilder<List<Classmate>>(
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
                child: ProtoMutedText('Impossible de charger la classe.'),
              );
            }

            final all = snapshot.requireData;
            final query = _query.trim().toLowerCase();
            final visible = all
                .where(
                  (x) => query.isEmpty || x.name.toLowerCase().contains(query),
                )
                .toList();

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ProtoSectionHeading(title: 'Inviter des camarades'),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Rechercher',
                          isDense: true,
                        ),
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final classmate in visible)
                        _ClassmateTile(
                          classmate: classmate,
                          selected: _selected.contains(classmate.userId),
                          onChanged: (selected) => setState(() {
                            if (selected) {
                              _selected.add(classmate.userId);
                            } else {
                              _selected.remove(classmate.userId);
                            }
                          }),
                        ),
                      if (visible.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: ProtoMutedText('Personne à inviter.'),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: FilledButton(
                    key: const ValueKey('invite-confirm'),
                    onPressed: () => Navigator.pop(
                      context,
                      all.where((x) => _selected.contains(x.userId)).toList(),
                    ),
                    child: Text(
                      _selected.isEmpty
                          ? 'Valider'
                          : _selected.length == 1
                          ? 'Inviter 1 personne'
                          : 'Inviter ${_selected.length} personnes',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ClassmateTile extends StatelessWidget {
  const _ClassmateTile({
    required this.classmate,
    required this.selected,
    required this.onChanged,
  });

  final Classmate classmate;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final taken = classmate.groupName != null;
    final here = classmate.isInvitedHere;
    final enabled = !taken && !here;

    return CheckboxListTile(
      key: ValueKey('invite-${classmate.userId}'),
      value: here || selected,
      onChanged: enabled ? (value) => onChanged(value ?? false) : null,
      secondary: GroupAvatar(initials: initialsOf(classmate.name), size: 34),
      title: Text(classmate.name),
      subtitle: here
          ? const Text('Déjà dans le groupe')
          : taken
          ? Text(
              'Déjà dans « ${classmate.groupName} »',
              style: TextStyle(color: context.sfMuted),
            )
          : null,
      activeColor: context.sfGroup,
    );
  }
}
