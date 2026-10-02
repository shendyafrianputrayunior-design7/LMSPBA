import 'package:flutter/material.dart';
import '../app_routes.dart';
import '../ui/layout.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();

  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skip() {
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.login,
    );
  }

  void _next() {
    if (_page == 2) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.login,
      );
      return;
    }

    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),

      body: SafeArea(
        child: Column(
          children: [
            // =====================================
            // ONBOARDING PAGES
            // =====================================

            Expanded(
              child: PageView(
                controller: _controller,

                onPageChanged: (index) {
                  setState(() {
                    _page = index;
                  });
                },

                children: [
                  _buildPage(
                    size,
                    'Welcome',
                    'Learn anytime, anywhere',
                    'assets/images/onboarding1-cr.png',
                  ),

                  _buildPage(
                    size,
                    'Track Progress',
                    'Progress cards and dashboards',
                    'assets/images/onboarding2-cr.png',
                  ),

                  _buildPage(
                    size,
                    'Start Learning',
                    'Explore courses and lessons',
                    'assets/images/onboarding3-cr.png',
                  ),
                ],
              ),
            ),

            // =====================================
            // BOTTOM NAVIGATION
            // =====================================

            Container(
              padding: const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),

              child: Row(
                children: [
                  // SKIP
                  SizedBox(
                    width: 70,
                    child: TextButton(
                      onPressed: _skip,
                      child: const Text('Skip'),
                    ),
                  ),

                  // PAGE INDICATORS
                  Expanded(
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          3,
                              (index) {
                            final selected = _page == index;

                            return AnimatedContainer(
                              duration: const Duration(
                                milliseconds: 250,
                              ),
                              margin:
                              const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              width: selected ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: selected
                                    ? theme.colorScheme.primary
                                    : Colors.grey.shade300,
                                borderRadius:
                                BorderRadius.circular(20),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // NEXT / GET STARTED
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _next,
                      child: Text(
                        _page == 2
                            ? 'Get Started'
                            : 'Next',
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

  Widget _buildPage(
      Size size,
      String title,
      String subtitle,
      String image,
      ) {
    final imageHeight =
    (size.height * 0.35).clamp(220.0, 360.0);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 20,
        ),
        child: AppLayout.centeredConstrained(
          maxWidth: 520,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // IMAGE
              Image.asset(
                image,
                width: size.width * 0.7,
                height: imageHeight,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 32),

              // TITLE
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium,
              ),

              const SizedBox(height: 12),

              // SUBTITLE
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}