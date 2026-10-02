import 'package:flutter/material.dart';
import '../app_routes.dart';
import '../widgets/app_bar_simple.dart';
import '../ui/app_spacing.dart';
import '../ui/layout.dart';
import '../ui/status_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editing = false;

  final _nameController = TextEditingController(
    text: 'Kasun Udara',
  );

  final _bioController = TextEditingController(
    text: 'Final-year Software Engineering student.',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final statusColors =
    theme.extension<StatusColors>();

    final completedCourses = [
      'Flutter for Beginners',
      'Dart Programming',
      'UI Design Basics',
    ];

    final avatarLetter = _nameController.text.isNotEmpty
        ? _nameController.text[0].toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: const AppBarSimple(
        title: 'Profile',
      ),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: AppSpacing.screenPadding(context),
        child: AppLayout.centeredConstrained(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // =========================================================
              // PROFILE HEADER
              // =========================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(22),
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
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [

                    // =================================================
                    // AVATAR
                    // =================================================

                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          avatarLetter,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // =================================================
                    // NORMAL MODE
                    // =================================================

                    if (!_editing) ...[
                      Text(
                        _nameController.text,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        _bioController.text,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _editing = true;
                            });
                          },
                          icon: const Icon(
                            Icons.edit_rounded,
                          ),
                          label: const Text(
                            'Edit Profile',
                          ),
                        ),
                      ),
                    ]

                    // =================================================
                    // EDIT MODE
                    // =================================================

                    else ...[
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: _bioController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Bio',
                          prefixIcon: Icon(
                            Icons.description_outlined,
                          ),
                          alignLabelWithHint: true,
                        ),
                      ),

                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _editing = false;
                            });
                          },
                          icon: const Icon(
                            Icons.check_rounded,
                          ),
                          label: const Text(
                            'Save Profile',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // =========================================================
              // LEARNING OVERVIEW
              // =========================================================

              Text(
                'Learning Overview',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context: context,
                      icon: Icons.menu_book_rounded,
                      value: '3',
                      label: 'Completed',
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _buildStatCard(
                      context: context,
                      icon: Icons.school_rounded,
                      value: '3',
                      label: 'Courses',
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _buildStatCard(
                      context: context,
                      icon: Icons.task_alt_rounded,
                      value: '3',
                      label: 'Assignments',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // =========================================================
              // COMPLETED COURSES
              // =========================================================

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Completed Courses',
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
                      '${completedCourses.length}',
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

              // =========================================================
              // COURSE LIST
              // =========================================================

              ...completedCourses.map(
                    (title) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colorScheme.outline,
                    ),
                  ),
                  child: Row(
                    children: [

                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: statusColors?.submittedFg ??
                              Colors.green.shade700,
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
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              'Course completed',
                              style: textTheme.bodySmall?.copyWith(
                                color:
                                colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // =========================================================
              // ACCOUNT
              // =========================================================

              Text(
                'Account',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 12),

              // =========================================================
              // SETTINGS
              // =========================================================

              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.outline,
                  ),
                ),
                child: ListTile(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.settings,
                    );
                  },

                  contentPadding:
                  const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),

                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      color: colorScheme.primary,
                    ),
                  ),

                  title: Text(
                    'Settings',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),

                  subtitle: Text(
                    'Manage application preferences',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              // =========================================================
              // LOGOUT
              // =========================================================

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
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [

                    Row(
                      children: [

                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius:
                            BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: Colors.redAccent,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sign out',
                                style:
                                textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),

                              const SizedBox(height: 3),

                              Text(
                                'Sign out from this account',
                                style:
                                textTheme.bodySmall?.copyWith(
                                  color:
                                  colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showLogoutDialog(context);
                        },

                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Colors.redAccent,
                        ),

                        label: const Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        style: OutlinedButton.styleFrom(
                          minimumSize:
                          const Size(0, 50),

                          side: const BorderSide(
                            color: Colors.redAccent,
                          ),

                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // STAT CARD
  // ===============================================================

  Widget _buildStatCard({
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
        vertical: 18,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outline,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: colorScheme.primary,
            size: 24,
          ),

          const SizedBox(height: 8),

          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            label,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // LOGOUT CONFIRMATION
  // ===============================================================

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

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
            'Are you sure you want to logout from this account?',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                      (route) => false,
                );
              },

              icon: const Icon(
                Icons.logout_rounded,
                size: 18,
              ),

              label: const Text(
                'Logout',
              ),
            ),
          ],
        );
      },
    );
  }
}