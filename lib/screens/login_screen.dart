import 'package:flutter/material.dart';
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
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    // Simulate login processing
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    setState(() => _loading = false);

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.home,
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
      // =====================================
      // BACKGROUND
      // =====================================

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

                  // =====================================
                  // WELCOME TEXT
                  // =====================================

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
                        // EMAIL LABEL
                        // =====================================

                        Text(
                          'Email Address',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // =====================================
                        // EMAIL FIELD
                        // =====================================

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
                        // PASSWORD LABEL
                        // =====================================

                        Text(
                          'Password',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // =====================================
                        // PASSWORD FIELD
                        // =====================================

                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction:
                          TextInputAction.done,

                          onFieldSubmitted: (_) {
                            if (!_loading) {
                              _submit();
                            }
                          },

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

                        const SizedBox(height: 12),

                        // =====================================
                        // REMEMBER ME + FORGOT PASSWORD
                        // =====================================

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
                                      activeColor:
                                      colorScheme.primary,

                                      checkColor:
                                      colorScheme.onPrimary,

                                      shape:
                                      RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(5),
                                      ),

                                      onChanged: (value) {
                                        setState(() {
                                          _rememberMe =
                                              value ?? false;
                                        });
                                      },
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  Flexible(
                                    child: Text(
                                      'Remember me',
                                      style:
                                      textTheme.bodyMedium?.copyWith(
                                        color:
                                        colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            TextButton(
                              onPressed: () {
                                // Forgot password is currently
                                // a UI-only action.
                              },
                              child: const Text(
                                'Forgot Password?',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // =====================================
                        // LOGIN BUTTON
                        // =====================================

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _loading
                                ? null
                                : _submit,

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
                                'Login',
                                key: ValueKey('login'),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // =====================================
                        // DIVIDER
                        // =====================================

                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: colorScheme.outline,
                              ),
                            ),

                            Padding(
                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'OR',
                                style:
                                textTheme.labelMedium?.copyWith(
                                  color:
                                  colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),

                            Expanded(
                              child: Divider(
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // =====================================
                        // SIGN UP
                        // =====================================

                        Center(
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [

                              Text(
                                "Don't have an account?",
                                style:
                                textTheme.bodyMedium?.copyWith(
                                  color:
                                  colorScheme.onSurfaceVariant,
                                ),
                              ),

                              TextButton(
                                onPressed: () {
                                  // Sign Up is currently
                                  // a UI-only action.
                                },
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