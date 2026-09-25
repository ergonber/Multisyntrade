class AnnouncementModel {
  final String id;
  final String title;
  final String? body;
  final String? imageUrl;
  final bool activo;
  final DateTime createdAt;

  const AnnouncementModel({
    required this.id,
    required this.title,
    this.body,
    this.imageUrl,
    this.activo = true,
    required this.createdAt,
  });

  factory AnnouncementModel.fromMap(Map<String, dynamic> map) {
    return AnnouncementModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'],
      imageUrl: map['image_url'],
      activo: map['activo'] ?? true,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'body': body,
    'image_url': imageUrl,
    'activo': activo,
  };
}
