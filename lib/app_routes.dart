import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/courses_screen.dart';
import 'screens/course_detail_screen.dart';
import 'screens/lesson_screen.dart';
import 'screens/settings_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String login = '/login';
  static const String onboarding = '/onboarding';
  static const String courses = '/courses';
  static const String courseDetail = '/course_detail';
  static const String lesson = '/lesson';
  static const String settings = '/settings';

  static Map<String, WidgetBuilder> get routes => {
    splash: (context) => const SplashScreen(),
    home: (context) => const HomeScreen(),
    login: (context) => const LoginScreen(),
    onboarding: (context) => const OnboardingScreen(),
    courses: (context) => const CoursesScreen(),
    courseDetail: (context) => const CourseDetailScreen(),
    lesson: (context) => const LessonScreen(),
    settings: (context) => const SettingsScreen(),
  };
}
