import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/courses_screen.dart';
import 'screens/course_detail_screen.dart';
import 'screens/lesson_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/security_screen.dart';
import 'screens/create_password_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String login = '/login';
  static const String onboarding = '/onboarding';
  static const String courses = '/courses';
  static const String courseDetail = '/course_detail';
  static const String lesson = '/lesson';
  static const String settings = '/settings';
  static const String forgotPassword = '/forgot-password';
  static const String signup = '/signup';
  static const String emailVerification = '/email-verification';
  static const String security = '/security';
  static const String createPassword = '/create-password';

  static Map<String, WidgetBuilder> get routes => {
    // Splash
    splash: (context) => const SplashScreen(),

    // Home
    home: (context) => const HomeScreen(),

    // Login
    login: (context) => const LoginScreen(),

    // Onboarding
    onboarding: (context) => const OnboardingScreen(),

    // Courses
    courses: (context) => const CoursesScreen(),

    // Course Detail
    courseDetail: (context) => const CourseDetailScreen(),

    // Lesson
    lesson: (context) => const LessonScreen(),

    // Settings
    settings: (context) => const SettingsScreen(),

    // Forgot Password
    forgotPassword: (context) => const ForgotPasswordScreen(),

    // Sign Up
    signup: (context) => const SignupScreen(),

    // Security
    security: (context) => const SecurityScreen(),

    // Create Password
    createPassword: (context) => const CreatePasswordScreen(),

    // Email Verification
    emailVerification: (context) {
      final email =
          ModalRoute.of(context)?.settings.arguments as String? ?? '';

      return EmailVerificationScreen(
        email: email,
      );
    },
  };
}