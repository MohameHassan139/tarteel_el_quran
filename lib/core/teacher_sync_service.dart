import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'storage_service.dart';
import 'reminder_service.dart';
import '../features/teacher_link/teacher_link_models.dart';
import '../features/teacher_link/utils/streak_utils.dart';

const String kTeachersCollection = 'quran_teachers';
const String kShareCodesCollection = 'quran_share_codes';
const String kStudentsCollection = 'quran_students';

/// Wraps every Firebase Auth/Firestore call this app makes for the
/// teacher/student linking feature. Nothing in this class touches the
/// network until a user explicitly activates student or teacher mode —
/// `init()` itself is 100% local (reads a plain string flag from Hive).
class TeacherSyncService extends GetxService {
  final StorageService _storage = Get.find<StorageService>();
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// '' | 'student' | 'teacher' | 'both'
  final RxString role = ''.obs;
  final RxnString studentUid = RxnString();
  final RxnString teacherUid = RxnString();
  final RxList<LinkedTeacher> linkedTeachers = <LinkedTeacher>[].obs;
  final Rxn<TeacherProfile> teacherProfile = Rxn<TeacherProfile>();
  final RxInt unreadNotesCount = 0.obs;

  StreamSubscription? _notesSub;

  bool get isStudent => role.value == 'student' || role.value == 'both';
  bool get isTeacher => role.value == 'teacher' || role.value == 'both';

  Future<TeacherSyncService> init() async {
    try {
      _db.settings = const Settings(persistenceEnabled: true);
    } catch (_) {}

    role.value = _storage.getTeacherLinkRole();
    if (role.value.isEmpty) return this;

    // Firebase Auth persists the anonymous session locally across restarts —
    // resuming it here (for a user who already opted in before) is not the
    // same as signing a new user in.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return this;

    if (isStudent) {
      studentUid.value = user.uid;
      _loadLinkedTeachersCache();
      _watchMyNotes(user.uid);
      unawaited(_loadLinkedTeachersFromCloud(user.uid));
    }
    if (isTeacher) {
      teacherUid.value = user.uid;
      _loadTeacherProfileCache();
    }

    return this;
  }

  Future<String> _ensureSignedIn() async {
    final existing = FirebaseAuth.instance.currentUser;
    if (existing != null) return existing.uid;
    final credential = await FirebaseAuth.instance.signInAnonymously();
    return credential.user!.uid;
  }

  String _generateShareCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous chars
    final rand = Random.secure();
    final code = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'TQ-$code';
  }

  // ------------------------------------------------------------------
  // Teacher side
  // ------------------------------------------------------------------

  Future<TeacherProfile> activateTeacherMode(String displayName) async {
    final uid = await _ensureSignedIn();

    String code = _generateShareCode();
    for (int attempt = 0; attempt < 5; attempt++) {
      final existing = await _db.collection(kShareCodesCollection).doc(code).get();
      if (!existing.exists) break;
      code = _generateShareCode();
    }

    final now = FieldValue.serverTimestamp();
    await _db.collection(kTeachersCollection).doc(uid).set({
      'uid': uid,
      'displayName': displayName,
      'shareCode': code,
      'active': true,
      'createdAt': now,
      'updatedAt': now,
    });
    await _db.collection(kShareCodesCollection).doc(code).set({
      'teacherUid': uid,
      'createdAt': now,
    });

    final profile = TeacherProfile(uid: uid, displayName: displayName, shareCode: code);
    teacherUid.value = uid;
    teacherProfile.value = profile;
    await _storage.setTeacherProfileCache(profile.toCache());

    final newRole = _storage.getTeacherLinkRole() == 'student' ? 'both' : 'teacher';
    await _storage.setTeacherLinkRole(newRole);
    role.value = newRole;

    return profile;
  }

  Future<StudentSummary?> fetchStudentProfile(String forStudentUid) async {
    try {
      final doc = await _db.collection(kStudentsCollection).doc(forStudentUid).get();
      if (!doc.exists) return null;
      return StudentSummary.fromMap(doc.id, doc.data()!);
    } catch (_) {
      return null;
    }
  }

  Stream<List<StudentSummary>> watchLinkedStudents(String forTeacherUid) {
    return _db
        .collection(kStudentsCollection)
        .where('linkedTeacherIds', arrayContains: forTeacherUid)
        .snapshots()
        .map((snap) => snap.docs.map((d) => StudentSummary.fromMap(d.id, d.data())).toList());
  }

  /// Sessions a student explicitly shared with [viewerTeacherUid].
  ///
  /// Firestore security rules are not filters: the `sessions` read rule only
  /// allows docs whose `visibleToTeacherIds` contains the teacher, so the
  /// query MUST carry the same constraint or the whole listen is rejected
  /// with permission-denied (the old unfiltered query always failed for
  /// teachers). Sorting happens client-side so no composite index is needed.
  Stream<List<HifzSessionRecord>> watchStudentSessions(String studentUidToWatch, {required String viewerTeacherUid}) {
    return _db
        .collection(kStudentsCollection)
        .doc(studentUidToWatch)
        .collection('sessions')
        .where('visibleToTeacherIds', arrayContains: viewerTeacherUid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => HifzSessionRecord.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => b.sortTime.compareTo(a.sortTime));
      return list;
    });
  }

  Stream<Map<String, DailyActivity>> watchStudentDailyWard(String studentUidToWatch, {int lastNDays = 366}) {
    return _db
        .collection(kStudentsCollection)
        .doc(studentUidToWatch)
        .collection('daily_ward')
        .orderBy('date', descending: true)
        .limit(lastNDays)
        .snapshots()
        .map((snap) => {for (final d in snap.docs) (d.data()['date'] as String? ?? d.id): DailyActivity.fromMap(d.data())});
  }

  Future<void> sendNoteToStudent({
    required String studentUidToNotify,
    required String fromTeacherUid,
    required String fromTeacherName,
    required String text,
  }) async {
    await _db.collection(kStudentsCollection).doc(studentUidToNotify).collection('notes').add({
      'fromTeacherUid': fromTeacherUid,
      'fromTeacherName': fromTeacherName,
      'text': text,
      'read': false,
      'readAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deactivateTeacherMode() async {
    final uid = teacherUid.value;
    if (uid == null) return;

    try {
      final teacherDoc = await _db.collection(kTeachersCollection).doc(uid).get();
      final code = teacherDoc.data()?['shareCode'] as String?;
      if (code != null) {
        await _db.collection(kShareCodesCollection).doc(code).delete();
      }
      await _db.collection(kTeachersCollection).doc(uid).delete();
    } catch (_) {
      // Local role is still cleared below even if the remote cleanup partially failed.
    }

    teacherUid.value = null;
    teacherProfile.value = null;
    await _storage.setTeacherProfileCache({});

    final newRole = _storage.getTeacherLinkRole() == 'both' ? 'student' : '';
    await _storage.setTeacherLinkRole(newRole);
    role.value = newRole;

    if (newRole.isEmpty) {
      try {
        await FirebaseAuth.instance.currentUser?.delete();
      } catch (_) {}
    }
  }

  // ------------------------------------------------------------------
  // Student side
  // ------------------------------------------------------------------

  Future<String> activateStudentProfile({
    required String name,
    required String phone,
    required String whatsapp,
  }) async {
    final uid = await _ensureSignedIn();
    final now = FieldValue.serverTimestamp();
    final existing = await _db.collection(kStudentsCollection).doc(uid).get();
    final existingData = existing.data();

    await _db.collection(kStudentsCollection).doc(uid).set({
      'uid': uid,
      'name': name,
      'phone': phone,
      'whatsapp': whatsapp,
      // Age and guardian phone are no longer collected (Play user-data /
      // Families policy). Remove any value saved by older app versions.
      'age': FieldValue.delete(),
      'fatherPhone': FieldValue.delete(),
      'linkedTeacherIds': existingData?['linkedTeacherIds'] ?? <String>[],
      'currentStreakDays': existingData?['currentStreakDays'] ?? 0,
      'lastActiveDate': existingData?['lastActiveDate'] ?? '',
      'totalSessionsSynced': existingData?['totalSessionsSynced'] ?? 0,
      'updatedAt': now,
      if (existingData == null) 'createdAt': now,
    }, SetOptions(merge: true));

    studentUid.value = uid;
    final newRole = _storage.getTeacherLinkRole() == 'teacher' ? 'both' : 'student';
    await _storage.setTeacherLinkRole(newRole);
    role.value = newRole;

    await _storage.setStudentProfileCache({
      'name': name,
      'phone': phone,
      'whatsapp': whatsapp,
    });

    _watchMyNotes(uid);
    unawaited(_loadLinkedTeachersFromCloud(uid));

    if (!_storage.isWardBackfillDone()) {
      unawaited(_backfillWardHistory(uid));
    }

    return uid;
  }

  Future<void> _backfillWardHistory(String uid) async {
    try {
      final history = _storage.getWardHistory();
      if (history.isEmpty) {
        await _storage.setWardBackfillDone(true);
        return;
      }
      final batch = _db.batch();
      history.forEach((date, seconds) {
        final ref = _db.collection(kStudentsCollection).doc(uid).collection('daily_ward').doc(date);
        batch.set(ref, {'date': date, 'seconds': seconds, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      });
      await batch.commit();
      await _storage.setWardBackfillDone(true);
    } catch (_) {
      // Best-effort — stays eligible for retry since the flag wasn't set.
    }
  }

  /// Returns null on success, or a short error code on failure:
  /// 'not_activated' | 'not_found' | 'cannot_link_self' | 'already_linked' | 'error'
  Future<String?> linkTeacherByCode(String code) async {
    final uid = studentUid.value;
    if (uid == null) return 'not_activated';
    final normalized = code.trim().toUpperCase();

    try {
      final codeDoc = await _db.collection(kShareCodesCollection).doc(normalized).get();
      if (!codeDoc.exists) return 'not_found';
      final teacherUidToLink = codeDoc.data()!['teacherUid'] as String;
      if (teacherUidToLink == uid) return 'cannot_link_self';
      if (linkedTeachers.any((t) => t.teacherUid == teacherUidToLink)) return 'already_linked';

      final teacherDoc = await _db.collection(kTeachersCollection).doc(teacherUidToLink).get();
      final teacherName = teacherDoc.data()?['displayName'] as String? ?? '';

      final studentRef = _db.collection(kStudentsCollection).doc(uid);
      await studentRef.update({
        'linkedTeacherIds': FieldValue.arrayUnion([teacherUidToLink]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await studentRef.collection('links').doc(teacherUidToLink).set({
        'teacherUid': teacherUidToLink,
        'teacherDisplayName': teacherName,
        'linkedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      final updated = LinkedTeacher(teacherUid: teacherUidToLink, teacherDisplayName: teacherName);
      linkedTeachers.add(updated);
      await _storage.setLinkedTeachersCache(linkedTeachers.map((t) => t.toCache()).toList());

      return null;
    } catch (_) {
      return 'error';
    }
  }

  Future<void> unlinkTeacher(String teacherUidToUnlink) async {
    final uid = studentUid.value;
    if (uid == null) return;

    try {
      final studentRef = _db.collection(kStudentsCollection).doc(uid);
      await studentRef.update({
        'linkedTeacherIds': FieldValue.arrayRemove([teacherUidToUnlink]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await studentRef.collection('links').doc(teacherUidToUnlink).set({'status': 'revoked'}, SetOptions(merge: true));
    } catch (_) {}

    linkedTeachers.removeWhere((t) => t.teacherUid == teacherUidToUnlink);
    await _storage.setLinkedTeachersCache(linkedTeachers.map((t) => t.toCache()).toList());
  }

  Future<void> _loadLinkedTeachersFromCloud(String uid) async {
    try {
      final linksSnap = await _db
          .collection(kStudentsCollection)
          .doc(uid)
          .collection('links')
          .where('status', isEqualTo: 'active')
          .get();
      final list = linksSnap.docs.map((d) => LinkedTeacher.fromMap(d.data())).toList();
      linkedTeachers.assignAll(list);
      await _storage.setLinkedTeachersCache(list.map((t) => t.toCache()).toList());
    } catch (_) {
      // Keep whatever's cached locally.
    }
  }

  void _loadLinkedTeachersCache() {
    linkedTeachers.assignAll(_storage.getLinkedTeachersCache().map((m) => LinkedTeacher.fromMap(m)));
  }

  void _loadTeacherProfileCache() {
    final cached = _storage.getTeacherProfileCache();
    if (cached != null && cached.isNotEmpty) {
      teacherProfile.value = TeacherProfile.fromMap(cached['uid'] as String? ?? teacherUid.value ?? '', cached);
    }
  }

  /// Mirrors a just-completed, just-rated local Hifz history entry to Firestore.
  /// `localEntry` must already contain a stable string `id` field.
  Future<void> syncHifzSession(Map<String, dynamic> localEntry, {String? shareToTeacherUid}) async {
    final uid = studentUid.value;
    if (uid == null) return;
    final id = localEntry['id'] as String?;
    if (id == null || _storage.getSyncedHifzSessionIds().contains(id)) return;

    try {
      final base = HifzSessionRecord.fromLocalEntry(id, localEntry);
      final record = HifzSessionRecord(
        id: base.id,
        chapterId: base.chapterId,
        chapterName: base.chapterName,
        plannedStartAyah: base.plannedStartAyah,
        plannedEndAyah: base.plannedEndAyah,
        reachedStartAyah: base.reachedStartAyah,
        reachedEndAyah: base.reachedEndAyah,
        fullyCompleted: base.fullyCompleted,
        durationSeconds: base.durationSeconds,
        verseRepetitionsPlanned: base.verseRepetitionsPlanned,
        rangeRepetitionsPlanned: base.rangeRepetitionsPlanned,
        reciterName: base.reciterName,
        reciterId: base.reciterId,
        rating: base.rating,
        notes: base.notes,
        date: base.date,
        visibleToTeacherIds: shareToTeacherUid != null ? [shareToTeacherUid] : const [],
      );

      await _db.collection(kStudentsCollection).doc(uid).collection('sessions').doc(id).set(record.toFirestoreMap());
      await _storage.addSyncedHifzSessionId(id);

      await _db.collection(kStudentsCollection).doc(uid).update({
        'totalSessionsSynced': FieldValue.increment(1),
        'lastActiveDate': base.date.split('T').first,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Best-effort — the local Hive history entry is already the source of truth.
    }
  }

  /// Syncs today's activity across every tracked feature (Mushaf reading,
  /// Hifz practice, Audio Hub listening) in one write, and recomputes the
  /// streak from the combined total. Introspects local storage itself so
  /// every caller just calls this with no arguments.
  Future<void> syncTodayActivity() async {
    final uid = studentUid.value;
    if (uid == null) return;

    final today = _todayDateString();
    // The ward stopwatch (activeSecondsToday) is already the COMBINED total:
    // Mushaf reading, Hifz practice and Audio Hub listening all log into it.
    // Adding hifz/audio on top of it again double-counted those minutes.
    final total = _storage.getWardGoal().activeSecondsToday;
    final trackedHifz = _storage.getHifzDailySeconds()[today];
    // Older app versions didn't track Hifz seconds per day; fall back to the
    // saved sessions' durations for that case. Each part is capped so the
    // breakdown can never add up to more than the real total.
    final int hifzSeconds = min(trackedHifz ?? _sumHifzSecondsForDate(today), total);
    final int audioSeconds = min(_storage.getAudioDailySeconds()[today] ?? 0, total - hifzSeconds);
    final int mushafSeconds = max(0, total - hifzSeconds - audioSeconds);

    try {
      await _db.collection(kStudentsCollection).doc(uid).collection('daily_ward').doc(today).set({
        'date': today,
        'seconds': total,
        'mushafSeconds': mushafSeconds,
        'hifzSeconds': hifzSeconds,
        'audioSeconds': audioSeconds,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final history = Map<String, int>.from(_storage.getWardHistory());
      history[today] = total;
      final streak = calculateCurrentStreak(history);
      await _db.collection(kStudentsCollection).doc(uid).update({
        'currentStreakDays': streak,
        // Merely opening a screen syncs a 0-second day — only count the day
        // as "active" once it meets the same threshold the streak uses.
        if (total >= 60) 'lastActiveDate': today,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  int _sumHifzSecondsForDate(String dateStr) {
    int total = 0;
    for (final entry in _storage.getHifzHistory()) {
      final entryDate = entry['date'] as String?;
      if (entryDate != null && entryDate.startsWith(dateStr)) {
        total += entry['durationSeconds'] as int? ?? 0;
      }
    }
    return total;
  }

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Merges a "what is this student doing right now" snapshot onto their
  /// profile doc — additive field, already covered by the existing student
  /// `update` rule. No-op if student mode isn't active.
  Future<void> setLiveActivity({
    required String feature,
    required String label,
    required int elapsedSeconds,
    int? chapterId,
    int? startAyah,
    int? endAyah,
  }) async {
    final uid = studentUid.value;
    if (uid == null) return;
    try {
      await _db.collection(kStudentsCollection).doc(uid).update({
        'liveActivity': {
          'feature': feature,
          // `label` is a language-neutral fallback; teachers render the surah
          // name from `chapterId` in their own app language.
          'label': label,
          'elapsedSeconds': elapsedSeconds,
          if (chapterId != null) 'chapterId': chapterId,
          if (startAyah != null) 'startAyah': startAyah,
          if (endAyah != null) 'endAyah': endAyah,
          'updatedAt': Timestamp.now(),
        },
      });
    } catch (_) {}
  }

  Future<void> clearLiveActivity() async {
    final uid = studentUid.value;
    if (uid == null) return;
    try {
      await _db.collection(kStudentsCollection).doc(uid).update({'liveActivity': FieldValue.delete()});
    } catch (_) {}
  }

  /// Live "what is this student doing right now" stream for a teacher
  /// viewing one student. Emits null when idle or when the field is absent.
  Stream<Map<String, dynamic>?> watchStudentLiveActivity(String forStudentUid) {
    return _db
        .collection(kStudentsCollection)
        .doc(forStudentUid)
        .snapshots()
        .map((doc) => doc.data()?['liveActivity'] as Map<String, dynamic>?);
  }

  bool _isFirstNotesSnapshot = true;

  void _watchMyNotes(String uid) {
    _notesSub?.cancel();
    _isFirstNotesSnapshot = true;
    _notesSub = _db.collection(kStudentsCollection).doc(uid).collection('notes').snapshots().listen((snap) {
      unreadNotesCount.value = snap.docs.where((d) => d.data()['read'] != true).length;

      // Firestore reports every existing document as "added" on the very
      // first listen callback — only pop a notification for notes that
      // arrive from the second emission onward (i.e. genuinely new ones).
      if (_isFirstNotesSnapshot) {
        _isFirstNotesSnapshot = false;
        return;
      }

      if (!Get.isRegistered<ReminderService>()) return;
      final reminder = Get.find<ReminderService>();
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final note = TeacherNote.fromMap(change.doc.id, change.doc.data() ?? {});
          final title = note.fromTeacherName.isEmpty ? 'teacher_link_note_notification_title'.tr : note.fromTeacherName;
          unawaited(reminder.showInstantNotification(id: note.id.hashCode, title: title, body: note.text));
        }
      }
    }, onError: (_) {});
  }

  Stream<List<TeacherNote>> watchMyNotesList(String uid) {
    return _db
        .collection(kStudentsCollection)
        .doc(uid)
        .collection('notes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => TeacherNote.fromMap(d.id, d.data())).toList());
  }

  Future<void> markNoteRead(String uid, String noteId) async {
    try {
      await _db.collection(kStudentsCollection).doc(uid).collection('notes').doc(noteId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Irreversibly deletes this student's synced cloud data and reverts the
  /// local role flag. Does not affect any teacher-mode state on this device.
  Future<void> deactivateAndDeleteCloudData() async {
    final uid = studentUid.value;
    if (uid == null) return;

    try {
      final studentRef = _db.collection(kStudentsCollection).doc(uid);
      await _deleteSubcollection(studentRef.collection('sessions'));
      await _deleteSubcollection(studentRef.collection('daily_ward'));
      await _deleteSubcollection(studentRef.collection('notes'));
      await _deleteSubcollection(studentRef.collection('links'));
      await studentRef.delete();
    } catch (_) {
      // Local cleanup still proceeds below so the user is never stuck.
    }

    await _notesSub?.cancel();
    studentUid.value = null;
    linkedTeachers.clear();
    unreadNotesCount.value = 0;

    await _storage.setStudentProfileCache({});
    await _storage.setLinkedTeachersCache([]);
    await _storage.setWardBackfillDone(false);

    final newRole = _storage.getTeacherLinkRole() == 'both' ? 'teacher' : '';
    await _storage.setTeacherLinkRole(newRole);
    role.value = newRole;

    if (newRole.isEmpty) {
      try {
        await FirebaseAuth.instance.currentUser?.delete();
      } catch (_) {}
    }
  }

  Future<void> _deleteSubcollection(CollectionReference<Map<String, dynamic>> ref) async {
    final snap = await ref.get();
    if (snap.docs.isEmpty) return;
    // Firestore batches are capped at 500 writes.
    const chunk = 450;
    for (int i = 0; i < snap.docs.length; i += chunk) {
      final batch = _db.batch();
      for (final doc in snap.docs.skip(i).take(chunk)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  @override
  void onClose() {
    _notesSub?.cancel();
    super.onClose();
  }
}
