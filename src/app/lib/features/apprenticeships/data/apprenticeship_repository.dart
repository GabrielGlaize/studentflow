import 'package:studyflow_app/features/apprenticeships/domain/apprenticeship_models.dart';

abstract interface class ApprenticeshipRepository {
  Future<List<ApprenticeshipOpportunity>> searchOpportunities({
    required String keywords,
    String? location,
    String? accessToken,
  });

  Future<List<ApprenticeshipSavedSearch>> listSavedSearches({
    String? accessToken,
  });

  Future<ApprenticeshipSavedSearch> saveSearch({
    required ApprenticeshipSavedSearch search,
    String? accessToken,
  });

  Future<void> deleteSavedSearch({
    required String searchId,
    String? accessToken,
  });

  Future<List<FavoriteApprenticeshipOffer>> listFavoriteOffers({
    String? accessToken,
  });

  Future<FavoriteApprenticeshipOffer> saveFavoriteOffer({
    required ApprenticeshipOpportunity opportunity,
    String? accessToken,
  });

  Future<void> deleteFavoriteOffer({
    required String favoriteId,
    String? accessToken,
  });

  Future<List<ApprenticeshipMessage>> listCommunityMessages({
    String? accessToken,
  });

  Future<ApprenticeshipMessage> shareCommunityMessage({
    required String content,
    String? link,
    String? accessToken,
  });
}
