import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/features/apprenticeships/domain/apprenticeship_models.dart';

void main() {
  test('ApprenticeshipOpportunity.fromJson lit la réponse du backend', () {
    final opportunity = ApprenticeshipOpportunity.fromJson({
      'source': 'la-bonne-alternance',
      'externalId': 'offer-1',
      'opportunityType': 'job',
      'title': 'Développeur Flutter',
      'company': 'Atelier Numérique',
      'location': 'Paris',
      'distanceKm': 4.2,
      'publishedAt': '2026-06-24T08:00:00Z',
      'expiresAt': null,
      'contractTypes': ['Apprentissage'],
      'targetDiploma': 'Bac+2',
      'remoteMode': null,
      'summary': 'Application mobile Flutter.',
      'applicationUrl': 'https://example.com/offer',
    });

    expect(opportunity.title, 'Développeur Flutter');
    expect(opportunity.contractTypes.single, 'Apprentissage');
    expect(opportunity.distanceKm, 4.2);
  });

  test('ApprenticeshipMessage.fromJson lit le fil entraide', () {
    final message = ApprenticeshipMessage.fromJson({
      'id': 'message-1',
      'content': 'Offre Flutter à partager.',
      'link': 'https://example.com',
      'authorName': 'Lina Moreau',
      'createdAt': '2026-06-24T10:15:00Z',
    });

    expect(message.content, 'Offre Flutter à partager.');
    expect(message.link, 'https://example.com');
    expect(message.authorName, 'Lina Moreau');
  });

  test(
    'ApprenticeshipSavedSearch lit et prépare une recherche sauvegardée',
    () {
      final search = ApprenticeshipSavedSearch.fromJson({
        'id': 'search-1',
        'name': 'Flutter Paris',
        'keywords': 'flutter',
        'location': 'Paris',
        'distanceKm': 30,
        'filtersJson': '{}',
        'alertEnabled': true,
        'lastCheckedAt': null,
        'createdAt': '2026-06-24T09:00:00Z',
      });

      expect(search.name, 'Flutter Paris');
      expect(search.alertEnabled, isTrue);
      expect(search.toCreateJson()['keywords'], 'flutter');
    },
  );

  test('FavoriteApprenticeshipOffer lit et prépare un favori', () {
    final favorite = FavoriteApprenticeshipOffer.fromJson({
      'id': 'favorite-1',
      'source': 'la-bonne-alternance',
      'externalOfferId': 'offer-1',
      'title': 'Développeur Flutter',
      'company': 'Atelier Numérique',
      'location': 'Paris',
      'url': 'https://example.com/offer',
      'publishedAt': '2026-06-24T08:00:00Z',
      'savedAt': '2026-06-25T08:00:00Z',
    });

    expect(favorite.title, 'Développeur Flutter');
    expect(favorite.toCreateJson()['externalOfferId'], 'offer-1');
    expect(favorite.toCreateJson()['url'], 'https://example.com/offer');
  });
}
