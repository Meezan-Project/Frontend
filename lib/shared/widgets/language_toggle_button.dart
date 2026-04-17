import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:mezaan/shared/localization/localization_controller.dart';

class LanguageToggleButton extends StatelessWidget {
  final Color? backgroundColor;
  final Color? iconColor;

  const LanguageToggleButton({super.key, this.backgroundColor, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final localizationController = LocalizationController.instance;

    return Obx(
      () => InkWell(
        borderRadius: BorderRadius.circular(20.r),
        onTap: localizationController.toggleLanguage,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.transparent,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: (iconColor ?? Colors.white).withValues(alpha: 0.28),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.language,
                color: iconColor ?? Colors.white,
                size: 20.sp,
              ),
              SizedBox(width: 4.w),
              Text(
                localizationController.currentLanguage.value.toUpperCase(),
                style: TextStyle(
                  color: iconColor ?? Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
