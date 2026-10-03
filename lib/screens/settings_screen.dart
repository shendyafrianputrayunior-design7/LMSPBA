import 'package:flutter/material.dart';

import '../app_routes.dart';
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
          'Settings',
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
              'Preferences',
            ),

            const SizedBox(height: 10),

            // =================================================
            // NOTIFICATIONS
            // =================================================

            _buildSettingCard(
              context: context,
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              subtitle: _notifications
                  ? 'Notifications enabled'
                  : 'Notifications disabled',

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
              title: 'Dark Mode',

              subtitle: themeController.isDarkMode
                  ? 'Dark mode enabled'
                  : 'Light mode enabled',

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
                            ? 'Dark mode enabled'
                            : 'Light mode enabled',
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
              title: 'Sound Effects',

              subtitle: _soundEffects
                  ? 'Sound effects enabled'
                  : 'Sound effects disabled',

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
              title: 'Learning Reminder',

              subtitle: _learningReminder
                  ? 'Learning reminder enabled'
                  : 'Learning reminder disabled',

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
              'General',
            ),

            const SizedBox(height: 10),

            // =================================================
            // ABOUT
            // =================================================

            _buildSettingCard(
              context: context,
              icon: Icons.info_outline_rounded,
              title: 'About',
              subtitle: 'Version 1.0.0',

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
              'Account',
            ),

            const SizedBox(height: 10),

            // =================================================
            // SECURITY
            // =================================================

            _buildSettingCard(
              context: context,
              icon: Icons.security_outlined,
              title: 'Security',
              subtitle: 'Password and account security',

              trailing: Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),

              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.security,
                );
              },
            ),

            // =================================================
            // LOGOUT
            // =================================================

            _buildSettingCard(
              context: context,
              icon: Icons.logout_rounded,
              title: 'Logout',
              subtitle: 'Sign out from your account',
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
  // ABOUT DIALOG
  // =========================================================

  void _showAboutDialog() {
    showDialog(
      context: context,

      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          backgroundColor: colorScheme.surface,

          title: Text(
            'About',

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
              const Text(
                'LMS App',

                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'A simple Learning Management System application built with Flutter.',

                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Version 1.0.0',

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

              child: const Text(
                'Close',
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
    showDialog(
      context: context,

      builder: (dialogContext) {
        final colorScheme =
            Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          backgroundColor: colorScheme.surface,

          title: Text(
            'Logout',

            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),

          content: Text(
            'Are you sure you want to logout?',

            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },

              child: const Text(
                'Cancel',
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

              child: const Text(
                'Logout',
              ),
            ),
          ],
        );
      },
    );
  }
}