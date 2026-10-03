import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreatePasswordScreen extends StatefulWidget {
  const CreatePasswordScreen({super.key});

  @override
  State<CreatePasswordScreen> createState() =>
      _CreatePasswordScreenState();
}

class _CreatePasswordScreenState
    extends State<CreatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'User tidak ditemukan. Silakan login kembali.',
        isError: true,
      );
      return;
    }

    if (user.email == null || user.email!.isEmpty) {
      _showMessage(
        'Akun ini tidak memiliki email.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _passwordController.text.trim(),
      );

      await user.linkWithCredential(credential);

      await user.reload();

      if (!mounted) return;

      _showMessage(
        'Password berhasil dibuat.',
      );

      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'provider-already-linked':
          message =
          'Password untuk akun ini sudah terhubung.';
          break;

        case 'credential-already-in-use':
          message =
          'Email tersebut sudah digunakan oleh akun lain.';
          break;

        case 'email-already-in-use':
          message =
          'Email tersebut sudah digunakan oleh akun lain.';
          break;

        case 'weak-password':
          message =
          'Password terlalu lemah. Gunakan minimal 6 karakter.';
          break;

        case 'requires-recent-login':
          message =
          'Sesi login sudah terlalu lama. Silakan login kembali dengan Google lalu coba lagi.';
          break;

        case 'network-request-failed':
          message =
          'Tidak ada koneksi internet. Silakan coba lagi.';
          break;

        default:
          message =
              e.message ?? 'Gagal membuat password.';
      }

      _showMessage(
        message,
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Terjadi kesalahan. Silakan coba lagi.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Create Password',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
      ),

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
            // ICON
            // =================================================

            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 36,
                  color: colorScheme.primary,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // =================================================
            // TITLE
            // =================================================

            Center(
              child: Text(
                'Create Your Password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
            ),

            const SizedBox(height: 8),

            Center(
              child: Text(
                'Create a password so you can also sign in using your email and password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // =================================================
            // EMAIL
            // =================================================

            Text(
              'Email',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.outline,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.email_outlined,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user?.email ?? '-',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // =================================================
            // FORM
            // =================================================

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Password',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction:
                    TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword =
                            !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons
                              .visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty) {
                        return 'Password wajib diisi';
                      }

                      if (value.length < 6) {
                        return 'Password minimal 6 karakter';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  Text(
                    'Confirm Password',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextFormField(
                    controller:
                    _confirmPasswordController,
                    obscureText:
                    _obscureConfirmPassword,
                    textInputAction:
                    TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_isLoading) {
                        _createPassword();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Confirm your password',
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword =
                            !_obscureConfirmPassword;
                          });
                        },
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons
                              .visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty) {
                        return 'Konfirmasi password wajib diisi';
                      }

                      if (value !=
                          _passwordController.text) {
                        return 'Password tidak sama';
                      }

                      return null;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // =================================================
            // CREATE PASSWORD BUTTON
            // =================================================

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed:
                _isLoading ? null : _createPassword,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2.5,
                  ),
                )
                    : const Text(
                  'Create Password',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // =================================================
            // INFORMATION
            // =================================================

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Setidaknya gunakan 6 karakter. Setelah password dibuat, akun ini dapat digunakan untuk login menggunakan Google maupun email dan password.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color:
                        colorScheme.onSurfaceVariant,
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
}