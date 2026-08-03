import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeline_tile/timeline_tile.dart';
import '../../../core/app_colors.dart';
import '../teacher_link_models.dart';

/// One row in a student's session history, rendered with the `timeline_tile`
/// package: a colored indicator (color = rating quality) connected by a line,
/// with the session details as a card on the trailing side.
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

  Color _colorForRating(int rating) {
    switch (rating) {
      case 5:
        return const Color(0xFF2E9E5B); // rich green
      case 4:
        return const Color(0xFF8BC34A); // lighter green
      case 3:
        return const Color(
          0xFFE4B93E,
        ); // amber (matches AppColors.accent family)
      case 2:
        return const Color(0xFFE8813A); // orange
      default:
        return const Color(0xFFE05C5C); // soft red
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ratingColor = _colorForRating(session.rating);
    final completionColor = session.fullyCompleted ? AppColors.primary : Colors.orange;

    return TimelineTile(
      alignment: TimelineAlign.start,
      isFirst: isFirst,
      isLast: isLast,
      indicatorStyle: IndicatorStyle(
        width: 32,
        height: 32,
        padding: const EdgeInsets.symmetric(vertical: 6),
        indicator: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ratingColor,
            boxShadow: [
              BoxShadow(
                color: ratingColor.withValues(alpha: 0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(Icons.psychology, color: Colors.white, size: 16),
        ),
      ),
      beforeLineStyle: LineStyle(
        color: ratingColor.withValues(alpha: 0.35),
        thickness: 3,
      ),
      endChild: Padding(
        padding: const EdgeInsets.only(right: 12, bottom: 14, left: 4),
        child: Card(
          color: isDark ? AppColors.cardDark : Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: ratingColor.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: completionColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${session.reachedEndAyah - session.reachedStartAyah + 1}/${session.plannedEndAyah - session.plannedStartAyah + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: completionColor,
                        ),
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
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < session.rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: ratingColor,
                      size: 15,
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
