import 'dart:async';
import 'package:flutter/material.dart';
import '../../models.dart';
import '../../main.dart'; // To get Locator

class WardScreen extends StatefulWidget {
  const WardScreen({super.key});

  @override
  State<WardScreen> createState() => _WardScreenState();
}

class _WardScreenState extends State<WardScreen> {
  late WardGoal _goal;
  Map<String, int> _history = {};
  Timer? _uiUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Periodically refresh the UI to show ticking seconds logged in StorageService
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _goal = Locator.storage.getWardGoal();
        });
      }
    });
  }

  @override
  void dispose() {
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  void _loadData() {
    final storage = Locator.storage;
    setState(() {
      _goal = storage.getWardGoal();
      _history = storage.getWardHistory();
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _goal.reminderHour, minute: _goal.reminderMinute),
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
      final updatedGoal = _goal.copyWith(
        reminderHour: picked.hour,
        reminderMinute: picked.minute,
      );
      await Locator.storage.saveWardGoal(updatedGoal);
      // Re-schedule daily reminder
      await Locator.reminder.scheduleDailyReminder(picked.hour, picked.minute);

      setState(() {
        _goal = updatedGoal;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم جدولة المنبه اليومي في تمام الساعة ${picked.format(context)}'),
          backgroundColor: const Color(0xFFC19A6B),
        ),
      );
    }
  }

  Future<void> _updateTargetMinutes(int minutes) async {
    final updated = _goal.copyWith(targetMinutes: minutes);
    await Locator.storage.saveWardGoal(updated);
    setState(() {
      _goal = updated;
    });
  }

  String _formatTime(int hour, int minute) {
    final hr = hour.toString().padLeft(2, '0');
    final min = minute.toString().padLeft(2, '0');
    return "$hr:$min";
  }

  @override
  Widget build(BuildContext context) {
    final completedSeconds = _goal.activeSecondsToday;
    final targetSeconds = _goal.targetMinutes * 60;
    final progress = targetSeconds > 0 ? (completedSeconds / targetSeconds) : 0.0;
    
    final completedMinutes = (completedSeconds / 60).floor();
    final remainingMinutes = _goal.targetMinutes - completedMinutes;

    final isDark = Locator.storage.isDarkMode();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الورد والمتابعة', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
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
                              'من أصل ${_goal.targetMinutes} دقيقة',
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
                      value: _goal.targetMinutes,
                      dropdownColor: const Color(0xFF1E1E1E),
                      items: [10, 15, 20, 30, 45, 60].map((e) {
                        return DropdownMenuItem(value: e, child: Text('$e دقيقة'));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) _updateTargetMinutes(val);
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
                        _formatTime(_goal.reminderHour, _goal.reminderMinute),
                        style: const TextStyle(color: Color(0xFFC19A6B), fontWeight: FontWeight.bold),
                      ),
                      onPressed: _pickTime,
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
            _history.isEmpty
                ? Card(
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
                  )
                : Card(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: _history.entries.map((entry) {
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
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
