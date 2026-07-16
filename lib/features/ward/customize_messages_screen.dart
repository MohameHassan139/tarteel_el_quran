import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
import '../../core/reminder_service.dart';
import '../../core/app_colors.dart';
import '../../models.dart';

class CustomizeMessagesController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final ReminderService _reminder = Get.find<ReminderService>();

  final RxList<ReminderMessage> messages = <ReminderMessage>[].obs;
  final RxString selectedCategory = 'start'.obs; // 'start', 'incomplete', 'completed'

  @override
  void onInit() {
    super.onInit();
    loadMessages();
  }

  void loadMessages() {
    messages.assignAll(_storage.getReminderMessages());
  }

  List<ReminderMessage> get filteredMessages {
    return messages.where((m) => m.category == selectedCategory.value).toList();
  }

  Future<void> addMessage(String textAr, String textEn) async {
    final newMsg = ReminderMessage(
      id: '${selectedCategory.value}_${DateTime.now().millisecondsSinceEpoch}',
      category: selectedCategory.value,
      textAr: textAr.trim(),
      textEn: textEn.trim(),
    );
    messages.add(newMsg);
    await _storage.saveReminderMessages(messages);
    await _reminder.rescheduleAllReminders();
    loadMessages();
  }

  Future<void> editMessage(String id, String textAr, String textEn) async {
    final idx = messages.indexWhere((m) => m.id == id);
    if (idx != -1) {
      messages[idx] = messages[idx].copyWith(
        textAr: textAr.trim(),
        textEn: textEn.trim(),
      );
      await _storage.saveReminderMessages(messages);
      await _reminder.rescheduleAllReminders();
      loadMessages();
    }
  }

  Future<void> deleteMessage(String id) async {
    messages.removeWhere((m) => m.id == id);
    await _storage.saveReminderMessages(messages);
    await _reminder.rescheduleAllReminders();
    loadMessages();
  }
}

class CustomizeMessagesScreen extends StatelessWidget {
  const CustomizeMessagesScreen({super.key});

  void _showAddEditDialog(BuildContext context, CustomizeMessagesController controller, {ReminderMessage? message}) {
    final textArController = TextEditingController(text: message?.textAr ?? '');
    final textEnController = TextEditingController(text: message?.textEn ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            message == null ? 'add_message'.tr : 'edit_message'.tr,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textArController,
                  maxLines: 3,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: 'message_text_ar'.tr,
                    labelStyle: const TextStyle(color: AppColors.primary),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.grey, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textEnController,
                  maxLines: 3,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'message_text_en'.tr,
                    labelStyle: const TextStyle(color: AppColors.primary),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.grey, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'cancel'.tr,
                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (textArController.text.trim().isEmpty || textEnController.text.trim().isEmpty) {
                  Get.snackbar(
                    'error'.tr,
                    'empty_message_error'.tr,
                    backgroundColor: Colors.redAccent,
                    colorText: Colors.white,
                  );
                  return;
                }
                if (message == null) {
                  controller.addMessage(textArController.text, textEnController.text);
                } else {
                  controller.editMessage(message.id, textArController.text, textEnController.text);
                }
                Navigator.pop(context);
                Get.snackbar(
                  'success'.tr,
                  'save_message'.tr,
                  backgroundColor: AppColors.primary,
                  colorText: Colors.white,
                );
              },
              child: Text('save_message'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CustomizeMessagesController());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'customize_reminder_messages'.tr,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddEditDialog(context, controller),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Styled Category Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Obx(() {
              return Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : AppColors.cardLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    _buildCategoryTab(controller, 'start', 'start_wird_messages'.tr),
                    _buildCategoryTab(controller, 'incomplete', 'incomplete_wird_messages'.tr),
                    _buildCategoryTab(controller, 'completed', 'completed_wird_messages'.tr),
                  ],
                ),
              );
            }),
          ),

          // Messages List
          Expanded(
            child: Obx(() {
              final msgs = controller.filteredMessages;
              if (msgs.isEmpty) {
                return Center(
                  child: Text(
                    'no_records'.tr,
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                itemCount: msgs.length,
                itemBuilder: (context, index) {
                  final msg = msgs[index];
                  final isRtl = Get.locale?.languageCode == 'ar';
                  final titleText = isRtl ? msg.textAr : msg.textEn;
                  final subtitleText = isRtl ? msg.textEn : msg.textAr;

                  return Card(
                    color: isDark ? AppColors.cardDark : AppColors.cardLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    margin: const EdgeInsets.only(bottom: 12.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  titleText,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  subtitleText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[500],
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                onPressed: () => _showAddEditDialog(context, controller, message: msg),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  Get.dialog(
                                    AlertDialog(
                                      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      title: Text('delete'.tr),
                                      content: Text('delete_message_confirm'.tr),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Get.back(),
                                          child: Text('cancel'.tr, style: const TextStyle(color: Colors.grey)),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                          onPressed: () {
                                            controller.deleteMessage(msg.id);
                                            Get.back();
                                            Get.snackbar(
                                              'success'.tr,
                                              'delete'.tr,
                                              backgroundColor: AppColors.primary,
                                              colorText: Colors.white,
                                            );
                                          },
                                          child: Text('delete'.tr, style: const TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(CustomizeMessagesController controller, String category, String title) {
    final isSelected = controller.selectedCategory.value == category;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.selectedCategory.value = category,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
