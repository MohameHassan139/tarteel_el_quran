import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'ward_controller.dart';

class WardScreen extends GetView<WardController> {
  const WardScreen({super.key});

  Future<void> _pickTime(BuildContext context) async {
    final goal = controller.wardGoal.value;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: goal.reminderHour, minute: goal.reminderMinute),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFC19A6B),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await controller.setReminderTime(picked.hour, picked.minute);
      Get.snackbar(
        'تنبيه الورد',
        'تم جدولة المنبه اليومي في تمام الساعة ${picked.format(context)}',
        backgroundColor: const Color(0xFFC19A6B),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  String _formatTime(int hour, int minute) {
    final hr = hour.toString().padLeft(2, '0');
    final min = minute.toString().padLeft(2, '0');
    return "$hr:$min";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = controller.isDarkMode();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الورد والمتابعة', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Obx(() {
          final goal = controller.wardGoal.value;
          final completedSeconds = goal.activeSecondsToday;
          final targetSeconds = goal.targetMinutes * 60;
          final progress = targetSeconds > 0 ? (completedSeconds / targetSeconds) : 0.0;
          
          final completedMinutes = (completedSeconds / 60).floor();
          final remainingMinutes = goal.targetMinutes - completedMinutes;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Accountability Goal Card
              Card(
                color: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Text(
                        "معدل تقدم اليوم",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Circular Progress Tracker
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: CircularProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              strokeWidth: 12,
                              backgroundColor: Colors.grey[850],
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC19A6B)),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$completedMinutes',
                                style: const TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'من أصل ${goal.targetMinutes} دقيقة',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      Text(
                        remainingMinutes <= 0
                            ? "أحسنت! تم إنجاز الورد اليومي بنجاح 🎉"
                            : "متبقي $remainingMinutes دقيقة لإنجاز الورد اليومي.",
                        style: TextStyle(
                          color: remainingMinutes <= 0 ? const Color(0xFFC19A6B) : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "ملاحظة: يقوم التطبيق بحساب وقت القراءة أوتوماتيكياً عند تصفح المصحف.",
                        style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Goal & Notification Configuration
              const Text(
                'إعدادات الورد والمنبه',
                style: TextStyle(color: Color(0xFFC19A6B), fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
              ),
              const SizedBox(height: 12),
              Card(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('المدة اليومية المستهدفة'),
                      trailing: DropdownButton<int>(
                        value: goal.targetMinutes,
                        dropdownColor: const Color(0xFF1E1E1E),
                        items: [10, 15, 20, 30, 45, 60].map((e) {
                          return DropdownMenuItem(value: e, child: Text('$e دقيقة'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) controller.updateTargetMinutes(val);
                        },
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      title: const Text('وقت التنبيه اليومي'),
                      subtitle: const Text('تذكير في حال عدم إكمال الورد'),
                      trailing: ActionChip(
                        backgroundColor: const Color(0xFFC19A6B).withOpacity(0.15),
                        side: const BorderSide(color: Color(0xFFC19A6B)),
                        label: Text(
                          _formatTime(goal.reminderHour, goal.reminderMinute),
                          style: const TextStyle(color: Color(0xFFC19A6B), fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _pickTime(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Reading History
              const Text(
                'سجل القراءة السابق',
                style: TextStyle(color: Color(0xFFC19A6B), fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
              ),
              const SizedBox(height: 12),
              Obx(() {
                if (controller.history.isEmpty) {
                  return Card(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        'لا توجد سجلات سابقة بعد. أكمل ورد اليوم لبدء تسجيل تقدمك التاريخي!',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return Card(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: controller.history.entries.map((entry) {
                        final readMins = (entry.value / 60).toStringAsFixed(1);
                        return ListTile(
                          leading: const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                          title: Text(entry.key),
                          trailing: Text(
                            '$readMins دقيقة',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC19A6B)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 40),
            ],
          );
        }),
      ),
    );
  }
}
