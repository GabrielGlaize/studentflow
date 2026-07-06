class ClassAnnouncement {
  const ClassAnnouncement({
    required this.id,
    required this.content,
    required this.isPinned,
    required this.authorName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String content;
  final bool isPinned;
  final String authorName;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ClassAnnouncement.fromJson(Map<String, Object?> json) {
    return ClassAnnouncement(
      id: json['id'] as String,
      content: json['content'] as String,
      isPinned: json['isPinned'] as bool? ?? false,
      authorName: json['authorName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
