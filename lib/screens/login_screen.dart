
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _googleLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // PESAN LOGIN
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  // ============================================================
  // MEMBUAT PROFIL SISWA BARU UNTUK GOOGLE SIGN-IN
  // Profil yang sudah ada tidak akan ditimpa.
  // ============================================================

  Future<void> _ensureUserProfile(User user) async {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    final userDoc = await userRef.get();

    if (userDoc.exists) return;

    await userRef.set({
      'uid': user.uid,
      'name': user.displayName ?? '',
      'username': user.displayName ?? '',
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'phone': '',
      'gender': '',
      'birthDate': '',
      'address': '',
      'school': '',
      'className': '',
      'major': '',
      'nisn': '',
      'bio': '',
      'role': 'student',
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // LOGIN BERDASARKAN ROLE DAN STATUS AKUN
  //
  // createStudentIfMissing hanya digunakan untuk Google Sign-In
  // yang membuat akun siswa baru.
  // ============================================================

  Future<bool> _loginBasedOnRole(
      User user, {
        bool createStudentIfMissing = false,
      }) async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      var userDoc = await userRef.get();

      // Login email/password tidak boleh otomatis membuat
      // profil baru jika profil pengguna tidak ditemukan.
      if (!userDoc.exists && createStudentIfMissing) {
        await _ensureUserProfile(user);
        userDoc = await userRef.get();
      }

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();

        _showMessage(
          'Profil akun tidak ditemukan. '
              'Hubungi administrator sekolah.',
        );

        return false;
      }

      final data = userDoc.data();

      if (data == null) {
        await FirebaseAuth.instance.signOut();
        _showMessage('Data profil akun tidak valid.');
        return false;
      }

      // ----------------------------------------------------------
      // CEK STATUS AKUN
      // ----------------------------------------------------------

      if (data['active'] == false) {
        await FirebaseAuth.instance.signOut();

        _showMessage(
          'Akun kamu telah dinonaktifkan oleh administrator.',
        );

        return false;
      }

      final role = (data['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      debugPrint('========== LOGIN USER ==========');
      debugPrint('UID   : ${user.uid}');
      debugPrint('EMAIL : ${user.email}');
      debugPrint('ROLE  : $role');
      debugPrint('ACTIVE: ${data['active'] ?? true}');
      debugPrint('================================');

      if (!mounted) return false;

      // ----------------------------------------------------------
      // ADMIN
      // ----------------------------------------------------------

      if (role == 'admin') {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.admin,
              (route) => false,
        );

        return true;
      }

      // ----------------------------------------------------------
      // GURU
      // ----------------------------------------------------------

      if (role == 'teacher') {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.teacher,
              (route) => false,
        );

        return true;
      }

      // ----------------------------------------------------------
      // SISWA
      // ----------------------------------------------------------

      if (role == 'student') {
        _goToHome();
        return true;
      }

      // Role kosong atau tidak dikenal tidak boleh diarahkan
      // otomatis ke dashboard siswa.
      await FirebaseAuth.instance.signOut();

      _showMessage(
        'Role akun tidak valid. Hubungi administrator.',
      );

      return false;
    } catch (e) {
      debugPrint('Error memeriksa profil dan role: $e');

      // Jika status akun tidak dapat diverifikasi, jangan
      // melanjutkan ke dashboard.
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}

      _showMessage(
        'Gagal memverifikasi akun. '
            'Periksa koneksi internet lalu coba lagi.',
      );

      return false;
    }
  }

  // ============================================================
  // HOME
  // ============================================================

  void _goToHome() {
    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
          (route) => false,
    );
  }

  // ============================================================
  // LOGIN EMAIL / PASSWORD
  // ============================================================

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_loading || _googleLoading) return;

    setState(() => _loading = true);

    try {
      final credential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(code: 'user-not-found');
      }

      await _loginBasedOnRole(user);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
          message = 'Email atau password salah.';
          break;
        case 'user-not-found':
          message = 'Akun dengan email tersebut tidak ditemukan.';
          break;
        case 'invalid-email':
          message = 'Format email tidak valid.';
          break;
        case 'user-disabled':
          message = 'Akun ini telah dinonaktifkan.';
          break;
        case 'too-many-requests':
          message = 'Terlalu banyak percobaan. Coba lagi nanti.';
          break;
        case 'network-request-failed':
          message = 'Periksa koneksi internet kamu.';
          break;
        default:
          message = e.message ?? 'Login gagal. Silakan coba lagi.';
      }

      _showMessage(message);
    } catch (e) {
      _showMessage('Terjadi kesalahan saat login: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ============================================================
  // GOOGLE SIGN-IN
  // ============================================================

  Future<void> _signInWithGoogle() async {
    if (_googleLoading || _loading) return;

    setState(() => _googleLoading = true);

    try {
      final googleUser =
      await GoogleSignIn.instance.authenticate();

      final googleAuth = googleUser.authentication;

      final googleCredential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      try {
        final userCredential =
        await FirebaseAuth.instance.signInWithCredential(
          googleCredential,
        );

        final user = userCredential.user;

        if (user == null) {
          throw FirebaseAuthException(code: 'user-not-found');
        }

        await _loginBasedOnRole(
          user,
          createStudentIfMissing: true,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'account-exists-with-different-credential') {
          await _handleGoogleAccountLinking(
            googleCredential,
            googleUser.email,
          );
        } else {
          rethrow;
        }
      }
    } on GoogleSignInException catch (e) {
      if (!mounted) return;

      if (e.code == GoogleSignInExceptionCode.canceled) return;

      _showMessage(
        'Google Login gagal: ${e.description ?? e.code.name}',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'credential-already-in-use':
          message = 'Akun Google sudah terhubung ke akun lain.';
          break;
        case 'network-request-failed':
          message = 'Periksa koneksi internet kamu.';
          break;
        case 'user-disabled':
          message = 'Akun ini telah dinonaktifkan.';
          break;
        default:
          message = e.message ?? 'Google Login gagal.';
      }

      _showMessage(message);
    } catch (e) {
      _showMessage('Terjadi kesalahan saat Google Login: $e');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  // ============================================================
  // GOOGLE ACCOUNT LINKING
  // ============================================================

  Future<void> _handleGoogleAccountLinking(
      AuthCredential googleCredential,
      String googleEmail,
      ) async {
    if (!mounted) return;

    final passwordController = TextEditingController();

    try {
      final password = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          bool obscurePassword = true;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Account Already Exists'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email $googleEmail sudah terdaftar '
                          'menggunakan Email/Password.',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Masukkan password akun tersebut '
                          'untuk menghubungkan Google.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final value = passwordController.text;
                      if (value.isNotEmpty) {
                        Navigator.pop(dialogContext, value);
                      }
                    },
                    child: const Text('Hubungkan'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (password == null || password.isEmpty) return;

      // Login terlebih dahulu menggunakan email/password.
      final emailCredential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: googleEmail,
        password: password,
      );

      final user = emailCredential.user;

      if (user == null) {
        throw FirebaseAuthException(code: 'user-not-found');
      }

      // Periksa profil SEBELUM menghubungkan Google.
      // Akun nonaktif tidak boleh melanjutkan proses linking.
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        _showMessage(
          'Profil akun tidak ditemukan. Hubungi administrator.',
        );
        return;
      }

      final data = userDoc.data();

      if (data == null || data['active'] == false) {
        await FirebaseAuth.instance.signOut();
        _showMessage(
          'Akun kamu tidak aktif atau profilnya tidak valid.',
        );
        return;
      }

      await user.linkWithCredential(googleCredential);
      await user.reload();

      final updatedUser = FirebaseAuth.instance.currentUser;

      if (updatedUser == null) {
        throw FirebaseAuthException(code: 'user-not-found');
      }

      _showMessage('Google berhasil terhubung ke akun kamu.');

      await _loginBasedOnRole(updatedUser);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Password salah. Akun Google belum terhubung.';
          break;
        case 'credential-already-in-use':
          message = 'Akun Google sudah terhubung ke akun lain.';
          break;
        case 'provider-already-linked':
          message = 'Google sudah terhubung dengan akun ini.';
          break;
        case 'too-many-requests':
          message = 'Terlalu banyak percobaan. Coba lagi nanti.';
          break;
        case 'network-request-failed':
          message = 'Periksa koneksi internet kamu.';
          break;
        default:
          message = e.message ?? 'Gagal menghubungkan akun Google.';
      }

      _showMessage(message);
    } catch (e) {
      _showMessage('Gagal menghubungkan akun Google: $e');
    } finally {
      passwordController.dispose();
    }
  }

  // ============================================================
  // NAVIGASI
  // ============================================================

  void _openForgotPassword() {
    Navigator.pushNamed(context, AppRoutes.forgotPassword);
  }

  void _openSignup() {
    Navigator.pushNamed(context, AppRoutes.signup);
  }

  // ============================================================
  // UI LOGIN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
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
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 32,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: logoSize + 30,
                        height: logoSize + 30,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(28),
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
                          semanticLabel: 'LMS App Logo',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      'Welcome Back!',
                      style: textTheme.headlineLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Login to continue your learning journey',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // EMAIL
                    Text(
                      'Email Address',
                      style: textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'Enter your email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(
                          r'^[\w.-]+@([\w-]+\.)+[\w-]{2,}$',
                        ).hasMatch(email)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // PASSWORD
                    Text(
                      'Password',
                      style: textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_loading && !_googleLoading) {
                          _submit();
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 chars';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // REMEMBER ME / FORGOT PASSWORD
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _rememberMe,
                                  activeColor: colorScheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  onChanged: (_loading || _googleLoading)
                                      ? null
                                      : (value) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Flexible(
                                child: Text('Remember me'),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: (_loading || _googleLoading)
                              ? null
                              : _openForgotPassword,
                          child: const Text('Forgot Password?'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // LOGIN BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: (_loading || _googleLoading)
                            ? null
                            : _submit,
                        child: _loading
                            ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colorScheme.onPrimary,
                          ),
                        )
                            : const Text('Login'),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // DIVIDER
                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: colorScheme.outline),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          child: Text(
                            'OR',
                            style: textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: colorScheme.outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // GOOGLE BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: (_loading || _googleLoading)
                            ? null
                            : _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: colorScheme.outline,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _googleLoading
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                          ),
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Image.asset(
                                'assets/images/google_logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('Continue with Google'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // SIGN UP
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed: (_loading || _googleLoading)
                                ? null
                                : _openSignup,
                            child: const Text('Sign Up'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
