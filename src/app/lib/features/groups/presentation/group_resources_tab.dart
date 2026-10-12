import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/exams/domain/exam_models.dart';
import 'package:studyflow_app/features/exams/presentation/revision_resource_viewer.dart';
import 'package:studyflow_app/features/groups/data/group_realtime.dart';
import 'package:studyflow_app/features/groups/data/group_repository.dart';
import 'package:studyflow_app/features/groups/domain/group_models.dart';

/// Liens et petits fichiers du groupe (mêmes règles de sécurité que les
/// fiches de révision), chiffrés sur le serveur.
class GroupResourcesTab extends StatefulWidget {
  const GroupResourcesTab({required this.group, super.key});

  final StudyGroupDetail group;

  @override
  State<GroupResourcesTab> createState() => _GroupResourcesTabState();
}

class _GroupResourcesTabState extends State<GroupResourcesTab>
    with AutomaticKeepAliveClientMixin {
  List<GroupResource>? _resources;
  String? _error;
  bool _busy = false;
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
              (x.area == 'resources' || x.area == 'reconnected'),
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
      final resources = await repository.listResources(
        groupId: _groupId,
        accessToken: await _token(),
      );
      if (mounted) {
        setState(() {
          _resources = resources;
          _error = null;
        });
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final resources = _resources;
    if (resources == null) {
      return _error == null
          ? const Center(child: CircularProgressIndicator())
          : ProtoStateCard(
              icon: Icons.cloud_off_outlined,
              title: 'Fichiers indisponibles',
              message: _error!,
              actionLabel: 'Réessayer',
              onAction: _load,
            );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: widget.group.summary.isArchived
          ? null
          : FloatingActionButton.extended(
              heroTag: 'group-resources-fab',
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              key: const ValueKey('group-resource-add'),
              backgroundColor: context.sfGroup,
              foregroundColor: context.sfCard,
              onPressed: _busy ? null : _add,
              icon: const Icon(Icons.attach_file),
              label: const Text('Ajouter'),
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
          children: [
            if (resources.isEmpty)
              const ProtoStateCard(
                icon: Icons.folder_shared_outlined,
                title: 'Rien de partagé',
                message:
                    'Liens (Drive, Canva, artefact Claude…) ou fichiers PDF, '
                    'images et pages HTML de 10 Mo maximum.',
                compact: true,
              ),
            for (final resource in resources)
              _ResourceTile(
                resource: resource,
                onOpen: () => _open(resource),
                onDelete: resource.canDelete ? () => _delete(resource) : null,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _add() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('group-resource-link'),
              leading: const Icon(Icons.link),
              title: const Text('Un lien'),
              subtitle: const Text('Drive, Canva, document en ligne…'),
              onTap: () => Navigator.pop(context, 'link'),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Un fichier'),
              subtitle: const Text('PDF, image, HTML ou texte · 10 Mo max'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'link') await _addLink();
    if (choice == 'file') await _addFile();
  }

  Future<void> _addLink() async {
    final url = TextEditingController();
    final title = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Partager un lien'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('group-link-url'),
              controller: url,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Lien (https://…)'),
            ),
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Titre (optionnel)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const ValueKey('group-link-save'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Partager'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(
        (repository, token) => repository.addLink(
          groupId: _groupId,
          url: url.text,
          title: title.text,
          accessToken: token,
        ),
      );
    }
    url.dispose();
    title.dispose();
  }

  Future<void> _addFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: RevisionFileRules.allowedExtensions,
      withData: true,
    );
    final file = picked?.files.singleOrNull;
    if (file == null || !mounted) return;
    final bytes = file.bytes;
    final problem = bytes == null
        ? 'Impossible de lire ce fichier.'
        : RevisionFileRules.check(file.name, bytes.length);
    if (problem != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    await _run(
      (repository, token) => repository.addFile(
        groupId: _groupId,
        fileName: file.name,
        bytes: bytes!,
        accessToken: token,
      ),
    );
  }

  Future<void> _run(
    Future<Object?> Function(GroupRepository repository, String? token) action,
  ) async {
    final appScope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action(appScope.groupRepository, await _token());
      if (mounted) await _load();
    } on Exception catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(GroupResource resource) async {
    if (resource.isLink) {
      final uri = Uri.tryParse(resource.url ?? '');
      if (uri != null) {
        await confirmAndOpenLink(context, uri, sharedBy: resource.authorName);
      }
      return;
    }

    final appScope = AppScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await appScope.groupRepository.downloadFile(
        resourceId: resource.id,
        accessToken: await _token(),
      );
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (context) =>
              RevisionFileViewer(resource: _asRevision(resource), bytes: bytes),
        ),
      );
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Ouverture impossible : $error')),
      );
    }
  }

  Future<void> _delete(GroupResource resource) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer cette ressource ?'),
        content: Text(
          '« ${resource.title} » ne sera plus visible par le groupe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run((repository, token) async {
      await repository.deleteResource(
        resourceId: resource.id,
        accessToken: token,
      );
      return null;
    });
  }
}

/// Le lecteur des fiches de révision sait déjà afficher PDF, images et HTML isolé.
RevisionResource _asRevision(GroupResource resource) => RevisionResource(
  id: resource.id,
  kind: resource.isLink ? RevisionResourceKind.link : RevisionResourceKind.file,
  title: resource.title,
  url: resource.url,
  fileName: resource.fileName,
  fileType: resource.fileType,
  sizeBytes: resource.sizeBytes,
  authorName: resource.authorName,
  isMine: resource.isMine,
  canEdit: resource.canDelete,
);

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.resource,
    required this.onOpen,
    this.onDelete,
  });

  final GroupResource resource;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final look = RevisionResourceLook.of(_asRevision(resource));
    return ProtoCard(
      key: ValueKey('group-resource-${resource.id}'),
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ProtoIconBox(
            icon: look.icon,
            size: 38,
            backgroundColor: context.sfGroupSoft,
            foregroundColor: context.sfGroup,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.sfText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${look.label} · ${resource.authorName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.sfMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Retirer',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 20),
            ),
        ],
      ),
    );
  }
}
