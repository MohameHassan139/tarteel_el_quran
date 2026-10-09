class RareRecitation {
  final String id;
  final String title;
  final String reciterName;
  final String location;
  final String surahName;
  final int? surahNumber;
  final String duration;
  final String audioUrl;
  final String era;
  final List<String> tags;

  const RareRecitation({
    required this.id,
    required this.title,
    required this.reciterName,
    required this.location,
    required this.surahName,
    this.surahNumber,
    required this.duration,
    required this.audioUrl,
    this.era = 'العصر الذهبي',
    this.tags = const [],
  });

  factory RareRecitation.fromJson(Map<String, dynamic> json) {
    return RareRecitation(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      reciterName: json['reciterName'] as String? ?? '',
      location: json['location'] as String? ?? '',
      surahName: json['surahName'] as String? ?? '',
      surahNumber: json['surahNumber'] as int?,
      duration: json['duration'] as String? ?? '',
      audioUrl: json['audioUrl'] as String? ?? '',
      era: json['era'] as String? ?? 'العصر الذهبي',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'reciterName': reciterName,
      'location': location,
      'surahName': surahName,
      'surahNumber': surahNumber,
      'duration': duration,
      'audioUrl': audioUrl,
      'era': era,
      'tags': tags,
    };
  }
}

