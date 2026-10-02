import 'package:flutter/material.dart';
import '../models/course.dart';
import '../ui/app_spacing.dart';
import '../ui/layout.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  bool _completed = false;
  double _opacity = 1.0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    final args =
    ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    final Course course = args['course'];
    final int lessonIndex = args['lessonIndex'];

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final double mediaHeight =
    (size.height * 0.28).clamp(190.0, 280.0);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lesson ${lessonIndex + 1}',
              style: textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              course.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding(context),
          child: AppLayout.centeredConstrained(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),

                // =========================================================
                // LESSON MEDIA
                // =========================================================

                AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: _opacity,
                  child: Container(
                    height: mediaHeight,

                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),

                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary,
                          colorScheme.secondary,
                        ],
                      ),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            theme.brightness == Brightness.dark
                                ? 0.20
                                : 0.08,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),

                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Lesson label

                        Positioned(
                          top: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),

                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),

                            child: const Text(
                              'LESSON',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),

                        // Play icon

                        Container(
                          width: 76,
                          height: 76,

                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.16),
                            shape: BoxShape.circle,
                          ),

                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),

                        // Lesson number

                        Positioned(
                          bottom: 18,
                          left: 20,
                          right: 20,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.play_circle_outline_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),

                              const SizedBox(width: 8),

                              Text(
                                'Lesson ${lessonIndex + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // =========================================================
                // LESSON INFORMATION
                // =========================================================

                Container(
                  padding: const EdgeInsets.all(20),

                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),

                    border: Border.all(
                      color: colorScheme.outline,
                    ),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                          theme.brightness == Brightness.dark
                              ? 0.18
                              : 0.035,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),

                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),

                            child: Icon(
                              Icons.menu_book_rounded,
                              color: colorScheme.primary,
                              size: 22,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Text(
                              'Lesson ${lessonIndex + 1}',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      Text(
                        'Course',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        course.title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),

                          const SizedBox(width: 6),

                          Text(
                            'Lesson content',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // =========================================================
                // CONTENT CARD
                // =========================================================

                Container(
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
                      Text(
                        'Lesson Content',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'This is a placeholder for the lesson content '
                            '(video/reading).',
                        style: textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // =========================================================
                // COMPLETION BUTTON
                // =========================================================

                SizedBox(
                  height: 54,

                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _completed = !_completed;
                        _opacity = _completed ? 0.6 : 1.0;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),

                          content: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                              ),

                              const SizedBox(width: 10),

                              Text(
                                _completed
                                    ? 'Marked complete'
                                    : 'Marked incomplete',
                              ),
                            ],
                          ),
                        ),
                      );
                    },

                    icon: Icon(
                      _completed
                          ? Icons.undo_rounded
                          : Icons.check_circle_outline_rounded,
                    ),

                    label: Text(
                      _completed
                          ? 'Mark Incomplete'
                          : 'Mark Complete',
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}