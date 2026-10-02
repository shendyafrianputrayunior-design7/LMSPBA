
import 'package:flutter/material.dart';
import '../models/course.dart';
import '../app_routes.dart';
import '../ui/app_spacing.dart';
import '../ui/layout.dart';

class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Course course =
    ModalRoute.of(context)!.settings.arguments as Course;

    final size = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final double headerImageHeight =
    (size.width * 0.48).clamp(180.0, 280.0);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text('Course Details'),
      ),

      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: AppSpacing.screenPadding(context),

        child: AppLayout.centeredConstrained(
          maxWidth: 720,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =========================================================
              // COURSE IMAGE
              // =========================================================

              Container(
                width: double.infinity,
                height: headerImageHeight,

                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        theme.brightness == Brightness.dark
                            ? 0.2
                            : 0.08,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),

                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),

                  child: Image.asset(
                    course.image,
                    width: double.infinity,
                    height: headerImageHeight,
                    fit: BoxFit.cover,

                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: colorScheme.primary.withOpacity(0.12),

                        child: Center(
                          child: Icon(
                            Icons.menu_book_rounded,
                            size: 64,
                            color: colorScheme.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // =========================================================
              // COURSE INFORMATION
              // =========================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),

                  border: Border.all(
                    color: colorScheme.outline,
                  ),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Course title

                    Text(
                      course.title,

                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Instructor

                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,

                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),

                          child: Icon(
                            Icons.person_rounded,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Instructor',

                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),

                              const SizedBox(height: 2),

                              Text(
                                course.instructor,

                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // =================================================
                    // COURSE STATS
                    // =================================================

                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard(
                            context: context,
                            icon: Icons.play_lesson_rounded,
                            value: '${course.lessons}',
                            label: 'Lessons',
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: _buildInfoCard(
                            context: context,
                            icon: Icons.access_time_rounded,
                            value: '${course.lessons * 10}+',
                            label: 'Minutes',
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: _buildInfoCard(
                            context: context,
                            icon: Icons.school_rounded,
                            value: 'Learn',
                            label: 'Course',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // =========================================================
              // ABOUT COURSE
              // =========================================================

              Text(
                'About this Course',

                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 10),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),

                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),

                  border: Border.all(
                    color: colorScheme.outline,
                  ),
                ),

                child: Text(
                  course.description,

                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // =========================================================
              // LESSON HEADER
              // =========================================================

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Expanded(
                    child: Text(
                      'Course Lessons',

                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),

                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: Text(
                      '${course.lessons}',

                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // =========================================================
              // LESSON LIST
              // =========================================================

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: course.lessons,

                itemBuilder: (ctx, i) {
                  return _buildLessonCard(
                    context,
                    course,
                    i,
                  );
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // COURSE INFO CARD
  // ===============================================================

  Widget _buildInfoCard({
    required BuildContext context,
    required IconData icon,
    required String value,
    required String label,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 6,
      ),

      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),

      child: Column(
        children: [
          Icon(
            icon,
            color: colorScheme.primary,
            size: 22,
          ),

          const SizedBox(height: 7),

          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,

            style: textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,

            style: textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // LESSON CARD
  // ===============================================================

  Widget _buildLessonCard(
      BuildContext context,
      Course course,
      int index,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final lessonNumber = index + 1;
    final duration = 10 + index;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),

        border: Border.all(
          color: colorScheme.outline,
        ),
      ),

      child: Row(
        children: [
          // Lesson number

          Container(
            width: 48,
            height: 48,

            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),

            child: Center(
              child: Text(
                '$lessonNumber',

                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Lesson information

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lesson $lessonNumber',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,

                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 5),

                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 15,
                      color: colorScheme.onSurfaceVariant,
                    ),

                    const SizedBox(width: 4),

                    Flexible(
                      child: Text(
                        '$duration mins',

                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Open button

          SizedBox(
            height: 42,

            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.lesson,
                  arguments: {
                    'course': course,
                    'lessonIndex': index,
                  },
                );
              },

              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                minimumSize: const Size(0, 42),
              ),

              child: const Text(
                'Open',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}