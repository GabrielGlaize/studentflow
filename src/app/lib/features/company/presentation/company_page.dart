import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/company/application/company_contacts_controller.dart';
import 'package:studyflow_app/features/company/application/company_documents_controller.dart';
import 'package:studyflow_app/features/profile/domain/app_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class CompanyPage extends StatefulWidget {
  const CompanyPage({required this.onOpenCompanyTasks, super.key});

  final VoidCallback onOpenCompanyTasks;

  @override
  State<CompanyPage> createState() => _CompanyPageState();
}

class _CompanyPageState extends State<CompanyPage> {
  @override
  Widget build(BuildContext context) {
    final appScope = AppScope.of(context);
    final settingsController = appScope.settingsController;
    final contactsController = appScope.companyContactsController;
    final documentsController = appScope.companyDocumentsController;

    return SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          settingsController,
          contactsController,
          documentsController,
        ]),
        builder: (context, _) {
          final companyDocuments = documentsController.documents
              .where((document) => document.scope == 'company')
              .toList(growable: false);
          final companyName = settingsController.companyName;
          final title = companyName?.trim().isNotEmpty == true
              ? companyName!.trim()
              : 'Entreprise';

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 112),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: context.sfText,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2,
                          ),
                    ),
                  ),
                  const ProtoIconBox(
                    icon: Icons.work_outline,
                    backgroundColor: AppColors.greenSoft,
                    foregroundColor: AppColors.green,
                    size: 42,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const ProtoMutedText(
                'Ton espace utile pour les ressources, tâches et contacts professionnels.',
              ),
              const SizedBox(height: 18),
              _CompanyNameCard(
                companyName: companyName,
                onEdit: _openCompanyNameSheet,
              ),
              _CompanyOverviewRow(
                documentCount: companyDocuments.length,
                contactCount: contactsController.contacts.length,
                onOpenCompanyTasks: widget.onOpenCompanyTasks,
              ),
              _DocumentsSection(
                documents: companyDocuments,
                onAddDocument: _openAddDocumentSheet,
                onDeleteDocument: documentsController.deleteDocument,
              ),
              _CompanyActionCard(
                key: const ValueKey('open-company-tasks-card'),
                icon: Icons.checklist_outlined,
                title: 'Tâches entreprise',
                subtitle:
                    'Retrouve les tâches liées à ton alternance ou à ton entreprise dans l’Agenda.',
                onTap: widget.onOpenCompanyTasks,
              ),
              _ContactsSection(
                contacts: contactsController.contacts,
                onAddContact: _openAddContactSheet,
                onDeleteContact: contactsController.deleteContact,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openAddContactSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AddContactSheet(),
    );
  }

  Future<void> _openAddDocumentSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AddDocumentSheet(),
    );
  }

  Future<void> _openCompanyNameSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _CompanyNameSheet(),
    );
  }
}

class _CompanyNameCard extends StatelessWidget {
  const _CompanyNameCard({required this.companyName, required this.onEdit});

  final String? companyName;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasName = companyName?.trim().isNotEmpty == true;

    return ProtoCard(
      onTap: onEdit,
      borderColor: AppColors.green.withValues(alpha: 0.35),
      backgroundColor: AppColors.greenSoft,
      child: Row(
        children: [
          ProtoIconBox(
            icon: Icons.business_center_outlined,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.white,
            foregroundColor: AppColors.green,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProtoOverline(hasName ? 'Entreprise' : 'À personnaliser'),
                const SizedBox(height: 3),
                Text(
                  hasName ? companyName!.trim() : 'Nom de ton entreprise',
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                const ProtoMutedText(
                  'Ce nom peut aussi apparaître dans l’onglet.',
                ),
              ],
            ),
          ),
          const Icon(Icons.edit_outlined, color: AppColors.green),
        ],
      ),
    );
  }
}

class _CompanyNameSheet extends StatefulWidget {
  const _CompanyNameSheet();

  @override
  State<_CompanyNameSheet> createState() => _CompanyNameSheetState();
}

class _CompanyNameSheetState extends State<_CompanyNameSheet> {
  final _nameController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _nameController.text =
        AppScope.of(context).settingsController.companyName ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProtoSectionHeading(
            overline: 'Entreprise',
            title: 'Nom affiché',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameController,
            maxLength: 32,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Exemple : Atelier Numérique',
              prefixIcon: Icon(Icons.business_center_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _save() {
    final appScope = AppScope.of(context);
    final settings = appScope.settingsController;
    settings.setCompanyName(_nameController.text);

    unawaited(() async {
      try {
        final accessToken = await appScope.sessionController
            .accessTokenForApi();
        await appScope.appPreferencesRepository.updatePreferences(
          preferences: RemoteAppPreferences(
            themeMode: settings.themeMode,
            hasCompany: settings.hasCompany,
            companyName: settings.companyName,
            professionalMode: ProfessionalMode.company,
          ),
          accessToken: accessToken,
        );
      } on Exception {
        // The local preference is already saved; syncing can be retried later.
      }
    }());

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

class _CompanyOverviewRow extends StatelessWidget {
  const _CompanyOverviewRow({
    required this.documentCount,
    required this.contactCount,
    required this.onOpenCompanyTasks,
  });

  final int documentCount;
  final int contactCount;
  final VoidCallback onOpenCompanyTasks;

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: _CompanyMetric(
              icon: Icons.folder_copy_outlined,
              label: 'Docs',
              value: '$documentCount',
              color: AppColors.sandSoft,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CompanyMetric(
              icon: Icons.groups_outlined,
              label: 'Contacts',
              value: '$contactCount',
              color: AppColors.greenSoft,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CompanyMetric(
              key: const ValueKey('open-company-tasks-metric'),
              icon: Icons.checklist_outlined,
              label: 'Tâches',
              value: 'Agenda',
              color: AppColors.primarySoft,
              onTap: onOpenCompanyTasks,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyMetric extends StatelessWidget {
  const _CompanyMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final metricBackground = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : color;
    final metricText = isDark ? Colors.white : context.sfText;
    final metricMuted = isDark
        ? Colors.white.withValues(alpha: 0.74)
        : context.sfMuted;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: metricBackground,
        borderRadius: BorderRadius.circular(15),
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.10))
            : null,
      ),
      child: Column(
        children: [
          Icon(icon, color: metricText, size: 18),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: metricText,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: metricMuted,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection({
    required this.documents,
    required this.onAddDocument,
    required this.onDeleteDocument,
  });

  final List<CompanyDocument> documents;
  final VoidCallback onAddDocument;
  final ValueChanged<String> onDeleteDocument;

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ProtoIconBox(
                  icon: Icons.folder_copy_outlined,
                  backgroundColor: AppColors.sandSoft,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: ProtoSectionHeading(
                    overline: 'Ressources',
                    title: 'Documents importants',
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('add-company-document-button'),
                  onPressed: onAddDocument,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (documents.isEmpty)
              const ProtoStateCard(
                icon: Icons.folder_open_outlined,
                title: 'Aucun document',
                message:
                    'Ajoute un contrat, une convention, un lien Drive ou une note utile.',
                compact: true,
              )
            else
              ...documents.map(
                (document) => _DocumentTile(
                  document: document,
                  onDelete: () => onDeleteDocument(document.id),
                  onOpen: () => _openDocument(context, document),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDocument(
    BuildContext context,
    CompanyDocument document,
  ) async {
    final link = document.link?.trim();
    final localPath = document.filePath?.trim();
    final uri = localPath != null && localPath.isNotEmpty
        ? Uri.file(localPath)
        : link != null && link.isNotEmpty
        ? Uri.tryParse(link)
        : null;
    if (uri == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Ajoute un fichier local, un lien Drive ou une note pour ouvrir ce document.',
            ),
          ),
        );
      return;
    }

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Lien impossible à ouvrir.')),
        );
    }
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.onDelete,
    required this.onOpen,
  });

  final CompanyDocument document;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final details = [
      document.kind,
      if (document.fileName != null) document.fileName!,
      if (document.link != null) document.link!,
      if (document.note != null) document.note!,
    ].join(' · ');

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.only(top: 11),
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.sfLine)),
        ),
        child: Row(
          children: [
            const ProtoIconBox(icon: Icons.description_outlined, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: TextStyle(
                      color: context.sfText,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  ProtoMutedText(details, maxLines: 2),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Supprimer le document',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              color: context.sfChevron,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddDocumentSheet extends StatefulWidget {
  const _AddDocumentSheet();

  @override
  State<_AddDocumentSheet> createState() => _AddDocumentSheetState();
}

class _AddDocumentSheetState extends State<_AddDocumentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _kindController = TextEditingController(text: 'Contrat');
  final _linkController = TextEditingController();
  final _noteController = TextEditingController();
  PlatformFile? _selectedFile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ajouter un document',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titre',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _kindController,
              decoration: const InputDecoration(
                labelText: 'Type',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _linkController,
              decoration: const InputDecoration(
                labelText: 'Lien optionnel',
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(
                _selectedFile == null
                    ? 'Importer depuis fichiers'
                    : 'Fichier : ${_selectedFile!.name}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note optionnelle',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Ajouter'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    final cleaned = (value ?? '').trim();
    if (cleaned.isEmpty) return 'Champ obligatoire.';
    if (cleaned.length > 120) return 'Maximum 120 caractères.';
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    AppScope.of(context).companyDocumentsController.addDocument(
      title: _titleController.text,
      kind: _kindController.text,
      link: _linkController.text,
      note: _noteController.text,
      fileName: _selectedFile?.name,
      filePath: _selectedFile?.path,
      fileSizeBytes: _selectedFile?.size,
    );

    Navigator.pop(context);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
    );
    final files = result?.files;
    final file = files == null || files.isEmpty ? null : files.first;
    if (file == null || !mounted) return;
    setState(() {
      _selectedFile = file;
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = file.name;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _kindController.dispose();
    _linkController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}

class _ContactsSection extends StatelessWidget {
  const _ContactsSection({
    required this.contacts,
    required this.onAddContact,
    required this.onDeleteContact,
  });

  final List<CompanyContact> contacts;
  final VoidCallback onAddContact;
  final ValueChanged<String> onDeleteContact;

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ProtoIconBox(
                  icon: Icons.groups_outlined,
                  backgroundColor: AppColors.greenSoft,
                  foregroundColor: AppColors.green,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: ProtoSectionHeading(
                    overline: 'Entreprise',
                    title: 'Contacts',
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('add-company-contact-button'),
                  onPressed: onAddContact,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (contacts.isEmpty)
              const ProtoStateCard(
                icon: Icons.person_add_alt_outlined,
                title: 'Aucun contact',
                message:
                    'Ajoute ton tuteur, un contact RH ou un référent utile.',
                compact: true,
              )
            else
              ...contacts.map(
                (contact) => _ContactTile(
                  contact: contact,
                  onDelete: () => onDeleteContact(contact.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onDelete});

  final CompanyContact contact;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final details = [
      contact.role,
      if (contact.email != null) contact.email!,
      if (contact.phone != null) contact.phone!,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.only(top: 11),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.sfLine)),
      ),
      child: Row(
        children: [
          const ProtoIconBox(
            icon: Icons.person_outline,
            size: 34,
            backgroundColor: AppColors.mint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                ProtoMutedText(details),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Supprimer le contact',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            color: context.sfChevron,
          ),
        ],
      ),
    );
  }
}

class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet();

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ajouter un contact',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _roleController,
              decoration: const InputDecoration(
                labelText: 'Rôle',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email optionnel',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Téléphone optionnel',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Ajouter'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    return (value ?? '').trim().isEmpty ? 'Champ obligatoire.' : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    AppScope.of(context).companyContactsController.addContact(
      name: _nameController.text,
      role: _roleController.text,
      email: _emailController.text,
      phone: _phoneController.text,
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

class _CompanyActionCard extends StatelessWidget {
  const _CompanyActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      onTap: onTap,
      child: Row(
        children: [
          ProtoIconBox(
            icon: icon,
            backgroundColor: AppColors.greenSoft,
            foregroundColor: AppColors.green,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                ProtoMutedText(subtitle),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.sfChevron),
        ],
      ),
    );
  }
}
