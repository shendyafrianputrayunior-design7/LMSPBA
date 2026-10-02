import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'theme.dart';
import 'theme_controller.dart';

final ThemeController themeController = ThemeController();

void main() {
  runApp(const LMSApp());
}

class LMSApp extends StatelessWidget {
  const LMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, child) {
        return MaterialApp(
          title: 'LMS App',

          debugShowCheckedModeBanner: false,

          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeController.themeMode,

          initialRoute: AppRoutes.splash,
          routes: AppRoutes.routes,
        );
      },
    );
  }
}