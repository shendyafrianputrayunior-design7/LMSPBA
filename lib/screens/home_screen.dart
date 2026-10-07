import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_routes.dart';
import '../models/course.dart';
import '../widgets/course_card.dart';
import '../widgets/progress_card.dart';
import '../ui/layout.dart';

import 'courses_screen.dart';
import 'profile_screen.dart';
import 'student_quizzes_screen.dart';
import 'assignments_screen.dart';
import 'student_schedule_screen.dart';
import 'student_attendance_screen.dart';
import 'student_exams_screen.dart';
import 'student_discussions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  // =========================================================
  // PROFILE
  // =========================================================

  String _photoUrl = '';
  bool _loadingPhoto = true;
  bool _photoError = false;

  // =========================================================
  // STUDENT DATA
  // =========================================================

  String _username = '';
  String _classId = '';
  String _role = '';

  bool _loadingStudent = true;
  String? _studentError;

  // =========================================================
  // WELCOME LOGIN DIALOG
  // =========================================================

  bool _welcomeDialogShown = false;

  // =========================================================
  // COURSES
  // =========================================================

  List<Course> _courses = [];

  bool _loadingCourses = true;
  String? _courseError;

  // =========================================================
  // COURSE PROGRESS
  // =========================================================

  final Map<String, int> _completedLessonsByCourse = {};
  final Map<String, int> _totalLessonsByCourse = {};

  bool _loadingProgress = true;

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  // =========================================================
  // LOAD STUDENT DATA
  // =========================================================

  Future<void> _loadStudentData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    setState(() {
      _loadingStudent = true;
      _loadingPhoto = true;
      _loadingCourses = true;
      _loadingProgress = true;

      _studentError = null;
      _courseError = null;
      _photoError = false;
    });

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _username = '';
        _classId = '';
        _role = '';
        _photoUrl = '';

        _courses = [];
        _completedLessonsByCourse.clear();
        _totalLessonsByCourse.clear();

        _loadingStudent = false;
        _loadingPhoto = false;
        _loadingCourses = false;
        _loadingProgress = false;

        _studentError = 'Akun siswa tidak ditemukan.';
        _courseError = 'Akun siswa tidak ditemukan.';
      });

      return;
    }

    try {
      debugPrint('====================================');
      debugPrint('MEMUAT DATA SISWA');
      debugPrint('UID: ${user.uid}');
      debugPrint('EMAIL: ${user.email}');
      debugPrint('====================================');

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (!doc.exists) {
        setState(() {
          _username = user.displayName ?? '';
          _classId = '';
          _role = '';
          _photoUrl = '';

          _courses = [];
          _completedLessonsByCourse.clear();
          _totalLessonsByCourse.clear();

          _loadingStudent = false;
          _loadingPhoto = false;
          _loadingCourses = false;
          _loadingProgress = false;

          _studentError =
          'Data siswa belum tersedia di Firestore.';
          _courseError =
          'Data siswa belum tersedia di Firestore.';
        });

        return;
      }

      final Map<String, dynamic> data =
          doc.data() ?? <String, dynamic>{};

      final String username =
      _readString(data, 'username').isNotEmpty
          ? _readString(data, 'username')
          : _readString(data, 'name').isNotEmpty
          ? _readString(data, 'name')
          : user.displayName ?? '';

      final String classId = _readString(data, 'classId');

      final String photoUrl = _readString(data, 'photoUrl');

      // ROLE USER
      final String role = _readString(data, 'role');

      setState(() {
        _username = username;
        _classId = classId;
        _photoUrl = photoUrl;
        _role = role;

        _loadingStudent = false;
        _loadingPhoto = false;

        _studentError = null;
        _photoError = false;
      });

      debugPrint('====================================');
      debugPrint('DATA SISWA SELESAI DIMUAT');
      debugPrint('Username: $_username');
      debugPrint('Class ID: $_classId');
      debugPrint('Role: $_role');
      debugPrint('Photo URL: $_photoUrl');
      debugPrint('====================================');

      await _loadCourses();

      if (!mounted) return;

      await _loadAllCourseProgress();

      if (!mounted) return;

      setState(() {
        _loadingCourses = false;
      });

      // =====================================================
      // TAMPILKAN POPUP LOGIN
      // =====================================================

      _showWelcomeDialog();
    } catch (e, stackTrace) {
      debugPrint('====================================');
      debugPrint('GAGAL MENGAMBIL DATA SISWA');
      debugPrint('ERROR: $e');
      debugPrint('STACK TRACE: $stackTrace');
      debugPrint('====================================');

      if (!mounted) return;

      setState(() {
        _username = user.displayName ?? '';
        _classId = '';
        _role = '';
        _photoUrl = '';

        _courses = [];
        _completedLessonsByCourse.clear();
        _totalLessonsByCourse.clear();

        _loadingStudent = false;
        _loadingPhoto = false;
        _loadingCourses = false;
        _loadingProgress = false;

        _photoError = true;
        _studentError = e.toString();
        _courseError = e.toString();
      });
    }
  }

  // =========================================================
  // FIRESTORE STRING HELPER
  // =========================================================

  String _readString(
      Map<String, dynamic> data,
      String key,
      ) {
    final value = data[key];

    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  // =========================================================
  // DATE HELPER
  // =========================================================

  String _readDate(
      Map<String, dynamic> data,
      String key,
      ) {
    final value = data[key];

    if (value == null) {
      return '';
    }

    if (value is Timestamp) {
      final date = value.toDate();

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    }

    return value.toString().trim();
  }

  // =========================================================
  // LOAD COURSES
  // =========================================================

  Future<void> _loadCourses() async {
    if (!mounted) return;

    if (_classId.isEmpty) {
      setState(() {
        _courses = [];
        _loadingCourses = false;
        _courseError = 'Data kelas siswa belum tersedia.';
      });

      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .where(
        'classId',
        isEqualTo: _classId,
      )
          .get();

      final courses = snapshot.docs
          .map(
            (doc) => Course.fromFirestore(
          doc.id,
          doc.data(),
        ),
      )
          .where(
            (course) => course.title.trim().isNotEmpty,
      )
          .toList();

      courses.sort(
            (a, b) => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
      );

      if (!mounted) return;

      setState(() {
        _courses = courses;
        _loadingCourses = false;
        _courseError = null;
      });
    } catch (e, stackTrace) {
      debugPrint('GAGAL MENGAMBIL COURSES: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        _courses = [];
        _loadingCourses = false;
        _courseError = e.toString();
      });
    }
  }

  // =========================================================
  // LOAD ALL COURSE PROGRESS
  // =========================================================

  Future<void> _loadAllCourseProgress() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || _courses.isEmpty) {
      if (!mounted) return;

      setState(() {
        _completedLessonsByCourse.clear();
        _totalLessonsByCourse.clear();
        _loadingProgress = false;
      });

      return;
    }

    if (mounted) {
      setState(() {
        _loadingProgress = true;
      });
    }

    try {
      final firestore = FirebaseFirestore.instance;

      final futures = _courses.map(
            (course) async {
          final lessonSnapshot = await firestore
              .collection('course_lessons')
              .where(
            'courseId',
            isEqualTo: course.id,
          )
              .get();

          final actualLessonIds = lessonSnapshot.docs
              .map(
                (doc) => doc.id,
          )
              .toSet();

          final int totalLessons =
          actualLessonIds.isNotEmpty
              ? actualLessonIds.length
              : course.lessons;

          final progressDoc = await firestore
              .collection('users')
              .doc(user.uid)
              .collection('course_progress')
              .doc(course.id)
              .get();

          final completedIds = <String>{};

          if (progressDoc.exists) {
            final data =
                progressDoc.data() ?? <String, dynamic>{};

            final completed = data['completedLessons'];

            if (completed is List) {
              for (final item in completed) {
                final lessonId = item.toString().trim();

                if (lessonId.isNotEmpty) {
                  completedIds.add(lessonId);
                }
              }
            }
          }

          int completedLessons = 0;

          if (actualLessonIds.isNotEmpty) {
            completedLessons = completedIds
                .intersection(actualLessonIds)
                .length;
          } else {
            completedLessons = completedIds.length;

            if (completedLessons > totalLessons) {
              completedLessons = totalLessons;
            }
          }

          return MapEntry<String, Map<String, int>>(
            course.id,
            <String, int>{
              'total': totalLessons,
              'completed': completedLessons,
            },
          );
        },
      );

      final results = await Future.wait(futures);

      if (!mounted) return;

      final Map<String, int> totalMap = <String, int>{};
      final Map<String, int> completedMap = <String, int>{};

      for (final result in results) {
        final Map<String, int> data = result.value;

        totalMap[result.key] = data['total'] ?? 0;
        completedMap[result.key] = data['completed'] ?? 0;
      }

      setState(() {
        _totalLessonsByCourse
          ..clear()
          ..addAll(totalMap);

        _completedLessonsByCourse
          ..clear()
          ..addAll(completedMap);

        _loadingProgress = false;
      });
    } catch (e, stackTrace) {
      debugPrint('GAGAL MEMUAT COURSE PROGRESS: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        _completedLessonsByCourse.clear();
        _totalLessonsByCourse.clear();
        _loadingProgress = false;
      });
    }
  }

  // =========================================================
  // WELCOME LOGIN DIALOG
  // =========================================================

  void _showWelcomeDialog() {
    if (!mounted || _welcomeDialogShown) return;

    _welcomeDialogShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final roleText = _getRoleText(_role);

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          final colorScheme = theme.colorScheme;

          return Dialog(
            backgroundColor: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                24,
                12,
                24,
                22,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // CLOSE BUTTON
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                      tooltip: 'Tutup',
                    ),
                  ),

                  // ICON
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified_user_rounded,
                      size: 38,
                      color: colorScheme.primary,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // TITLE
                  Text(
                    'Login Berhasil',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Selamat datang kembali,',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    _username.isNotEmpty
                        ? _username
                        : 'Pengguna',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ROLE CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Anda login sebagai',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          roleText,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    'Selamat belajar dan semoga aktivitas '
                        'belajar hari ini berjalan lancar.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // OK BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text(
                        'Mulai Belajar',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  // =========================================================
  // ROLE TEXT
  // =========================================================

  String _getRoleText(String role) {
    switch (role.toLowerCase().trim()) {
      case 'student':
        return 'SISWA';

      case 'teacher':
        return 'GURU';

      case 'admin':
        return 'ADMIN';

      default:
        return role.isEmpty
            ? 'PENGGUNA'
            : role.toUpperCase();
    }
  }

  // =========================================================
  // LESSON HELPERS
  // =========================================================

  int _getTotalLessonCount(
      Course course,
      ) {
    return _totalLessonsByCourse[course.id] ?? course.lessons;
  }

  int _getCompletedLessonCount(
      Course course,
      ) {
    final completed = _completedLessonsByCourse[course.id] ?? 0;

    final total = _getTotalLessonCount(course);

    if (completed > total) {
      return total;
    }

    return completed;
  }

  double _getCourseProgress(
      Course course,
      ) {
    final total = _getTotalLessonCount(course);

    final completed = _getCompletedLessonCount(course);

    if (total <= 0) {
      return 0.0;
    }

    return (completed / total).clamp(0.0, 1.0);
  }

  double _getOverallProgress() {
    if (_courses.isEmpty) {
      return 0.0;
    }

    int totalLessons = 0;
    int completedLessons = 0;

    for (final course in _courses) {
      totalLessons += _getTotalLessonCount(course);
      completedLessons += _getCompletedLessonCount(course);
    }

    if (totalLessons <= 0) {
      return 0.0;
    }

    return (completedLessons / totalLessons).clamp(0.0, 1.0);
  }

  int _getOverallCompletedLessons() {
    int completed = 0;

    for (final course in _courses) {
      completed += _getCompletedLessonCount(course);
    }

    return completed;
  }

  int _getOverallTotalLessons() {
    int total = 0;

    for (final course in _courses) {
      total += _getTotalLessonCount(course);
    }

    return total;
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _dashboardTab(),
      const CoursesScreen(),
      AssignmentsScreen(
        classId: _classId,
      ),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _index == 0
          ? AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor:
        Theme.of(context).scaffoldBackgroundColor,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'eLearn-NXT',
              style:
              Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Learning Management System',
              style:
              Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showAnnouncements,
            icon: const Icon(
              Icons.notifications_none_rounded,
            ),
          ),
          IconButton(
            onPressed: _loadStudentData,
            tooltip: 'Refresh',
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      )
          : null,
      body: tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() {
            _index = i;
          });

          if (i == 0) {
            _loadStudentData();
          }
        },
        height: 68,
        backgroundColor: Theme.of(context).colorScheme.surface,
        indicatorColor:
        Theme.of(context).colorScheme.primary.withOpacity(0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
            ),
            selectedIcon: Icon(
              Icons.home_rounded,
            ),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.menu_book_outlined,
            ),
            selectedIcon: Icon(
              Icons.menu_book_rounded,
            ),
            label: 'Courses',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.assignment_outlined,
            ),
            selectedIcon: Icon(
              Icons.assignment_rounded,
            ),
            label: 'Assignments',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_outline_rounded,
            ),
            selectedIcon: Icon(
              Icons.person_rounded,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // =========================================================
  // DASHBOARD
  // =========================================================

  Widget _dashboardTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final size = MediaQuery.sizeOf(context);

    final double progressListHeight =
    (size.height * 0.24).clamp(175.0, 205.0);

    final double progressCardWidth =
    (size.width * 0.76).clamp(245.0, 330.0);

    final horizontalPadding =
    (size.width * 0.045).clamp(16.0, 28.0);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: AppLayout.centeredConstrained(
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _username.isNotEmpty
                              ? 'Welcome back, $_username 👋'
                              : 'Welcome back 👋',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _loadingStudent
                              ? 'Loading your learning data...'
                              : 'Ready to continue learning today?',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildProfileAvatar(),
                ],
              ),
            ),

            const SizedBox(height: 22),

            if (_studentError != null)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                ),
                child: _buildStudentErrorCard(),
              ),

            if (_studentError != null)
              const SizedBox(height: 16),

            // =================================================
            // OVERALL PROGRESS
            // =================================================

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: Builder(
                builder: (context) {
                  final progress = _getOverallProgress();

                  final completed =
                  _getOverallCompletedLessons();

                  final total = _getOverallTotalLessons();

                  final percentage =
                  (progress * 100).round();

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary,
                          colorScheme.primary.withOpacity(0.82),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                          colorScheme.primary.withOpacity(0.20),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color:
                                Colors.white.withOpacity(0.16),
                                borderRadius:
                                BorderRadius.circular(13),
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Your Learning Progress',
                                style:
                                textTheme.titleSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '$percentage%',
                              style:
                              textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor:
                            const Color(0x33FFFFFF),
                            valueColor:
                            const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _loadingProgress
                                  ? 'Memuat progress...'
                                  : total > 0
                                  ? '$completed of $total lessons completed'
                                  : 'Belum ada lesson',
                              style:
                              textTheme.bodySmall?.copyWith(
                                color:
                                Colors.white.withOpacity(0.85),
                              ),
                            ),
                            Text(
                              percentage >= 100
                                  ? 'Completed!'
                                  : percentage > 0
                                  ? 'Keep going!'
                                  : 'Start learning!',
                              style:
                              textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: Text(
                'Quick Menu',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: _buildQuickMenu(),
            ),

            const SizedBox(height: 28),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your Courses',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _index = 1;
                      });
                    },
                    child: const Text(
                      'See All',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              height: progressListHeight,
              child: _buildCourseProgressList(
                progressCardWidth,
                horizontalPadding,
              ),
            ),

            const SizedBox(height: 28),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Continue Learning',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: _buildContinueLearning(),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // COURSE PROGRESS LIST
  // =========================================================

  Widget _buildCourseProgressList(
      double cardWidth,
      double horizontalPadding,
      ) {
    if (_loadingCourses || _loadingProgress) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_courses.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
        ),
        child: Center(
          child: Text(
            _courseError ??
                'Belum ada course untuk kelas kamu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final progressCourses =
    _courses.take(5).toList();

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
      ),
      scrollDirection: Axis.horizontal,
      itemCount: progressCourses.length,
      separatorBuilder: (_, __) =>
      const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final course = progressCourses[index];

        final progress =
        _getCourseProgress(course);

        final completedLessons =
        _getCompletedLessonCount(course);

        final totalLessons =
        _getTotalLessonCount(course);

        return SizedBox(
          width: cardWidth,
          child: ProgressCard(
            title: course.title,
            subtitle:
            '$completedLessons of $totalLessons lessons',
            percent: progress,
          ),
        );
      },
    );
  }

  // =========================================================
  // CONTINUE LEARNING
  // =========================================================

  Widget _buildContinueLearning() {
    if (_loadingCourses) {
      return const Padding(
        padding: EdgeInsets.symmetric(
          vertical: 30,
        ),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_courses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outline
                .withOpacity(0.35),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 38,
              color:
              Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            Text(
              'Belum ada course',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _courseError ??
                  'Belum ada course untuk kelas kamu.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final courses =
    _courses.take(3).toList();

    return Column(
      children: [
        for (
        int index = 0;
        index < courses.length;
        index++
        ) ...[
          CourseCard(
            course: courses[index],
            onTap: () async {
              await Navigator.pushNamed(
                context,
                AppRoutes.courseDetail,
                arguments: courses[index],
              );

              if (!mounted) return;

              await _loadAllCourseProgress();

              if (!mounted) return;

              setState(() {});
            },
          ),
          if (index != courses.length - 1)
            const SizedBox(height: 12),
        ],
      ],
    );
  }

  // =========================================================
  // PROFILE AVATAR
  // =========================================================

  Widget _buildProfileAvatar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color:
            colorScheme.primary.withOpacity(0.20),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(
        child: _loadingPhoto
            ? const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child:
            CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
              AlwaysStoppedAnimation<Color>(
                Colors.white,
              ),
            ),
          ),
        )
            : _photoUrl.isNotEmpty && !_photoError
            ? Image.network(
          _photoUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder:
              (
              context,
              error,
              stackTrace,
              ) {
            return const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 24,
            );
          },
        )
            : const Icon(
          Icons.person_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  // =========================================================
  // QUICK MENU
  // =========================================================

  Widget _buildQuickMenu() {
    final menuItems = <_QuickMenuItem>[
      _QuickMenuItem(
        title: 'Schedule',
        icon: Icons.calendar_month_rounded,
      ),
      _QuickMenuItem(
        title: 'Attendance',
        icon: Icons.fact_check_rounded,
      ),
      _QuickMenuItem(
        title: 'Quiz',
        icon: Icons.psychology_rounded,
      ),
      _QuickMenuItem(
        title: 'Exams',
        icon: Icons.school_rounded,
      ),
      _QuickMenuItem(
        title: 'Materials',
        icon: Icons.menu_book_rounded,
      ),
      _QuickMenuItem(
        title: 'Announcements',
        icon: Icons.campaign_rounded,
      ),
      _QuickMenuItem(
        title: 'Achievement',
        icon: Icons.emoji_events_rounded,
      ),
      _QuickMenuItem(
        title: 'Others',
        icon: Icons.apps_rounded,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: menuItems.length,
      gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
        mainAxisExtent: 78,
      ),
      itemBuilder: (context, index) {
        final item = menuItems[index];

        return _buildMenuItem(
          title: item.title,
          icon: item.icon,
          onTap: () {
            _handleQuickMenuTap(item.title);
          },
        );
      },
    );
  }

  // =========================================================
  // MENU ITEM
  // =========================================================

  Widget _buildMenuItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
              colorScheme.outline.withOpacity(0.55),
            ),
          ),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                  colorScheme.primary.withOpacity(0.10),
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w700,
                    color:
                    colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // HANDLE QUICK MENU
  // =========================================================

  void _handleQuickMenuTap(
      String title,
      ) {
    switch (title) {
      case 'Schedule':
        _showSchedule();
        break;

      case 'Attendance':
        _showAttendance();
        break;

      case 'Quiz':
        _showQuiz();
        break;

      case 'Exams':
        _showExams();
        break;

      case 'Materials':
        _showMaterials();
        break;

      case 'Announcements':
        _showAnnouncements();
        break;

      case 'Achievement':
        _showAchievements();
        break;

      case 'Others':
        _showOthersMenu();
        break;
    }
  }

  // =========================================================
  // SCHEDULE
  // =========================================================

  void _showSchedule() {
    if (_classId.isEmpty) {
      _showMessage(
        'Data kelas siswa belum tersedia.',
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentScheduleScreen(
          classId: _classId,
        ),
      ),
    );
  }

  // =========================================================
  // ATTENDANCE
  // =========================================================

  void _showAttendance() {
    if (_classId.isEmpty) {
      _showMessage(
        'Data kelas siswa belum tersedia.',
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentAttendanceScreen(
          classId: _classId,
        ),
      ),
    );
  }

  // =========================================================
  // MATERIALS
  // =========================================================

  void _showMaterials() {
    if (_classId.isEmpty) {
      _showMessage(
        'Data kelas siswa belum tersedia.',
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor:
      Theme.of(context).colorScheme.surface,
      builder: (context) {
        return _FirestoreListSheet(
          title: 'Materials',
          icon: Icons.menu_book_rounded,
          stream: FirebaseFirestore.instance
              .collection('materials')
              .where(
            'classId',
            isEqualTo: _classId,
          )
              .snapshots(),
          emptyText:
          'Belum ada materi untuk kelas kamu.',
          itemBuilder: (context, doc) {
            final data =
                doc.data() ??
                    <String, dynamic>{};

            final title =
            _readString(data, 'title');

            final subject =
            _readString(data, 'subject');

            final type =
            _readString(data, 'type');

            final description =
            _readString(data, 'description');

            final fileUrl =
            _getFileUrl(data);

            return _InfoCard(
              icon:
              Icons.description_rounded,
              title: title.isEmpty
                  ? 'Materi'
                  : title,
              subtitle:
              '${subject.isEmpty ? '-' : subject} • ${type.isEmpty ? 'File' : type}',
              detail: description.isEmpty
                  ? fileUrl.isEmpty
                  ? 'Belum ada file materi.'
                  : 'Tekan untuk membuka materi.'
                  : description,
              trailing: fileUrl.isNotEmpty
                  ? const Icon(
                Icons.open_in_new_rounded,
              )
                  : null,
              onTap: fileUrl.isNotEmpty
                  ? () {
                _openMaterialUrl(fileUrl);
              }
                  : null,
            );
          },
        );
      },
    );
  }

  // =========================================================
  // FILE URL
  // =========================================================

  String _getFileUrl(
      Map<String, dynamic> data,
      ) {
    final fileUrl =
    _readString(data, 'fileUrl');

    if (fileUrl.isNotEmpty) {
      return fileUrl;
    }

    final url =
    _readString(data, 'url');

    if (url.isNotEmpty) {
      return url;
    }

    final attachmentUrl =
    _readString(data, 'attachmentUrl');

    return attachmentUrl;
  }

  // =========================================================
  // OPEN URL
  // =========================================================

  Future<void> _openMaterialUrl(
      String url,
      ) async {
    var value = url.trim();

    if (value.isEmpty) {
      _showMessage(
        'File belum tersedia.',
      );
      return;
    }

    Uri? uri = Uri.tryParse(value);

    if (uri != null && uri.scheme.isEmpty) {
      value = 'https://$value';
      uri = Uri.tryParse(value);
    }

    if (uri == null ||
        (uri.scheme != 'http' &&
            uri.scheme != 'https')) {
      _showMessage(
        'URL tidak valid.',
      );
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _showMessage(
          'Tidak dapat membuka file.',
        );
      }
    } catch (e) {
      debugPrint(
        'Gagal membuka URL: $e',
      );

      if (!mounted) return;

      _showMessage(
        'Gagal membuka file.',
      );
    }
  }

  // =========================================================
  // ANNOUNCEMENTS
  // =========================================================

  void _showAnnouncements() {
    if (_classId.isEmpty) {
      _showMessage(
        'Data kelas siswa belum tersedia.',
      );
      return;
    }

    final targetClasses =
    <String>[
      'Semua Kelas',
      _classId,
    ].toSet().toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor:
      Theme.of(context).colorScheme.surface,
      builder: (context) {
        return _FirestoreListSheet(
          title: 'Announcements',
          icon: Icons.campaign_rounded,
          stream: FirebaseFirestore.instance
              .collection('announcements')
              .where(
            'targetClass',
            whereIn: targetClasses,
          )
              .snapshots(),
          emptyText:
          'Belum ada pengumuman.',
          itemBuilder: (context, doc) {
            final data =
                doc.data() ??
                    <String, dynamic>{};

            final title =
            _readString(data, 'title');

            final content =
            _readString(data, 'content');

            final category =
            _readString(data, 'category');

            final date =
            _readString(data, 'date');

            final important =
                data['important'] == true;

            return _InfoCard(
              icon: important
                  ? Icons.priority_high_rounded
                  : Icons.campaign_rounded,
              title: title.isEmpty
                  ? 'Pengumuman'
                  : title,
              subtitle:
              '${category.isEmpty ? 'Pengumuman' : category} • ${date.isEmpty ? '-' : date}',
              detail:
              content.isEmpty
                  ? '-'
                  : content,
            );
          },
        );
      },
    );
  }

  // =========================================================
  // ACHIEVEMENT
  // =========================================================

  void _showAchievements() {
    if (_classId.isEmpty) {
      _showMessage(
        'Data kelas siswa belum tersedia.',
      );
      return;
    }

    final targetClasses =
    <String>[
      'Semua Kelas',
      _classId,
    ].toSet().toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor:
      Theme.of(context).colorScheme.surface,
      builder: (context) {
        return _FirestoreListSheet(
          title: 'Achievement',
          icon:
          Icons.emoji_events_rounded,
          stream: FirebaseFirestore.instance
              .collection('achievements')
              .where(
            'targetClass',
            whereIn: targetClasses,
          )
              .snapshots(),
          emptyText:
          'Belum ada achievement.',
          itemBuilder: (context, doc) {
            final data =
                doc.data() ??
                    <String, dynamic>{};

            final title =
            _readString(data, 'title');

            final description =
            _readString(data, 'description');

            final category =
            _readString(data, 'category');

            final points =
            _readString(data, 'points');

            final active =
                data['active'] != false;

            return _InfoCard(
              icon:
              Icons.emoji_events_rounded,
              title: title.isEmpty
                  ? 'Achievement'
                  : title,
              subtitle:
              '${category.isEmpty ? '-' : category} • ${points.isEmpty ? '0' : points} poin',
              detail:
              description.isEmpty
                  ? '-'
                  : description,
              trailing: active
                  ? const Icon(
                Icons.check_circle_rounded,
              )
                  : null,
            );
          },
        );
      },
    );
  }

  // =========================================================
  // QUIZ
  // =========================================================

  Future<void> _showQuiz() async {
    if (_classId.isEmpty) {
      _showMessage(
        'Data kelas siswa belum tersedia.',
      );
      return;
    }

    bool loadingShown = false;

    try {
      _showLoadingSheet(
        'Memuat Quiz...',
      );

      loadingShown = true;

      final courseSnapshot =
      await FirebaseFirestore.instance
          .collection('courses')
          .where(
        'classId',
        isEqualTo: _classId,
      )
          .get();

      if (!mounted) return;

      if (loadingShown &&
          Navigator.canPop(context)) {
        Navigator.pop(context);
        loadingShown = false;
      }

      if (courseSnapshot.docs.isEmpty) {
        _showMessage(
          'Belum ada course untuk kelas kamu.',
        );
        return;
      }

      final courseIds =
      courseSnapshot.docs
          .map(
            (doc) => doc.id,
      )
          .toList();

      final List<
          QueryDocumentSnapshot<
              Map<String, dynamic>>>
      quizDocs = [];

      for (
      int i = 0;
      i < courseIds.length;
      i += 30
      ) {
        final batch =
        courseIds.skip(i).take(30).toList();

        final snapshot =
        await FirebaseFirestore.instance
            .collection('quizzes')
            .where(
          'courseId',
          whereIn: batch,
        )
            .get();

        quizDocs.addAll(
          snapshot.docs,
        );
      }

      if (!mounted) return;

      if (quizDocs.isEmpty) {
        _showMessage(
          'Belum ada quiz dari guru untuk kelas kamu.',
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor:
        Theme.of(context).colorScheme.surface,
        builder: (context) {
          return _QuizListSheet(
            quizDocs: quizDocs,
            courseDocs: courseSnapshot.docs,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      if (loadingShown &&
          Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      _showMessage(
        'Gagal memuat Quiz: $e',
      );
    }
  }

  // =========================================================
  // EXAMS
  // =========================================================

  void _showExams() {
    if (_classId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Data kelas belum tersedia.',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentExamsScreen(
          classId: _classId,
        ),
      ),
    );
  }

  // =========================================================
  // OTHERS
  // =========================================================

  void _showOthersMenu() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Others',
                    style:
                    theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildOtherMenuItem(
                  icon: Icons.forum_outlined,
                  title: 'Discussions',
                  subtitle: 'Forum diskusi kelas',
                  onTap: () {
                    Navigator.pop(context);
                    _showDiscussions();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // OTHER MENU ITEM
  // =========================================================

  Widget _buildOtherMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return ListTile(
      contentPadding:
      const EdgeInsets.symmetric(
        vertical: 2,
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color:
          colorScheme.primary.withOpacity(0.10),
          borderRadius:
          BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: colorScheme.primary,
          size: 21,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color:
          colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color:
        colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }

  // =========================================================
  // DISCUSSIONS
  // =========================================================

  void _showDiscussions() {
    if (_classId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Data kelas belum tersedia.',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentDiscussionsScreen(
          classId: _classId,
        ),
      ),
    );
  }

  // =========================================================
  // LOADING SHEET
  // =========================================================

  void _showLoadingSheet(
      String message,
      ) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding:
            const EdgeInsets.all(24),
            child: Row(
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(message),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // STUDENT ERROR
  // =========================================================

  Widget _buildStudentErrorCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
          colorScheme.error.withOpacity(0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Data siswa belum tersedia',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color:
                    colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Silakan refresh atau periksa data akun siswa di Firestore.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme
                        .onErrorContainer
                        .withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadStudentData,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            color: colorScheme.error,
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
        SnackBarBehavior.floating,
      ),
    );
  }
}

// =================================================================
// QUICK MENU MODEL
// =================================================================

class _QuickMenuItem {
  final String title;
  final IconData icon;

  const _QuickMenuItem({
    required this.title,
    required this.icon,
  });
}

// =================================================================
// QUIZ LIST
// =================================================================

class _QuizListSheet extends StatelessWidget {
  final List<
      QueryDocumentSnapshot<
          Map<String, dynamic>>>
  quizDocs;

  final List<
      QueryDocumentSnapshot<
          Map<String, dynamic>>>
  courseDocs;

  const _QuizListSheet({
    required this.quizDocs,
    required this.courseDocs,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Map<String, String> courseMap =
    <String, String>{
      for (final course in courseDocs)
        course.id:
        (course.data()['title']
            ?.toString()
            .trim()
            .isNotEmpty ==
            true)
            ? course.data()['title'].toString()
            : 'Course',
    };

    return SafeArea(
      child: SizedBox(
        height:
        MediaQuery.sizeOf(context).height *
            0.75,
        child: Column(
          children: [
            Padding(
              padding:
              const EdgeInsets.fromLTRB(
                20,
                8,
                20,
                16,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme
                          .primary
                          .withOpacity(0.10),
                      borderRadius:
                      BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.psychology_rounded,
                      color:
                      colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Quiz',
                      style: theme
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding:
                const EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  30,
                ),
                itemCount: quizDocs.length,
                separatorBuilder:
                    (_, __) =>
                const SizedBox(
                  height: 10,
                ),
                itemBuilder:
                    (context, index) {
                  final doc =
                  quizDocs[index];

                  final Map<String, dynamic>
                  data =
                  doc.data();

                  final String courseId =
                      data['courseId']
                          ?.toString() ??
                          '';

                  final String title =
                      data['title']
                          ?.toString() ??
                          'Quiz';

                  final String description =
                      data['description']
                          ?.toString() ??
                          '';

                  final String duration =
                      data['duration']
                          ?.toString() ??
                          '0';

                  final String courseTitle =
                      courseMap[courseId] ??
                          'Course';

                  return _InfoCard(
                    icon: Icons.quiz_outlined,
                    title: title,
                    subtitle:
                    '$courseTitle • $duration menit',
                    detail:
                    description.isEmpty
                        ? 'Quiz dari guru'
                        : description,
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                    ),
                    onTap: () {
                      Navigator.pop(context);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              StudentQuizzesScreen(
                                courseId: courseId,
                                courseTitle:
                                courseTitle,
                              ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// FIRESTORE LIST BOTTOM SHEET
// =================================================================

class _FirestoreListSheet extends StatelessWidget {
  final String title;
  final IconData icon;

  final Stream<
      QuerySnapshot<
          Map<String, dynamic>>>
  stream;

  final String emptyText;

  final Widget Function(
      BuildContext context,
      DocumentSnapshot<
          Map<String, dynamic>>
      document,
      ) itemBuilder;

  const _FirestoreListSheet({
    required this.title,
    required this.icon,
    required this.stream,
    required this.emptyText,
    required this.itemBuilder,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: SizedBox(
        height:
        MediaQuery.sizeOf(context).height *
            0.72,
        child: Column(
          children: [
            Padding(
              padding:
              const EdgeInsets.fromLTRB(
                20,
                4,
                20,
                12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme
                          .primary
                          .withOpacity(0.10),
                      borderRadius:
                      BorderRadius.circular(13),
                    ),
                    child: Icon(
                      icon,
                      color:
                      colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: theme
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<
                  QuerySnapshot<
                      Map<String,
                          dynamic>>>(
                stream: stream,
                builder:
                    (context, snapshot) {
                  if (snapshot
                      .connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child:
                      CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding:
                        const EdgeInsets.all(
                          24,
                        ),
                        child: Text(
                          'Gagal memuat data.\n\n'
                              '${snapshot.error}',
                          textAlign:
                          TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final docs =
                      snapshot.data?.docs ??
                          <
                              QueryDocumentSnapshot<
                                  Map<String,
                                      dynamic>>>[];

                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding:
                        const EdgeInsets.all(
                          24,
                        ),
                        child: Text(
                          emptyText,
                          textAlign:
                          TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding:
                    const EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      30,
                    ),
                    itemCount: docs.length,
                    separatorBuilder:
                        (_, __) =>
                    const SizedBox(
                      height: 10,
                    ),
                    itemBuilder:
                        (context, index) {
                      return itemBuilder(
                        context,
                        docs[index],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// INFO CARD
// =================================================================

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String detail;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.detail,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(17),
            border: Border.all(
              color: colorScheme
                  .outline
                  .withOpacity(0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme
                      .primary
                      .withOpacity(0.10),
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color:
                  colorScheme.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color:
                        colorScheme.primary,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      detail,
                      maxLines: 3,
                      overflow:
                      TextOverflow.ellipsis,
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}