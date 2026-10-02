import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../app_strings.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _soundEffects = true;
  bool _learningReminder = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // =====================================================
    // LANGUAGE
    // =====================================================

    final language = LanguageScope.of(context);
    final strings = AppStrings(language);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // ===================================================
      // APP BAR
      // ===================================================

      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,

        title: Text(
          strings.settings,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
      ),

      // ===================================================
      // BODY
      // ===================================================

      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),

          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            30,
          ),

          children: [
            // =================================================
            // PREFERENCES
            // =================================================

            _sectionTitle(
              context,
              strings.preferences,
            ),

            const SizedBox(height: 10),

            // =================================================
            // NOTIFICATIONS
            // =================================================

            _buildSettingCard(
              context: context,
              icon: Icons.notifications_none_rounded,
              title: strings.notifications,

              subtitle: _notifications
                  ? strings.notificationsEnabled
                  : strings.notificationsDisabled,

              trailing: Switch(
                value: _notifications,

                onChanged: (value) {
                  setState(() {
                    _notifications = value;
                  });
                },
              ),
            ),

            // =================================================
            // DARK MODE
            // =================================================

            _buildSettingCard(
              context: context,
              icon: Icons.dark_mode_outlined,

              title: strings.darkMode,

              subtitle: themeController.isDarkMode
                  ? strings.darkModeEnabled
                  : strings.lightModeEnabled,

              trailing: Switch(
                value: themeController.isDarkMode,

                onChanged: (value) {
                  themeController.setDarkMode(value);

                  setState(() {});

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,

                      content: Text(
                        value
                            ? strings.darkModeEnabled
                            : strings.lightModeEnabled,
                      ),
                    ),
                  );
                },
              ),
            ),

            // =================================================
            // SOUND EFFECTS
            // =================================================

            _buildSettingCard(
              context: context,
              icon: Icons.volume_up_outlined,

              title: strings.soundEffects,

              subtitle: _soundEffects
                  ? strings.soundEnabled
                  : strings.soundDisabled,

              trailing: Switch(
                value: _soundEffects,

                onChanged: (value) {
                  setState(() {
                    _soundEffects = value;
                  });
                },
              ),
            ),

            // =================================================
            // LEARNING REMINDER
            // =================================================

            _buildSettingCard(
              context: context,
              icon: Icons.alarm_outlined,

              title: strings.learningReminder,

              subtitle: _learningReminder
                  ? strings.reminderEnabled
                  : strings.reminderDisabled,

              trailing: Switch(
                value: _learningReminder,

                onChanged: (value) {
                  setState(() {
                    _learningReminder = value;
                  });
                },
              ),
            ),

            const SizedBox(height: 28),

            // =================================================
            // GENERAL
            // =================================================

            _sectionTitle(
              context,
              strings.general,
            ),

            const SizedBox(height: 10),

            // =================================================
            // LANGUAGE
            // =================================================

            _buildSettingCard(
              context: context,
              icon: Icons.language_rounded,

              title: strings.language,

              subtitle: language.isIndonesian
                  ? strings.indonesian
                  : strings.english,

              trailing: Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),

              onTap: _showLanguageDialog,
            ),

            // =================================================
            // ABOUT
            // =================================================

            _buildSettingCard(
              context: context,
              icon: Icons.info_outline_rounded,

              title: strings.about,

              subtitle: strings.version,

              trailing: Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),

              onTap: _showAboutDialog,
            ),

            const SizedBox(height: 28),

            // =================================================
            // ACCOUNT
            // =================================================

            _sectionTitle(
              context,
              strings.account,
            ),

            const SizedBox(height: 10),

            // =================================================
            // LOGOUT
            // =================================================

            _buildSettingCard(
              context: context,
              icon: Icons.logout_rounded,

              title: strings.logout,

              subtitle: strings.logoutSubtitle,

              iconColor: const Color(0xFFDC2626),

              onTap: () {
                _showLogoutDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // SECTION TITLE
  // =========================================================

  Widget _sectionTitle(
      BuildContext context,
      String title,
      ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Text(
      title,

      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  // =========================================================
  // SETTING CARD
  // =========================================================

  Widget _buildSettingCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final actualIconColor =
        iconColor ?? colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      decoration: BoxDecoration(
        color: colorScheme.surface,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(
          color: colorScheme.outline,
        ),
      ),

      child: ListTile(
        onTap: onTap,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 5,
        ),

        leading: Container(
          width: 44,
          height: 44,

          decoration: BoxDecoration(
            color: actualIconColor.withOpacity(0.10),

            borderRadius: BorderRadius.circular(13),
          ),

          child: Icon(
            icon,
            color: actualIconColor,
            size: 22,
          ),
        ),

        title: Text(
          title,

          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: colorScheme.onSurface,
          ),
        ),

        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),

          child: Text(
            subtitle,

            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        trailing: trailing,
      ),
    );
  }

  // =========================================================
  // LANGUAGE DIALOG
  // =========================================================

  void _showLanguageDialog() {
    final language = LanguageScope.of(context);
    final strings = AppStrings(language);

    showDialog(
      context: context,

      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          backgroundColor: colorScheme.surface,

          title: Text(
            strings.selectLanguage,

            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              // =================================================
              // ENGLISH
              // =================================================

              RadioListTile<String>(
                value: 'en',

                groupValue: language.locale.languageCode,

                activeColor: colorScheme.primary,

                title: Text(
                  strings.english,

                  style: TextStyle(
                    color: colorScheme.onSurface,
                  ),
                ),

                onChanged: (value) {
                  if (value == null) return;

                  language.setLanguage(value);

                  Navigator.pop(dialogContext);
                },
              ),

              // =================================================
              // INDONESIAN
              // =================================================

              RadioListTile<String>(
                value: 'id',

                groupValue: language.locale.languageCode,

                activeColor: colorScheme.primary,

                title: Text(
                  'Bahasa Indonesia',

                  style: TextStyle(
                    color: colorScheme.onSurface,
                  ),
                ),

                onChanged: (value) {
                  if (value == null) return;

                  language.setLanguage(value);

                  Navigator.pop(dialogContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // ABOUT DIALOG
  // =========================================================

  void _showAboutDialog() {
    final language = LanguageScope.of(context);
    final strings = AppStrings(language);

    showDialog(
      context: context,

      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          backgroundColor: colorScheme.surface,

          title: Text(
            strings.about,

            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Text(
                'LMS App',

                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                strings.aboutDescription,

                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                strings.version,

                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },

              child: Text(
                strings.close,
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // LOGOUT DIALOG
  // =========================================================

  void _showLogoutDialog(BuildContext context) {
    final language = LanguageScope.of(context);
    final strings = AppStrings(language);

    showDialog(
      context: context,

      builder: (dialogContext) {
        final colorScheme =
            Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          backgroundColor: colorScheme.surface,

          title: Text(
            strings.logout,

            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),

          content: Text(
            strings.logoutQuestion,

            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },

              child: Text(
                strings.cancel,
              ),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                      (route) => false,
                );
              },

              child: Text(
                strings.logout,
              ),
            ),
          ],
        );
      },
    );
  }
}