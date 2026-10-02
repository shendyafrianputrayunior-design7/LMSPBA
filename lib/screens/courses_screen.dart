import 'package:flutter/material.dart';
import '../models/course.dart';
import '../widgets/app_bar_simple.dart';
import '../widgets/course_card.dart';
import '../app_routes.dart';
import '../ui/app_spacing.dart';
import '../ui/layout.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // =================================================
      // BACKGROUND
      // =================================================

      backgroundColor: theme.scaffoldBackgroundColor,

      // =================================================
      // APP BAR
      // =================================================

      appBar: AppBarSimple(
        title: 'Courses',
      ),

      // =================================================
      // BODY
      // =================================================

      body: AppLayout.centeredConstrained(
        maxWidth: 720,

        child: ListView(
          physics: const BouncingScrollPhysics(),

          padding: AppSpacing.listPadding(context).copyWith(
            top: 20,
            bottom: 30,
          ),

          children: [
            // =================================================
            // HEADER
            // =================================================

            Text(
              'Explore Courses',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Find something new to learn and improve your skills.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 20),

            // =================================================
            // COURSE SUMMARY
            // =================================================

            Container(
              padding: const EdgeInsets.all(18),

              decoration: BoxDecoration(
                // Tetap menggunakan warna primary
                // agar kartu summary tetap terlihat seperti
                // desain sebelumnya.
                color: colorScheme.primary,

                borderRadius: BorderRadius.circular(20),

                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),

              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,

                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),

                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [
                        Text(
                          '${dummyCourses.length} Courses Available',

                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'Start learning at your own pace',

                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            // =================================================
            // SECTION TITLE
            // =================================================

            Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,

              children: [
                Text(
                  'All Courses',

                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),

                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),

                  child: Text(
                    '${dummyCourses.length}',

                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // =================================================
            // COURSE LIST
            // =================================================

            for (final course in dummyCourses) ...[
              CourseCard(
                course: course,

                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.courseDetail,
                    arguments: course,
                  );
                },
              ),

              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}