import 'package:studyflow_app/core/demo/demo_session_state.dart';
import 'package:studyflow_app/features/apprenticeships/data/apprenticeship_repository.dart';
import 'package:studyflow_app/features/apprenticeships/domain/apprenticeship_models.dart';

class DemoApprenticeshipRepository implements ApprenticeshipRepository {
  const DemoApprenticeshipRepository();

  static final List<ApprenticeshipMessage> _messages = [
    ApprenticeshipMessage(
      id: 'message-1',
      content:
          'Atelier Numérique cherche encore un alternant Flutter. Offre sérieuse, entretien rapide.',
      link: 'https://labonnealternance.apprentissage.beta.gouv.fr',
      authorName: 'Lina Moreau',
      createdAt: DateTime(2026, 6, 24, 10, 15),
    ),
    ApprenticeshipMessage(
      id: 'message-2',
      content:
          'Pensez à filtrer avec “développeur .NET”, il y a plus de résultats que “informatique”.',
      authorName: 'Gabriel Demo',
      createdAt: DateTime(2026, 6, 23, 17, 40),
    ),
  ];
  static final List<ApprenticeshipSavedSearch> _savedSearches = [
    ApprenticeshipSavedSearch(
      id: 'search-1',
      name: 'Flutter · Paris',
      keywords: 'développeur Flutter',
      location: 'Paris',
      createdAt: DateTime(2026, 6, 24, 9),
    ),
  ];
  static final List<FavoriteApprenticeshipOffer> _favoriteOffers = [];

  @override
  Future<List<ApprenticeshipOpportunity>> searchOpportunities({
    required String keywords,
    String? location,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final city = location?.trim().isEmpty ?? true ? 'Paris' : location!.trim();
    final searched = keywords.trim().isEmpty
        ? 'développement'
        : keywords.trim();

    return [
      ApprenticeshipOpportunity(
        source: 'demo',
        externalId: 'demo-1',
        opportunityType: 'job',
        title: 'Alternance $searched Flutter',
        company: 'Atelier Numérique',
        location: city,
        distanceKm: 4.2,
        publishedAt: DateTime.now().subtract(const Duration(days: 2)),
        contractTypes: const ['Apprentissage'],
        targetDiploma: 'Bac+2',
        summary:
            'Participation au développement d’une application mobile Flutter avec une API .NET.',
        applicationUrl: 'https://labonnealternance.apprentissage.beta.gouv.fr',
      ),
      ApprenticeshipOpportunity(
        source: 'demo',
        externalId: 'demo-2',
        opportunityType: 'job',
        title: 'Développeur backend .NET en alternance',
        company: 'Data School Factory',
        location: city,
        distanceKm: 8.7,
        publishedAt: DateTime.now().subtract(const Duration(days: 5)),
        contractTypes: const ['Professionnalisation', 'Apprentissage'],
        targetDiploma: 'Bac+3',
        summary:
            'Création d’API, modélisation PostgreSQL et contribution à une plateforme éducative.',
        applicationUrl: 'https://labonnealternance.apprentissage.beta.gouv.fr',
      ),
    ];
  }

  @override
  Future<List<ApprenticeshipSavedSearch>> listSavedSearches({
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return List.unmodifiable(_savedSearches);
  }

  @override
  Future<ApprenticeshipSavedSearch> saveSearch({
    required ApprenticeshipSavedSearch search,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));

    final savedSearch = ApprenticeshipSavedSearch(
      id: 'search-${_savedSearches.length + 1}',
      name: search.name.trim(),
      keywords: search.keywords.trim(),
      location: search.location?.trim(),
      distanceKm: search.distanceKm,
      filtersJson: search.filtersJson,
      alertEnabled: search.alertEnabled,
      createdAt: DateTime.now(),
    );
    _savedSearches.removeWhere(
      (item) =>
          item.keywords.toLowerCase() == savedSearch.keywords.toLowerCase() &&
          (item.location ?? '').toLowerCase() ==
              (savedSearch.location ?? '').toLowerCase(),
    );
    _savedSearches.insert(0, savedSearch);
    return savedSearch;
  }

  @override
  Future<void> deleteSavedSearch({
    required String searchId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _savedSearches.removeWhere((search) => search.id == searchId);
  }

  @override
  Future<List<FavoriteApprenticeshipOffer>> listFavoriteOffers({
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return List.unmodifiable(_favoriteOffers);
  }

  @override
  Future<FavoriteApprenticeshipOffer> saveFavoriteOffer({
    required ApprenticeshipOpportunity opportunity,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));

    FavoriteApprenticeshipOffer? existing;
    for (final favorite in _favoriteOffers) {
      if (favorite.source == opportunity.source &&
          favorite.externalOfferId == opportunity.externalId) {
        existing = favorite;
        break;
      }
    }
    if (existing != null) return existing;

    final favorite = FavoriteApprenticeshipOffer.fromOpportunity(
      id: 'favorite-${_favoriteOffers.length + 1}',
      opportunity: opportunity,
      savedAt: DateTime.now(),
    );
    _favoriteOffers.insert(0, favorite);
    return favorite;
  }

  @override
  Future<void> deleteFavoriteOffer({
    required String favoriteId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _favoriteOffers.removeWhere((favorite) => favorite.id == favoriteId);
  }

  @override
  Future<List<ApprenticeshipMessage>> listCommunityMessages({
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (DemoSessionState.hasNoClass(accessToken)) return const [];
    return List.unmodifiable(_messages);
  }

  @override
  Future<ApprenticeshipMessage> shareCommunityMessage({
    required String content,
    String? link,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (DemoSessionState.hasNoClass(accessToken)) {
      throw StateError('Rejoins une classe pour partager une offre.');
    }

    final message = ApprenticeshipMessage(
      id: 'message-${_messages.length + 1}',
      content: content.trim(),
      link: link?.trim().isEmpty ?? true ? null : link!.trim(),
      authorName: 'Gabriel Demo',
      createdAt: DateTime.now(),
    );
    _messages.insert(0, message);
    return message;
  }
}
