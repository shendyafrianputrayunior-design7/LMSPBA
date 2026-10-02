import 'package:flutter/material.dart';
import '../app_routes.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
    });

    // Simulasi proses pembuatan akun
    await Future.delayed(
      const Duration(seconds: 1),
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    // Setelah akun dibuat → lanjut ke verifikasi email
    Navigator.pushNamed(
      context,
      AppRoutes.emailVerification,
      arguments: _emailController.text.trim(),
    );
  }

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
            constraints: const BoxConstraints(
              maxWidth: 480,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =====================================
                  // LOGO
                  // =====================================

                  Center(
                    child: Container(
                      width: logoSize + 30,
                      height: logoSize + 30,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color:
                        colorScheme.surfaceContainerHighest,
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
                        semanticLabel: 'LMS App Logo',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // =====================================
                  // TITLE
                  // =====================================

                  Text(
                    'Create Account',
                    style: textTheme.headlineLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Create your account and start your learning journey',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // =====================================
                  // FORM
                  // =====================================

                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        // =====================================
                        // FULL NAME
                        // =====================================

                        Text(
                          'Full Name',
                          style:
                          textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller: _nameController,
                          textInputAction:
                          TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: 'Enter your full name',
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color:
                              colorScheme.onSurfaceVariant,
                            ),
                          ),
                          style: TextStyle(
                            color: colorScheme.onSurface,
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Please enter your name';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // =====================================
                        // EMAIL
                        // =====================================

                        Text(
                          'Email Address',
                          style:
                          textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller: _emailController,
                          keyboardType:
                          TextInputType.emailAddress,
                          textInputAction:
                          TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: 'Enter your email',
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color:
                              colorScheme.onSurfaceVariant,
                            ),
                          ),
                          style: TextStyle(
                            color: colorScheme.onSurface,
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Please enter your email';
                            }

                            final emailRegex = RegExp(
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

                        // =====================================
                        // PASSWORD
                        // =====================================

                        Text(
                          'Password',
                          style:
                          textTheme.labelLarge?.copyWith(
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
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color:
                              colorScheme.onSurfaceVariant,
                            ),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color:
                                colorScheme.onSurfaceVariant,
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
                            color: colorScheme.onSurface,
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

                        const SizedBox(height: 20),

                        // =====================================
                        // CONFIRM PASSWORD
                        // =====================================

                        Text(
                          'Confirm Password',
                          style:
                          textTheme.labelLarge?.copyWith(
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
                            if (!_loading) {
                              _signup();
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Confirm your password',
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color:
                              colorScheme.onSurfaceVariant,
                            ),
                            suffixIcon: IconButton(
                              tooltip:
                              _obscureConfirmPassword
                                  ? 'Show password'
                                  : 'Hide password',
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color:
                                colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          style: TextStyle(
                            color: colorScheme.onSurface,
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.isEmpty) {
                              return 'Please confirm your password';
                            }

                            if (value !=
                                _passwordController.text) {
                              return 'Passwords do not match';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // =====================================
                        // SIGN UP BUTTON
                        // =====================================

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed:
                            _loading ? null : _signup,
                            child: AnimatedSwitcher(
                              duration:
                              const Duration(
                                milliseconds: 200,
                              ),
                              child: _loading
                                  ? SizedBox(
                                key: const ValueKey(
                                  'loading',
                                ),
                                width: 22,
                                height: 22,
                                child:
                                CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color:
                                  colorScheme.onPrimary,
                                ),
                              )
                                  : const Text(
                                'Create Account',
                                key: ValueKey(
                                  'signup',
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // =====================================
                        // BACK TO LOGIN
                        // =====================================

                        Center(
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account?',
                                style: textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                  color: colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  'Login',
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