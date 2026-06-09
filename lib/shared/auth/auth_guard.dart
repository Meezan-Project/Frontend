import 'package:mezaan/shared/auth/auth_state.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';

class AuthGuard {
  static String resolveRouteName(String? requestedRouteName) {
    final requested = requestedRouteName ?? AppRoutes.login;
    const publicRoutes = {
      AppRoutes.onboarding,
      AppRoutes.auth,
      AppRoutes.login,
      AppRoutes.forgotPassword,
      AppRoutes.register,
      AppRoutes.otp,
    };

    if (publicRoutes.contains(requested)) {
      if (!authState.isLoggedIn || authState.role == null) {
        return requested;
      }

      return _homeRouteForRole(authState.role);
    }

    // If not logged in or role is missing, send private routes to login.
    if (!authState.isLoggedIn || authState.role == null) {
      return AppRoutes.login;
    }

    final role = authState.role;

    if (requested == AppRoutes.adminHome && role != AppRole.admin) {
      return AppRoutes.login;
    }

    if (requested == AppRoutes.lawyerHome && role != AppRole.lawyer) {
      return AppRoutes.login;
    }

    if (requested == AppRoutes.userHome && role != AppRole.user) {
      return AppRoutes.login;
    }

    if (requested == AppRoutes.secretaryHome && role != AppRole.secretary) {
      return AppRoutes.login;
    }

    return requested;
  }

  static String _homeRouteForRole(AppRole? role) {
    switch (role) {
      case AppRole.user:
        return AppRoutes.userHome;
      case AppRole.lawyer:
        return AppRoutes.lawyerHome;
      case AppRole.admin:
        return AppRoutes.adminHome;
      case AppRole.secretary:
        return AppRoutes.secretaryHome;
      case null:
        return AppRoutes.login;
    }
  }
}
