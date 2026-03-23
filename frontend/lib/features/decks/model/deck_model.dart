class DeckModel {
  final String id;
  final String title;
  final String? description;
  final bool isPublic;

  final DateTime updatedAt;
  final int version;
  final bool isDeleted;

  DeckModel({
    required this.id,
    required this.title,
    this.description,
    required this.isPublic,
    required this.updatedAt,
    this.version = 1,
    this.isDeleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "description": description,
      "is_public": isPublic,
      "updated_at": updatedAt.toIso8601String(),
      "version": version,
      "is_deleted": isDeleted,
    };
  }
}