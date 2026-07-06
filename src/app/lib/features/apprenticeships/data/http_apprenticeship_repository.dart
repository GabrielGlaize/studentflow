import 'package:studyflow_app/core/network/api_client.dart';
import 'package:studyflow_app/features/apprenticeships/data/apprenticeship_repository.dart';
import 'package:studyflow_app/features/apprenticeships/domain/apprenticeship_models.dart';

class HttpApprenticeshipRepository implements ApprenticeshipRepository {
  const HttpApprenticeshipRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<ApprenticeshipOpportunity>> searchOpportunities({
    required String keywords,
    String? location,
    String? accessToken,
  }) async {
    final query = Uri(
      path: '/api/v1/apprenticeships/opportunities',
      queryParameters: {
        'keywords': keywords,
        if (location != null && location.trim().isNotEmpty)
          'location': location.trim(),
      },
    );

    final json = await _apiClient.getJsonList(
      query.toString(),
      accessToken: accessToken,
    );

    return json.map(ApprenticeshipOpportunity.fromJson).toList(growable: false);
  }

  @override
  Future<List<ApprenticeshipSavedSearch>> listSavedSearches({
    String? accessToken,
  }) async {
    final json = await _apiClient.getJsonList(
      '/api/v1/apprenticeships/saved-searches',
      accessToken: accessToken,
    );

    return json.map(ApprenticeshipSavedSearch.fromJson).toList(growable: false);
  }

  @override
  Future<ApprenticeshipSavedSearch> saveSearch({
    required ApprenticeshipSavedSearch search,
    String? accessToken,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/apprenticeships/saved-searches',
      body: search.toCreateJson(),
      accessToken: accessToken,
    );

    return ApprenticeshipSavedSearch.fromJson(json);
  }

  @override
  Future<void> deleteSavedSearch({
    required String searchId,
    String? accessToken,
  }) {
    return _apiClient.deleteNoContent(
      '/api/v1/apprenticeships/saved-searches/$searchId',
      accessToken: accessToken,
    );
  }

  @override
  Future<List<FavoriteApprenticeshipOffer>> listFavoriteOffers({
    String? accessToken,
  }) async {
    final json = await _apiClient.getJsonList(
      '/api/v1/apprenticeships/favorite-offers',
      accessToken: accessToken,
    );

    return json
        .map(FavoriteApprenticeshipOffer.fromJson)
        .toList(growable: false);
  }

  @override
  Future<FavoriteApprenticeshipOffer> saveFavoriteOffer({
    required ApprenticeshipOpportunity opportunity,
    String? accessToken,
  }) async {
    final favorite = FavoriteApprenticeshipOffer.fromOpportunity(
      id: 'pending',
      opportunity: opportunity,
      savedAt: DateTime.now(),
    );
    final json = await _apiClient.postJson(
      '/api/v1/apprenticeships/favorite-offers',
      body: favorite.toCreateJson(),
      accessToken: accessToken,
    );

    return FavoriteApprenticeshipOffer.fromJson(json);
  }

  @override
  Future<void> deleteFavoriteOffer({
    required String favoriteId,
    String? accessToken,
  }) {
    return _apiClient.deleteNoContent(
      '/api/v1/apprenticeships/favorite-offers/$favoriteId',
      accessToken: accessToken,
    );
  }

  @override
  Future<List<ApprenticeshipMessage>> listCommunityMessages({
    String? accessToken,
  }) async {
    final json = await _apiClient.getJsonList(
      '/api/v1/apprenticeship-messages',
      accessToken: accessToken,
    );

    return json.map(ApprenticeshipMessage.fromJson).toList(growable: false);
  }

  @override
  Future<ApprenticeshipMessage> shareCommunityMessage({
    required String content,
    String? link,
    String? accessToken,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/apprenticeship-messages',
      body: {
        'content': content.trim(),
        'link': link?.trim().isEmpty ?? true ? null : link!.trim(),
      },
      accessToken: accessToken,
    );

    return ApprenticeshipMessage.fromJson(json);
  }
}
