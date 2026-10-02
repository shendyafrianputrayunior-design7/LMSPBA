import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'theme.dart';
import 'theme_controller.dart';
import 'language_controller.dart';

final ThemeController themeController = ThemeController();
final LanguageController languageController = LanguageController();

void main() {
  runApp(const LMSApp());
}

class LMSApp extends StatelessWidget {
  const LMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        themeController,
        languageController,
      ]),
      builder: (context, child) {
        return MaterialApp(
          title: 'LMS App',

          debugShowCheckedModeBanner: false,

          // =========================
          // THEME
          // =========================

          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeController.themeMode,

          // =========================
          // LANGUAGE
          // =========================

          locale: languageController.locale,

          supportedLocales: const [
            Locale('en'),
            Locale('id'),
          ],

          // =========================
          // ROUTES
          // =========================

          initialRoute: AppRoutes.splash,
          routes: AppRoutes.routes,
        );
      },
    );
  }
}