
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_routes.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _hasPassword = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkPasswordProvider();
  }

  // =========================================================
  // CHECK PASSWORD PROVIDER
  // =========================================================

  Future<void> _checkPasswordProvider() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _hasPassword = false;
        _isChecking = false;
      });
      return;
    }

    try {
      // Perbarui data provider dari Firebase.
      await user.reload();

      final refreshedUser = auth.currentUser;

      final hasPassword =
          refreshedUser?.providerData.any(
                (provider) => provider.providerId == 'password',
          ) ??
              false;

      if (!mounted) return;

      setState(() {
        _hasPassword = hasPassword;
        _isChecking = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isChecking = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to check account security status.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // =========================================================
  // OPEN CREATE / CHANGE PASSWORD PAGE
  // =========================================================

  Future<void> _openPasswordPage() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Please sign in again to continue.');
      return;
    }

    final result = await Navigator.pushNamed(
      context,
      AppRoutes.createPassword,
    );

    if (!mounted) return;

    if (result == true) {
      await _checkPasswordProvider();
    }
  }

  // =========================================================
  // SHOW MESSAGE
  // =========================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // APP BAR
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Security',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
      ),

      // BODY
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          children: [
            Text(
              'Account Security',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 10),

            // EMAIL CARD
            _buildSecurityCard(
              context: context,
              icon: Icons.email_outlined,
              title: 'Email',
              subtitle: user?.email ?? 'No email',
              showArrow: false,
            ),

            // PASSWORD CARD
            _buildSecurityCard(
              context: context,
              icon: Icons.lock_outline_rounded,
              title: 'Password',
              subtitle: _isChecking
                  ? 'Checking password status...'
                  : _hasPassword
                  ? 'Password is already set'
                  : 'Password has not been set',
              showArrow: !_isChecking,
              onTap: _isChecking ? null : _openPasswordPage,
              trailing: _isChecking
                  ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
                  : null,
            ),

            const SizedBox(height: 28),

            // INFORMATION CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isChecking
                          ? 'Checking the sign-in methods available for your account.'
                          : _hasPassword
                          ? 'Your account can use email and password or Google to sign in, depending on the linked sign-in methods.'
                          : 'Set a password to add email and password as a sign-in method alongside Google.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // SECURITY CARD
  // =========================================================

  Widget _buildSecurityCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool showArrow,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
            color: colorScheme.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: colorScheme.primary,
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
        trailing: trailing ??
            (showArrow
                ? Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            )
                : null),
      ),
    );
  }
}
