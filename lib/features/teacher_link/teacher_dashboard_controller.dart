import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import '../../core/connectivity_service.dart';
import '../../core/teacher_sync_service.dart';
import 'teacher_link_models.dart';

enum StudentFilter { all, activeToday, needsAttention }

enum StudentSort { recent, name, streak }

class TeacherDashboardController extends GetxController {
  final TeacherSyncService sync = Get.find<TeacherSyncService>();
  ConnectivityService? get _connectivity =>
      Get.isRegistered<ConnectivityService>() ? Get.find<ConnectivityService>() : null;
  bool get _isOnline => _connectivity?.isOnline.value ?? true;

  final nameController = TextEditingController();
  final searchController = TextEditingController();
  final RxBool isSaving = false.obs;
  final RxBool isLoadingStudents = true.obs;
  final RxList<StudentSummary> students = <StudentSummary>[].obs;

  final RxString searchQuery = ''.obs;
  final Rx<StudentFilter> filter = StudentFilter.all.obs;
  final Rx<StudentSort> sort = StudentSort.recent.obs;

  /// Bumped every 30s so "live now" badges expire without a new snapshot.
  final RxInt clockTick = 0.obs;
  Timer? _clockTimer;

  StreamSubscription? _studentsSub;

  int get activeTodayCount => students.where((s) => s.isActiveToday).length;
  int get needsAttentionCount => students.where((s) => s.needsAttention).length;
  int get liveCount => students.where((s) => s.isLiveNow).length;

  /// Search + filter + sort applied. Reads every reactive input so an `Obx`
  /// that calls it rebuilds when any of them changes.
  List<StudentSummary> get visibleStudents {
    clockTick.value; // dependency only
    final q = searchQuery.value.trim().toLowerCase();
    final f = filter.value;
    final list = students.where((s) {
      if (q.isNotEmpty && !s.name.toLowerCase().contains(q)) return false;
      switch (f) {
        case StudentFilter.all:
          return true;
        case StudentFilter.activeToday:
          return s.isActiveToday;
        case StudentFilter.needsAttention:
          return s.needsAttention;
      }
    }).toList();

    int byRecent(StudentSummary a, StudentSummary b) {
      if (a.isLiveNow != b.isLiveNow) return a.isLiveNow ? -1 : 1;
      final da = a.daysSinceActive ?? 1 << 30;
      final db = b.daysSinceActive ?? 1 << 30;
      return da.compareTo(db);
    }

    switch (sort.value) {
      case StudentSort.recent:
        list.sort(byRecent);
        break;
      case StudentSort.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case StudentSort.streak:
        list.sort((a, b) => b.currentStreakDays.compareTo(a.currentStreakDays));
        break;
    }
    return list;
  }

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(() => searchQuery.value = searchController.text);
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) => clockTick.value++);
    if (sync.isTeacher) {
      _watchStudents();
    } else {
      isLoadingStudents.value = false;
    }
  }

  void _watchStudents() {
    final uid = sync.teacherUid.value;
    if (uid == null) {
      isLoadingStudents.value = false;
      return;
    }
    _studentsSub?.cancel();
    isLoadingStudents.value = true;
    _studentsSub = sync.watchLinkedStudents(uid).listen((list) {
      students.assignAll(list);
      isLoadingStudents.value = false;
    }, onError: (_) {
      isLoadingStudents.value = false;
    });
  }

  /// Sends a short note straight from the dashboard (no need to open the
  /// student's page). Returns true on success.
  Future<bool> sendQuickNote(StudentSummary student, String text) async {
    final body = text.trim();
    final teacherUid = sync.teacherUid.value;
    if (body.isEmpty || teacherUid == null) return false;
    if (!_isOnline) {
      Get.snackbar('teacher_link_error'.tr, 'teacher_link_needs_internet'.tr, snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    try {
      await sync.sendNoteToStudent(
        studentUidToNotify: student.uid,
        fromTeacherUid: teacherUid,
        fromTeacherName: sync.teacherProfile.value?.displayName ?? '',
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
    }
  }

  Future<void> activate() async {
    if (nameController.text.trim().isEmpty) {
      Get.snackbar('teacher_link_error'.tr, 'teacher_link_name_required'.tr, snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (!_isOnline) {
      Get.snackbar('teacher_link_error'.tr, 'teacher_link_needs_internet'.tr, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    isSaving.value = true;
    try {
      await sync.activateTeacherMode(nameController.text.trim());
      _watchStudents();
    } catch (e) {
      Get.snackbar('teacher_link_error'.tr, e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isSaving.value = false;
    }
  }

  void copyShareCode() {
    final code = sync.teacherProfile.value?.shareCode;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    Get.snackbar(
      'teacher_link_code_copied'.tr,
      code,
      backgroundColor: AppColors.primary,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> deactivate() async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.getCard(Get.isDarkMode),
        title: Text('teacher_link_deactivate_title'.tr, style: TextStyle(color: Get.isDarkMode ? Colors.white : Colors.black87)),
        content: Text(
          'teacher_link_deactivate_confirm'.tr,
          style: TextStyle(color: Get.isDarkMode ? Colors.grey : Colors.black54),
        ),
        actions: [
          TextButton(child: Text('cancel'.tr, style: const TextStyle(color: Colors.grey)), onPressed: () => Get.back(result: false)),
          TextButton(child: Text('teacher_link_deactivate_action'.tr, style: const TextStyle(color: Colors.red)), onPressed: () => Get.back(result: true)),
        ],
      ),
    );
    if (confirm != true) return;
    if (!_isOnline) {
      Get.snackbar('teacher_link_error'.tr, 'teacher_link_needs_internet'.tr, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    await _studentsSub?.cancel();
    students.clear();
    await sync.deactivateTeacherMode();
    nameController.clear();
  }

  @override
  void onClose() {
    _studentsSub?.cancel();
    _clockTimer?.cancel();
    nameController.dispose();
    searchController.dispose();
    super.onClose();
  }
}
