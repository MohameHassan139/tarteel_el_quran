import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quran_library/quran_library.dart';
import 'settings_controller.dart';
import '../../core/app_colors.dart';

class SettingsScreen extends GetView<SettingsController> {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات العامة', style: TextStyle(fontWeight: FontWeight.bold)),
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
              // Quran Fonts Download Card
              Card(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.font_download_outlined, color: AppColors.primary),
                  title: const Text('خطوط المصحف الحقيقية', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('تحميل خطوط المصحف الشريف للعرض الأصيل'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () {
                      QuranLibrary().getFontsDownloadDialog(
                        null,
                        lang,
                      );
                    },
                    child: const Text('تحميل', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Settings Card
              Card(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    // Reciter Selector
                    ListTile(
                      title: const Text('القارئ المختار'),
                      subtitle: const Text('مصدر تلاوة الصوتيات (أونلاين/أوفلاين)'),
                      trailing: DropdownButton<int>(
                        value: reciterId,
                        dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 16,
                          fontFamily: 'system-ui',
                        ),
                        items: const [
                          DropdownMenuItem(value: 7, child: Text('مشاري العفاسي')),
                          DropdownMenuItem(value: 6, child: Text('محمود الحصري')),
                          DropdownMenuItem(value: 2, child: Text('عبد الباسط عبد الصمد')),
                          DropdownMenuItem(value: 9, child: Text('محمد صديق المنشاوي')),
                        ],
                        onChanged: (val) {
                          if (val != null) controller.updateReciter(val);
                        },
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),

                    if (reciterId != 7) ...[
                      ListTile(
                        title: const Text('رواية/أسلوب التلاوة'),
                        subtitle: Text(reciterId == 6
                            ? 'مرتّل أو معلّم (تعليمي)'
                            : 'مرتّل أو مجوّد (بالأحكام والأنغام)'),
                        trailing: DropdownButton<String>(
                          value: style,
                          dropdownColor: isDark ? AppColors.cardDark : AppColors.cardLight,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontFamily: 'system-ui',
                          ),
                          items: reciterId == 6
                              ? const [
                                  DropdownMenuItem(value: 'murattal', child: Text('مرتّل')),
                                  DropdownMenuItem(value: 'mujawwad', child: Text('معلّم')),
                                ]
                              : const [
                                  DropdownMenuItem(value: 'murattal', child: Text('مرتّل')),
                                  DropdownMenuItem(value: 'mujawwad', child: Text('مجوّد')),
                                ],
                          onChanged: (val) {
                            if (val != null) controller.updateStyle(val);
                          },
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                    
                    // Theme Selector
                    SwitchListTile(
                      title: const Text('المظهر الداكن'),
                      subtitle: const Text('تفعيل الخلفيات الداكنة لراحة العينين'),
                      value: isDark,
                      activeColor: AppColors.primary,
                      onChanged: (val) => controller.toggleTheme(val),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),

                    ListTile(
                      title: const Text('لغة التطبيق / App Language'),
                      subtitle: Text(lang == 'ar' ? 'العربية' : 'English'),
                      trailing: DropdownButton<String>(
                        value: lang,
                        dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 16,
                          fontFamily: 'system-ui',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ar', child: Text('العربية')),
                          DropdownMenuItem(value: 'en', child: Text('English')),
                        ],
                        onChanged: (val) {
                          if (val != null) controller.updateLanguage(val);
                        },
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    
                    // Notification Pipeline Test
                    ListTile(
                      title: const Text('اختبار إشعارات المنبه'),
                      subtitle: const Text('محاكاة فحص إنجاز الورد اليومي وإرسال إشعار فوري'),
                      trailing: IconButton(
                        icon: const Icon(Icons.notification_important, color: AppColors.primary),
                        onPressed: () => controller.triggerTestNotification(),
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
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'عند ضبط وقت تنبيه الورد اليومي، سيقوم التطبيق بفحص أوتوماتيكي للتأكد من إنجاز دقائق القراءة المستهدفة وتذكيرك في حال عدم الإكمال.',
                          style: TextStyle(
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
