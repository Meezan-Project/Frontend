import 'package:flutter/material.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class LawyerNotificationsScreen extends StatelessWidget {
  const LawyerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'.translate()),
        backgroundColor: AppColors.navyBlue,
      ),
      body: Center(
        child: Text('Notifications screen coming soon.'.translate()),
      ),
    );
  }
}