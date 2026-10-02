import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../app_strings.dart';
import '../language_controller.dart';
import '../main.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final language = LanguageScope.of(context);
    final strings = AppStrings(language);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // =====================================================
      // APP BAR
      // =====================================================

      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,

        title: Text(
          strings.home,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),

        actions: [
          IconButton(
            tooltip: strings.settings,
            icon: const Icon(
              Icons.settings_outlined,
            ),
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.settings,
              );
            },
          ),

          const SizedBox(width: 8),
        ],
      ),

      // =====================================================
      // BODY
      // =====================================================

      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),

          padding: const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            30,
          ),

          children: [

            // =================================================
            // WELCOME
            // =================================================

            Text(
              strings.welcomeBack,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              language.isIndonesian
                  ? 'Siap untuk melanjutkan pembelajaran hari ini?'
                  : 'Ready to continue your learning today?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 22),

            // =================================================
            // QUICK ACTIONS
            // =================================================

            Row(
              children: [

                Expanded(
                  child: _buildActionCard(
                    context: context,
                    icon: Icons.menu_book_rounded,
                    title: strings.courses,
                    subtitle: language.isIndonesian
                        ? 'Lihat kursus'
                        : 'View courses',
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.courses,
                      );
                    },
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _buildActionCard(
                    context: context,
                    icon: Icons.assignment_outlined,
                    title: strings.assignments,
                    subtitle: language.isIndonesian
                        ? 'Lihat tugas'
                        : 'View assignments',
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.home,
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // =================================================
            // CONTINUE LEARNING
            // =================================================

            _buildSectionHeader(
              context,
              title: strings.continueLearning,
              actionText: strings.seeAll,
              onAction: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.courses,
                );
              },
            ),

            const SizedBox(height: 12),

            _buildContinueCard(
              context: context,
              strings: strings,
              language: language,
            ),

            const SizedBox(height: 28),

            // =================================================
            // YOUR PROGRESS
            // =================================================

            Text(
              strings.yourProgress,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 12),

            _buildProgressCard(
              context,
              strings,
              language,
            ),

            const SizedBox(height: 28),

            // =================================================
            // PROFILE
            // =================================================

            _buildProfileCard(
              context,
              strings,
              language,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // ACTION CARD
  // =========================================================

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(18),

      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),

        child: Container(
          padding: const EdgeInsets.all(15),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),

            border: Border.all(
              color: colorScheme.outline,
            ),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  theme.brightness == Brightness.dark
                      ? 0.18
                      : 0.04,
                ),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Container(
                width: 42,
                height: 42,

                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),

                child: Icon(
                  icon,
                  color: colorScheme.primary,
                  size: 21,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,

                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,

                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // SECTION HEADER
  // =========================================================

  Widget _buildSectionHeader(
      BuildContext context, {
        required String title,
        required String actionText,
        required VoidCallback onAction,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,

            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
        ),

        TextButton(
          onPressed: onAction,
          child: Text(actionText),
        ),
      ],
    );
  }

  // =========================================================
  // CONTINUE CARD
  // =========================================================

  Widget _buildContinueCard({
    required BuildContext context,
    required AppStrings strings,
    required LanguageController language,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(20),

      child: InkWell(
        borderRadius: BorderRadius.circular(20),

        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.courses,
          );
        },

        child: Container(
          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),

            border: Border.all(
              color: colorScheme.outline,
            ),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  theme.brightness == Brightness.dark
                      ? 0.18
                      : 0.04,
                ),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),

          child: Row(
            children: [

              Container(
                width: 62,
                height: 62,

                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),

                child: Icon(
                  Icons.play_arrow_rounded,
                  color: colorScheme.primary,
                  size: 30,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [

                    Text(
                      language.isIndonesian
                          ? 'Flutter untuk Pemula'
                          : 'Flutter for Beginners',

                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,

                      style:
                      theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      language.isIndonesian
                          ? 'Lanjutkan pelajaran terakhir'
                          : 'Continue your last lesson',

                      style:
                      theme.textTheme.bodySmall?.copyWith(
                        color:
                        colorScheme.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 10),

                    ClipRRect(
                      borderRadius:
                      BorderRadius.circular(99),

                      child: LinearProgressIndicator(
                        value: 0.65,
                        minHeight: 6,

                        backgroundColor:
                        colorScheme
                            .surfaceContainerHighest,

                        valueColor:
                        AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      '65%',

                      style:
                      theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // PROGRESS CARD
  // =========================================================

  Widget _buildProgressCard(
      BuildContext context,
      AppStrings strings,
      LanguageController language,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),

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
                  : 0.04,
            ),
            blurRadius: 12,
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
                width: 44,
                height: 44,

                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),

                child: Icon(
                  Icons.insights_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  language.isIndonesian
                      ? 'Kemajuan Kursus'
                      : 'Course Progress',

                  style:
                  theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),

              Text(
                '65%',

                style:
                theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(99),

            child: LinearProgressIndicator(
              value: 0.65,
              minHeight: 8,

              backgroundColor:
              colorScheme.surfaceContainerHighest,

              valueColor:
              AlwaysStoppedAnimation<Color>(
                colorScheme.primary,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,

            children: [

              Text(
                language.isIndonesian
                    ? '3 dari 5 pelajaran'
                    : '3 of 5 lessons',

                style:
                theme.textTheme.bodySmall?.copyWith(
                  color:
                  colorScheme.onSurfaceVariant,
                ),
              ),

              Text(
                strings.keepGoing,

                style:
                theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // PROFILE CARD
  // =========================================================

  Widget _buildProfileCard(
      BuildContext context,
      AppStrings strings,
      LanguageController language,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(20),

      child: InkWell(
        borderRadius: BorderRadius.circular(20),

        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.settings,
          );
        },

        child: Container(
          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
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
                  shape: BoxShape.circle,

                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.secondary,
                    ],
                  ),
                ),

                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [

                    Text(
                      'Kasun Udara',

                      style:
                      theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      language.isIndonesian
                          ? 'Lihat pengaturan aplikasi'
                          : 'View application settings',

                      style:
                      theme.textTheme.bodySmall?.copyWith(
                        color:
                        colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}