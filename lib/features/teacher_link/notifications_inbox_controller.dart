import 'dart:async';
import 'package:get/get.dart';
import '../../core/teacher_sync_service.dart';
import 'teacher_link_models.dart';

class NotificationsInboxController extends GetxController {
  final TeacherSyncService sync = Get.find<TeacherSyncService>();

  final RxList<TeacherNote> notes = <TeacherNote>[].obs;
  StreamSubscription? _notesSub;

  @override
  void onInit() {
    super.onInit();
    final uid = sync.studentUid.value;
    if (uid != null) {
      _notesSub = sync.watchMyNotesList(uid).listen((list) {
        notes.assignAll(list);
      }, onError: (_) {});
    }
  }

  void markRead(TeacherNote note) {
    final uid = sync.studentUid.value;
    if (uid == null || note.read) return;
    sync.markNoteRead(uid, note.id);
  }

  @override
  void onClose() {
    _notesSub?.cancel();
    super.onClose();
  }
}
