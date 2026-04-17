import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/auth/auth_state.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';

class LawyerDashboardScreen extends StatelessWidget {
  const LawyerDashboardScreen({super.key});

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
              onPressed: () {
                authState.logout();
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
