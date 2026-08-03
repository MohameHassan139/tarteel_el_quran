import 'package:get/get.dart';
import 'role_onboarding_controller.dart';
import 'student_profile_controller.dart';
import 'teacher_dashboard_controller.dart';
import 'student_detail_controller.dart';
import 'notifications_inbox_controller.dart';

class RoleOnboardingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => RoleOnboardingController());
  }
}

class StudentProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => StudentProfileController());
  }
}

class TeacherDashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => TeacherDashboardController());
  }
}

class StudentDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => StudentDetailController());
  }
}

class NotificationsInboxBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => NotificationsInboxController());
  }
}
