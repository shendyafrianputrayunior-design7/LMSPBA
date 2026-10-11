
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

  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  bool get _hasPassword {
    final user = FirebaseAuth.instance.currentUser;

    return user?.providerData.any(
          (provider) => provider.providerId == 'password',
    ) ??
        false;
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createPassword() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Pengguna tidak ditemukan. Silakan login kembali.',
        isError: true,
      );
      return;
    }

    final email = user.email;

    if (email == null || email.isEmpty) {
      _showMessage(
        'Akun ini tidak memiliki email.',
        isError: true,
      );
      return;
    }

    final hasPassword = _hasPassword;

    setState(() {
      _isLoading = true;
    });

    try {
      if (hasPassword) {
        // Verifikasi password lama terlebih dahulu.
        final credential = EmailAuthProvider.credential(
          email: email,
          password: _currentPasswordController.text,
        );

        await user.reauthenticateWithCredential(credential);

        // Password lama benar, perbarui dengan password baru.
        await user.updatePassword(
          _passwordController.text,
        );
      } else {
        // Tambahkan provider email-password untuk akun Google.
        final credential = EmailAuthProvider.credential(
          email: email,
          password: _passwordController.text,
        );

        await user.linkWithCredential(credential);
      }

      await FirebaseAuth.instance.currentUser?.reload();

      if (!mounted) return;

      _showMessage(
        hasPassword
            ? 'Password berhasil diperbarui.'
            : 'Password berhasil dibuat.',
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
        case 'wrong-password':
        case 'invalid-credential':
          message =
          'Password lama salah. Silakan periksa kembali.';
          break;

        case 'weak-password':
          message =
          'Password terlalu lemah. Gunakan minimal 6 karakter.';
          break;

        case 'requires-recent-login':
          message =
          'Sesi login sudah terlalu lama. Silakan login ulang, lalu coba kembali.';
          break;

        case 'provider-already-linked':
          message =
          'Password sudah terhubung dengan akun ini. Buka kembali halaman ini.';
          break;

        case 'credential-already-in-use':
        case 'email-already-in-use':
          message =
          'Email tersebut sudah digunakan oleh akun lain.';
          break;

        case 'network-request-failed':
          message =
          'Tidak ada koneksi internet. Silakan coba lagi.';
          break;

        case 'too-many-requests':
          message =
          'Terlalu banyak percobaan. Silakan coba lagi nanti.';
          break;

        case 'user-mismatch':
          message =
          'Kredensial tidak sesuai dengan akun yang sedang digunakan.';
          break;

        default:
          message =
              e.message ?? 'Gagal menyimpan password.';
      }

      _showMessage(message, isError: true);
    } catch (_) {
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
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : null,
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          textInputAction: textInputAction,
          enabled: !_isLoading,
          autocorrect: false,
          enableSuggestions: false,
          onFieldSubmitted: onFieldSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
            ),
            suffixIcon: IconButton(
              onPressed: _isLoading
                  ? null
                  : onToggleVisibility,
              icon: Icon(
                obscureText
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final hasPassword = _hasPassword;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          hasPassword ? 'Change Password' : 'Create Password',
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
            Center(
              child: Text(
                hasPassword
                    ? 'Change Your Password'
                    : 'Create Your Password',
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
                hasPassword
                    ? 'Verify your current password before setting a new one.'
                    : 'Create a password so you can also sign in using your email and password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // EMAIL
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
            const SizedBox(height: 24),

            // PASSWORD FORM
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PASSWORD LAMA
                  if (hasPassword) ...[
                    _buildPasswordField(
                      label: 'Current Password',
                      hint: 'Enter your current password',
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrentPassword,
                      onToggleVisibility: () {
                        setState(() {
                          _obscureCurrentPassword =
                          !_obscureCurrentPassword;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password lama wajib diisi';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  // PASSWORD BARU
                  _buildPasswordField(
                    label: 'New Password',
                    hint: 'Enter your new password',
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    onToggleVisibility: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password baru wajib diisi';
                      }

                      if (value.length < 6) {
                        return 'Password minimal 6 karakter';
                      }

                      if (hasPassword &&
                          value == _currentPasswordController.text) {
                        return 'Password baru harus berbeda dari password lama';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // KONFIRMASI PASSWORD
                  _buildPasswordField(
                    label: 'Confirm New Password',
                    hint: 'Confirm your new password',
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    onToggleVisibility: () {
                      setState(() {
                        _obscureConfirmPassword =
                        !_obscureConfirmPassword;
                      });
                    },
                    onFieldSubmitted: (_) {
                      if (!_isLoading) {
                        _createPassword();
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Konfirmasi password wajib diisi';
                      }

                      if (value != _passwordController.text) {
                        return 'Password baru tidak sama';
                      }

                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createPassword,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                  ),
                )
                    : Text(
                  hasPassword
                      ? 'Update Password'
                      : 'Create Password',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // INFORMATION
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasPassword
                          ? 'Masukkan password lama yang benar sebelum mengubah password. Gunakan minimal 6 karakter untuk password baru.'
                          : 'Gunakan minimal 6 karakter. Setelah password dibuat, akun dapat digunakan untuk login dengan Google maupun email dan password.',
                      style: TextStyle(
                        fontSize: 12,
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
}
