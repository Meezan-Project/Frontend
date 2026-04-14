import 'package:flutter/material.dart';
import 'package:mezaan/shared/auth/auth_state.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';

class UserDashboardScreen extends StatelessWidget {
  const UserDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Dashboard')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Welcome User'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  LoadingNavigator.pushNamed(context, AppRoutes.adminHome),
              child: const Text('Try Admin Dashboard'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () =>
                  LoadingNavigator.pushNamed(context, AppRoutes.lawyerHome),
              child: const Text('Try Lawyer Interface'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                authState.logout();
                LoadingNavigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (route) => false,
                );
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
