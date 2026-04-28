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

    final roleHome = _homeRouteForRole(authState.role);

    if (!authState.isLoggedIn && !publicRoutes.contains(requested)) {
      return AppRoutes.login;
    }

    // When logged in, always keep user in their role space and avoid returning
    // to auth/onboarding screens unless they explicitly log out.
    if (authState.isLoggedIn && publicRoutes.contains(requested)) {
      return roleHome;
    }

    final role = authState.role;

    if (requested == AppRoutes.adminHome && role != AppRole.admin) {
      return roleHome;
    }

    if (requested == AppRoutes.lawyerHome && role != AppRole.lawyer) {
      return roleHome;
    }

    if (requested == AppRoutes.userHome && role != AppRole.user) {
      return roleHome;
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
      case null:
        return AppRoutes.login;
    }
  }
}
