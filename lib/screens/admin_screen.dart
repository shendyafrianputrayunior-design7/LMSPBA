import 'package:flutter/material.dart';

import 'admin_classes_screen.dart';
import 'admin_teachers_screen.dart';
import 'admin_schedule_screen.dart';
import 'admin_materials_screen.dart';
import 'admin_quiz_screen.dart';
import 'admin_exam_screen.dart';
import 'admin_announcements_screen.dart';
import 'admin_achievements_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(
              context,
              colorScheme,
              theme,
            ),

            const SizedBox(height: 28),

            Text(
              'Manajemen LMS',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Kelola data pembelajaran dan informasi sekolah.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 18),

            _buildMenuGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(
      BuildContext context,
      ColorScheme colorScheme,
      ThemeData theme,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withOpacity(0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Panel',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Kelola seluruh data LMS dari satu tempat.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid(BuildContext context) {
    final menus = [
      // ============================================================
      // KELAS
      // ============================================================
      _AdminMenuItem(
        title: 'Kelas',
        subtitle: 'Kelola data kelas',
        icon: Icons.class_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminClassesScreen(),
            ),
          );
        },
      ),

      // ============================================================
      // GURU
      // ============================================================
      _AdminMenuItem(
        title: 'Guru',
        subtitle: 'Kelola data guru',
        icon: Icons.people_alt_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminTeachersScreen(),
            ),
          );
        },
      ),

      // ============================================================
      // JADWAL
      // ============================================================
      _AdminMenuItem(
        title: 'Jadwal',
        subtitle: 'Kelola jadwal pelajaran',
        icon: Icons.calendar_month_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminScheduleScreen(),
            ),
          );
        },
      ),

      // ============================================================
      // MATERI
      // ============================================================
      _AdminMenuItem(
        title: 'Materi',
        subtitle: 'Kelola materi pembelajaran',
        icon: Icons.menu_book_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminMaterialsScreen(),
            ),
          );
        },
      ),

      // ============================================================
      // QUIZ
      // ============================================================
      _AdminMenuItem(
        title: 'Quiz',
        subtitle: 'Kelola quiz dan soal',
        icon: Icons.quiz_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminQuizScreen(),
            ),
          );
        },
      ),

      // ============================================================
      // UJIAN
      // ============================================================
      _AdminMenuItem(
        title: 'Ujian',
        subtitle: 'Kelola ujian',
        icon: Icons.assignment_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminExamScreen(),
            ),
          );
        },
      ),

      // ============================================================
      // PENGUMUMAN
      // ============================================================
      _AdminMenuItem(
        title: 'Pengumuman',
        subtitle: 'Kelola pengumuman',
        icon: Icons.campaign_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminAnnouncementsScreen(),
            ),
          );
        },
      ),

      // ============================================================
      // ACHIEVEMENT
      // ============================================================
      _AdminMenuItem(
        title: 'Achievement',
        subtitle: 'Kelola pencapaian siswa',
        icon: Icons.emoji_events_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminAchievementsScreen(),
            ),
          );
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final crossAxisCount = width >= 800
            ? 4
            : width >= 550
            ? 3
            : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: menus.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemBuilder: (context, index) {
            return _buildMenuCard(
              context,
              menus[index],
            );
          },
        );
      },
    );
  }

  Widget _buildMenuCard(
      BuildContext context,
      _AdminMenuItem item,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                item.icon,
                color: colorScheme.primary,
                size: 25,
              ),
            ),

            const Spacer(),

            Text(
              item.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              item.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _AdminMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}