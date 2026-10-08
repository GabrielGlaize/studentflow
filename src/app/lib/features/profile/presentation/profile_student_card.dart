part of 'profile_page.dart';

class _StudentCardSection extends StatelessWidget {
  const _StudentCardSection({
    required this.document,
    required this.isDelegate,
    required this.onImport,
    required this.onOpen,
    required this.onDelete,
  });

  final CompanyDocument? document;
  final bool isDelegate;
  final VoidCallback onImport;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final hasCard = document != null;

    return ProtoCard(
      borderColor: hasCard ? AppColors.mint : AppColors.line,
      backgroundColor: hasCard ? const Color(0xFFEFFFFB) : Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoIconBox(
            icon: hasCard ? Icons.badge_outlined : Icons.add_photo_alternate,
            backgroundColor: hasCard ? AppColors.mint : AppColors.primarySoft,
            foregroundColor: AppColors.petrol,
            size: 45,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProtoOverline(isDelegate ? 'Accès rapide' : 'Carte étudiante'),
                const SizedBox(height: 3),
                Text(
                  hasCard
                      ? 'Carte étudiante enregistrée'
                      : 'Importer ma carte étudiante',
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                ProtoMutedText(
                  hasCard
                      ? [
                          if (document!.fileName != null) document!.fileName!,
                          if (document!.link != null) document!.link!,
                          if (document!.note != null) document!.note!,
                        ].where((value) => value.trim().isNotEmpty).join(' · ')
                      : 'Ajoute une photo, un lien Drive ou une note pour la retrouver vite.',
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (hasCard)
                      FilledButton.icon(
                        onPressed: onOpen,
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('Voir'),
                      ),
                    OutlinedButton.icon(
                      onPressed: onImport,
                      icon: Icon(
                        hasCard ? Icons.edit_outlined : Icons.upload_outlined,
                        size: 16,
                      ),
                      label: Text(hasCard ? 'Modifier' : 'Importer'),
                    ),
                    if (hasCard && onDelete != null)
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Retirer'),
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

class _StudentCardImportSheet extends StatefulWidget {
  const _StudentCardImportSheet();

  @override
  State<_StudentCardImportSheet> createState() =>
      _StudentCardImportSheetState();
}

class _StudentCardImportSheetState extends State<_StudentCardImportSheet> {
  final _formKey = GlobalKey<FormState>();
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
            const ProtoSectionHeading(
              overline: 'Profil',
              title: 'Carte étudiante',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _linkController,
              decoration: const InputDecoration(
                labelText: 'Lien ou emplacement optionnel',
                prefixIcon: Icon(Icons.link_outlined),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickStudentCard,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _selectedFile == null
                    ? 'Importer photo ou fichier'
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
                    child: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final controller = AppScope.of(context).companyDocumentsController;
    for (final document in controller.documents) {
      if (document.scope == 'student-card') {
        controller.deleteDocument(document.id);
      }
    }
    controller.addDocument(
      title: 'Carte étudiante',
      kind: 'Carte étudiante',
      scope: 'student-card',
      link: _linkController.text,
      note: _noteController.text,
      fileName: _selectedFile?.name,
      filePath: _selectedFile?.path,
      fileSizeBytes: _selectedFile?.size,
    );

    Navigator.pop(context);
  }

  Future<void> _pickStudentCard() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
      type: FileType.image,
    );
    final files = result?.files;
    final file = files == null || files.isEmpty ? null : files.first;
    if (file == null || !mounted) return;
    setState(() {
      _selectedFile = file;
    });
  }

  @override
  void dispose() {
    _linkController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
