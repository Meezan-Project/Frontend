import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/auth/auth_state.dart';
import 'package:mezaan/shared/auth/firebase_session_service.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';

class LawyerDashboardScreen extends StatelessWidget {
  const LawyerDashboardScreen({super.key});

  Future<bool> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Logout'.translate()),
          content: Text('Are you sure you want to logout?'.translate()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'.translate()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Logout'.translate()),
            ),
          ],
        );
      },
    );

    return shouldLogout ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Lawyer Interface'.translate())),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Welcome Lawyer'.translate(),
              style: TextStyle(fontSize: 16.sp),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () =>
                  LoadingNavigator.pushNamed(context, AppRoutes.adminHome),
              child: Text('Try Admin Dashboard'.translate()),
            ),
            SizedBox(height: 8.h),
            ElevatedButton(
              onPressed: () =>
                  LoadingNavigator.pushNamed(context, AppRoutes.userHome),
              child: Text('Try User Dashboard'.translate()),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () async {
                final shouldLogout = await _confirmLogout(context);
                if (!shouldLogout) return;
                await FirebaseSessionService.signOutAll();
                authState.logout();
                if (!context.mounted) return;
                LoadingNavigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (route) => false,
                );
              },
              child: Text('Logout'.translate()),
            ),
          ],
        ),
      ),
    );
  }
}
