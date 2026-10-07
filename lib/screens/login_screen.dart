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
  // FIRESTORE USER PROFILE
  // ============================================================

  Future<void> _ensureUserProfile(User user) async {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    final userDoc = await userRef.get();

    // Hanya membuat profile jika benar-benar belum ada.
    // Profile yang sudah ada tidak akan ditimpa.
    if (!userDoc.exists) {
      await userRef.set({
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
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ============================================================
  // LOGIN BERDASARKAN ROLE
  // ============================================================

  Future<void> _loginBasedOnRole(User user) async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      final userDoc = await userRef.get();

      // ----------------------------------------------------------
      // PROFILE BELUM ADA
      // ----------------------------------------------------------

      if (!userDoc.exists) {
        await _ensureUserProfile(user);

        if (!mounted) return;

        _goToHome();
        return;
      }

      // ----------------------------------------------------------
      // AMBIL ROLE
      // ----------------------------------------------------------

      final data = userDoc.data();

      final role = (data?['role'] ?? 'student')
          .toString()
          .trim()
          .toLowerCase();

      debugPrint('========================================');
      debugPrint('LOGIN USER');
      debugPrint('UID   : ${user.uid}');
      debugPrint('EMAIL : ${user.email}');
      debugPrint('ROLE  : $role');
      debugPrint('========================================');

      if (!mounted) return;

      // ----------------------------------------------------------
      // ADMIN
      // ----------------------------------------------------------

      if (role == 'admin') {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.admin,
              (route) => false,
        );

        return;
      }

      // ----------------------------------------------------------
      // TEACHER / GURU
      // ----------------------------------------------------------

      if (role == 'teacher') {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.teacher,
              (route) => false,
        );

        return;
      }

      // ----------------------------------------------------------
      // STUDENT
      // ----------------------------------------------------------

      _goToHome();
    } catch (e) {
      debugPrint('Error cek role: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal membaca data akun: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // GO TO HOME
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_loading || _googleLoading) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // ----------------------------------------------------------
      // FIREBASE LOGIN
      // ----------------------------------------------------------

      final credential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
        );
      }

      // ----------------------------------------------------------
      // CEK ROLE
      // ----------------------------------------------------------

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
          message =
          'Terlalu banyak percobaan. Silakan coba lagi nanti.';
          break;

        case 'network-request-failed':
          message = 'Periksa koneksi internet kamu.';
          break;

        default:
          message = e.message ?? 'Login gagal. Silakan coba lagi.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Terjadi kesalahan saat login: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // GOOGLE LOGIN
  // ============================================================

  Future<void> _signInWithGoogle() async {
    if (_googleLoading || _loading) {
      return;
    }

    setState(() {
      _googleLoading = true;
    });

    try {
      // ----------------------------------------------------------
      // GOOGLE SIGN IN
      // ----------------------------------------------------------

      final GoogleSignInAccount googleUser =
      await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final googleCredential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      try {
        // --------------------------------------------------------
        // NORMAL GOOGLE LOGIN
        // --------------------------------------------------------

        final userCredential =
        await FirebaseAuth.instance.signInWithCredential(
          googleCredential,
        );

        final user = userCredential.user;

        if (user == null) {
          throw FirebaseAuthException(
            code: 'user-not-found',
          );
        }

        // Cek role setelah Google Login.
        await _loginBasedOnRole(user);
      } on FirebaseAuthException catch (e) {
        // --------------------------------------------------------
        // EMAIL SUDAH ADA DENGAN EMAIL/PASSWORD
        // --------------------------------------------------------

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

      if (e.code == GoogleSignInExceptionCode.canceled) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Google Login gagal: '
                '${e.description ?? e.code.name}',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'Google Login gagal.';

      switch (e.code) {
        case 'credential-already-in-use':
          message =
          'Akun Google tersebut sudah terhubung ke akun lain.';
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Terjadi kesalahan saat Login dengan Google: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _googleLoading = false;
        });
      }
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

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool obscurePassword = true;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Account Already Exists',
              ),
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
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                      ),
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
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = passwordController.text;

                    if (value.isNotEmpty) {
                      Navigator.pop(
                        context,
                        value,
                      );
                    }
                  },
                  child: const Text('Connect'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();

    if (password == null || password.isEmpty) {
      return;
    }

    try {
      // ----------------------------------------------------------
      // LOGIN EMAIL/PASSWORD
      // ----------------------------------------------------------

      final emailCredential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: googleEmail,
        password: password,
      );

      final user = emailCredential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
        );
      }

      // ----------------------------------------------------------
      // LINK GOOGLE KE AKUN YANG SAMA
      // ----------------------------------------------------------

      await user.linkWithCredential(
        googleCredential,
      );

      // ----------------------------------------------------------
      // REFRESH USER
      // ----------------------------------------------------------

      await user.reload();

      final updatedUser =
          FirebaseAuth.instance.currentUser;

      if (updatedUser == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Google berhasil terhubung ke akun kamu.',
          ),
        ),
      );

      // ----------------------------------------------------------
      // CEK ROLE
      // ----------------------------------------------------------

      await _loginBasedOnRole(updatedUser);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message =
          'Password salah. Akun Google belum terhubung.';
          break;

        case 'credential-already-in-use':
          message =
          'Akun Google tersebut sudah terhubung '
              'ke akun lain.';
          break;

        case 'provider-already-linked':
          message =
          'Google sudah terhubung dengan akun ini.';
          break;

        case 'too-many-requests':
          message =
          'Terlalu banyak percobaan. Silakan coba lagi nanti.';
          break;

        case 'network-request-failed':
          message = 'Periksa koneksi internet kamu.';
          break;

        default:
          message =
              e.message ??
                  'Gagal menghubungkan akun Google.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghubungkan akun Google: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  void _openForgotPassword() {
    Navigator.pushNamed(
      context,
      AppRoutes.forgotPassword,
    );
  }

  // ============================================================
  // SIGN UP
  // ============================================================

  void _openSignup() {
    Navigator.pushNamed(
      context,
      AppRoutes.signup,
    );
  }

  // ============================================================
  // UI
  // ============================================================

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
                      padding:
                      const EdgeInsets.all(15),
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
                            offset:
                            const Offset(0, 8),
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
                  // WELCOME
                  // =====================================================

                  Text(
                    'Welcome Back!',
                    style: textTheme
                        .headlineLarge
                        ?.copyWith(
                      color:
                      colorScheme.onSurface,
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Login to continue your learning journey',
                    style: textTheme.bodyMedium
                        ?.copyWith(
                      color: colorScheme
                          .onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // =====================================================
                  // FORM
                  // =====================================================

                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        // =================================================
                        // EMAIL
                        // =================================================

                        Text(
                          'Email Address',
                          style: textTheme
                              .labelLarge
                              ?.copyWith(
                            color:
                            colorScheme.onSurface,
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller:
                          _emailController,
                          keyboardType:
                          TextInputType.emailAddress,
                          textInputAction:
                          TextInputAction.next,
                          decoration:
                          InputDecoration(
                            hintText:
                            'Enter your email',
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          style: TextStyle(
                            color:
                            colorScheme.onSurface,
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Please enter your email';
                            }

                            final emailRegex =
                            RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            );

                            if (!emailRegex.hasMatch(
                              value.trim(),
                            )) {
                              return 'Enter a valid email address';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // =================================================
                        // PASSWORD
                        // =================================================

                        Text(
                          'Password',
                          style: textTheme
                              .labelLarge
                              ?.copyWith(
                            color:
                            colorScheme.onSurface,
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller:
                          _passwordController,
                          obscureText:
                          _obscurePassword,
                          textInputAction:
                          TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!_loading &&
                                !_googleLoading) {
                              _submit();
                            }
                          },
                          decoration:
                          InputDecoration(
                            hintText:
                            'Enter your password',
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: colorScheme
                                  .onSurfaceVariant,
                            ),
                            suffixIcon:
                            IconButton(
                              tooltip:
                              _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              icon: Icon(
                                _obscurePassword
                                    ? Icons
                                    .visibility_outlined
                                    : Icons
                                    .visibility_off_outlined,
                                color: colorScheme
                                    .onSurfaceVariant,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword =
                                  !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          style: TextStyle(
                            color:
                            colorScheme.onSurface,
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.isEmpty) {
                              return 'Please enter password';
                            }

                            if (value.length < 6) {
                              return 'Password must be at least 6 chars';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // =================================================
                        // REMEMBER ME + FORGOT
                        // =================================================

                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value:
                                      _rememberMe,
                                      activeColor:
                                      colorScheme
                                          .primary,
                                      checkColor:
                                      colorScheme
                                          .onPrimary,
                                      shape:
                                      RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius
                                            .circular(5),
                                      ),
                                      onChanged:
                                      (_loading ||
                                          _googleLoading)
                                          ? null
                                          : (value) {
                                        setState(() {
                                          _rememberMe =
                                              value ??
                                                  false;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 8,
                                  ),
                                  Flexible(
                                    child: Text(
                                      'Remember me',
                                      style: textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                        color:
                                        colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed:
                              _loading ||
                                  _googleLoading
                                  ? null
                                  : _openForgotPassword,
                              child: const Text(
                                'Forgot Password?',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // =================================================
                        // LOGIN BUTTON
                        // =================================================

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child:
                          ElevatedButton(
                            onPressed:
                            _loading ||
                                _googleLoading
                                ? null
                                : _submit,
                            child:
                            AnimatedSwitcher(
                              duration:
                              const Duration(
                                milliseconds: 200,
                              ),
                              child: _loading
                                  ? SizedBox(
                                key:
                                const ValueKey(
                                  'loading',
                                ),
                                width: 22,
                                height: 22,
                                child:
                                CircularProgressIndicator(
                                  strokeWidth:
                                  2.5,
                                  color:
                                  colorScheme
                                      .onPrimary,
                                ),
                              )
                                  : const Text(
                                'Login',
                                key:
                                ValueKey(
                                  'login',
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // =================================================
                        // DIVIDER
                        // =================================================

                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: colorScheme
                                    .outline,
                              ),
                            ),
                            Padding(
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'OR',
                                style: textTheme
                                    .labelMedium
                                    ?.copyWith(
                                  color:
                                  colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: colorScheme
                                    .outline,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // =================================================
                        // GOOGLE LOGIN
                        // =================================================

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child:
                          OutlinedButton(
                            onPressed:
                            _loading ||
                                _googleLoading
                                ? null
                                : _signInWithGoogle,
                            style:
                            OutlinedButton
                                .styleFrom(
                              side: BorderSide(
                                color: colorScheme
                                    .outline,
                              ),
                              shape:
                              RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(14),
                              ),
                            ),
                            child:
                            AnimatedSwitcher(
                              duration:
                              const Duration(
                                milliseconds: 200,
                              ),
                              child:
                              _googleLoading
                                  ? SizedBox(
                                key:
                                const ValueKey(
                                  'google_loading',
                                ),
                                width: 22,
                                height: 22,
                                child:
                                CircularProgressIndicator(
                                  strokeWidth:
                                  2.5,
                                  color:
                                  colorScheme
                                      .primary,
                                ),
                              )
                                  : Row(
                                key:
                                const ValueKey(
                                  'google_button',
                                ),
                                mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child:
                                    Image.asset(
                                      'assets/images/google_logo.png',
                                      fit: BoxFit
                                          .contain,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 12,
                                  ),
                                  Text(
                                    'Continue with Google',
                                    style:
                                    TextStyle(
                                      color:
                                      colorScheme
                                          .onSurface,
                                      fontWeight:
                                      FontWeight
                                          .w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // =================================================
                        // SIGN UP
                        // =================================================

                        Center(
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                            children: [
                              Text(
                                "Don't have an account?",
                                style: textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                  color:
                                  colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              TextButton(
                                onPressed:
                                _loading ||
                                    _googleLoading
                                    ? null
                                    : _openSignup,
                                child: const Text(
                                  'Sign Up',
                                ),
                              ),
                            ],
                          ),
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
    );
  }
}