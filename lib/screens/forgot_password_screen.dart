import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
    });

    try {
      final email = _emailController.text.trim();

      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Password reset link has been sent to $email.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'user-not-found':
          message = 'No account found with this email.';
          break;

        case 'too-many-requests':
          message =
          'Too many requests. Please try again later.';
          break;

        case 'network-request-failed':
          message =
          'Network error. Please check your internet connection.';
          break;

        default:
          message =
          'Failed to send reset link. Please try again.';
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
            'Something went wrong. Please try again.',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final size = MediaQuery.sizeOf(context);

    final horizontalPadding =
    (size.width * 0.06).clamp(20.0, 32.0);

    final logoSize =
    (size.shortestSide * 0.22).clamp(90.0, 130.0);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Forgot Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 500,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // Logo
                    SizedBox(
                      height: logoSize,
                      width: logoSize,
                      child: Image.asset(
                        'assets/images/logo-bgr.png',
                        semanticLabel: 'LMS App Logo',
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 28),

                    Text(
                      'Forgot Password?',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Enter your email address and we will send you a link to reset your password.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 32),

                    Text(
                      'Email Address',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _emailController,
                      keyboardType:
                      TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'Enter your email',
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(14),
                        ),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Please enter your email';
                        }

                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }

                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (!_loading) {
                          _sendResetLink();
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed:
                        _loading ? null : _sendResetLink,
                        child: AnimatedSwitcher(
                          duration:
                          const Duration(milliseconds: 200),
                          child: _loading
                              ? const SizedBox(
                            key: ValueKey('loading'),
                            width: 22,
                            height: 22,
                            child:
                            CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                              : const Text(
                            'Send Reset Link',
                            key: ValueKey('button'),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: _loading
                          ? null
                          : () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Back to Login',
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