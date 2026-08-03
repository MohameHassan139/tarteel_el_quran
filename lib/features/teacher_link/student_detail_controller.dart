import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import '../../core/connectivity_service.dart';
import '../../core/teacher_sync_service.dart';
import 'teacher_link_models.dart';

enum TimeRange { day, week, month, all }

class StudentDetailController extends GetxController {
  final TeacherSyncService sync = Get.find<TeacherSyncService>();
  final ConnectivityService _connectivity = Get.find<ConnectivityService>();

  late final String studentUid;
  late final String studentName;

  final Rxn<StudentSummary> profile = Rxn<StudentSummary>();
  final RxList<HifzSessionRecord> sessions = <HifzSessionRecord>[].obs;
  final RxMap<String, DailyActivity> dailyWard = <String, DailyActivity>{}.obs;
  final Rxn<Map<String, dynamic>> liveActivity = Rxn<Map<String, dynamic>>();
  final RxBool isLoadingProfile = true.obs;
  final Rx<TimeRange> selectedRange = TimeRange.week.obs;

  final noteController = TextEditingController();
  final RxBool isSendingNote = false.obs;

  StreamSubscription? _sessionsSub;
  StreamSubscription? _wardSub;
  StreamSubscription? _liveActivitySub;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map;
    studentUid = args['studentUid'] as String;
    studentName = args['studentName'] as String? ?? '';

    _loadProfile();
    _sessionsSub = sync.watchStudentSessions(studentUid).listen((list) {
      sessions.assignAll(list);
    }, onError: (_) {});
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
    final activity = liveActivity.value;
    if (activity == null) return false;
    final updatedAt = activity['updatedAt'];
    DateTime? updatedAtDate;
    if (updatedAt is Timestamp) updatedAtDate = updatedAt.toDate();
    if (updatedAtDate == null) return false;
    return DateTime.now().difference(updatedAtDate) < const Duration(minutes: 2);
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

  bool _withinRange(DateTime date) {
    final now = DateTime.now();
    if (selectedRange.value == TimeRange.day) {
      return date.year == now.year && date.month == now.month && date.day == now.day;
    }
    final cutoff = now.subtract(Duration(days: _rangeDays));
    return date.isAfter(cutoff);
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

  int get totalHifzMinutes => (filteredSessions.fold<int>(0, (acc, s) => acc + s.durationSeconds) / 60).round();
  int get totalMushafMinutes => (filteredDailyWard.values.fold<int>(0, (acc, d) => acc + d.mushafSeconds) / 60).round();
  int get totalAudioMinutes => (filteredDailyWard.values.fold<int>(0, (acc, d) => acc + d.audioSeconds) / 60).round();
  int get activeDaysInRange => filteredDailyWard.values.where((d) => d.seconds > 0).length;

  Future<void> sendNote() async {
    final text = noteController.text.trim();
    if (text.isEmpty) return;
    final teacherUid = sync.teacherUid.value;
    final teacherName = sync.teacherProfile.value?.displayName ?? '';
    if (teacherUid == null) return;
    if (!_connectivity.isOnline.value) {
      Get.snackbar('teacher_link_error'.tr, 'teacher_link_needs_internet'.tr, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    isSendingNote.value = true;
    try {
      await sync.sendNoteToStudent(
        studentUidToNotify: studentUid,
        fromTeacherUid: teacherUid,
        fromTeacherName: teacherName,
        text: text,
      );
      noteController.clear();
      Get.snackbar(
        'teacher_link_note_sent_title'.tr,
        'teacher_link_note_sent_desc'.tr,
        backgroundColor: AppColors.primary,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('teacher_link_error'.tr, e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isSendingNote.value = false;
    }
  }

  @override
  void onClose() {
    _sessionsSub?.cancel();
    _wardSub?.cancel();
    _liveActivitySub?.cancel();
    noteController.dispose();
    super.onClose();
  }
}
