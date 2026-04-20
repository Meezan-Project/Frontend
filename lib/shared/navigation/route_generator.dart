import 'package:flutter/material.dart';
import 'package:mezaan/admin/screens/admin_dashboard_screen.dart';
import 'package:mezaan/lawyer/screens/lawyer_dashboard_screen.dart';
import 'package:mezaan/shared/auth/auth_guard.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/screens/auth_screen.dart';
import 'package:mezaan/shared/screens/launch_splash_screen.dart';
import 'package:mezaan/shared/screens/login_screen.dart';
import 'package:mezaan/shared/screens/onboarding_screen.dart';
import 'package:mezaan/shared/screens/register_screen.dart';
import 'package:mezaan/shared/theme/responsive_page_wrapper.dart';
import 'package:mezaan/user/screens/user_ai_chat_screen.dart';
import 'package:mezaan/user/screens/user_dashboard_screen.dart';

class RouteGenerator {
  static Route<dynamic> _buildModernRoute({
    required Widget page,
    required String routeName,
  }) {
    return PageRouteBuilder(
      settings: RouteSettings(name: routeName),
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) =>
          ResponsivePageWrapper(child: page),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final slide =
            Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        final scale = Tween<double>(begin: 0.985, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );

        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(scale: scale, child: child),
          ),
        );
      },
    );
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    if (settings.name == AppRoutes.splash) {
      return _buildModernRoute(
        page: const LaunchSplashScreen(),
        routeName: AppRoutes.splash,
      );
    }

    // Onboarding and Auth don't need auth guard
    if (settings.name == AppRoutes.onboarding) {
      return _buildModernRoute(
        page: const OnboardingScreen(),
        routeName: AppRoutes.onboarding,
      );
    }

    if (settings.name == AppRoutes.auth) {
      return _buildModernRoute(
        page: const AuthScreen(),
        routeName: AppRoutes.auth,
      );
    }

    final guardedRoute = AuthGuard.resolveRouteName(settings.name);

    switch (guardedRoute) {
      case AppRoutes.login:
        return _buildModernRoute(
          page: const LoginScreen(),
          routeName: AppRoutes.login,
        );
      case AppRoutes.register:
        return _buildModernRoute(
          page: const RegisterScreen(),
          routeName: AppRoutes.register,
        );
      case AppRoutes.userHome:
        return _buildModernRoute(
          page: const UserDashboardScreen(),
          routeName: AppRoutes.userHome,
        );
      case AppRoutes.userAiChat:
        return _buildModernRoute(
          page: const UserAIChatScreen(),
          routeName: AppRoutes.userAiChat,
        );
      case AppRoutes.lawyerHome:
        return _buildModernRoute(
          page: const LawyerDashboardScreen(),
          routeName: AppRoutes.lawyerHome,
        );
      case AppRoutes.adminHome:
        return _buildModernRoute(
          page: const AdminDashboardScreen(),
          routeName: AppRoutes.adminHome,
        );
      default:
        return _buildModernRoute(
          page: const LoginScreen(),
          routeName: AppRoutes.login,
        );
    }
  }
}
