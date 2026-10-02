import 'package:flutter/material.dart';

import '../widgets/progress_card.dart';
import '../models/course.dart';
import '../widgets/course_card.dart';
import '../screens/courses_screen.dart';
import '../screens/assignments_screen.dart';
import '../screens/profile_screen.dart';
import '../ui/app_spacing.dart';
import '../ui/layout.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _dashboardTab(),
      const CoursesScreen(),
      const AssignmentsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LMS',
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
        },

        height: 68,

        backgroundColor:
        Theme.of(context).colorScheme.surface,

        indicatorColor:
        Theme.of(context)
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

                          style:
                          textTheme.headlineSmall?.copyWith(
                            fontWeight:
                            FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          'Ready to continue learning today?',

                          style:
                          textTheme.bodyMedium?.copyWith(
                            color:
                            colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // PROFILE AVATAR

                  Container(
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
                          offset:
                          const Offset(0, 5),
                        ),
                      ],
                    ),

                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
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

                    child:
                    const ProgressCard(
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

                    child:
                    const ProgressCard(
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

            // =================================================
            // BOTTOM SPACE
            // =================================================

          ],
        ),
      ),
    );
  }
}