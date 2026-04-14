import 'package:flutter/material.dart';
import 'package:mezaan/shared/auth/auth_state.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Welcome Admin'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  LoadingNavigator.pushNamed(context, AppRoutes.lawyerHome),
              child: const Text('Try Lawyer Interface'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () =>
                  LoadingNavigator.pushNamed(context, AppRoutes.userHome),
              child: const Text('Try User Dashboard'),
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
