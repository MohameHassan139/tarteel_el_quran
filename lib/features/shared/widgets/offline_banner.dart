import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/connectivity_service.dart';
import '../../../core/app_colors.dart';

/// Thin, non-blocking banner shown when the device has no network connection.
/// Meant to sit above cached content instead of a full-screen error state.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Degrade to invisible rather than throw if ConnectivityService never
    // registered (its init is guarded in main.dart's initServices, so this
    // widget can't assume it's there).
    if (!Get.isRegistered<ConnectivityService>()) return const SizedBox.shrink();

    final connectivity = Get.find<ConnectivityService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      if (connectivity.isOnline.value) return const SizedBox.shrink();

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: isDark
            ? AppColors.secondaryDark
            : AppColors.accentLight.withValues(alpha: 0.6),
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'offline_banner'.tr,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
