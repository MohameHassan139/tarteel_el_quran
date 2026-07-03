import 'dart:async';
import 'package:flutter/material.dart';
import '../../models.dart';
import '../../main.dart'; // To get Locator
import '../widgets/bottom_player.dart';
import 'mushaf_screen.dart';
import 'hifz_screen.dart';
import 'ward_screen.dart';
import 'settings_screen.dart';
import 'audio_hub_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late WardGoal _goal;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _goal = Locator.storage.getWardGoal();
    
    // Periodically update the progress display to capture active reading duration changes
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _goal = Locator.storage.getWardGoal();
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Widget _buildGridItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget targetScreen,
  }) {
    final isDark = Locator.storage.isDarkMode();
    
    return Card(
      elevation: 4,
      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3EFE6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => targetScreen),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Locator.storage.isDarkMode();
    final completedMinutes = (_goal.activeSecondsToday / 60).floor();
    final progress = _goal.targetMinutes > 0 ? (completedMinutes / _goal.targetMinutes) : 0.0;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Dashboard Layout
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 110), // Room for bottom player
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Greeting
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ترتيل القرآن',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC19A6B),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'بوابة القراءة والاستماع والحفظ',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.settings, color: Color(0xFFC19A6B), size: 26),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SettingsScreen()),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFFC19A6B).withOpacity(0.15),
                            child: const Icon(Icons.stars, color: Color(0xFFC19A6B), size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Today's Ward Progress Card
                  Card(
                    color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3EFE6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'الورد اليومي',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '$completedMinutes من ${_goal.targetMinutes} دقيقة',
                                style: const TextStyle(
                                  color: Color(0xFFC19A6B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: isDark ? Colors.grey[850] : Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC19A6B)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            progress >= 1.0
                                ? 'أحسنت! لقد أكملت وردك لليوم 🎉'
                                : 'متبقي ${(_goal.targetMinutes - completedMinutes).clamp(0, _goal.targetMinutes)} دقيقة لإنجاز هدف اليوم.',
                            style: TextStyle(
                              color: progress >= 1.0 ? const Color(0xFFC19A6B) : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Grid Menu Header
                  const Text(
                    'الخدمات والميزات',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC19A6B),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2x2 Grid View
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.15,
                    children: [
                      _buildGridItem(
                        context: context,
                        title: 'المصحف الشريف',
                        subtitle: 'قراءة السور وتصفح التفسير',
                        icon: Icons.menu_book,
                        color: const Color(0xFFC19A6B),
                        targetScreen: const MushafScreen(),
                      ),
                      _buildGridItem(
                        context: context,
                        title: 'حفظ القرآن',
                        subtitle: 'حلقة تكرار وحفظ الآيات',
                        icon: Icons.psychology,
                        color: Colors.blueAccent,
                        targetScreen: const HifzScreen(),
                      ),
                      _buildGridItem(
                        context: context,
                        title: 'الورد والمتابعة',
                        subtitle: 'سجل الإنجاز والهدف اليومي',
                        icon: Icons.assignment_turned_in,
                        color: Colors.green,
                        targetScreen: const WardScreen(),
                      ),
                      _buildGridItem(
                        context: context,
                        title: 'الاستماع والتحميل',
                        subtitle: 'تلاوات صوتية وتحميل جماعي',
                        icon: Icons.headphones,
                        color: Colors.teal,
                        targetScreen: const AudioHubScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Persistent Audio Player anchored at bottom
            const Align(
              alignment: Alignment.bottomCenter,
              child: BottomPlayer(),
            ),
          ],
        ),
      ),
    );
  }
}
