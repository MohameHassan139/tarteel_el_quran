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
      id: json['id'] as int,
      nameSimple: json['name_simple'] as String,
      nameComplex: json['name_complex'] as String,
      nameArabic: json['name_arabic'] as String,
      versesCount: json['verses_count'] as int,
      revelationPlace: json['revelation_place'] as String,
      revelationOrder: json['revelation_order'] as int,
      translatedName: (json['translated_name'] as Map<String, dynamic>)['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_simple': nameSimple,
      'name_complex': nameComplex,
      'name_arabic': nameArabic,
      'verses_count': versesCount,
      'revelation_place': revelationPlace,
      'revelation_order': revelationOrder,
      'translated_name': {'name': translatedName},
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
    String transText = '';
    if (json['translations'] != null && (json['translations'] as List).isNotEmpty) {
      transText = json['translations'][0]['text'] as String;
      // Strip HTML tags from translation text
      transText = transText.replaceAll(RegExp(r'<[^>]*>|&nbsp;'), '');
    }
    return Verse(
      id: json['id'] as int,
      verseNumber: json['verse_number'] as int,
      verseKey: json['verse_key'] as String,
      textUthmani: json['text_uthmani'] as String? ?? '',
      translationText: transText,
      juzNumber: json['juz_number'] as int? ?? 1,
      pageNumber: json['page_number'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'verse_number': verseNumber,
      'verse_key': verseKey,
      'text_uthmani': textUthmani,
      'translations': [
        {'text': translationText}
      ],
      'juz_number': juzNumber,
      'page_number': pageNumber,
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

class VerseTiming {
  final String verseKey;
  final int timestampFrom;
  final int timestampTo;
  final int duration;

  VerseTiming({
    required this.verseKey,
    required this.timestampFrom,
    required this.timestampTo,
    required this.duration,
  });

  factory VerseTiming.fromJson(Map<String, dynamic> json) {
    return VerseTiming(
      verseKey: json['verse_key'] as String,
      timestampFrom: json['timestamp_from'] as int,
      timestampTo: json['timestamp_to'] as int,
      duration: json['duration'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'verse_key': verseKey,
      'timestamp_from': timestampFrom,
      'timestamp_to': timestampTo,
      'duration': duration,
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
