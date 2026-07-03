import 'package:flutter/material.dart';
import 'package:quran_library/quran_library.dart';
import '../../main.dart'; // To get Locator

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedReciterId = 7;
  String _selectedStyle = 'murattal';
  bool _isDark = true;
  String _appLanguage = 'ar';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final storage = Locator.storage;
    setState(() {
      _selectedReciterId = storage.getSelectedReciterId();
      _selectedStyle = storage.getSelectedStyle();
      _isDark = storage.isDarkMode();
      _appLanguage = storage.getAppLanguage();
    });
  }

  Future<void> _updateReciter(int id) async {
    await Locator.storage.setSelectedReciterId(id);
    if (id == 7) {
      await Locator.storage.setSelectedStyle('murattal');
      _selectedStyle = 'murattal';
    }
    setState(() {
      _selectedReciterId = id;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تحديث القارئ المفضل بنجاح'),
        backgroundColor: Color(0xFFC19A6B),
      ),
    );
  }

  Future<void> _updateStyle(String style) async {
    await Locator.storage.setSelectedStyle(style);
    setState(() {
      _selectedStyle = style;
    });
    String styleAr = '';
    if (_selectedReciterId == 6) {
      styleAr = style == 'mujawwad' ? 'معلّم' : 'مرتّل';
    } else {
      styleAr = style == 'mujawwad' ? 'مجوّد' : 'مرتّل';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم اختيار رواية/نمط التلاوة: $styleAr'),
        backgroundColor: const Color(0xFFC19A6B),
      ),
    );
  }

  Future<void> _toggleTheme(bool value) async {
    await Locator.storage.setDarkMode(value);
    Locator.themeNotifier.value = value;
    setState(() {
      _isDark = value;
    });
  }

  Future<void> _triggerTestNotification() async {
    await Locator.reminder.triggerInstantTestNotification();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إرسال تنبيه تجريبي! تحقق من لوحة الإشعارات.'),
        backgroundColor: Color(0xFFC19A6B),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Locator.storage.isDarkMode();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات العامة', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quran Fonts Download Card
            Card(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.font_download_outlined, color: Color(0xFFC19A6B)),
                title: const Text('خطوط المصحف الحقيقية', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('تحميل خطوط المصحف الشريف للعرض الأصيل'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC19A6B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () {
                    QuranLibrary().getFontsDownloadDialog(
                      null,
                      Locator.storage.getAppLanguage(),
                    );
                  },
                  child: const Text('تحميل', style: TextStyle(fontSize: 13)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Settings Card
            Card(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  // Reciter Selector
                  ListTile(
                    title: const Text('القارئ المختار'),
                    subtitle: const Text('مصدر تلاوة الصوتيات (أونلاين/أوفلاين)'),
                    trailing: DropdownButton<int>(
                      value: _selectedReciterId,
                      dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                        if (val != null) _updateReciter(val);
                      },
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),

                  if (_selectedReciterId != 7) ...[
                    ListTile(
                      title: const Text('رواية/أسلوب التلاوة'),
                      subtitle: Text(_selectedReciterId == 6
                          ? 'مرتّل أو معلّم (تعليمي)'
                          : 'مرتّل أو مجوّد (بالأحكام والأنغام)'),
                      trailing: DropdownButton<String>(
                        value: _selectedStyle,
                        dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 16,
                          fontFamily: 'system-ui',
                        ),
                        items: _selectedReciterId == 6
                            ? const [
                                DropdownMenuItem(value: 'murattal', child: Text('مرتّل')),
                                DropdownMenuItem(value: 'mujawwad', child: Text('معلّم')),
                              ]
                            : const [
                                DropdownMenuItem(value: 'murattal', child: Text('مرتّل')),
                                DropdownMenuItem(value: 'mujawwad', child: Text('مجوّد')),
                              ],
                        onChanged: (val) {
                          if (val != null) _updateStyle(val);
                        },
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                  
                  // Theme Selector
                  SwitchListTile(
                    title: const Text('المظهر الداكن'),
                    subtitle: const Text('تفعيل الخلفيات الداكنة لراحة العينين'),
                    value: _isDark,
                    activeColor: const Color(0xFFC19A6B),
                    onChanged: _toggleTheme,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),

                  ListTile(
                    title: const Text('لغة التطبيق / App Language'),
                    subtitle: Text(_appLanguage == 'ar' ? 'العربية' : 'English'),
                    trailing: DropdownButton<String>(
                      value: _appLanguage,
                      dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 16,
                        fontFamily: 'system-ui',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ar', child: Text('العربية')),
                        DropdownMenuItem(value: 'en', child: Text('English')),
                      ],
                      onChanged: (val) async {
                        if (val != null) {
                          await Locator.storage.setAppLanguage(val);
                          Locator.languageNotifier.value = val;
                          setState(() {
                            _appLanguage = val;
                          });
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  
                  // Notification Pipeline Test
                  ListTile(
                    title: const Text('اختبار إشعارات المنبه'),
                    subtitle: const Text('محاكاة فحص إنجاز الورد اليومي وإرسال إشعار فوري'),
                    trailing: IconButton(
                      icon: const Icon(Icons.notification_important, color: Color(0xFFC19A6B)),
                      onPressed: _triggerTestNotification,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Note about background execution
            Card(
              color: const Color(0xFFC19A6B).withOpacity(0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFC19A6B), width: 0.5),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFC19A6B)),
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
        ),
      ),
    );
  }
}
