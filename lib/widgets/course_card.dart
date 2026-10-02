import 'package:flutter/material.dart';
import '../models/course.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback? onTap;

  const CourseCard({
    super.key,
    required this.course,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Material(
      // Mengikuti light/dark theme
      color: colorScheme.surface,

      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),

        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),

            border: Border.all(
              color: colorScheme.outline,
              width: 1,
            ),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  theme.brightness == Brightness.dark
                      ? 0.18
                      : 0.04,
                ),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),

          child: Padding(
            padding: const EdgeInsets.all(12),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // =================================================
                // COURSE IMAGE
                // =================================================

                ClipRRect(
                  borderRadius: BorderRadius.circular(15),

                  child: SizedBox(
                    width: 105,
                    height: 105,

                    child: Image.asset(
                      course.image,
                      fit: BoxFit.cover,

                      errorBuilder: (
                          context,
                          error,
                          stackTrace,
                          ) {
                        return Container(
                          color: colorScheme.primary.withOpacity(0.1),

                          child: Icon(
                            Icons.menu_book_rounded,
                            size: 34,
                            color: colorScheme.primary,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // =================================================
                // COURSE INFORMATION
                // =================================================

                Expanded(
                  child: SizedBox(
                    height: 105,

                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [
                        // =================================================
                        // COURSE TITLE
                        // =================================================

                        Text(
                          course.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,

                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,

                            // Dark/light otomatis
                            color: colorScheme.onSurface,

                            height: 1.3,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // =================================================
                        // INSTRUCTOR
                        // =================================================

                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 15,
                              color:
                              colorScheme.onSurfaceVariant,
                            ),

                            const SizedBox(width: 5),

                            Expanded(
                              child: Text(
                                course.instructor,
                                maxLines: 1,
                                overflow:
                                TextOverflow.ellipsis,

                                style:
                                textTheme.bodySmall?.copyWith(
                                  color:
                                  colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // =================================================
                        // LESSONS + ARROW
                        // =================================================

                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,

                              decoration: BoxDecoration(
                                color: colorScheme.primary
                                    .withOpacity(0.1),

                                borderRadius:
                                BorderRadius.circular(9),
                              ),

                              child: Icon(
                                Icons.play_circle_outline_rounded,
                                size: 17,
                                color: colorScheme.primary,
                              ),
                            ),

                            const SizedBox(width: 8),

                            Text(
                              '${course.lessons} lessons',

                              style:
                              textTheme.bodySmall?.copyWith(
                                color:
                                colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const Spacer(),

                            // =================================================
                            // ARROW
                            // =================================================

                            Container(
                              width: 30,
                              height: 30,

                              decoration: BoxDecoration(
                                color: colorScheme
                                    .surfaceContainerHighest,

                                borderRadius:
                                BorderRadius.circular(9),
                              ),

                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 17,
                                color:
                                colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}