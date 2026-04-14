import 'package:mezaan/shared/auth/auth_state.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';

class AuthGuard {
  static String resolveRouteName(String? requestedRouteName) {
    final requested = requestedRouteName ?? AppRoutes.login;
    const publicRoutes = {
      AppRoutes.onboarding,
      AppRoutes.auth,
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.otp,
    };

    if (!authState.isLoggedIn && !publicRoutes.contains(requested)) {
      return AppRoutes.login;
    }

    if (authState.isLoggedIn && requested == AppRoutes.login) {
      return _homeRouteForRole(authState.role);
    }

    final role = authState.role;

    if (requested == AppRoutes.adminHome && role != AppRole.admin) {
      return _homeRouteForRole(role);
    }

    if (requested == AppRoutes.lawyerHome && role != AppRole.lawyer) {
      return _homeRouteForRole(role);
    }

    if (requested == AppRoutes.userHome && role != AppRole.user) {
      return _homeRouteForRole(role);
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
