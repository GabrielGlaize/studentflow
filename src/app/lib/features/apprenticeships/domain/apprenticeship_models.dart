class ApprenticeshipOpportunity {
  const ApprenticeshipOpportunity({
    required this.source,
    required this.externalId,
    required this.opportunityType,
    required this.title,
    required this.contractTypes,
    required this.applicationUrl,
    this.company,
    this.location,
    this.distanceKm,
    this.publishedAt,
    this.expiresAt,
    this.targetDiploma,
    this.remoteMode,
    this.summary,
  });

  final String source;
  final String externalId;
  final String opportunityType;
  final String title;
  final String? company;
  final String? location;
  final double? distanceKm;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final List<String> contractTypes;
  final String? targetDiploma;
  final String? remoteMode;
  final String? summary;
  final String applicationUrl;

  factory ApprenticeshipOpportunity.fromJson(Map<String, Object?> json) {
    return ApprenticeshipOpportunity(
      source: json['source'] as String,
      externalId: json['externalId'] as String,
      opportunityType: json['opportunityType'] as String,
      title: json['title'] as String,
      company: json['company'] as String?,
      location: json['location'] as String?,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      publishedAt: json['publishedAt'] == null
          ? null
          : DateTime.parse(json['publishedAt'] as String),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      contractTypes: (json['contractTypes'] as List<Object?>? ?? [])
          .whereType<String>()
          .toList(growable: false),
      targetDiploma: json['targetDiploma'] as String?,
      remoteMode: json['remoteMode'] as String?,
      summary: json['summary'] as String?,
      applicationUrl: json['applicationUrl'] as String,
    );
  }
}

class ApprenticeshipSavedSearch {
  const ApprenticeshipSavedSearch({
    required this.id,
    required this.name,
    required this.keywords,
    required this.createdAt,
    this.location,
    this.distanceKm,
    this.filtersJson = '{}',
    this.alertEnabled = false,
    this.lastCheckedAt,
  });

  final String id;
  final String name;
  final String keywords;
  final String? location;
  final int? distanceKm;
  final String filtersJson;
  final bool alertEnabled;
  final DateTime? lastCheckedAt;
  final DateTime createdAt;

  factory ApprenticeshipSavedSearch.fromJson(Map<String, Object?> json) {
    return ApprenticeshipSavedSearch(
      id: json['id'] as String,
      name: json['name'] as String,
      keywords: json['keywords'] as String,
      location: json['location'] as String?,
      distanceKm: (json['distanceKm'] as num?)?.toInt(),
      filtersJson: json['filtersJson'] as String? ?? '{}',
      alertEnabled: json['alertEnabled'] as bool? ?? false,
      lastCheckedAt: json['lastCheckedAt'] == null
          ? null
          : DateTime.parse(json['lastCheckedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, Object?> toCreateJson() {
    return {
      'name': name.trim(),
      'keywords': keywords.trim(),
      'location': _cleanOptional(location),
      'latitude': null,
      'longitude': null,
      'distanceKm': distanceKm,
      'filtersJson': filtersJson.trim().isEmpty ? '{}' : filtersJson.trim(),
      'alertEnabled': alertEnabled,
    };
  }
}

class FavoriteApprenticeshipOffer {
  const FavoriteApprenticeshipOffer({
    required this.id,
    required this.source,
    required this.externalOfferId,
    required this.title,
    required this.url,
    required this.savedAt,
    this.company,
    this.location,
    this.publishedAt,
  });

  final String id;
  final String source;
  final String externalOfferId;
  final String title;
  final String? company;
  final String? location;
  final String url;
  final DateTime? publishedAt;
  final DateTime savedAt;

  factory FavoriteApprenticeshipOffer.fromJson(Map<String, Object?> json) {
    return FavoriteApprenticeshipOffer(
      id: json['id'] as String,
      source: json['source'] as String,
      externalOfferId: json['externalOfferId'] as String,
      title: json['title'] as String,
      company: json['company'] as String?,
      location: json['location'] as String?,
      url: json['url'] as String,
      publishedAt: json['publishedAt'] == null
          ? null
          : DateTime.parse(json['publishedAt'] as String),
      savedAt: DateTime.parse(json['savedAt'] as String),
    );
  }

  factory FavoriteApprenticeshipOffer.fromOpportunity({
    required String id,
    required ApprenticeshipOpportunity opportunity,
    required DateTime savedAt,
  }) {
    return FavoriteApprenticeshipOffer(
      id: id,
      source: opportunity.source,
      externalOfferId: opportunity.externalId,
      title: opportunity.title,
      company: opportunity.company,
      location: opportunity.location,
      url: opportunity.applicationUrl,
      publishedAt: opportunity.publishedAt,
      savedAt: savedAt,
    );
  }

  Map<String, Object?> toCreateJson() {
    return {
      'source': source.trim(),
      'externalOfferId': externalOfferId.trim(),
      'title': title.trim(),
      'company': _cleanOptional(company),
      'location': _cleanOptional(location),
      'url': url.trim(),
      'publishedAt': publishedAt?.toUtc().toIso8601String(),
    };
  }
}

class ApprenticeshipMessage {
  const ApprenticeshipMessage({
    required this.id,
    required this.content,
    required this.authorName,
    required this.createdAt,
    this.link,
  });

  final String id;
  final String content;
  final String? link;
  final String authorName;
  final DateTime createdAt;

  factory ApprenticeshipMessage.fromJson(Map<String, Object?> json) {
    return ApprenticeshipMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      link: json['link'] as String?,
      authorName: json['authorName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

String? _cleanOptional(String? value) {
  final cleaned = value?.trim();
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}
