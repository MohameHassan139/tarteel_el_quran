import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';
import '../shared/widgets/bottom_player.dart';
import 'home_controller.dart';
import '../../core/app_colors.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  Widget _buildGridItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String routeName,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 4,
      color: isDark ? AppColors.cardDark : AppColors.cardLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Get.toNamed(routeName),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'app_title'.tr,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'app_subtitle'.tr,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.settings, color: AppColors.primary, size: 26),
                            onPressed: () => Get.toNamed(AppRoutes.SETTINGS),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary.withOpacity(0.15),
                            child: const Icon(Icons.stars, color: AppColors.primary, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Today's Ward Progress Card
                  Obx(() {
                    final goal = controller.wardGoal.value;
                    final completedMinutes = (goal.activeSecondsToday / 60).floor();
                    final progress = goal.targetMinutes > 0 ? (completedMinutes / goal.targetMinutes) : 0.0;
                    final isDark = Theme.of(context).brightness == Brightness.dark;

                    return Card(
                      color: isDark ? AppColors.cardDark : AppColors.cardLight,
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
                                Text(
                                  'daily_ward'.tr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'minutes_of_target'.trParams({
                                    'completed': '$completedMinutes',
                                    'target': '${goal.targetMinutes}',
                                  }),
                                  style: const TextStyle(
                                    color: AppColors.primary,
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
                                backgroundColor: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              progress >= 1.0
                                  ? 'daily_ward_completed'.tr
                                  : 'daily_ward_remaining'.trParams({
                                      'minutes': '${(goal.targetMinutes - completedMinutes).clamp(0, goal.targetMinutes)}'
                                    }),
                              style: TextStyle(
                                color: progress >= 1.0 ? AppColors.primary : Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),

                  // Grid Menu Header
                  Text(
                    'services_and_features'.tr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
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
                        title: 'mushaf_title'.tr,
                        subtitle: 'mushaf_subtitle'.tr,
                        icon: Icons.menu_book,
                        color: AppColors.primary,
                        routeName: AppRoutes.MUSHAF,
                      ),
                      _buildGridItem(
                        context: context,
                        title: 'hifz_title'.tr,
                        subtitle: 'hifz_subtitle'.tr,
                        icon: Icons.psychology,
                        color: Colors.blueAccent,
                        routeName: AppRoutes.HIFZ,
                      ),
                      _buildGridItem(
                        context: context,
                        title: 'ward_title'.tr,
                        subtitle: 'ward_subtitle'.tr,
                        icon: Icons.assignment_turned_in,
                        color: Colors.green,
                        routeName: AppRoutes.WARD,
                      ),
                      _buildGridItem(
                        context: context,
                        title: 'audio_hub_title'.tr,
                        subtitle: 'audio_hub_subtitle'.tr,
                        icon: Icons.headphones,
                        color: Colors.teal,
                        routeName: AppRoutes.AUDIO_HUB,
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
