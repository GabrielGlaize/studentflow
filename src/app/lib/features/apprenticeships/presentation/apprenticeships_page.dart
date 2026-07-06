import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/apprenticeships/domain/apprenticeship_models.dart';
import 'package:studyflow_app/features/company/application/company_documents_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class ApprenticeshipsPage extends StatefulWidget {
  const ApprenticeshipsPage({this.onBackToCompany, super.key});

  final VoidCallback? onBackToCompany;

  @override
  State<ApprenticeshipsPage> createState() => _ApprenticeshipsPageState();
}

class _ApprenticeshipsPageState extends State<ApprenticeshipsPage> {
  final _keywordsController = TextEditingController(text: 'développeur');
  final _locationController = TextEditingController(text: 'Paris');
  Future<List<ApprenticeshipOpportunity>>? _resultsFuture;
  Future<List<ApprenticeshipMessage>>? _messagesFuture;
  Future<List<ApprenticeshipSavedSearch>>? _savedSearchesFuture;
  Future<List<FavoriteApprenticeshipOffer>>? _favoriteOffersFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resultsFuture ??= _search();
    _messagesFuture ??= _loadMessages();
    _savedSearchesFuture ??= _loadSavedSearches();
    _favoriteOffersFuture ??= _loadFavoriteOffers();
  }

  @override
  Widget build(BuildContext context) {
    final documentsController = AppScope.of(context).companyDocumentsController;

    return SafeArea(
      child: AnimatedBuilder(
        animation: documentsController,
        builder: (context, _) {
          final applicationDocuments = documentsController.documents
              .where((document) => document.scope == 'apprenticeship')
              .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.only(bottom: 112),
            children: [
              if (widget.onBackToCompany != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: widget.onBackToCompany,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Retour entreprise'),
                    ),
                  ),
                ),
              ProtoScreenTitle(
                title: 'Alternances',
                subtitle: 'Recherche officielle et entraide de classe.',
                trailing: const ProtoIconBox(
                  icon: Icons.work_outline,
                  backgroundColor: AppColors.greenSoft,
                  foregroundColor: AppColors.green,
                  size: 42,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: Column(
                  children: [
                    ProtoCard(
                      borderColor: const Color(0xFFB9E3DC),
                      backgroundColor: const Color(0xFFF1FFF9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ProtoSectionHeading(
                            overline: 'La bonne alternance',
                            title: 'Trouver une offre',
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _keywordsController,
                            decoration: const InputDecoration(
                              labelText: 'Métier, domaine ou mots-clés',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onSubmitted: (_) => _submitSearch(),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _locationController,
                                  decoration: const InputDecoration(
                                    labelText: 'Ville',
                                    prefixIcon: Icon(
                                      Icons.location_on_outlined,
                                    ),
                                  ),
                                  onSubmitted: (_) => _submitSearch(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                onPressed: _submitSearch,
                                icon: const Icon(Icons.search, size: 17),
                                label: const Text('Chercher'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: _saveCurrentSearch,
                              icon: const Icon(Icons.bookmark_add_outlined),
                              label: const Text('Sauvegarder la recherche'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _ApplicationDocumentsSection(
                      documents: applicationDocuments,
                      onAddDocument: _openAddApplicationDocumentSheet,
                      onDeleteDocument: documentsController.deleteDocument,
                    ),
                    FutureBuilder<List<ApprenticeshipSavedSearch>>(
                      future: _savedSearchesFuture,
                      builder: (context, snapshot) {
                        return _SavedSearchesSection(
                          searches: snapshot.data ?? const [],
                          isLoading:
                              snapshot.connectionState != ConnectionState.done,
                          onSelect: _runSavedSearch,
                          onDelete: _deleteSavedSearch,
                        );
                      },
                    ),
                    FutureBuilder<List<FavoriteApprenticeshipOffer>>(
                      future: _favoriteOffersFuture,
                      builder: (context, snapshot) {
                        return _FavoriteOffersSection(
                          offers: snapshot.data ?? const [],
                          isLoading:
                              snapshot.connectionState != ConnectionState.done,
                          onDelete: _deleteFavoriteOffer,
                        );
                      },
                    ),
                    FutureBuilder<List<ApprenticeshipMessage>>(
                      future: _messagesFuture,
                      builder: (context, snapshot) {
                        return _CommunitySection(
                          messages: snapshot.data ?? const [],
                          isLoading:
                              snapshot.connectionState != ConnectionState.done,
                          onShare: _openShareSheet,
                          onRetry: _refreshMessages,
                        );
                      },
                    ),
                  ],
                ),
              ),
              FutureBuilder<List<FavoriteApprenticeshipOffer>>(
                future: _favoriteOffersFuture,
                builder: (context, snapshot) {
                  return _ResultsSection(
                    future: _resultsFuture,
                    favorites: snapshot.data ?? const [],
                    onRetry: _submitSearch,
                    onToggleFavorite: _toggleFavorite,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openAddApplicationDocumentSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _AddApplicationDocumentSheet(),
    );
  }

  Future<List<ApprenticeshipOpportunity>> _search() async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();

    return appScope.apprenticeshipRepository.searchOpportunities(
      keywords: _keywordsController.text,
      location: _locationController.text,
      accessToken: accessToken,
    );
  }

  Future<List<ApprenticeshipMessage>> _loadMessages() async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();

    return appScope.apprenticeshipRepository.listCommunityMessages(
      accessToken: accessToken,
    );
  }

  Future<List<ApprenticeshipSavedSearch>> _loadSavedSearches() async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();

    return appScope.apprenticeshipRepository.listSavedSearches(
      accessToken: accessToken,
    );
  }

  Future<List<FavoriteApprenticeshipOffer>> _loadFavoriteOffers() async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();

    return appScope.apprenticeshipRepository.listFavoriteOffers(
      accessToken: accessToken,
    );
  }

  Future<void> _refreshSavedSearches() async {
    setState(() {
      _savedSearchesFuture = _loadSavedSearches();
    });
    await _savedSearchesFuture;
  }

  Future<void> _refreshFavoriteOffers() async {
    setState(() {
      _favoriteOffersFuture = _loadFavoriteOffers();
    });
    await _favoriteOffersFuture;
  }

  Future<void> _refreshMessages() async {
    setState(() {
      _messagesFuture = _loadMessages();
    });
    await _messagesFuture;
  }

  Future<void> _openShareSheet() async {
    final shared = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _ShareMessageSheet(),
    );

    if (shared == true && mounted) await _refreshMessages();
  }

  void _submitSearch() {
    setState(() {
      _resultsFuture = _search();
    });
  }

  Future<void> _saveCurrentSearch() async {
    final keywords = _keywordsController.text.trim();
    final location = _locationController.text.trim();
    if (keywords.isEmpty) {
      _showSnackBar('Ajoute au moins un mot-clé avant de sauvegarder.');
      return;
    }

    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.apprenticeshipRepository.saveSearch(
        search: ApprenticeshipSavedSearch(
          id: 'pending',
          name: location.isEmpty ? keywords : '$keywords · $location',
          keywords: keywords,
          location: location.isEmpty ? null : location,
          createdAt: DateTime.now(),
        ),
        accessToken: accessToken,
      );
      if (!mounted) return;
      _showSnackBar('Recherche sauvegardée.');
      await _refreshSavedSearches();
    } on Exception catch (error) {
      if (!mounted) return;
      _showSnackBar(error.toString());
    }
  }

  void _runSavedSearch(ApprenticeshipSavedSearch search) {
    _keywordsController.text = search.keywords;
    _locationController.text = search.location ?? '';
    _submitSearch();
  }

  Future<void> _deleteSavedSearch(ApprenticeshipSavedSearch search) async {
    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.apprenticeshipRepository.deleteSavedSearch(
        searchId: search.id,
        accessToken: accessToken,
      );
      if (!mounted) return;
      await _refreshSavedSearches();
    } on Exception catch (error) {
      if (!mounted) return;
      _showSnackBar(error.toString());
    }
  }

  Future<void> _toggleFavorite(
    ApprenticeshipOpportunity opportunity,
    FavoriteApprenticeshipOffer? favorite,
  ) async {
    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      if (favorite == null) {
        await appScope.apprenticeshipRepository.saveFavoriteOffer(
          opportunity: opportunity,
          accessToken: accessToken,
        );
        if (!mounted) return;
        _showSnackBar('Offre ajoutée aux favoris.');
      } else {
        await appScope.apprenticeshipRepository.deleteFavoriteOffer(
          favoriteId: favorite.id,
          accessToken: accessToken,
        );
        if (!mounted) return;
        _showSnackBar('Offre retirée des favoris.');
      }
      await _refreshFavoriteOffers();
    } on Exception catch (error) {
      if (!mounted) return;
      _showSnackBar(error.toString());
    }
  }

  Future<void> _deleteFavoriteOffer(FavoriteApprenticeshipOffer offer) async {
    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.apprenticeshipRepository.deleteFavoriteOffer(
        favoriteId: offer.id,
        accessToken: accessToken,
      );
      if (!mounted) return;
      await _refreshFavoriteOffers();
    } on Exception catch (error) {
      if (!mounted) return;
      _showSnackBar(error.toString());
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _keywordsController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}

class _ResultsSection extends StatelessWidget {
  const _ResultsSection({
    required this.future,
    required this.favorites,
    required this.onRetry,
    required this.onToggleFavorite,
  });

  final Future<List<ApprenticeshipOpportunity>>? future;
  final List<FavoriteApprenticeshipOffer> favorites;
  final VoidCallback onRetry;
  final Future<void> Function(
    ApprenticeshipOpportunity opportunity,
    FavoriteApprenticeshipOffer? favorite,
  )
  onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ApprenticeshipOpportunity>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ProtoPageLoader(label: 'Offres alternance');
        }

        if (snapshot.hasError) {
          return _ApprenticeshipError(onRetry: onRetry);
        }

        final opportunities = snapshot.requireData;
        if (opportunities.isEmpty) {
          return const _EmptyResults();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: ProtoSectionHeading(
                  overline: 'Offres',
                  title: 'Résultats recommandés',
                ),
              ),
              ...opportunities.map(
                (opportunity) => _OpportunityCard(
                  opportunity: opportunity,
                  favorite: _favoriteFor(opportunity),
                  onToggleFavorite: onToggleFavorite,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  FavoriteApprenticeshipOffer? _favoriteFor(
    ApprenticeshipOpportunity opportunity,
  ) {
    for (final favorite in favorites) {
      if (favorite.source == opportunity.source &&
          favorite.externalOfferId == opportunity.externalId) {
        return favorite;
      }
    }
    return null;
  }
}

class _ApplicationDocumentsSection extends StatelessWidget {
  const _ApplicationDocumentsSection({
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
      borderColor: const Color(0xFFCDE7E2),
      backgroundColor: const Color(0xFFF4FFFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ProtoIconBox(
                icon: Icons.folder_special_outlined,
                backgroundColor: AppColors.greenSoft,
                foregroundColor: AppColors.green,
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: ProtoSectionHeading(
                  overline: 'Candidature',
                  title: 'CV et lettres',
                ),
              ),
              TextButton.icon(
                onPressed: onAddDocument,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (documents.isEmpty)
            const ProtoMutedText(
              'Ajoute ton CV, ta lettre de motivation ou ton portfolio pour les retrouver vite.',
            )
          else
            ...documents.map(
              (document) => _ApplicationDocumentLine(
                document: document,
                onDelete: () => onDeleteDocument(document.id),
                onOpen: () => _openDocument(context, document),
              ),
            ),
        ],
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
              'Ajoute un fichier ou un lien pour ouvrir ce document.',
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

class _ApplicationDocumentLine extends StatelessWidget {
  const _ApplicationDocumentLine({
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(top: 9),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: context.sfCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.sfLine),
        ),
        child: Row(
          children: [
            ProtoIconBox(
              icon: _documentIcon(document.kind),
              size: 34,
              backgroundColor: AppColors.primarySoft,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.sfText,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  ProtoMutedText(details, maxLines: 2),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Supprimer',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              color: context.sfChevron,
            ),
          ],
        ),
      ),
    );
  }

  IconData _documentIcon(String kind) {
    final lowerKind = kind.toLowerCase();
    if (lowerKind.contains('cv')) return Icons.description_outlined;
    if (lowerKind.contains('lettre')) return Icons.mail_outline;
    return Icons.insert_drive_file_outlined;
  }
}

class _AddApplicationDocumentSheet extends StatefulWidget {
  const _AddApplicationDocumentSheet();

  @override
  State<_AddApplicationDocumentSheet> createState() =>
      _AddApplicationDocumentSheetState();
}

class _AddApplicationDocumentSheetState
    extends State<_AddApplicationDocumentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController(text: 'CV');
  final _linkController = TextEditingController();
  final _noteController = TextEditingController();
  String _kind = 'CV';
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
              overline: 'Candidature',
              title: 'Ajouter un document',
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(
                labelText: 'Type',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'CV', child: Text('CV')),
                DropdownMenuItem(
                  value: 'Lettre de motivation',
                  child: Text('Lettre de motivation'),
                ),
                DropdownMenuItem(value: 'Portfolio', child: Text('Portfolio')),
                DropdownMenuItem(value: 'Autre', child: Text('Autre')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _kind = value;
                  if (_titleController.text.trim().isEmpty ||
                      _titleController.text == 'CV') {
                    _titleController.text = value;
                  }
                });
              },
            ),
            const SizedBox(height: 12),
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
              controller: _linkController,
              decoration: const InputDecoration(
                labelText: 'Lien optionnel',
                prefixIcon: Icon(Icons.link_outlined),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(
                _selectedFile == null
                    ? 'Importer un fichier'
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
    return (value ?? '').trim().isEmpty ? 'Champ obligatoire.' : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    AppScope.of(context).companyDocumentsController.addDocument(
      title: _titleController.text,
      kind: _kind,
      scope: 'apprenticeship',
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
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
    );
    final files = result?.files;
    final file = files == null || files.isEmpty ? null : files.first;
    if (file == null || !mounted) return;
    setState(() {
      _selectedFile = file;
      if (_titleController.text.trim().isEmpty ||
          _titleController.text == _kind) {
        _titleController.text = file.name;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _linkController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}

class _SavedSearchesSection extends StatelessWidget {
  const _SavedSearchesSection({
    required this.searches,
    required this.isLoading,
    required this.onSelect,
    required this.onDelete,
  });

  final List<ApprenticeshipSavedSearch> searches;
  final bool isLoading;
  final ValueChanged<ApprenticeshipSavedSearch> onSelect;
  final ValueChanged<ApprenticeshipSavedSearch> onDelete;

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProtoSectionHeading(
            overline: 'Recherche',
            title: 'Recherches sauvegardées',
          ),
          const SizedBox(height: 10),
          if (isLoading)
            const LinearProgressIndicator(minHeight: 3)
          else if (searches.isEmpty)
            const ProtoMutedText(
              'Sauvegarde tes recherches utiles pour les relancer vite.',
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: searches
                  .map(
                    (search) => InputChip(
                      label: Text(search.name),
                      avatar: const Icon(Icons.bookmark_outline, size: 17),
                      onPressed: () => onSelect(search),
                      onDeleted: () => onDelete(search),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _FavoriteOffersSection extends StatelessWidget {
  const _FavoriteOffersSection({
    required this.offers,
    required this.isLoading,
    required this.onDelete,
  });

  final List<FavoriteApprenticeshipOffer> offers;
  final bool isLoading;
  final ValueChanged<FavoriteApprenticeshipOffer> onDelete;

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      borderColor: const Color(0xFFDCC9A8),
      backgroundColor: const Color(0xFFFFFAEF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProtoSectionHeading(
            overline: 'Favoris',
            title: 'Offres sauvegardées',
          ),
          const SizedBox(height: 10),
          if (isLoading)
            const LinearProgressIndicator(minHeight: 3)
          else if (offers.isEmpty)
            const ProtoMutedText(
              'Ajoute une offre en favori pour la retrouver rapidement.',
            )
          else
            ...offers
                .take(3)
                .map(
                  (offer) => _FavoriteOfferLine(
                    offer: offer,
                    onDelete: () => onDelete(offer),
                  ),
                ),
        ],
      ),
    );
  }
}

class _FavoriteOfferLine extends StatelessWidget {
  const _FavoriteOfferLine({required this.offer, required this.onDelete});

  final FavoriteApprenticeshipOffer offer;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: context.sfCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.sfLine),
      ),
      child: Row(
        children: [
          const ProtoIconBox(
            icon: Icons.star_outline,
            backgroundColor: AppColors.sandSoft,
            foregroundColor: Color(0xFF947035),
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => _openUrl(offer.url),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.sfText,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (offer.company != null) offer.company!,
                      if (offer.location != null) offer.location!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.sfMuted, fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Retirer des favoris',
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

class _CommunitySection extends StatelessWidget {
  const _CommunitySection({
    required this.messages,
    required this.isLoading,
    required this.onShare,
    required this.onRetry,
  });

  final List<ApprenticeshipMessage> messages;
  final bool isLoading;
  final VoidCallback onShare;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      borderColor: Color(0xFFB9D7E3),
      backgroundColor: Color(0xFFEDF8FD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProtoIconBox(
                icon: Icons.campaign_outlined,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.white,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProtoOverline('Communauté', color: context.sfText),
                    const SizedBox(height: 3),
                    Text(
                      'Offres partagées par la classe',
                      style: TextStyle(
                        color: context.sfText,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const ProtoMutedText(
                      'Centralise les bons plans sans remplacer Discord.',
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onShare,
                icon: const Icon(Icons.add),
                color: AppColors.green,
                tooltip: 'Partager une offre',
              ),
            ],
          ),
          if (isLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 3),
          ] else if (messages.isEmpty) ...[
            const SizedBox(height: 12),
            const ProtoMutedText(
              'Aucune offre partagée pour le moment. Sois le premier à aider la classe.',
            ),
          ] else ...[
            const SizedBox(height: 12),
            ...messages
                .take(2)
                .map((message) => _CommunityMessageCard(message)),
            if (messages.length > 2)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onRetry,
                  child: Text('${messages.length - 2} autres messages'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CommunityMessageCard extends StatelessWidget {
  const _CommunityMessageCard(this.message);

  final ApprenticeshipMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: context.sfCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.sfLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  message.authorName,
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _shortDate(message.createdAt),
                style: TextStyle(color: context.sfMuted, fontSize: 8),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ProtoMutedText(message.content, maxLines: 3),
          if (message.link != null) ...[
            const SizedBox(height: 7),
            InkWell(
              onTap: () => launchUrl(
                Uri.parse(message.link!),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                message.link!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShareMessageSheet extends StatefulWidget {
  const _ShareMessageSheet();

  @override
  State<_ShareMessageSheet> createState() => _ShareMessageSheetState();
}

class _ShareMessageSheetState extends State<_ShareMessageSheet> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _linkController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProtoSectionHeading(
              overline: 'Entraide alternance',
              title: 'Partager une offre',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Message',
                prefixIcon: Icon(Icons.chat_bubble_outline),
              ),
              minLines: 2,
              maxLines: 4,
              validator: (value) {
                return (value ?? '').trim().isEmpty
                    ? 'Écris un court message.'
                    : null;
              },
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
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSaving ? null : _submit,
                    child: Text(_isSaving ? 'Partage...' : 'Partager'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.apprenticeshipRepository.shareCommunityMessage(
        content: _contentController.text,
        link: _linkController.text,
        accessToken: accessToken,
      );
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _linkController.dispose();
    super.dispose();
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({
    required this.opportunity,
    required this.favorite,
    required this.onToggleFavorite,
  });

  final ApprenticeshipOpportunity opportunity;
  final FavoriteApprenticeshipOffer? favorite;
  final Future<void> Function(
    ApprenticeshipOpportunity opportunity,
    FavoriteApprenticeshipOffer? favorite,
  )
  onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final isFavorite = favorite != null;

    return ProtoCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ProtoIconBox(
                icon: Icons.business_center_outlined,
                backgroundColor: AppColors.greenSoft,
                foregroundColor: AppColors.green,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProtoOverline(opportunity.source, color: AppColors.green),
                    const SizedBox(height: 4),
                    Text(
                      opportunity.title,
                      style: TextStyle(
                        color: context.sfText,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (opportunity.company != null) opportunity.company!,
                        if (opportunity.location != null) opportunity.location!,
                        if (opportunity.distanceKm != null)
                          '${opportunity.distanceKm!.toStringAsFixed(1)} km',
                      ].join(' · '),
                      style: TextStyle(color: context.sfMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => onToggleFavorite(opportunity, favorite),
                tooltip: isFavorite
                    ? 'Retirer des favoris'
                    : 'Ajouter aux favoris',
                color: isFavorite ? const Color(0xFFC48A2C) : AppColors.muted,
                icon: Icon(isFavorite ? Icons.star : Icons.star_border),
              ),
            ],
          ),
          if (opportunity.summary != null) ...[
            const SizedBox(height: 11),
            ProtoMutedText(opportunity.summary!, maxLines: 3),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...opportunity.contractTypes.map(
                (contract) => ProtoChip(
                  label: contract,
                  backgroundColor: AppColors.greenSoft,
                  foregroundColor: AppColors.green,
                ),
              ),
              if (opportunity.targetDiploma != null)
                ProtoChip(
                  label: opportunity.targetDiploma!,
                  backgroundColor: AppColors.sandSoft,
                  foregroundColor: const Color(0xFF4F7891),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _openUrl(opportunity.applicationUrl),
              icon: const Icon(Icons.open_in_new, size: 17),
              label: const Text('Voir l’offre'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return const ProtoStateCard(
      icon: Icons.search_off_outlined,
      title: 'Aucune offre trouvée',
      message:
          'Essaie un mot-clé plus large, une autre ville ou une recherche “développeur”.',
    );
  }
}

class _ApprenticeshipError extends StatelessWidget {
  const _ApprenticeshipError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ProtoStateCard(
      icon: Icons.cloud_off_outlined,
      title: 'Offres indisponibles',
      message: 'La source d’alternances ne répond pas pour le moment.',
      actionLabel: 'Réessayer',
      onAction: onRetry,
    );
  }
}

String _shortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month · $hour:$minute';
}
