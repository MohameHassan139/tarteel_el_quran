import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _toDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  return null;
}

class TeacherProfile {
  final String uid;
  final String displayName;
  final String shareCode;

  TeacherProfile({required this.uid, required this.displayName, required this.shareCode});

  factory TeacherProfile.fromMap(String uid, Map<String, dynamic> map) {
    return TeacherProfile(
      uid: uid,
      displayName: map['displayName'] as String? ?? '',
      shareCode: map['shareCode'] as String? ?? '',
    );
  }

  Map<String, dynamic> toCache() => {'uid': uid, 'displayName': displayName, 'shareCode': shareCode};
}

class LinkedTeacher {
  final String teacherUid;
  final String teacherDisplayName;

  LinkedTeacher({required this.teacherUid, required this.teacherDisplayName});

  factory LinkedTeacher.fromMap(Map<String, dynamic> map) {
    return LinkedTeacher(
      teacherUid: map['teacherUid'] as String? ?? '',
      teacherDisplayName: map['teacherDisplayName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toCache() => {'teacherUid': teacherUid, 'teacherDisplayName': teacherDisplayName};
}

class StudentSummary {
  final String uid;
  final String name;
  final int age;
  final String phone;
  final String whatsapp;
  final String fatherPhone;
  final int currentStreakDays;
  final String lastActiveDate;
  final int totalSessionsSynced;

  StudentSummary({
    required this.uid,
    required this.name,
    required this.age,
    required this.phone,
    required this.whatsapp,
    required this.fatherPhone,
    required this.currentStreakDays,
    required this.lastActiveDate,
    required this.totalSessionsSynced,
  });

  factory StudentSummary.fromMap(String uid, Map<String, dynamic> map) {
    return StudentSummary(
      uid: uid,
      name: map['name'] as String? ?? '',
      age: map['age'] as int? ?? 0,
      phone: map['phone'] as String? ?? '',
      whatsapp: map['whatsapp'] as String? ?? '',
      fatherPhone: map['fatherPhone'] as String? ?? '',
      currentStreakDays: map['currentStreakDays'] as int? ?? 0,
      lastActiveDate: map['lastActiveDate'] as String? ?? '',
      totalSessionsSynced: map['totalSessionsSynced'] as int? ?? 0,
    );
  }
}

class HifzSessionRecord {
  final String id;
  final int chapterId;
  final String chapterName;
  final int plannedStartAyah;
  final int plannedEndAyah;
  final int reachedStartAyah;
  final int reachedEndAyah;
  final bool fullyCompleted;
  final int durationSeconds;
  final int verseRepetitionsPlanned;
  final int rangeRepetitionsPlanned;
  final String reciterName;
  final int rating;
  final String notes;
  final String date;
  final List<String> visibleToTeacherIds;

  HifzSessionRecord({
    required this.id,
    required this.chapterId,
    required this.chapterName,
    required this.plannedStartAyah,
    required this.plannedEndAyah,
    required this.reachedStartAyah,
    required this.reachedEndAyah,
    required this.fullyCompleted,
    required this.durationSeconds,
    required this.verseRepetitionsPlanned,
    required this.rangeRepetitionsPlanned,
    required this.reciterName,
    required this.rating,
    required this.notes,
    required this.date,
    required this.visibleToTeacherIds,
  });

  factory HifzSessionRecord.fromLocalEntry(String id, Map<String, dynamic> entry) {
    final plannedStart = entry['startAyah'] as int? ?? 1;
    final plannedEnd = entry['endAyah'] as int? ?? plannedStart;
    final reachedEnd = (entry['reachedEndAyah'] as int?) ?? plannedEnd;
    return HifzSessionRecord(
      id: id,
      chapterId: entry['chapterId'] as int? ?? 0,
      chapterName: entry['chapterName'] as String? ?? '',
      plannedStartAyah: plannedStart,
      plannedEndAyah: plannedEnd,
      reachedStartAyah: plannedStart,
      reachedEndAyah: reachedEnd,
      fullyCompleted: reachedEnd >= plannedEnd,
      durationSeconds: entry['durationSeconds'] as int? ?? 0,
      verseRepetitionsPlanned: entry['verseRepetitions'] as int? ?? 1,
      rangeRepetitionsPlanned: entry['rangeRepetitions'] as int? ?? 1,
      reciterName: entry['reciterName'] as String? ?? '',
      rating: entry['rating'] as int? ?? 0,
      notes: entry['notes'] as String? ?? '',
      date: entry['date'] as String? ?? DateTime.now().toIso8601String(),
      visibleToTeacherIds: const [],
    );
  }

  factory HifzSessionRecord.fromMap(String id, Map<String, dynamic> map) {
    return HifzSessionRecord(
      id: id,
      chapterId: map['chapterId'] as int? ?? 0,
      chapterName: map['chapterName'] as String? ?? '',
      plannedStartAyah: map['plannedStartAyah'] as int? ?? 1,
      plannedEndAyah: map['plannedEndAyah'] as int? ?? 1,
      reachedStartAyah: map['reachedStartAyah'] as int? ?? 1,
      reachedEndAyah: map['reachedEndAyah'] as int? ?? 1,
      fullyCompleted: map['fullyCompleted'] as bool? ?? false,
      durationSeconds: map['durationSeconds'] as int? ?? 0,
      verseRepetitionsPlanned: map['verseRepetitionsPlanned'] as int? ?? 1,
      rangeRepetitionsPlanned: map['rangeRepetitionsPlanned'] as int? ?? 1,
      reciterName: map['reciterName'] as String? ?? '',
      rating: map['rating'] as int? ?? 0,
      notes: map['notes'] as String? ?? '',
      date: map['date'] as String? ?? '',
      visibleToTeacherIds: (map['visibleToTeacherIds'] as List?)?.map((e) => e as String).toList() ?? const [],
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'chapterId': chapterId,
      'chapterName': chapterName,
      'plannedStartAyah': plannedStartAyah,
      'plannedEndAyah': plannedEndAyah,
      'reachedStartAyah': reachedStartAyah,
      'reachedEndAyah': reachedEndAyah,
      'fullyCompleted': fullyCompleted,
      'durationSeconds': durationSeconds,
      'verseRepetitionsPlanned': verseRepetitionsPlanned,
      'rangeRepetitionsPlanned': rangeRepetitionsPlanned,
      'reciterName': reciterName,
      'rating': rating,
      'notes': notes,
      'date': date,
      'visibleToTeacherIds': visibleToTeacherIds,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

/// One day's activity totals, broken down per feature. Older `daily_ward`
/// docs written before this breakdown existed only have `seconds` — the
/// per-feature fields default to 0 for those.
class DailyActivity {
  final int seconds;
  final int mushafSeconds;
  final int hifzSeconds;
  final int audioSeconds;

  const DailyActivity({
    required this.seconds,
    required this.mushafSeconds,
    required this.hifzSeconds,
    required this.audioSeconds,
  });

  static const zero = DailyActivity(seconds: 0, mushafSeconds: 0, hifzSeconds: 0, audioSeconds: 0);

  factory DailyActivity.fromMap(Map<String, dynamic> map) {
    return DailyActivity(
      seconds: map['seconds'] as int? ?? 0,
      mushafSeconds: map['mushafSeconds'] as int? ?? 0,
      hifzSeconds: map['hifzSeconds'] as int? ?? 0,
      audioSeconds: map['audioSeconds'] as int? ?? 0,
    );
  }

  /// Whether this day has a per-feature breakdown at all (vs. a legacy
  /// total-only entry, or an entry where the breakdown genuinely sums to 0
  /// but the plain total doesn't — rare, but keeps the stacked chart honest).
  bool get hasBreakdown => (mushafSeconds + hifzSeconds + audioSeconds) > 0;
}

class TeacherNote {
  final String id;
  final String fromTeacherUid;
  final String fromTeacherName;
  final String text;
  final bool read;
  final DateTime? createdAt;

  TeacherNote({
    required this.id,
    required this.fromTeacherUid,
    required this.fromTeacherName,
    required this.text,
    required this.read,
    required this.createdAt,
  });

  factory TeacherNote.fromMap(String id, Map<String, dynamic> map) {
    return TeacherNote(
      id: id,
      fromTeacherUid: map['fromTeacherUid'] as String? ?? '',
      fromTeacherName: map['fromTeacherName'] as String? ?? '',
      text: map['text'] as String? ?? '',
      read: map['read'] as bool? ?? false,
      createdAt: _toDate(map['createdAt']),
    );
  }
}
