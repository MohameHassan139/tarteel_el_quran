import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/app_colors.dart';
import '../teacher_link_models.dart';

/// One row in a student's session history, styled as a vertical timeline:
/// a dot + connecting line on the leading edge, and a card with the session
/// details on the trailing side.
class SessionTimelineTile extends StatelessWidget {
  final HifzSessionRecord session;
  final bool isFirst;
  final bool isLast;

  const SessionTimelineTile({
    super.key,
    required this.session,
    this.isFirst = false,
    this.isLast = false,
  });

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completionColor = session.fullyCompleted ? AppColors.primary : Colors.orange;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(width: 2, height: 8, color: isFirst ? Colors.transparent : Colors.grey.withValues(alpha: 0.3)),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: completionColor),
                ),
                Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : Colors.grey.withValues(alpha: 0.3))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                color: isDark ? AppColors.cardDark : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'teacher_link_session_title'.trParams({
                                'surah': session.chapterName,
                                'start': '${session.reachedStartAyah}',
                                'end': '${session.reachedEndAyah}',
                              }),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: completionColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              '${session.reachedEndAyah - session.reachedStartAyah + 1}/${session.plannedEndAyah - session.plannedStartAyah + 1}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: completionColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'teacher_link_session_subtitle'.trParams({
                          'date': _formatDate(session.date),
                          'duration': _formatDuration(session.durationSeconds),
                          'reciter': session.reciterName,
                        }),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      if (session.notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          session.notes,
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(5, (i) {
                          return Icon(
                            i < session.rating ? Icons.star_rounded : Icons.star_border_rounded,
                            color: AppColors.accent,
                            size: 15,
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
