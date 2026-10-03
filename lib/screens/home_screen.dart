import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/progress_card.dart';
import '../models/course.dart';
import '../widgets/course_card.dart';
import '../screens/courses_screen.dart';
import '../screens/assignments_screen.dart';
import '../screens/profile_screen.dart';
import '../ui/layout.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  // =========================================================
  // PROFILE PHOTO
  // =========================================================

  String _photoUrl = '';
  bool _loadingPhoto = true;
  bool _photoError = false;

  @override
  void initState() {
    super.initState();
    _loadProfilePhoto();
  }

  // =========================================================
  // LOAD PROFILE PHOTO FROM FIRESTORE
  // =========================================================

  Future<void> _loadProfilePhoto() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _photoUrl = '';
          _loadingPhoto = false;
        });

        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      final data = doc.data();

      setState(() {
        _photoUrl = data?['photoUrl'] ?? '';
        _photoError = false;
        _loadingPhoto = false;
      });
    } catch (e) {
      debugPrint('Gagal mengambil foto profil: $e');

      if (!mounted) return;

      setState(() {
        _photoUrl = '';
        _photoError = true;
        _loadingPhoto = false;
      });
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _dashboardTab(),
      const CoursesScreen(),
      const AssignmentsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor:
      Theme.of(context).scaffoldBackgroundColor,

      // =====================================================
      // APP BAR
      // =====================================================

      appBar: _index == 0
          ? AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor:
        Theme.of(context).scaffoldBackgroundColor,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'eLearn-NXT',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Learning Management System',
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
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      )
          : null,

      // =====================================================
      // BODY
      // =====================================================

      body: tabs[_index],

      // =====================================================
      // BOTTOM NAVIGATION
      // =====================================================

      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() {
            _index = i;
          });

          // Reload foto ketika kembali ke Home
          if (i == 0) {
            _loadProfilePhoto();
          }
        },
        height: 68,
        backgroundColor:
        Theme.of(context).colorScheme.surface,
        indicatorColor: Theme.of(context)
            .colorScheme
            .primary
            .withOpacity(0.12),
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
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [

            // =================================================
            // WELCOME HEADER
            // =================================================

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
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back 👋',
                          style: textTheme
                              .headlineSmall
                              ?.copyWith(
                            fontWeight:
                            FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Ready to continue learning today?',
                          style: textTheme
                              .bodyMedium
                              ?.copyWith(
                            color: colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // =================================================
                  // PROFILE AVATAR
                  // =================================================

                  _buildProfileAvatar(),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // =================================================
            // LEARNING OVERVIEW
            // =================================================

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary
                          .withOpacity(0.82),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary
                          .withOpacity(0.20),
                      blurRadius: 18,
                      offset:
                      const Offset(0, 8),
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
                          decoration:
                          BoxDecoration(
                            color: Colors.white
                                .withOpacity(0.16),
                            borderRadius:
                            BorderRadius
                                .circular(13),
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
                            style: textTheme
                                .titleSmall
                                ?.copyWith(
                              color:
                              Colors.white,
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),
                        ),

                        Text(
                          '65%',
                          style: textTheme
                              .titleMedium
                              ?.copyWith(
                            color:
                            Colors.white,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    ClipRRect(
                      borderRadius:
                      BorderRadius.circular(99),
                      child:
                      LinearProgressIndicator(
                        value: 0.65,
                        minHeight: 8,
                        backgroundColor:
                        Colors.white
                            .withOpacity(0.18),
                        valueColor:
                        const AlwaysStoppedAnimation<
                            Color>(
                          Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                      children: [
                        Text(
                          '3 of 5 lessons completed',
                          style: textTheme
                              .bodySmall
                              ?.copyWith(
                            color: Colors.white
                                .withOpacity(
                                0.85),
                          ),
                        ),
                        Text(
                          'Keep going!',
                          style: textTheme
                              .bodySmall
                              ?.copyWith(
                            color: Colors.white,
                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // =================================================
            // QUICK MENU
            // =================================================

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

            // =================================================
            // YOUR COURSES
            // =================================================

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your Courses',
                      style: textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w800,
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

            // =================================================
            // COURSE PROGRESS
            // =================================================

            SizedBox(
              height: progressListHeight,
              child: ListView(
                physics:
                const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal:
                  horizontalPadding,
                ),
                scrollDirection:
                Axis.horizontal,
                children: [
                  SizedBox(
                    width: progressCardWidth,
                    child: const ProgressCard(
                      title:
                      'Flutter for Beginners',
                      subtitle:
                      'Chapter 2 of 12',
                      percent: 0.30,
                    ),
                  ),

                  const SizedBox(width: 12),

                  SizedBox(
                    width: progressCardWidth,
                    child: const ProgressCard(
                      title:
                      'Dart Programming',
                      subtitle:
                      'Chapter 5 of 10',
                      percent: 0.50,
                    ),
                  ),

                  const SizedBox(width: 12),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // =================================================
            // CONTINUE LEARNING
            // =================================================

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Continue Learning',
                      style: textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 20,
                    color:
                    colorScheme.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: Column(
                children: [
                  for (final course
                  in dummyCourses) ...[
                    CourseCard(
                      course: course,
                      onTap: () {},
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
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
            color: colorScheme.primary
                .withOpacity(0.20),
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
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
              AlwaysStoppedAnimation<Color>(
                Colors.white,
              ),
            ),
          ),
        )
            : _photoUrl.isNotEmpty &&
            !_photoError
            ? Image.network(
          _photoUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder:
              (context, error, stackTrace) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) {
              if (!mounted) return;

              if (!_photoError) {
                setState(() {
                  _photoError = true;
                });
              }
            });

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
  // QUICK MENU 4 x 2
  // =========================================================

  Widget _buildQuickMenu() {
    final menuItems = [
      {
        'title': 'Schedule',
        'icon': Icons.calendar_month_rounded,
      },
      {
        'title': 'Attendance',
        'icon': Icons.fact_check_rounded,
      },
      {
        'title': 'Quiz',
        'icon': Icons.psychology_rounded,
      },
      {
        'title': 'Exams',
        'icon': Icons.school_rounded,
      },
      {
        'title': 'Materials',
        'icon': Icons.menu_book_rounded,
      },
      {
        'title': 'Announcements',
        'icon': Icons.campaign_rounded,
      },
      {
        'title': 'Achievement',
        'icon': Icons.emoji_events_rounded,
      },
      {
        'title': 'Others',
        'icon': Icons.apps_rounded,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics:
      const NeverScrollableScrollPhysics(),
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
          title: item['title'] as String,
          icon: item['icon'] as IconData,
          onTap: () {
            _handleQuickMenuTap(
              item['title'] as String,
            );
          },
        );
      },
    );
  }

  // =========================================================
  // QUICK MENU ITEM
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
            borderRadius:
            BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline
                  .withOpacity(0.55),
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
                  color: colorScheme.primary
                      .withOpacity(0.10),
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
  // QUICK MENU ACTION
  // =========================================================

  void _handleQuickMenuTap(String title) {
    switch (title) {
      case 'Schedule':
        _showComingSoon('Schedule');
        break;

      case 'Attendance':
        _showComingSoon('Attendance');
        break;

      case 'Quiz':
        _showComingSoon('Quiz');
        break;

      case 'Exams':
        _showComingSoon('Exams');
        break;

      case 'Materials':
        _showComingSoon('Materials');
        break;

      case 'Announcements':
        _showComingSoon('Announcements');
        break;

      case 'Achievement':
        _showComingSoon('Achievement');
        break;

      case 'Others':
        _showOthersMenu();
        break;
    }
  }

  // =========================================================
  // COMING SOON
  // =========================================================

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$title akan tersedia pada update berikutnya.',
        ),
        behavior:
        SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // OTHERS MENU
  // =========================================================

  void _showOthersMenu() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor:
      colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
            const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24,
            ),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                Align(
                  alignment:
                  Alignment.centerLeft,
                  child: Text(
                    'Other Features',
                    style: theme
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                _buildOtherMenuItem(
                  icon:
                  Icons.people_outline_rounded,
                  title: 'Class',
                  subtitle:
                  'Informasi kelas',
                ),

                _buildOtherMenuItem(
                  icon:
                  Icons.person_search_outlined,
                  title: 'Teachers',
                  subtitle:
                  'Daftar guru',
                ),

                _buildOtherMenuItem(
                  icon: Icons.forum_outlined,
                  title: 'Discussion',
                  subtitle:
                  'Forum diskusi',
                ),

                _buildOtherMenuItem(
                  icon: Icons.folder_outlined,
                  title: 'Documents',
                  subtitle:
                  'Dokumen pembelajaran',
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
          color: colorScheme.primary
              .withOpacity(0.10),
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
      onTap: () {
        Navigator.pop(context);
        _showComingSoon(title);
      },
    );
  }
}