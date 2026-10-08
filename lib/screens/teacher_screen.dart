import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../models/course.dart';
import 'teacher_course_form_screen.dart';
import 'teacher_lessons_screen.dart';
import 'teacher_quizzes_screen.dart';
import 'teacher_assignments_screen.dart';
import 'teacher_materials_screen.dart';
import 'teacher_announcements_screen.dart';
import 'teacher_exams_screen.dart';
import 'teacher_discussions_screen.dart';
import 'teacher_students_screen.dart';
import 'teacher_attendance_screen.dart';
import 'teacher_schedule_form_screen.dart';

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> {
  int _currentIndex = 0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _teacherData;
  bool _loadingProfile = true;

  // ============================================================
  // TEACHER ID UTAMA
  // ============================================================

  static const String _teacherId = 'teacher_001';

  @override
  void initState() {
    super.initState();

    _initializeTeacherData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showTeacherWelcomeDialog();
    });
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> _initializeTeacherData() async {
    await _loadTeacherProfile();
  }

  Future<void> _refreshTeacherData() async {
    await _loadTeacherProfile();
  }

  // ============================================================
  // WELCOME
  // ============================================================

  void _showTeacherWelcomeDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 520,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                24,
                12,
                24,
                24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      tooltip: 'Tutup',
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                    ),
                  ),
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      size: 42,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Selamat Datang, Guru!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Anda berhasil login sebagai Teacher.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Melalui dashboard ini Anda dapat mengelola '
                        'course, materi, quiz, tugas, jadwal, '
                        'presensi, ujian, pengumuman, dan aktivitas '
                        'pembelajaran siswa.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      icon: const Icon(
                        Icons.dashboard_rounded,
                      ),
                      label: const Text('Mulai'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // LOAD PROFILE
  // ============================================================

  Future<void> _loadTeacherProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _loadingProfile = false;
      });

      return;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      setState(() {
        _teacherData = doc.data();
        _loadingProfile = false;
      });
    } catch (e) {
      debugPrint('Gagal mengambil profile guru: $e');

      if (!mounted) return;

      setState(() {
        _loadingProfile = false;
      });
    }
  }

  // ============================================================
  // DATA GURU
  // ============================================================

  String get _teacherName {
    final name = (
        _teacherData?['name'] ??
            _teacherData?['username'] ??
            _teacherData?['displayName'] ??
            'Guru'
    ).toString().trim();

    return name.isEmpty ? 'Guru' : name;
  }

  // ============================================================
  // TAMBAH COURSE
  // ============================================================

  Future<void> _openAddCourse() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TeacherCourseFormScreen(),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      setState(() {});
    }
  }

  // ============================================================
  // EDIT COURSE
  // ============================================================

  Future<void> _editCourse(
      String courseId,
      Map<String, dynamic> courseData,
      ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherCourseFormScreen(
          courseId: courseId,
          courseData: courseData,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      setState(() {});
    }
  }

  // ============================================================
  // KELOLA LESSON
  // ============================================================

  void _manageLessons(
      String courseId,
      Map<String, dynamic> courseData,
      ) {
    final course = Course.fromFirestore(
      courseId,
      courseData,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherLessonsScreen(
          course: course,
        ),
      ),
    );
  }

  // ============================================================
  // KELOLA QUIZ
  // ============================================================

  void _manageQuizzes(
      String courseId,
      Map<String, dynamic> courseData,
      ) {
    final course = Course.fromFirestore(
      courseId,
      courseData,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherQuizzesScreen(
          course: course,
        ),
      ),
    );
  }

  // ============================================================
  // HAPUS COURSE
  // ============================================================

  Future<void> _deleteCourse(
      String courseId,
      String courseTitle,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Course?'),
          content: Text(
            'Course "$courseTitle" akan dihapus secara permanen.\n\n'
                'Tindakan ini tidak dapat dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _firestore
          .collection('courses')
          .doc(courseId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Course berhasil dihapus.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus course: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    await _auth.signOut();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
          (route) => false,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboard(),
      _buildCourses(),
      _buildProfile(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (!mounted) return;

          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Courses',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _buildDashboard() {
    final theme = Theme.of(context);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshTeacherData,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard Guru',
                        style:
                        theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Selamat datang, $_teacherName',
                        style:
                        theme.textTheme.bodyMedium?.copyWith(
                          color:
                          theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                  theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    color:
                    theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _buildCourseSummary(),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics:
              const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.35,
              children: [
                _DashboardCard(
                  icon: Icons.menu_book_outlined,
                  title: 'My Courses',
                  subtitle: 'Kelola course',
                  onTap: () {
                    setState(() {
                      _currentIndex = 1;
                    });
                  },
                ),
                _DashboardCard(
                  icon: Icons.assignment_outlined,
                  title: 'Assignments',
                  subtitle: 'Kelola tugas',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                        const TeacherAssignmentsScreen(),
                      ),
                    );
                  },
                ),
                _DashboardCard(
                  icon: Icons.groups_outlined,
                  title: 'Students',
                  subtitle: 'Daftar siswa',
                  onTap: _showStudents,
                ),
                _DashboardCard(
                  icon: Icons.bar_chart_outlined,
                  title: 'Reports',
                  subtitle: 'Laporan belajar',
                  onTap: _showReports,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Aksi Cepat',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics:
              const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.7,
              children: [
                _QuickActionButton(
                  icon: Icons.add_circle_outline,
                  label: 'Tambah Course',
                  onTap: _openAddCourse,
                ),
                _QuickActionButton(
                  icon: Icons.calendar_month_outlined,
                  label: 'Jadwal Mengajar',
                  onTap: _showSchedules,
                ),
                _QuickActionButton(
                  icon: Icons.fact_check_outlined,
                  label: 'Presensi Siswa',
                  onTap: _showAttendance,
                ),
                _QuickActionButton(
                  icon: Icons.school_outlined,
                  label: 'Ujian',
                  onTap: _showExams,
                ),
                _QuickActionButton(
                  icon: Icons.library_books_outlined,
                  label: 'Materi',
                  onTap: _showMaterials,
                ),
                _QuickActionButton(
                  icon: Icons.campaign_outlined,
                  label: 'Pengumuman',
                  onTap: _showAnnouncements,
                ),
                _QuickActionButton(
                  icon: Icons.forum_outlined,
                  label: 'Diskusi',
                  onTap: _showDiscussions,
                ),
                _QuickActionButton(
                  icon: Icons.assignment_turned_in_outlined,
                  label: 'Tugas',
                  onTap: _showAssignments,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // COURSE SUMMARY
  // ============================================================

  Widget _buildCourseSummary() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('courses')
          .where(
        'teacherId',
        isEqualTo: _teacherId,
      )
          .snapshots(),
      builder: (context, snapshot) {
        final count =
            snapshot.data?.docs.length ?? 0;

        final theme = Theme.of(context);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                Icons.menu_book,
                size: 36,
                color:
                theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count Course',
                      style: theme
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Course yang Anda kelola',
                      style:
                      theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // COURSES
  // ============================================================

  Widget _buildCourses() {
    final theme = Theme.of(context);

    return SafeArea(
      child: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('courses')
            .where(
          'teacherId',
          isEqualTo: _teacherId,
        )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                const EdgeInsets.all(24),
                child: Text(
                  'Gagal mengambil data course.\n\n'
                      '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs =
              snapshot.data?.docs ?? [];

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                title: const Text(
                  'My Courses',
                ),
                actions: [
                  IconButton(
                    tooltip: 'Tambah Course',
                    onPressed: _openAddCourse,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              if (docs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding:
                      const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize:
                        MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            size: 72,
                            color: theme
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada course',
                            style: theme
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tambahkan course pertama Anda.',
                            textAlign:
                            TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed:
                            _openAddCourse,
                            icon:
                            const Icon(Icons.add),
                            label: const Text(
                              'Tambah Course',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding:
                  const EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    24,
                  ),
                  sliver: SliverList(
                    delegate:
                    SliverChildBuilderDelegate(
                          (context, index) {
                        final doc =
                        docs[index];
                        final data =
                        doc.data();

                        final title =
                        (data['title'] ??
                            'Tanpa Judul')
                            .toString();

                        final instructor =
                        (data['instructor'] ??
                            _teacherName)
                            .toString();

                        final description =
                        (data['description'] ??
                            '')
                            .toString();

                        final image =
                        (data['image'] ??
                            '')
                            .toString();

                        final lessons =
                        data['lessons'] is int
                            ? data['lessons']
                        as int
                            : int.tryParse(
                          (data['lessons'] ??
                              '0')
                              .toString(),
                        ) ??
                            0;

                        return _CourseTeacherCard(
                          courseId: doc.id,
                          courseData: data,
                          title: title,
                          instructor: instructor,
                          description: description,
                          image: image,
                          lessons: lessons,
                          onTap: () {
                            _manageLessons(
                              doc.id,
                              data,
                            );
                          },
                          onLessons: () {
                            _manageLessons(
                              doc.id,
                              data,
                            );
                          },
                          onQuiz: () {
                            _manageQuizzes(
                              doc.id,
                              data,
                            );
                          },
                          onEdit: () {
                            _editCourse(
                              doc.id,
                              data,
                            );
                          },
                          onDelete: () {
                            _deleteCourse(
                              doc.id,
                              title,
                            );
                          },
                        );
                      },
                      childCount: docs.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // ASSIGNMENTS
  // ============================================================

  void _showAssignments() {
    _showDatabaseSheet(
      title: 'Assignments',
      icon: Icons.assignment_outlined,
      stream: _firestore
          .collection('assignments')
          .where(
        'teacherId',
        isEqualTo: _teacherId,
      )
          .snapshots(),
      emptyMessage:
      'Belum ada assignment yang dibuat.',
      itemBuilder: (context, doc) {
        final data = doc.data();

        final title =
        (data['title'] ?? 'Tanpa Judul')
            .toString();

        final description =
        (data['description'] ??
            data['instructions'] ??
            '')
            .toString();

        final course =
        (data['courseTitle'] ??
            data['courseName'] ??
            '')
            .toString();

        final dueDate =
        (data['dueDate'] ?? '-')
            .toString();

        final points =
        (data['points'] ??
            data['maxScore'] ??
            '')
            .toString();

        return _DatabaseItemCard(
          icon: Icons.assignment_outlined,
          title: title,
          subtitle: course.isEmpty
              ? 'Assignment'
              : course,
          details: [
            if (description.isNotEmpty)
              description,
            'Deadline: $dueDate',
            if (points.isNotEmpty)
              'Nilai maksimal: $points',
          ],
        );
      },
    );
  }

  // ============================================================
  // STUDENTS
  // ============================================================

  void _showStudents() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const TeacherStudentsScreen(),
      ),
    );
  }

  // ============================================================
  // ATTENDANCE
  // ============================================================

  void _showAttendance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const TeacherAttendanceScreen(),
      ),
    );
  }

  // ============================================================
  // REPORTS
  // ============================================================

  Future<void> _showReports() async {
    bool loadingDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child:
                CircularProgressIndicator(),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Mengambil laporan...',
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      final results = await Future.wait([
        _firestore
            .collection('courses')
            .where(
          'teacherId',
          isEqualTo: _teacherId,
        )
            .get(),
        _firestore
            .collection('assignments')
            .where(
          'teacherId',
          isEqualTo: _teacherId,
        )
            .get(),
        _firestore
            .collection('quizzes')
            .where(
          'teacherId',
          isEqualTo: _teacherId,
        )
            .get(),
        _firestore
            .collection('course_lessons')
            .where(
          'teacherId',
          isEqualTo: _teacherId,
        )
            .get(),
        _firestore
            .collection('users')
            .where(
          'role',
          isEqualTo: 'student',
        )
            .get(),
      ]);

      final courses =
          (results[0] as QuerySnapshot).docs.length;

      final assignments =
          (results[1] as QuerySnapshot).docs.length;

      final quizzes =
          (results[2] as QuerySnapshot).docs.length;

      final lessons =
          (results[3] as QuerySnapshot).docs.length;

      final students =
          (results[4] as QuerySnapshot).docs.length;

      if (!mounted) return;

      if (loadingDialogOpen) {
        loadingDialogOpen = false;
        Navigator.of(context).pop();
      }

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) {
          final theme =
          Theme.of(sheetContext);

          return SafeArea(
            child: Padding(
              padding:
              const EdgeInsets.fromLTRB(
                20,
                8,
                20,
                24,
              ),
              child: Column(
                mainAxisSize:
                MainAxisSize.min,
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reports',
                    style: theme
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ringkasan aktivitas pembelajaran Anda.',
                    style: theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color: theme
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics:
                    const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _ReportCard(
                        icon:
                        Icons.menu_book_outlined,
                        value: '$courses',
                        label: 'Courses',
                      ),
                      _ReportCard(
                        icon:
                        Icons.library_books_outlined,
                        value: '$lessons',
                        label: 'Materi',
                      ),
                      _ReportCard(
                        icon:
                        Icons.quiz_outlined,
                        value: '$quizzes',
                        label: 'Quiz',
                      ),
                      _ReportCard(
                        icon:
                        Icons.assignment_outlined,
                        value: '$assignments',
                        label: 'Assignments',
                      ),
                      _ReportCard(
                        icon:
                        Icons.groups_outlined,
                        value: '$students',
                        label: 'Students',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted && loadingDialogOpen) {
        loadingDialogOpen = false;
        Navigator.of(context).pop();
      }

      if (!mounted) return;

      _showMessage(
        'Gagal mengambil laporan:\n$e',
      );
    }
  }

  // ============================================================
  // SCHEDULE
  // ============================================================

  Future<void> _showSchedules() async {
    _showDatabaseSheet(
      title: 'Jadwal Mengajar',
      icon: Icons.calendar_month_outlined,
      stream: _firestore
          .collection('schedules')
          .where(
        'teacherId',
        isEqualTo: _teacherId,
      )
          .snapshots(),
      emptyMessage:
      'Belum ada jadwal mengajar.',
      showAddButton: true,
      onAdd: _showScheduleForm,
      itemBuilder: (context, doc) {
        final data = doc.data();

        final subject =
        (data['subject'] ??
            data['title'] ??
            'Mata Pelajaran')
            .toString();

        final day =
        (data['day'] ?? '-').toString();

        final start =
        (data['startTime'] ?? '-')
            .toString();

        final end =
        (data['endTime'] ?? '-')
            .toString();

        final room =
        (data['room'] ?? '-')
            .toString();

        final classId =
        (data['classId'] ?? '-')
            .toString();

        return _ScheduleCard(
          scheduleId: doc.id,
          data: data,
          subject: subject,
          day: day,
          start: start,
          end: end,
          room: room,
          classId: classId,
          onEdit: () {
            _showScheduleForm(
              scheduleId: doc.id,
              scheduleData: data,
            );
          },
          onDelete: () {
            _deleteSchedule(
              doc.id,
              subject,
            );
          },
        );
      },
    );
  }

  // ============================================================
  // FORM JADWAL
  // ============================================================

  Future<void> _showScheduleForm({
    String? scheduleId,
    Map<String, dynamic>? scheduleData,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherScheduleFormScreen(
          scheduleId: scheduleId,
          scheduleData: scheduleData,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      setState(() {});
    }
  }

  // ============================================================
  // DELETE SCHEDULE
  // ============================================================

  Future<void> _deleteSchedule(
      String scheduleId,
      String subject,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
          const Text('Hapus Jadwal?'),
          content: Text(
            'Jadwal "$subject" akan dihapus secara permanen.\n\n'
                'Tindakan ini tidak dapat dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child:
              const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child:
              const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _firestore
          .collection('schedules')
          .doc(scheduleId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Jadwal berhasil dihapus.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus jadwal: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // OTHER MENU
  // ============================================================

  void _showExams() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const TeacherExamsScreen(),
      ),
    );
  }

  void _showMaterials() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const TeacherMaterialsScreen(),
      ),
    );
  }

  void _showAnnouncements() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const TeacherAnnouncementsScreen(),
      ),
    );
  }

  void _showDiscussions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const TeacherDiscussionsScreen(),
      ),
    );
  }

  // ============================================================
  // DATABASE SHEET
  // ============================================================

  void _showDatabaseSheet({
    required String title,
    required IconData icon,
    required Stream<
        QuerySnapshot<Map<String, dynamic>>> stream,
    required String emptyMessage,
    required Widget Function(
        BuildContext,
        QueryDocumentSnapshot<
            Map<String, dynamic>>,
        ) itemBuilder,
    bool showAddButton = false,
    VoidCallback? onAdd,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height:
            MediaQuery.of(sheetContext)
                .size
                .height *
                .82,
            child: Column(
              children: [
                Padding(
                  padding:
                  const EdgeInsets.fromLTRB(
                    20,
                    8,
                    12,
                    16,
                  ),
                  child: Row(
                    children: [
                      Icon(icon),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: Text(
                          title,
                          style:
                          const TextStyle(
                            fontSize: 22,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ),
                      if (showAddButton)
                        IconButton.filledTonal(
                          tooltip: 'Tambah',
                          onPressed: onAdd,
                          icon:
                          const Icon(Icons.add),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<
                      QuerySnapshot<
                          Map<String, dynamic>>>(
                    stream: stream,
                    builder:
                        (
                        context,
                        snapshot,
                        ) {
                      if (snapshot
                          .connectionState ==
                          ConnectionState
                              .waiting) {
                        return const Center(
                          child:
                          CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding:
                            const EdgeInsets
                                .all(24),
                            child: Text(
                              'Gagal mengambil data.\n\n'
                                  '${snapshot.error}',
                              textAlign:
                              TextAlign.center,
                            ),
                          ),
                        );
                      }

                      final docs =
                          snapshot.data?.docs ??
                              [];

                      if (docs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding:
                            const EdgeInsets
                                .all(24),
                            child: Column(
                              mainAxisSize:
                              MainAxisSize.min,
                              children: [
                                Icon(
                                  icon,
                                  size: 60,
                                  color: Theme.of(
                                    context,
                                  )
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(
                                    height: 16),
                                Text(
                                  emptyMessage,
                                  textAlign:
                                  TextAlign
                                      .center,
                                ),
                                if (showAddButton) ...[
                                  const SizedBox(
                                      height: 20),
                                  FilledButton.icon(
                                    onPressed:
                                    onAdd,
                                    icon:
                                    const Icon(
                                      Icons.add,
                                    ),
                                    label:
                                    const Text(
                                      'Tambah Jadwal',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding:
                        const EdgeInsets
                            .fromLTRB(
                          20,
                          0,
                          20,
                          20,
                        ),
                        itemCount:
                        docs.length,
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
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Widget _buildProfile() {
    final theme = Theme.of(context);
    final user = _auth.currentUser;

    return SafeArea(
      child: ListView(
        padding:
        const EdgeInsets.all(20),
        children: [
          Text(
            'Profile Guru',
            style: theme
                .textTheme
                .headlineSmall
                ?.copyWith(
              fontWeight:
              FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: CircleAvatar(
              radius: 46,
              backgroundColor:
              theme.colorScheme
                  .primaryContainer,
              child: Icon(
                Icons.person,
                size: 48,
                color: theme
                    .colorScheme
                    .onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _loadingProfile
                  ? 'Memuat...'
                  : _teacherName,
              style: theme
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              user?.email ?? '-',
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading:
                  Icon(Icons.badge_outlined),
                  title:
                  Text('Teacher ID'),
                  subtitle:
                  Text(_teacherId),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                  const Icon(
                    Icons.email_outlined,
                  ),
                  title:
                  const Text('Email'),
                  subtitle:
                  Text(
                    user?.email ?? '-',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _logout,
            icon:
            const Icon(Icons.logout),
            label:
            const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// QUICK ACTION
// ================================================================

class _QuickActionButton
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context);

    return Material(
      color:
      theme.colorScheme.surface,
      borderRadius:
      BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(14),
        child: Container(
          decoration:
          BoxDecoration(
            borderRadius:
            BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme
                  .outlineVariant,
            ),
          ),
          padding:
          const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                BoxDecoration(
                  color: theme
                      .colorScheme
                      .primaryContainer,
                  borderRadius:
                  BorderRadius.circular(
                    11,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: theme
                      .colorScheme
                      .onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,
                  style: theme
                      .textTheme
                      .labelLarge
                      ?.copyWith(
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// DASHBOARD CARD
// ================================================================

class _DashboardCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context);

    return Card(
      clipBehavior:
      Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
          const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28,
                color: theme
                    .colorScheme
                    .primary,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow:
                TextOverflow.ellipsis,
                style: theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow:
                TextOverflow.ellipsis,
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// DATABASE ITEM
// ================================================================

class _DatabaseItemCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> details;

  const _DatabaseItemCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context);

    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor:
              theme.colorScheme
                  .primaryContainer,
              child: Icon(
                icon,
                color: theme
                    .colorScheme
                    .onPrimaryContainer,
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
                        .titleMedium
                        ?.copyWith(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: theme
                            .colorScheme
                            .primary,
                      ),
                    ),
                  ],
                  for (final detail
                  in details)
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        detail,
                        style: theme
                            .textTheme
                            .bodySmall,
                      ),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// SCHEDULE CARD
// ================================================================

class _ScheduleCard
    extends StatelessWidget {
  final String scheduleId;
  final Map<String, dynamic> data;
  final String subject;
  final String day;
  final String start;
  final String end;
  final String room;
  final String classId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ScheduleCard({
    required this.scheduleId,
    required this.data,
    required this.subject,
    required this.day,
    required this.start,
    required this.end,
    required this.room,
    required this.classId,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context);

    return Card(
      clipBehavior:
      Clip.antiAlias,
      child: Padding(
        padding:
        const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration:
              BoxDecoration(
                color: theme
                    .colorScheme
                    .primaryContainer,
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
              ),
              child: Icon(
                Icons
                    .calendar_month_outlined,
                color: theme
                    .colorScheme
                    .onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    subject,
                    maxLines: 2,
                    overflow:
                    TextOverflow.ellipsis,
                    style: theme
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    day,
                    style: theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color: theme
                          .colorScheme
                          .primary,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons
                            .access_time_outlined,
                        text:
                        '$start - $end',
                      ),
                      _InfoChip(
                        icon: Icons
                            .meeting_room_outlined,
                        text: room.isEmpty
                            ? '-'
                            : room,
                      ),
                      _InfoChip(
                        icon: Icons
                            .groups_outlined,
                        text:
                        classId.isEmpty
                            ? '-'
                            : classId,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Menu Jadwal',
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value ==
                    'delete') {
                  onDelete();
                }
              },
              itemBuilder:
                  (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons
                            .edit_outlined,
                      ),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons
                            .delete_outline,
                      ),
                      SizedBox(width: 10),
                      Text('Hapus'),
                    ],
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

// ================================================================
// INFO CHIP
// ================================================================

class _InfoChip
    extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context);

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration:
      BoxDecoration(
        color: theme.colorScheme
            .surfaceContainerHighest,
        borderRadius:
        BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: theme
                .colorScheme
                .onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style:
            theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ================================================================
// REPORT CARD
// ================================================================

class _ReportCard
    extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _ReportCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context);

    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 28,
              color: theme
                  .colorScheme
                  .primary,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                fontWeight:
                FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style:
              theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// COURSE CARD
// ================================================================

class _CourseTeacherCard
    extends StatelessWidget {
  final String courseId;
  final Map<String, dynamic> courseData;
  final String title;
  final String instructor;
  final String description;
  final String image;
  final int lessons;
  final VoidCallback onTap;
  final VoidCallback onLessons;
  final VoidCallback onQuiz;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CourseTeacherCard({
    required this.courseId,
    required this.courseData,
    required this.title,
    required this.instructor,
    required this.description,
    required this.image,
    required this.lessons,
    required this.onTap,
    required this.onLessons,
    required this.onQuiz,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context);

    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 14,
      ),
      clipBehavior:
      Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
          const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              _buildImage(theme),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow:
                            TextOverflow.ellipsis,
                            style: theme
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip:
                          'Menu Course',
                          onSelected:
                              (value) {
                            switch (value) {
                              case 'lessons':
                                onLessons();
                                break;
                              case 'quiz':
                                onQuiz();
                                break;
                              case 'edit':
                                onEdit();
                                break;
                              case 'delete':
                                onDelete();
                                break;
                            }
                          },
                          itemBuilder:
                              (context) =>
                          const [
                            PopupMenuItem(
                              value:
                              'lessons',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons
                                        .library_books_outlined,
                                  ),
                                  SizedBox(
                                      width: 10),
                                  Text(
                                    'Kelola Materi',
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'quiz',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons
                                        .quiz_outlined,
                                  ),
                                  SizedBox(
                                      width: 10),
                                  Text(
                                    'Kelola Quiz',
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons
                                        .edit_outlined,
                                  ),
                                  SizedBox(
                                      width: 10),
                                  Text(
                                    'Edit',
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons
                                        .delete_outline,
                                  ),
                                  SizedBox(
                                      width: 10),
                                  Text(
                                    'Hapus',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      instructor,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: theme
                            .colorScheme
                            .primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description.isEmpty
                          ? 'Belum ada deskripsi.'
                          : description,
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,
                      style: theme
                          .textTheme
                          .bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons
                              .library_books_outlined,
                          size: 16,
                          color: theme
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$lessons materi',
                          style: theme
                              .textTheme
                              .bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(ThemeData theme) {
    if (image.isEmpty) {
      return Container(
        width: 90,
        height: 90,
        decoration:
        BoxDecoration(
          color: theme
              .colorScheme
              .surfaceContainerHighest,
          borderRadius:
          BorderRadius.circular(14),
        ),
        child: Icon(
          Icons
              .menu_book_outlined,
          size: 36,
          color: theme
              .colorScheme
              .onSurfaceVariant,
        ),
      );
    }

    return ClipRRect(
      borderRadius:
      BorderRadius.circular(14),
      child: Image.asset(
        image,
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) {
          return Container(
            width: 90,
            height: 90,
            color: theme
                .colorScheme
                .surfaceContainerHighest,
            child: Icon(
              Icons
                  .broken_image_outlined,
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          );
        },
      ),
    );
  }
}