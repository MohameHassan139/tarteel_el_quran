import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import '../../core/connectivity_service.dart';
import '../../core/teacher_sync_service.dart';
import 'teacher_link_models.dart';

enum TimeRange { day, week, month, all }

enum SessionFilter { all, completed, partial, lowRating }

class StudentDetailController extends GetxController {
  final TeacherSyncService sync = Get.find<TeacherSyncService>();
  ConnectivityService? get _connectivity =>
      Get.isRegistered<ConnectivityService>() ? Get.find<ConnectivityService>() : null;

  late final String studentUid;
  late final String studentName;

  final Rxn<StudentSummary> profile = Rxn<StudentSummary>();
  final RxList<HifzSessionRecord> sessions = <HifzSessionRecord>[].obs;
  final RxMap<String, DailyActivity> dailyWard = <String, DailyActivity>{}.obs;
  final Rxn<Map<String, dynamic>> liveActivity = Rxn<Map<String, dynamic>>();
  final RxBool isLoadingProfile = true.obs;
  final RxBool isLoadingSessions = true.obs;
  final Rx<TimeRange> selectedRange = TimeRange.week.obs;
  final Rx<SessionFilter> sessionFilter = SessionFilter.all.obs;

  /// Bumped periodically so the "live now" banner disappears once stale.
  final RxInt clockTick = 0.obs;
  Timer? _clockTimer;

  final noteController = TextEditingController();
  final RxBool isSendingNote = false.obs;

  StreamSubscription? _sessionsSub;
  StreamSubscription? _wardSub;
  StreamSubscription? _liveActivitySub;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments is Map ? Get.arguments as Map : const {};
    studentUid = args['studentUid'] as String? ?? '';
    studentName = args['studentName'] as String? ?? '';
    if (studentUid.isEmpty) {
      isLoadingProfile.value = false;
      isLoadingSessions.value = false;
      return;
    }

    _clockTimer = Timer.periodic(const Duration(seconds: 20), (_) => clockTick.value++);
    _loadProfile();
    final teacherUid = sync.teacherUid.value;
    if (teacherUid != null) {
      _sessionsSub = sync.watchStudentSessions(studentUid, viewerTeacherUid: teacherUid).listen((list) {
        sessions.assignAll(list);
        isLoadingSessions.value = false;
      }, onError: (_) {
        isLoadingSessions.value = false;
      });
    } else {
      isLoadingSessions.value = false;
    }
    _wardSub = sync.watchStudentDailyWard(studentUid, lastNDays: 366).listen((map) {
      dailyWard.assignAll(map);
    }, onError: (_) {});
    _liveActivitySub = sync.watchStudentLiveActivity(studentUid).listen((activity) {
      liveActivity.value = activity;
    }, onError: (_) {});
  }

  Future<void> _loadProfile() async {
    isLoadingProfile.value = true;
    profile.value = await sync.fetchStudentProfile(studentUid);
    isLoadingProfile.value = false;
  }

  void setRange(TimeRange range) => selectedRange.value = range;

  /// True while the live-activity timestamp is recent enough to trust —
  /// stale entries (student closed the app / lost connection) are treated
  /// as "not currently active" rather than shown forever.
  bool get isLiveActivityFresh {
    clockTick.value; // re-evaluate periodically
    return isLiveActivityMapFresh(liveActivity.value);
  }

  int get _rangeDays {
    switch (selectedRange.value) {
      case TimeRange.day:
        return 1;
      case TimeRange.week:
        return 7;
      case TimeRange.month:
        return 30;
      case TimeRange.all:
        return 3650;
    }
  }

  /// Calendar-day window: "week" = today + the 6 previous days, for both
  /// daily-ward dates (midnight) and session timestamps (any time of day).
  bool _withinRange(DateTime date) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, now.day - (_rangeDays - 1));
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(firstDay);
  }

  List<HifzSessionRecord> get filteredSessions {
    if (selectedRange.value == TimeRange.all) return sessions;
    return sessions.where((s) {
      final date = DateTime.tryParse(s.date);
      return date != null && _withinRange(date);
    }).toList();
  }

  Map<String, DailyActivity> get filteredDailyWard {
    if (selectedRange.value == TimeRange.all) return dailyWard;
    final result = <String, DailyActivity>{};
    dailyWard.forEach((dateStr, activity) {
      final date = DateTime.tryParse(dateStr);
      if (date != null && _withinRange(date)) {
        result[dateStr] = activity;
      }
    });
    return result;
  }

  /// Session list after the range AND the review filter chips.
  List<HifzSessionRecord> get reviewSessions {
    final f = sessionFilter.value;
    final base = filteredSessions;
    switch (f) {
      case SessionFilter.all:
        return base;
      case SessionFilter.completed:
        return base.where((s) => s.fullyCompleted).toList();
      case SessionFilter.partial:
        return base.where((s) => !s.fullyCompleted).toList();
      case SessionFilter.lowRating:
        return base.where((s) => s.rating > 0 && s.rating <= 2).toList();
    }
  }

  double get averageRating {
    final rated = filteredSessions.where((s) => s.rating > 0).toList();
    if (rated.isEmpty) return 0;
    return rated.fold<int>(0, (acc, s) => acc + s.rating) / rated.length;
  }

  int get completionPercent {
    final list = filteredSessions;
    if (list.isEmpty) return 0;
    return (list.where((s) => s.fullyCompleted).length * 100 / list.length).round();
  }

  int get ayahsReviewed => filteredSessions.fold<int>(0, (acc, s) => acc + s.reachedCount);

  /// Hifz minutes come from the daily ward breakdown (covers every session,
  /// shared or private), falling back to shared sessions for legacy days.
  int get totalHifzMinutes {
    final fromWard = filteredDailyWard.values.fold<int>(0, (acc, d) => acc + d.hifzSeconds);
    final seconds = fromWard > 0 ? fromWard : filteredSessions.fold<int>(0, (acc, s) => acc + s.durationSeconds);
    return (seconds / 60).round();
  }

  int get totalMinutes => (filteredDailyWard.values.fold<int>(0, (acc, d) => acc + d.seconds) / 60).round();
  int get totalMushafMinutes => (filteredDailyWard.values.fold<int>(0, (acc, d) => acc + d.mushafSeconds) / 60).round();
  int get totalAudioMinutes => (filteredDailyWard.values.fold<int>(0, (acc, d) => acc + d.audioSeconds) / 60).round();
  int get activeDaysInRange => filteredDailyWard.values.where((d) => d.seconds >= 60).length;

  /// Sends the draft typed in the Notes tab; clears it on success.
  Future<bool> sendNote() async {
    final ok = await sendNoteText(noteController.text);
    if (ok) noteController.clear();
    return ok;
  }

  /// Sends [text] as a note (used by the Notes tab and the composer sheet).
  Future<bool> sendNoteText(String text) async {
    final body = text.trim();
    if (body.isEmpty || isSendingNote.value) return false;
    final teacherUid = sync.teacherUid.value;
    final teacherName = sync.teacherProfile.value?.displayName ?? '';
    if (teacherUid == null || studentUid.isEmpty) return false;
    if (!(_connectivity?.isOnline.value ?? true)) {
      Get.snackbar('teacher_link_error'.tr, 'teacher_link_needs_internet'.tr, snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    isSendingNote.value = true;
    try {
      await sync.sendNoteToStudent(
        studentUidToNotify: studentUid,
        fromTeacherUid: teacherUid,
        fromTeacherName: teacherName,
        text: body,
      );
      Get.snackbar(
        'teacher_link_note_sent_title'.tr,
        'teacher_link_note_sent_desc'.tr,
        backgroundColor: AppColors.primary,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    } catch (e) {
      Get.snackbar('teacher_link_error'.tr, e.toString(), snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isSendingNote.value = false;
    }
  }

  @override
  void onClose() {
    _sessionsSub?.cancel();
    _wardSub?.cancel();
    _liveActivitySub?.cancel();
    _clockTimer?.cancel();
    noteController.dispose();
    super.onClose();
  }
}
