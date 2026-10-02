import 'package:flutter/material.dart';

class ProgressCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double percent; // 0.0 - 1.0

  const ProgressCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final clampedPercent = percent.clamp(0.0, 1.0);
    final percentage = (clampedPercent * 100).toStringAsFixed(0);

    return Container(
      decoration: BoxDecoration(
        // Mengikuti light/dark theme
        color: colorScheme.surface,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(
          color: colorScheme.outline,
          width: 1,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.18 : 0.04,
            ),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // =================================================
            // HEADER
            // =================================================

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // Course icon
                Container(
                  width: 42,
                  height: 42,

                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(13),
                  ),

                  child: Icon(
                    Icons.menu_book_rounded,
                    color: colorScheme.primary,
                    size: 21,
                  ),
                ),

                const SizedBox(width: 12),

                // Course title
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,

                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,

                      // Dark/light otomatis
                      color: colorScheme.onSurface,

                      height: 1.3,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Percentage
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),

                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),

                  child: Text(
                    '$percentage%',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // =================================================
            // CHAPTER
            // =================================================

            Row(
              children: [
                Icon(
                  Icons.play_circle_outline_rounded,
                  size: 17,
                  color: colorScheme.onSurfaceVariant,
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,

                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // =================================================
            // PROGRESS BAR
            // =================================================

            ClipRRect(
              borderRadius: BorderRadius.circular(99),

              child: LinearProgressIndicator(
                value: clampedPercent,
                minHeight: 7,

                // Mengikuti theme
                backgroundColor:
                colorScheme.surfaceContainerHighest,

                valueColor: AlwaysStoppedAnimation<Color>(
                  colorScheme.primary,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // =================================================
            // FOOTER
            // =================================================

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [
                Text(
                  '$percentage% completed',

                  style: textTheme.bodySmall?.copyWith(
                    // Dark/light otomatis
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                if (clampedPercent >= 1.0)
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 15,
                        color: Colors.green.shade600,
                      ),

                      const SizedBox(width: 4),

                      Text(
                        'Completed',
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'Keep going!',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}