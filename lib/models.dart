class Chapter {
  final int id;
  final String nameSimple;
  final String nameComplex;
  final String nameArabic;
  final int versesCount;
  final String revelationPlace;
  final int revelationOrder;
  final String translatedName;

  Chapter({
    required this.id,
    required this.nameSimple,
    required this.nameComplex,
    required this.nameArabic,
    required this.versesCount,
    required this.revelationPlace,
    required this.revelationOrder,
    required this.translatedName,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['number'] as int,
      nameSimple: json['englishName'] as String,
      nameComplex: json['englishName'] as String,
      nameArabic: json['name'] as String,
      versesCount: json['numberOfAyahs'] as int,
      revelationPlace: json['revelationType'] as String,
      revelationOrder: 0,
      translatedName: json['englishNameTranslation'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': id,
      'englishName': nameSimple,
      'name': nameArabic,
      'numberOfAyahs': versesCount,
      'revelationType': revelationPlace,
      'englishNameTranslation': translatedName,
    };
  }
}

class Verse {
  final int id;
  final int verseNumber;
  final String verseKey;
  final String textUthmani;
  final String translationText;
  final int juzNumber;
  final int pageNumber;

  Verse({
    required this.id,
    required this.verseNumber,
    required this.verseKey,
    required this.textUthmani,
    required this.translationText,
    required this.juzNumber,
    required this.pageNumber,
  });

  factory Verse.fromJson(Map<String, dynamic> json) {
    String transText = json['translationText'] as String? ?? '';
    // Strip HTML tags from translation text
    transText = transText.replaceAll(RegExp(r'<[^>]*>|&nbsp;'), '');
    return Verse(
      id: json['number'] as int,
      verseNumber: json['numberInSurah'] as int,
      verseKey: json['verseKey'] as String? ?? '${json['surah_number'] ?? 1}:${json['numberInSurah']}',
      textUthmani: json['text'] as String? ?? '',
      translationText: transText,
      juzNumber: json['juz'] as int? ?? 1,
      pageNumber: json['page'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': id,
      'numberInSurah': verseNumber,
      'verseKey': verseKey,
      'text': textUthmani,
      'translationText': translationText,
      'juz': juzNumber,
      'page': pageNumber,
    };
  }
}

class Reciter {
  final int id;
  final String name;

  Reciter({
    required this.id,
    required this.name,
  });

  factory Reciter.fromJson(Map<String, dynamic> json) {
    return Reciter(
      id: json['id'] as int,
      name: json['reciter_name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reciter_name': name,
    };
  }
}

class WardGoal {
  final int targetMinutes;
  final int reminderHour;
  final int reminderMinute;
  final int activeSecondsToday;
  final String lastLoggedDate; // YYYY-MM-DD

  WardGoal({
    required this.targetMinutes,
    required this.reminderHour,
    required this.reminderMinute,
    required this.activeSecondsToday,
    required this.lastLoggedDate,
  });

  factory WardGoal.defaultGoal() {
    return WardGoal(
      targetMinutes: 30,
      reminderHour: 20, // 8:00 PM
      reminderMinute: 0,
      activeSecondsToday: 0,
      lastLoggedDate: _getTodayDateString(),
    );
  }

  static String _getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  WardGoal copyWith({
    int? targetMinutes,
    int? reminderHour,
    int? reminderMinute,
    int? activeSecondsToday,
    String? lastLoggedDate,
  }) {
    return WardGoal(
      targetMinutes: targetMinutes ?? this.targetMinutes,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      activeSecondsToday: activeSecondsToday ?? this.activeSecondsToday,
      lastLoggedDate: lastLoggedDate ?? this.lastLoggedDate,
    );
  }

  factory WardGoal.fromJson(Map<String, dynamic> json) {
    return WardGoal(
      targetMinutes: json['targetMinutes'] as int? ?? 30,
      reminderHour: json['reminderHour'] as int? ?? 20,
      reminderMinute: json['reminderMinute'] as int? ?? 0,
      activeSecondsToday: json['activeSecondsToday'] as int? ?? 0,
      lastLoggedDate: json['lastLoggedDate'] as String? ?? _getTodayDateString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'targetMinutes': targetMinutes,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      'activeSecondsToday': activeSecondsToday,
      'lastLoggedDate': lastLoggedDate,
    };
  }
}
