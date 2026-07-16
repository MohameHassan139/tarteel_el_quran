import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'settings_controller.dart';
import '../../core/app_colors.dart';

class SettingsScreen extends GetView<SettingsController> {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('settings_title'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Obx(() {
          final isDark = controller.isDarkMode.value;
          final reciterId = controller.selectedReciterId.value;
          final style = controller.selectedStyle.value;
          final lang = controller.appLanguage.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // Settings Card
              Card(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    // Reciter Selector
                    ListTile(
                      title: Text('selected_reciter'.tr),
                      subtitle: Text('reciter_desc'.tr),
                      trailing: SizedBox(
                        width: 160,
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: reciterId,
                          dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontFamily: 'system-ui',
                          ),
                          items: [
                            DropdownMenuItem(value: 7, child: Text('reciter_7'.tr)),
                            DropdownMenuItem(value: 6, child: Text('reciter_6'.tr)),
                            DropdownMenuItem(value: 2, child: Text('reciter_2'.tr)),
                            DropdownMenuItem(value: 9, child: Text('reciter_9'.tr)),
                            DropdownMenuItem(value: 10, child: Text('reciter_10'.tr)),
                            DropdownMenuItem(value: 3, child: Text('reciter_3'.tr)),
                            DropdownMenuItem(value: 17, child: Text('reciter_17'.tr)),
                            DropdownMenuItem(value: 15, child: Text('reciter_15'.tr)),
                            DropdownMenuItem(value: 20, child: Text('reciter_20'.tr)),
                            DropdownMenuItem(value: 22, child: Text('reciter_22'.tr)),
                            DropdownMenuItem(value: 23, child: Text('reciter_23'.tr)),
                            DropdownMenuItem(value: 11, child: Text('reciter_11'.tr)),
                            DropdownMenuItem(value: 14, child: Text('reciter_14'.tr)),
                            DropdownMenuItem(value: 16, child: Text('reciter_16'.tr)),
                            DropdownMenuItem(value: 18, child: Text('reciter_18'.tr)),
                            DropdownMenuItem(value: 19, child: Text('reciter_19'.tr)),
                            DropdownMenuItem(value: 21, child: Text('reciter_21'.tr)),
                          ],
                          onChanged: (val) {
                            if (val != null) controller.updateReciter(val);
                          },
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),

                    if (reciterId == 6 || reciterId == 2 || reciterId == 9) ...[
                      ListTile(
                        title: Text('reciter_style'.tr),
                        subtitle: Text(reciterId == 6
                            ? 'reciter_style_desc_3'.tr
                            : 'reciter_style_desc_2'.tr),
                        trailing: SizedBox(
                          width: 120,
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: style == 'teacher' && reciterId != 6 ? 'murattal' : style,
                            dropdownColor: isDark ? AppColors.cardDark : AppColors.cardLight,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 16,
                              fontFamily: 'system-ui',
                            ),
                            items: reciterId == 6
                                ? [
                                    DropdownMenuItem(value: 'murattal', child: Text('murattal'.tr)),
                                    DropdownMenuItem(value: 'mujawwad', child: Text('mujawwad'.tr)),
                                    DropdownMenuItem(value: 'teacher', child: Text('teacher'.tr)),
                                  ]
                                : [
                                    DropdownMenuItem(value: 'murattal', child: Text('murattal'.tr)),
                                    DropdownMenuItem(value: 'mujawwad', child: Text('mujawwad'.tr)),
                                  ],
                            onChanged: (val) {
                              if (val != null) controller.updateStyle(val);
                            },
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                    
                    // Theme Selector
                    SwitchListTile(
                      title: Text('dark_mode'.tr),
                      subtitle: Text('dark_mode_desc'.tr),
                      value: isDark,
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) => controller.toggleTheme(val),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),

                    SwitchListTile(
                      title: Text('keep_screen_on'.tr),
                      subtitle: Text('keep_screen_on_desc'.tr),
                      value: controller.keepScreenOn.value,
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) => controller.toggleKeepScreenOn(val),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),

                    ListTile(
                      title: Text('app_lang'.tr),
                      subtitle: Text(lang == 'ar' ? 'arabic'.tr : 'english'.tr),
                      trailing: SizedBox(
                        width: 120,
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: lang,
                          dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontFamily: 'system-ui',
                          ),
                          items: [
                            DropdownMenuItem(value: 'ar', child: Text('arabic'.tr)),
                            DropdownMenuItem(value: 'en', child: Text('english'.tr)),
                          ],
                          onChanged: (val) {
                            if (val != null) controller.updateLanguage(val);
                          },
                        ),
                      ),
                    ),

                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Note about background execution
              Card(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.primary, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'background_remind_info'.tr,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
