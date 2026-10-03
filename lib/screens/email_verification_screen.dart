import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_routes.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends State<EmailVerificationScreen> {
  bool _loading = false;
  bool _resending = false;

  // ============================================================
  // CHECK EMAIL VERIFICATION
  // ============================================================

  Future<void> _checkVerification() async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'User tidak ditemukan.',
        );
      }

      // Refresh status user dari Firebase
      await user.reload();

      final refreshedUser =
          FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'User tidak ditemukan.',
        );
      }

      if (!refreshedUser.emailVerified) {
        if (!mounted) return;

        setState(() {
          _loading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email belum diverifikasi. Silakan buka link verifikasi di email kamu terlebih dahulu.',
            ),
          ),
        );

        return;
      }

      // ==========================================================
      // EMAIL SUDAH DIVERIFIKASI
      // ==========================================================

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Gagal memeriksa verifikasi email.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Terjadi kesalahan saat memeriksa verifikasi email.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // RESEND VERIFICATION EMAIL
  // ============================================================

  Future<void> _resendVerificationEmail() async {
    if (_resending) return;

    setState(() {
      _resending = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'User tidak ditemukan.',
        );
      }

      if (user.emailVerified) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email kamu sudah diverifikasi.',
            ),
          ),
        );

        return;
      }

      await user.sendEmailVerification();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email verifikasi telah dikirim ulang.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message =
          e.message ?? 'Gagal mengirim email verifikasi.';

      if (e.code == 'too-many-requests') {
        message =
        'Terlalu banyak permintaan. Silakan tunggu beberapa saat sebelum mencoba lagi.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gagal mengirim email verifikasi.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _resending = false;
        });
      }
    }
  }

  // ============================================================
  // BACK TO LOGIN
  // ============================================================

  Future<void> _backToLogin() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final isDark =
        theme.brightness == Brightness.dark;

    final size = MediaQuery.sizeOf(context);

    final horizontalPadding =
    (size.width * 0.06).clamp(20.0, 32.0);

    final logoSize =
    (size.shortestSide * 0.22).clamp(90.0, 130.0);

    return Scaffold(
      backgroundColor: colorScheme.surface,

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 480,
            ),

            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 32,
              ),

              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [

                  // =====================================================
                  // LOGO
                  // =====================================================

                  Center(
                    child: Container(
                      width: logoSize + 30,
                      height: logoSize + 30,
                      padding: const EdgeInsets.all(15),

                      decoration: BoxDecoration(
                        color: colorScheme
                            .surfaceContainerHighest,

                        borderRadius:
                        BorderRadius.circular(28),

                        border: Border.all(
                          color: colorScheme.outline,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              isDark ? 0.20 : 0.06,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),

                      child: Image.asset(
                        'assets/images/logo-bgr.png',
                        semanticLabel:
                        'LMS App Logo',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // =====================================================
                  // TITLE
                  // =====================================================

                  Text(
                    'Verify Your Email',
                    style:
                    textTheme.headlineLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'We have sent a verification link to your email address.',
                    style:
                    textTheme.bodyMedium?.copyWith(
                      color:
                      colorScheme.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // =====================================================
                  // EMAIL
                  // =====================================================

                  Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.all(14),

                    decoration: BoxDecoration(
                      color: colorScheme
                          .surfaceContainerHighest,

                      borderRadius:
                      BorderRadius.circular(12),
                    ),

                    child: Row(
                      children: [

                        Icon(
                          Icons.email_outlined,
                          color:
                          colorScheme.primary,
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            widget.email,
                            style: textTheme
                                .bodyMedium
                                ?.copyWith(
                              color:
                              colorScheme.onSurface,
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // =====================================================
                  // INFORMATION
                  // =====================================================

                  Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.all(16),

                    decoration: BoxDecoration(
                      color: colorScheme.primary
                          .withOpacity(0.08),

                      borderRadius:
                      BorderRadius.circular(14),

                      border: Border.all(
                        color: colorScheme.primary
                            .withOpacity(0.20),
                      ),
                    ),

                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [

                        Icon(
                          Icons.mark_email_read_outlined,
                          color:
                          colorScheme.primary,
                          size: 24,
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            'Buka email kamu dan tekan link verifikasi yang dikirim oleh Firebase. Setelah itu kembali ke aplikasi dan tekan tombol "Check Verification".',
                            style: textTheme
                                .bodyMedium
                                ?.copyWith(
                              color: colorScheme
                                  .onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // =====================================================
                  // CHECK VERIFICATION
                  // =====================================================

                  SizedBox(
                    width: double.infinity,
                    height: 54,

                    child: ElevatedButton(
                      onPressed:
                      _loading
                          ? null
                          : _checkVerification,

                      child: AnimatedSwitcher(
                        duration:
                        const Duration(
                          milliseconds: 200,
                        ),

                        child: _loading
                            ? SizedBox(
                          key:
                          const ValueKey(
                            'checking',
                          ),

                          width: 22,
                          height: 22,

                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color:
                            colorScheme
                                .onPrimary,
                          ),
                        )
                            : const Text(
                          'Check Verification',
                          key:
                          ValueKey(
                            'check',
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // =====================================================
                  // RESEND EMAIL
                  // =====================================================

                  Center(
                    child: Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,

                      children: [

                        Text(
                          "Didn't receive the email?",
                          style: textTheme
                              .bodyMedium
                              ?.copyWith(
                            color: colorScheme
                                .onSurfaceVariant,
                          ),
                        ),

                        TextButton(
                          onPressed:
                          _resending
                              ? null
                              : _resendVerificationEmail,

                          child: _resending
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                            CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                              : const Text(
                            'Resend',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // =====================================================
                  // BACK TO LOGIN
                  // =====================================================

                  Center(
                    child: TextButton.icon(
                      onPressed:
                      _loading ||
                          _resending
                          ? null
                          : _backToLogin,

                      icon: const Icon(
                        Icons.arrow_back,
                      ),

                      label: const Text(
                        'Back to Login',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}