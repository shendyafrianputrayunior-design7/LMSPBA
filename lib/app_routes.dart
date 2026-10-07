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
import 'screens/admin_screen.dart';
import 'screens/teacher_screen.dart';

class AppRoutes {
  // ============================================================
  // ROUTE NAMES
  // ============================================================

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
  static const String emailVerification =
      '/email-verification';
  static const String security = '/security';
  static const String createPassword =
      '/create-password';

  // ADMIN
  static const String admin = '/admin';

  static const String teacher = '/teacher';

  // ============================================================
  // ROUTES
  // ============================================================

  static Map<String, WidgetBuilder> get routes => {


    // ======================================================
    // SPLASH
    // ======================================================

    splash: (context) => const SplashScreen(),

    // ======================================================
    // HOME
    // ======================================================

    home: (context) => const HomeScreen(),

    // ======================================================
    // LOGIN
    // ======================================================

    login: (context) => const LoginScreen(),

    // ======================================================
    // ONBOARDING
    // ======================================================

    onboarding: (context) =>
    const OnboardingScreen(),

    // ======================================================
    // COURSES
    // ======================================================

    courses: (context) =>
    const CoursesScreen(),

    // ======================================================
    // COURSE DETAIL
    // ======================================================

    courseDetail: (context) =>
    const CourseDetailScreen(),

    // ======================================================
    // LESSON
    // ======================================================

    lesson: (context) =>
    const LessonScreen(),

    // ======================================================
    // SETTINGS
    // ======================================================

    settings: (context) =>
    const SettingsScreen(),

    // ======================================================
    // FORGOT PASSWORD
    // ======================================================

    forgotPassword: (context) =>
    const ForgotPasswordScreen(),

    // ======================================================
    // SIGN UP
    // ======================================================

    signup: (context) =>
    const SignupScreen(),

    // ======================================================
    // SECURITY
    // ======================================================

    security: (context) =>
    const SecurityScreen(),

    // ======================================================
    // CREATE PASSWORD
    // ======================================================

    createPassword: (context) =>
    const CreatePasswordScreen(),

    // ======================================================
    // EMAIL VERIFICATION
    // ======================================================

    emailVerification: (context) {
      final email =
          ModalRoute.of(context)?.settings.arguments
          as String? ??
              '';

      return EmailVerificationScreen(
        email: email,
      );
    },

    // ======================================================
    // ADMIN DASHBOARD
    // ======================================================

    admin: (context) =>
    const AdminScreen(),

    teacher: (context) => const TeacherScreen(),
  };
}