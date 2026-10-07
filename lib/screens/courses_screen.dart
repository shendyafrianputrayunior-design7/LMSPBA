import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/course.dart';
import '../widgets/app_bar_simple.dart';
import '../widgets/course_card.dart';
import '../app_routes.dart';
import '../ui/app_spacing.dart';
import '../ui/layout.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  List<Course> _courses = [];

  bool _loading = true;
  String? _error;

  String _classId = '';
  String _className = '';

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  // =============================================================
  // LOAD COURSES
  // =============================================================

  Future<void> _loadCourses() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception(
          'Pengguna belum login.',
        );
      }

      // =========================================================
      // GET USER
      // =========================================================

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception(
          'Data pengguna tidak ditemukan.',
        );
      }

      final userData =
          userDoc.data() ?? <String, dynamic>{};

      final classId =
      (userData['classId'] ?? '').toString();

      if (classId.isEmpty) {
        throw Exception(
          'Data kelas belum tersedia. '
              'Silakan lengkapi classId pada data siswa.',
        );
      }

      // =========================================================
      // GET CLASS NAME
      // =========================================================

      String className = classId;

      final classDoc = await _firestore
          .collection('classes')
          .doc(classId)
          .get();

      if (classDoc.exists) {
        final classData =
            classDoc.data() ??
                <String, dynamic>{};

        className =
            (classData['name'] ?? classId).toString();
      }

      // =========================================================
      // GET COURSES
      // =========================================================

      final snapshot = await _firestore
          .collection('courses')
          .where(
        'classId',
        isEqualTo: classId,
      )
          .get();

      final courses = snapshot.docs.map((doc) {
        return Course.fromFirestore(
          doc.id,
          doc.data(),
        );
      }).toList();

      // Sort berdasarkan title
      courses.sort(
            (a, b) => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
      );

      if (!mounted) return;

      setState(() {
        _classId = classId;
        _className = className;
        _courses = courses;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        );
      });
    }
  }

  // =============================================================
  // REFRESH
  // =============================================================

  Future<void> _refresh() async {
    await _loadCourses();
  }

  // =============================================================
  // BUILD
  // =============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor:
      theme.scaffoldBackgroundColor,

      // =========================================================
      // APP BAR
      // =========================================================

      appBar: AppBarSimple(
        title: 'Courses',
      ),

      // =========================================================
      // BODY
      // =========================================================

      body: _buildBody(
        context,
        theme,
        textTheme,
        colorScheme,
      ),
    );
  }

  // =============================================================
  // BODY
  // =============================================================

  Widget _buildBody(
      BuildContext context,
      ThemeData theme,
      TextTheme textTheme,
      ColorScheme colorScheme,
      ) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return _buildErrorState(
        context,
        theme,
        colorScheme,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,

      child: AppLayout.centeredConstrained(
        maxWidth: 720,

        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),

          padding:
          AppSpacing.listPadding(context).copyWith(
            top: 20,
            bottom: 30,
          ),

          children: [
            // =====================================================
            // HEADER
            // =====================================================

            Text(
              'Explore Courses',
              style:
              textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              _className.isEmpty
                  ? 'Find something new to learn and improve your skills.'
                  : 'Courses available for class $_className.',
              style:
              textTheme.bodyMedium?.copyWith(
                color:
                colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 20),

            // =====================================================
            // COURSE SUMMARY
            // =====================================================

            Container(
              padding:
              const EdgeInsets.all(18),

              decoration: BoxDecoration(
                color: colorScheme.primary,

                borderRadius:
                BorderRadius.circular(20),

                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary
                        .withOpacity(0.18),
                    blurRadius: 18,
                    offset:
                    const Offset(0, 8),
                  ),
                ],
              ),

              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,

                    decoration:
                    BoxDecoration(
                      color: Colors.white
                          .withOpacity(0.15),
                      borderRadius:
                      BorderRadius.circular(14),
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
                          '${_courses.length} Courses Available',

                          style:
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'Start learning at your own pace',

                          style: TextStyle(
                            color: Colors.white
                                .withOpacity(0.8),
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

            // =====================================================
            // SECTION TITLE
            // =====================================================

            Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,

              children: [
                Text(
                  'All Courses',

                  style:
                  textTheme.titleLarge?.copyWith(
                    fontWeight:
                    FontWeight.w800,
                    color:
                    colorScheme.onSurface,
                  ),
                ),

                Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),

                  decoration:
                  BoxDecoration(
                    color: colorScheme.primary
                        .withOpacity(0.1),
                    borderRadius:
                    BorderRadius.circular(10),
                  ),

                  child: Text(
                    '${_courses.length}',

                    style: TextStyle(
                      color:
                      colorScheme.primary,
                      fontSize: 12,
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // =====================================================
            // EMPTY STATE
            // =====================================================

            if (_courses.isEmpty)
              _buildEmptyState(
                context,
                theme,
                colorScheme,
              ),

            // =====================================================
            // COURSE LIST
            // =====================================================

            for (final course in _courses) ...[
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

  // =============================================================
  // EMPTY STATE
  // =============================================================

  Widget _buildEmptyState(
      BuildContext context,
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    return Container(
      margin:
      const EdgeInsets.only(top: 20),

      padding:
      const EdgeInsets.all(28),

      decoration: BoxDecoration(
        color:
        colorScheme.surfaceContainerHighest
            .withOpacity(0.45),

        borderRadius:
        BorderRadius.circular(20),

        border: Border.all(
          color:
          colorScheme.outlineVariant,
        ),
      ),

      child: Column(
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 58,
            color: colorScheme
                .onSurfaceVariant
                .withOpacity(0.5),
          ),

          const SizedBox(height: 16),

          Text(
            'Belum Ada Course',
            style:
            theme.textTheme.titleMedium?.copyWith(
              fontWeight:
              FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'Belum ada course yang tersedia '
                'untuk kelas $_className.',
            textAlign: TextAlign.center,
            style:
            theme.textTheme.bodyMedium?.copyWith(
              color:
              colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // ERROR STATE
  // =============================================================

  Widget _buildErrorState(
      BuildContext context,
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    return RefreshIndicator(
      onRefresh: _refresh,

      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),

        children: [
          SizedBox(
            height:
            MediaQuery.sizeOf(context).height *
                0.30,
          ),

          Padding(
            padding:
            const EdgeInsets.all(24),

            child: Column(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color:
                  colorScheme.error,
                ),

                const SizedBox(height: 16),

                Text(
                  'Gagal Memuat Courses',
                  textAlign:
                  TextAlign.center,

                  style: theme
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  _error ??
                      'Terjadi kesalahan.',
                  textAlign:
                  TextAlign.center,

                  style: theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    color: colorScheme
                        .onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 20),

                FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(
                    Icons.refresh_rounded,
                  ),
                  label:
                  const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}