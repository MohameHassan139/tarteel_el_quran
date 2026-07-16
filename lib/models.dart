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

class Mp3QuranMoshaf {
  final int id;
  final String name;
  final String server;
  final int surahTotal;
  final List<int> surahList;

  Mp3QuranMoshaf({
    required this.id,
    required this.name,
    required this.server,
    required this.surahTotal,
    required this.surahList,
  });

  factory Mp3QuranMoshaf.fromJson(Map<String, dynamic> json) {
    final rawList = json['surah_list'] as String? ?? '';
    List<int> surahs = [];
    if (rawList.isNotEmpty) {
      surahs = rawList.split(',').map((e) => int.tryParse(e.trim())).whereType<int>().toList();
    }
    return Mp3QuranMoshaf(
      id: json['id'] is int ? json['id'] as int : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      name: json['name'] as String? ?? '',
      server: json['server'] as String? ?? '',
      surahTotal: json['surah_total'] is int ? json['surah_total'] as int : (int.tryParse(json['surah_total']?.toString() ?? '') ?? 0),
      surahList: surahs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'server': server,
      'surah_total': surahTotal,
      'surah_list': surahList.join(','),
    };
  }
}

class Mp3QuranReciter {
  final int id;
  final String name;
  final List<Mp3QuranMoshaf> moshafs;

  Mp3QuranReciter({
    required this.id,
    required this.name,
    required this.moshafs,
  });

  factory Mp3QuranReciter.fromJson(Map<String, dynamic> json) {
    final list = json['moshaf'] as List? ?? [];
    return Mp3QuranReciter(
      id: json['id'] is int ? json['id'] as int : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      name: json['name'] as String? ?? '',
      moshafs: list.map((e) => Mp3QuranMoshaf.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'moshaf': moshafs.map((e) => e.toJson()).toList(),
    };
  }
}

class ReminderMessage {
  final String id;
  final String category; // 'start', 'incomplete', 'completed'
  final String textAr;
  final String textEn;

  ReminderMessage({
    required this.id,
    required this.category,
    required this.textAr,
    required this.textEn,
  });

  factory ReminderMessage.fromJson(Map<String, dynamic> json) {
    return ReminderMessage(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? 'start',
      textAr: json['textAr'] as String? ?? '',
      textEn: json['textEn'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'textAr': textAr,
      'textEn': textEn,
    };
  }

  ReminderMessage copyWith({
    String? id,
    String? category,
    String? textAr,
    String? textEn,
  }) {
    return ReminderMessage(
      id: id ?? this.id,
      category: category ?? this.category,
      textAr: textAr ?? this.textAr,
      textEn: textEn ?? this.textEn,
    );
  }
}
