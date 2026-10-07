import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/course.dart';
import '../app_routes.dart';
import '../ui/app_spacing.dart';
import '../ui/layout.dart';
import 'student_quizzes_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _lessons = [];

  final Set<String> _completedLessonIds = {};

  bool _loadingLessons = true;
  bool _loadingProgress = true;

  String? _lessonError;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  // ===============================================================
  // INITIAL LOAD
  // ===============================================================

  Future<void> _loadInitialData() async {
    await _loadLessons();

    if (!mounted) return;

    final arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments is Course) {
      await _loadProgress(arguments.id);
    }
  }

  // ===============================================================
  // LOAD LESSONS
  // ===============================================================

  Future<void> _loadLessons() async {
    if (!mounted) return;

    final route = ModalRoute.of(context);

    if (route == null) {
      return;
    }

    final arguments = route.settings.arguments;

    if (arguments is! Course) {
      if (!mounted) return;

      setState(() {
        _loadingLessons = false;
        _lessonError = 'Data course tidak ditemukan.';
      });

      return;
    }

    final Course course = arguments;

    setState(() {
      _loadingLessons = true;
      _lessonError = null;
    });

    try {
      final snapshot = await _firestore
          .collection('course_lessons')
          .where(
        'courseId',
        isEqualTo: course.id,
      )
          .get();

      final lessons = snapshot.docs.map((doc) {
        final data = doc.data();

        return <String, dynamic>{
          'id': doc.id,
          ...data,
        };
      }).toList();

      // ===========================================================
      // SORT BERDASARKAN ORDER DI FLUTTER
      // ===========================================================

      lessons.sort((a, b) {
        final orderA = a['order'] is int
            ? a['order'] as int
            : int.tryParse(
          (a['order'] ?? '0').toString(),
        ) ??
            0;

        final orderB = b['order'] is int
            ? b['order'] as int
            : int.tryParse(
          (b['order'] ?? '0').toString(),
        ) ??
            0;

        return orderA.compareTo(orderB);
      });

      if (!mounted) return;

      setState(() {
        _lessons = lessons;
        _loadingLessons = false;
        _lessonError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingLessons = false;
        _lessonError = e.toString().replaceFirst(
          'Exception: ',
          '',
        );
      });
    }
  }

  // ===============================================================
  // LOAD PROGRESS
  // ===============================================================

  Future<void> _loadProgress(String courseId) async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _completedLessonIds.clear();
        _loadingProgress = false;
      });

      return;
    }

    setState(() {
      _loadingProgress = true;
    });

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('course_progress')
          .doc(courseId)
          .get();

      final Set<String> completedIds = {};

      if (snapshot.exists) {
        final data = snapshot.data();

        final completedLessons = data?['completedLessons'];

        if (completedLessons is List) {
          for (final item in completedLessons) {
            completedIds.add(
              item.toString(),
            );
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _completedLessonIds
          ..clear()
          ..addAll(completedIds);

        _loadingProgress = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingProgress = false;
      });
    }
  }

  // ===============================================================
  // REFRESH
  // ===============================================================

  Future<void> _refreshLessons() async {
    await _loadLessons();

    if (!mounted) return;

    final arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments is Course) {
      await _loadProgress(arguments.id);
    }
  }

  // ===============================================================
  // PROGRESS COUNT
  // ===============================================================

  int get _completedCount {
    return _completedLessonIds.length;
  }

  double get _progressValue {
    if (_lessons.isEmpty) {
      return 0;
    }

    return (_completedCount / _lessons.length).clamp(
      0.0,
      1.0,
    );
  }

  // ===============================================================
  // BUILD
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments is! Course) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Course Details',
          ),
        ),
        body: const Center(
          child: Text(
            'Data course tidak ditemukan.',
          ),
        ),
      );
    }

    final Course course = arguments;

    final size = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final double headerImageHeight = (size.width * 0.48).clamp(
      180.0,
      280.0,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // =========================================================
      // APP BAR
      // =========================================================

      appBar: AppBar(
        title: const Text(
          'Course Details',
        ),
      ),

      // =========================================================
      // BODY
      // =========================================================

      body: RefreshIndicator(
        onRefresh: _refreshLessons,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.screenPadding(context),
          child: AppLayout.centeredConstrained(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // =================================================
                // COURSE IMAGE
                // =================================================

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
                      errorBuilder: (
                          context,
                          error,
                          stackTrace,
                          ) {
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

                // =================================================
                // COURSE INFORMATION
                // =================================================

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
                      Text(
                        course.title,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // =================================================
                      // INSTRUCTOR
                      // =================================================

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
                              value: _loadingLessons
                                  ? '...'
                                  : '${_lessons.length}',
                              label: 'Lessons',
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: _buildInfoCard(
                              context: context,
                              icon: Icons.access_time_rounded,
                              value: _loadingLessons
                                  ? '...'
                                  : '${_totalMinutes()}+',
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

                // =================================================
                // PROGRESS CARD
                // =================================================

                _buildProgressCard(
                  context,
                ),

                const SizedBox(height: 16),

                // =================================================
                // QUIZ CARD
                // =================================================

                _buildQuizCard(
                  context,
                  course,
                ),

                const SizedBox(height: 24),

                // =================================================
                // ABOUT COURSE
                // =================================================

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

                // =================================================
                // LESSON HEADER
                // =================================================

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
                        _loadingLessons
                            ? '...'
                            : '${_lessons.length}',
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

                // =================================================
                // LESSON CONTENT
                // =================================================

                _buildLessonSection(
                  context,
                  course,
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // QUIZ CARD
  // ===============================================================

  Widget _buildQuizCard(
      BuildContext context,
      Course course,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.quiz_rounded,
              color: colorScheme.primary,
              size: 26,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Course Quiz',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Uji pemahaman kamu setelah mempelajari materi.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudentQuizzesScreen(
                    courseId: course.id,
                    courseTitle: course.title,
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            child: const Text(
              'Quiz',
            ),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // PROGRESS CARD
  // ===============================================================

  Widget _buildProgressCard(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final int total = _lessons.length;
    final int completed = _completedCount;

    final int percentage = total == 0
        ? 0
        : ((_progressValue * 100).round());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  color: colorScheme.primary,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Progress',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      _loadingProgress
                          ? 'Memuat progress...'
                          : '$completed dari $total lessons selesai',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              if (!_loadingProgress)
                Text(
                  '$percentage%',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: _loadingProgress
                  ? null
                  : _progressValue,
              minHeight: 9,
              backgroundColor:
              colorScheme.surfaceContainerHighest,
            ),
          ),

          if (!_loadingProgress &&
              total > 0 &&
              completed == total) ...[
            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(
                  Icons.celebration_rounded,
                  size: 18,
                  color: Colors.green,
                ),

                const SizedBox(width: 6),

                Text(
                  'Course selesai! Semua lesson sudah dipelajari.',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ===============================================================
  // LESSON SECTION
  // ===============================================================

  Widget _buildLessonSection(
      BuildContext context,
      Course course,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_loadingLessons) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: 50,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outline,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_lessonError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.error.withOpacity(0.4),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: colorScheme.error,
            ),

            const SizedBox(height: 12),

            Text(
              'Gagal Memuat Lesson',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _lessonError!,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 18),

            FilledButton.icon(
              onPressed: _refreshLessons,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Coba Lagi',
              ),
            ),
          ],
        ),
      );
    }

    if (_lessons.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outline,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 58,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),

            const SizedBox(height: 14),

            Text(
              'Belum Ada Lesson',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              'Belum ada materi lesson untuk course ini.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < _lessons.length; i++) ...[
          _buildLessonCard(
            context,
            course,
            _lessons[i],
            i,
          ),

          if (i != _lessons.length - 1)
            const SizedBox(height: 12),
        ],
      ],
    );
  }

  // ===============================================================
  // TOTAL MINUTES
  // ===============================================================

  int _totalMinutes() {
    int total = 0;

    for (final lesson in _lessons) {
      total += int.tryParse(
        (lesson['duration'] ?? 0).toString(),
      ) ??
          0;
    }

    return total;
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
      Map<String, dynamic> lesson,
      int index,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final String lessonId =
    (lesson['id'] ?? '').toString();

    final bool isCompleted =
    _completedLessonIds.contains(lessonId);

    final int lessonOrder = int.tryParse(
      (lesson['order'] ?? index + 1).toString(),
    ) ??
        index + 1;

    final String title =
    (lesson['title'] ?? 'Lesson $lessonOrder')
        .toString();

    final int duration = int.tryParse(
      (lesson['duration'] ?? 0).toString(),
    ) ??
        0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted
              ? Colors.green.withOpacity(0.45)
              : colorScheme.outline,
        ),
      ),
      child: Row(
        children: [
          // =======================================================
          // LESSON NUMBER
          // =======================================================

          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withOpacity(0.12)
                  : colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 27,
              )
                  : Text(
                '$lessonOrder',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // =======================================================
          // LESSON INFORMATION
          // =======================================================

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
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
                        duration > 0
                            ? '$duration mins'
                            : 'Lesson content',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),

                if (isCompleted) ...[
                  const SizedBox(height: 4),

                  const Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          // =======================================================
          // OPEN BUTTON
          // =======================================================

          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: () async {
                await Navigator.pushNamed(
                  context,
                  AppRoutes.lesson,
                  arguments: {
                    'course': course,
                    'lessonIndex': index,
                    'lesson': lesson,
                  },
                );

                // Refresh progress setelah kembali
                // dari LessonScreen.
                if (!mounted) return;

                await _loadProgress(
                  course.id,
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                minimumSize: const Size(
                  0,
                  42,
                ),
              ),
              child: Text(
                isCompleted
                    ? 'Review'
                    : 'Open',
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