import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/exams/domain/exam_models.dart';
import 'package:studyflow_app/features/exams/presentation/exam_widgets.dart';
import 'package:studyflow_app/features/exams/presentation/revision_resource_viewer.dart';

/// Fiche de révision d'une matière : ce qu'il faut réviser (chacun coche pour
/// lui) et les ressources partagées par la classe.
class ExamSubjectPage extends StatefulWidget {
  const ExamSubjectPage({
    required this.examSubjectId,
    required this.palette,
    super.key,
  });

  final String examSubjectId;
  final SubjectPalette palette;

  static Future<void> open(
    BuildContext context, {
    required String examSubjectId,
    required SubjectPalette palette,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            ExamSubjectPage(examSubjectId: examSubjectId, palette: palette),
      ),
    );
  }

  @override
  State<ExamSubjectPage> createState() => _ExamSubjectPageState();
}

class _ExamSubjectPageState extends State<ExamSubjectPage> {
  final _itemController = TextEditingController();
  final _itemFocus = FocusNode();
  final _itemsScroll = ScrollController();
  ExamSubjectSheet? _sheet;
  Object? _error;
  bool _sending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sheet == null && _error == null) _load();
  }

  @override
  void dispose() {
    _itemController.dispose();
    _itemFocus.dispose();
    _itemsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _sheet;
    final accent = widget.palette.accent(context);

    return DefaultTabController(
      length: 2,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          appBar: AppBar(title: Text(sheet?.name ?? 'Fiche de révision')),
          body: sheet == null
              ? (_error != null
                    ? ProtoStateCard(
                        icon: Icons.cloud_off_outlined,
                        title: 'Fiche indisponible',
                        message: 'Impossible de charger cette fiche.',
                        actionLabel: 'Réessayer',
                        onAction: () {
                          setState(() => _error = null);
                          _load();
                        },
                      )
                    : const ProtoPageLoader(label: 'Fiche de révision'))
              : Column(
                  children: [
                    // Clavier ouvert : on laisse la place à la liste.
                    if (MediaQuery.viewInsetsOf(context).bottom == 0)
                      _SheetHeader(sheet: sheet, palette: widget.palette),
                    Material(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: TabBar(
                        labelColor: context.sfText,
                        unselectedLabelColor: context.sfMuted,
                        indicatorColor: accent,
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                        tabs: [
                          Tab(text: 'À réviser (${sheet.items.length})'),
                          Tab(text: 'Ressources (${sheet.resources.length})'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildItemsTab(sheet),
                          _buildResourcesTab(sheet),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildItemsTab(ExamSubjectSheet sheet) {
    final accent = widget.palette.accent(context);

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: sheet.items.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                    children: [
                      Icon(Icons.checklist_rtl, size: 44, color: accent),
                      const SizedBox(height: 12),
                      Text(
                        'Rien à réviser pour l’instant',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.sfText,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Lance la fiche : un chapitre, une notion, un exercice type…',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : ListView.separated(
                    controller: _itemsScroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: sheet.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _RevisionItemTile(
                      item: sheet.items[index],
                      accent: accent,
                      onToggle: () => _toggle(sheet.items[index]),
                      onEdit: () => _editItem(sheet.items[index]),
                      onDelete: () => _deleteItem(sheet.items[index]),
                    ),
                  ),
          ),
        ),
        if (sheet.canContribute) _buildComposer(accent),
      ],
    );
  }

  Widget _buildComposer(Color accent) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        8,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: context.sfCard,
        border: Border(top: BorderSide(color: context.sfLine)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('revision-item-field'),
              controller: _itemController,
              focusNode: _itemFocus,
              minLines: 1,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _addItem(),
              decoration: const InputDecoration(
                hintText: 'Ajouter un point à réviser…',
                counterText: '',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: const ValueKey('revision-item-send'),
            tooltip: 'Ajouter',
            onPressed: _sending ? null : _addItem,
            style: IconButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: context.sfIsDark
                  ? AppColors.petrolDark
                  : Colors.white,
            ),
            icon: const Icon(Icons.arrow_upward),
          ),
        ],
      ),
    );
  }

  Widget _buildResourcesTab(ExamSubjectSheet sheet) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          if (sheet.canContribute) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('add-link-button'),
                    onPressed: _addLink,
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Un lien'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('add-file-button'),
                    onPressed: _addFile,
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Un fichier'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 16, color: context.sfMuted),
                const SizedBox(width: 6),
                const Expanded(
                  child: ProtoMutedText(
                    'Fichiers acceptés : ${RevisionFileRules.acceptedLabel}. Les programmes (.exe, .apk…) et les archives sont refusés.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (sheet.resources.isEmpty)
            const ProtoStateCard(
              icon: Icons.folder_open_outlined,
              title: 'Aucune ressource',
              message:
                  'Partage un artefact Claude, une vidéo, une fiche PDF ou une page HTML pour réviser.',
              compact: true,
            )
          else
            for (final resource in sheet.resources)
              _ResourceTile(
                resource: resource,
                onOpen: () => openRevisionResource(context, resource),
                onDelete: () => _deleteResource(resource),
              ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final sheet = await appScope.examRepository.getSheet(
        examSubjectId: widget.examSubjectId,
        accessToken: accessToken,
      );
      if (mounted) setState(() => _sheet = sheet);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _addItem() async {
    final text = _itemController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final item = await appScope.examRepository.addItem(
        examSubjectId: widget.examSubjectId,
        text: text,
        accessToken: accessToken,
      );
      _itemController.clear();
      if (mounted) {
        setState(() => _sheet = _withItems([..._sheet!.items, item]));
        // Le nouveau point arrive en bas de la liste : on le montre.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_itemsScroll.hasClients) return;
          _itemsScroll.animateTo(
            _itemsScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        });
      }
    } on Exception catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// La case est mise à jour tout de suite, puis confirmée par le serveur.
  Future<void> _toggle(RevisionItem item) async {
    final checked = !item.checkedByMe;
    _replaceItem(
      item.copyWith(
        checkedByMe: checked,
        checkCount: item.checkCount + (checked ? 1 : -1),
      ),
    );

    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.examRepository.setItemChecked(
        itemId: item.id,
        checked: checked,
        accessToken: accessToken,
      );
    } on Exception catch (error) {
      _replaceItem(item);
      _showError(error);
    }
  }

  Future<void> _editItem(RevisionItem item) async {
    final controller = TextEditingController(text: item.text);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le point'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
          maxLength: 500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty || !mounted) return;

    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final updated = await appScope.examRepository.updateItem(
        itemId: item.id,
        text: text,
        accessToken: accessToken,
      );
      _replaceItem(updated);
    } on Exception catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteItem(RevisionItem item) async {
    final confirmed = await _confirm(
      title: 'Retirer ce point ?',
      message: '« ${item.text} » disparaîtra de la fiche pour toute la classe.',
    );
    if (!confirmed || !mounted) return;

    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.examRepository.deleteItem(
        itemId: item.id,
        accessToken: accessToken,
      );
      if (mounted) {
        setState(
          () => _sheet = _withItems(
            _sheet!.items.where((x) => x.id != item.id).toList(),
          ),
        );
      }
    } on Exception catch (error) {
      _showError(error);
    }
  }

  Future<void> _addLink() async {
    final resource = await showModalBottomSheet<RevisionResource>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AddLinkSheet(examSubjectId: widget.examSubjectId),
    );
    if (resource != null && mounted) _prependResource(resource);
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
      _showMessage(problem);
      return;
    }

    final resource = await showModalBottomSheet<RevisionResource>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _UploadFileSheet(
        examSubjectId: widget.examSubjectId,
        fileName: file.name,
        bytes: bytes!,
      ),
    );
    if (resource != null && mounted) _prependResource(resource);
  }

  Future<void> _deleteResource(RevisionResource resource) async {
    final confirmed = await _confirm(
      title: 'Retirer cette ressource ?',
      message: '« ${resource.title} » ne sera plus visible par la classe.',
    );
    if (!confirmed || !mounted) return;

    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.examRepository.deleteResource(
        resourceId: resource.id,
        accessToken: accessToken,
      );
      if (mounted) {
        setState(
          () => _sheet = _withResources(
            _sheet!.resources.where((x) => x.id != resource.id).toList(),
          ),
        );
      }
    } on Exception catch (error) {
      _showError(error);
    }
  }

  void _prependResource(RevisionResource resource) {
    setState(() => _sheet = _withResources([resource, ..._sheet!.resources]));
  }

  void _replaceItem(RevisionItem item) {
    if (!mounted || _sheet == null) return;
    setState(
      () => _sheet = _withItems([
        for (final x in _sheet!.items) x.id == item.id ? item : x,
      ]),
    );
  }

  ExamSubjectSheet _withItems(List<RevisionItem> items) =>
      _copy(items: items, resources: _sheet!.resources);

  ExamSubjectSheet _withResources(List<RevisionResource> resources) =>
      _copy(items: _sheet!.items, resources: resources);

  ExamSubjectSheet _copy({
    required List<RevisionItem> items,
    required List<RevisionResource> resources,
  }) {
    final sheet = _sheet!;
    return ExamSubjectSheet(
      id: sheet.id,
      sessionId: sheet.sessionId,
      sessionTitle: sheet.sessionTitle,
      subjectId: sheet.subjectId,
      name: sheet.name,
      examDay: sheet.examDay,
      startsAt: sheet.startsAt,
      details: sheet.details,
      canContribute: sheet.canContribute,
      items: items,
      resources: resources,
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showError(Object error) {
    final text = error.toString();
    _showMessage(text.startsWith('Bad state: ') ? text.substring(11) : text);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.sheet, required this.palette});

  final ExamSubjectSheet sheet;
  final SubjectPalette palette;

  @override
  Widget build(BuildContext context) {
    final accent = palette.accent(context);
    final total = sheet.items.length;
    final checked = sheet.checkedCount;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.soft(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_outlined, size: 16, color: accent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        examSlotLabel(sheet.examDay, sheet.startsAt),
                        style: TextStyle(
                          color: context.sfText,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                if (sheet.details case final details?) ...[
                  const SizedBox(height: 4),
                  Text(
                    details,
                    style: TextStyle(color: context.sfText, fontSize: 14),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  total == 0
                      ? sheet.sessionTitle
                      : 'Tu as révisé $checked point${checked > 1 ? 's' : ''} sur $total',
                  style: TextStyle(color: context.sfMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ProgressRing(
            value: total == 0 ? 0 : checked / total,
            color: accent,
            size: 58,
            strokeWidth: 6,
            label: total == 0 ? '–' : null,
          ),
        ],
      ),
    );
  }
}

class _RevisionItemTile extends StatelessWidget {
  const _RevisionItemTile({
    required this.item,
    required this.accent,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final RevisionItem item;
  final Color accent;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final others = item.checkCount - (item.checkedByMe ? 1 : 0);

    return Material(
      color: context.sfCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: item.checkedByMe
              ? accent.withValues(alpha: 0.5)
              : context.sfLine,
        ),
      ),
      child: InkWell(
        key: ValueKey('revision-item-${item.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.checkedByMe ? accent : Colors.transparent,
                  border: Border.all(
                    color: item.checkedByMe ? accent : context.sfMuted,
                    width: 2,
                  ),
                ),
                child: item.checkedByMe
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: context.sfIsDark
                            ? AppColors.petrolDark
                            : Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.text,
                      style: TextStyle(
                        color: item.checkedByMe
                            ? context.sfMuted
                            : context.sfText,
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        item.isMine
                            ? 'Ajouté par toi'
                            : 'par ${item.authorName}',
                        if (others > 0)
                          '$others autre${others > 1 ? 's' : ''} l’${others > 1 ? 'ont' : 'a'} révisé',
                      ].join(' · '),
                      style: TextStyle(color: context.sfMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (item.canEdit)
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  icon: Icon(Icons.more_vert, color: context.sfChevron),
                  onSelected: (value) =>
                      value == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(value: 'delete', child: Text('Retirer')),
                  ],
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.resource,
    required this.onOpen,
    required this.onDelete,
  });

  final RevisionResource resource;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final look = RevisionResourceLook.of(resource);
    final color = look.color(context);
    final detail = resource.isLink
        ? '${resource.linkKind.label} · ${Uri.tryParse(resource.url ?? '')?.host ?? ''}'
        : [
            look.label,
            if (resource.sizeBytes != null)
              RevisionFileRules.size(resource.sizeBytes!),
          ].join(' · ');

    return ProtoCard(
      onTap: onOpen,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: Row(
        children: [
          ProtoIconBox(
            icon: look.icon,
            backgroundColor: color.withValues(alpha: 0.14),
            foregroundColor: color,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.sfMuted, fontSize: 13),
                ),
                Text(
                  resource.isMine
                      ? 'Partagé par toi'
                      : 'par ${resource.authorName}',
                  style: TextStyle(color: context.sfMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (resource.canEdit)
            IconButton(
              tooltip: 'Retirer',
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline, color: context.sfChevron),
            )
          else
            Icon(Icons.chevron_right, color: context.sfChevron),
        ],
      ),
    );
  }
}

class _AddLinkSheet extends StatefulWidget {
  const _AddLinkSheet({required this.examSubjectId});

  final String examSubjectId;

  @override
  State<_AddLinkSheet> createState() => _AddLinkSheetState();
}

class _AddLinkSheetState extends State<_AddLinkSheet> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = _urlController.text.trim();
    final kind = RevisionLinkKind.of(url);
    final valid = url.isNotEmpty && RevisionLinkRules.check(url) == null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Partager un lien',
            style: TextStyle(
              color: context.sfText,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const ProtoMutedText(
            'Artefact Claude, vidéo, document en ligne… Toute la classe le verra.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('link-url-field'),
            controller: _urlController,
            autofocus: true,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: 'Lien (https://…)',
              prefixIcon: const Icon(Icons.link),
              errorText: _error,
            ),
          ),
          if (valid) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  RevisionResourceLook.linkIcon(kind),
                  size: 16,
                  color: context.sfAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  '${kind.label} · ${Uri.parse(url).host}',
                  style: TextStyle(
                    color: context.sfAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('link-title-field'),
            controller: _titleController,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Titre (optionnel)',
              hintText: 'Quiz sur les intégrales',
              prefixIcon: Icon(Icons.title),
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('link-save-button'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Partage…' : 'Partager le lien'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final problem = RevisionLinkRules.check(_urlController.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() => _saving = true);
    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final resource = await appScope.examRepository.addLink(
        examSubjectId: widget.examSubjectId,
        url: _urlController.text,
        title: _titleController.text,
        accessToken: accessToken,
      );
      if (mounted) Navigator.pop(context, resource);
    } on Exception catch (error) {
      final text = error.toString();
      if (mounted) {
        setState(
          () => _error = text.startsWith('Bad state: ')
              ? text.substring(11)
              : text,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _UploadFileSheet extends StatefulWidget {
  const _UploadFileSheet({
    required this.examSubjectId,
    required this.fileName,
    required this.bytes,
  });

  final String examSubjectId;
  final String fileName;
  final List<int> bytes;

  @override
  State<_UploadFileSheet> createState() => _UploadFileSheetState();
}

class _UploadFileSheetState extends State<_UploadFileSheet> {
  late final _titleController = TextEditingController(
    text: widget.fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Partager un fichier',
            style: TextStyle(
              color: context.sfText,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ProtoCard(
            margin: EdgeInsets.zero,
            child: Row(
              children: [
                Icon(Icons.insert_drive_file_outlined, color: context.sfAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.sfText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  RevisionFileRules.size(widget.bytes.length),
                  style: TextStyle(color: context.sfMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Titre',
              prefixIcon: const Icon(Icons.title),
              counterText: '',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 4),
          const ProtoMutedText(
            'Le serveur vérifie le contenu du fichier avant de le partager.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('file-upload-button'),
            onPressed: _saving ? null : _upload,
            child: Text(_saving ? 'Envoi…' : 'Partager le fichier'),
          ),
        ],
      ),
    );
  }

  Future<void> _upload() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final resource = await appScope.examRepository.addFile(
        examSubjectId: widget.examSubjectId,
        fileName: widget.fileName,
        bytes: widget.bytes,
        title: _titleController.text,
        accessToken: accessToken,
      );
      if (mounted) Navigator.pop(context, resource);
    } on Exception catch (error) {
      final text = error.toString();
      if (mounted) {
        setState(
          () => _error = text.startsWith('Bad state: ')
              ? text.substring(11)
              : text,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
