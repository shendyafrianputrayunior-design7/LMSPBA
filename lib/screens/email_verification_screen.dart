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
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _loading = false;

  // Kode verifikasi untuk simulasi
  final String _verificationCode = '123456';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    // Cek kode verifikasi
    if (_codeController.text.trim() != _verificationCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid verification code.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    // Simulasi proses verifikasi
    await Future.delayed(
      const Duration(seconds: 1),
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    // Verifikasi berhasil → langsung ke Home/Dashboard
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
          (route) => false,
    );
  }

  void _resendCode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'A new verification code has been sent.',
        ),
      ),
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
                  // =====================================
                  // LOGO
                  // =====================================

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

                  // =====================================
                  // TITLE
                  // =====================================

                  Text(
                    'Verify Your Email',
                    style: textTheme.headlineLarge
                        ?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'We have sent a verification code to your email address.',
                    style: textTheme.bodyMedium
                        ?.copyWith(
                      color:
                      colorScheme.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // =====================================
                  // EMAIL
                  // =====================================

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
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
                            style: textTheme.bodyMedium
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
                        Text(
                          'Verification Code',
                          style: textTheme.labelLarge
                              ?.copyWith(
                            color:
                            colorScheme.onSurface,
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller:
                          _codeController,
                          keyboardType:
                          TextInputType.number,
                          textInputAction:
                          TextInputAction.done,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                            colorScheme.onSurface,
                            fontSize: 24,
                            fontWeight:
                            FontWeight.w700,
                            letterSpacing: 8,
                          ),
                          decoration:
                          InputDecoration(
                            hintText: '000000',
                            counterText: '',
                            prefixIcon: Icon(
                              Icons
                                  .verified_user_outlined,
                              color: colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Please enter the verification code';
                            }

                            if (value.trim().length !=
                                6) {
                              return 'Code must be 6 digits';
                            }

                            if (!RegExp(
                              r'^\d{6}$',
                            ).hasMatch(
                                value.trim())) {
                              return 'Code must contain numbers only';
                            }

                            return null;
                          },
                          onFieldSubmitted: (_) {
                            if (!_loading) {
                              _verifyCode();
                            }
                          },
                        ),

                        const SizedBox(height: 24),

                        // =====================================
                        // VERIFY BUTTON
                        // =====================================

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed:
                            _loading
                                ? null
                                : _verifyCode,
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
                                  strokeWidth:
                                  2.5,
                                  color: colorScheme
                                      .onPrimary,
                                ),
                              )
                                  : const Text(
                                'Verify Email',
                                key: ValueKey(
                                  'verify',
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // =====================================
                        // RESEND CODE
                        // =====================================

                        Center(
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              Text(
                                "Didn't receive the code?",
                                style: textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                  color: colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              TextButton(
                                onPressed:
                                _resendCode,
                                child: const Text(
                                  'Resend Code',
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // =====================================
                        // DEMO INFORMATION
                        // =====================================

                        Container(
                          width: double.infinity,
                          padding:
                          const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colorScheme.primary
                                .withOpacity(0.08),
                            borderRadius:
                            BorderRadius.circular(
                              12,
                            ),
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
                                Icons.info_outline,
                                size: 20,
                                color: colorScheme
                                    .primary,
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              Expanded(
                                child: Text(
                                  'Demo mode: use verification code 123456.',
                                  style: textTheme
                                      .bodySmall
                                      ?.copyWith(
                                    color: colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // =====================================
                        // BACK TO LOGIN
                        // =====================================

                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                            },
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}