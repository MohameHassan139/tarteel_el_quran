import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import '../shared/widgets/offline_banner.dart';
import 'notifications_inbox_controller.dart';

class NotificationsInboxScreen extends GetView<NotificationsInboxController> {
  const NotificationsInboxScreen({super.key});

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('teacher_link_inbox_title'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: Obx(() {
        if (controller.notes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('teacher_link_inbox_empty'.tr, style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.notes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final note = controller.notes[index];
            return Card(
              color: isDark ? AppColors.cardDark : Colors.white,
              elevation: note.read ? 1 : 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: note.read ? BorderSide.none : const BorderSide(color: AppColors.primary, width: 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => controller.markRead(note),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              note.fromTeacherName.isEmpty ? 'reciter_unknown'.tr : note.fromTeacherName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          if (!note.read)
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(note.text, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 6),
                      Text(_formatDate(note.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      })),
        ],
      ),
    );
  }
}
