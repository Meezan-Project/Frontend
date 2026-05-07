import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class LawyerBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onDestinationSelected;
  final VoidCallback? onOpenDrawer;

  const LawyerBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final shadowColor = isDark ? Colors.black26 : Colors.black12;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 20.r,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Left Item 1: Rescue (SOS)
              _buildNavItem(
                context: context,
                index: 0,
                icon: Icons.emergency_rounded,
                label: 'Rescue'.translate(),
                isSelected: currentIndex == 0,
                iconColor: AppColors.sosRed,
              ),
              // Left Item 2: Schedule
              _buildNavItem(
                context: context,
                index: 1,
                icon: Icons.calendar_month_rounded,
                label: 'Schedule'.translate(),
                isSelected: currentIndex == 1,
              ),
              // Center Item: Home (Prominent FAB-style)
              _buildCenterButton(context),
              // Right Item 1: Cases
              _buildNavItem(
                context: context,
                index: 2,
                icon: Icons.work_rounded,
                label: 'Cases'.translate(),
                isSelected: currentIndex == 2,
              ),
              // Right Item 2: Menu (Opens Drawer)
              _buildMenuItem(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    Color? iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = AppColors.navyBlue;
    final unselectedColor = isDark ? Colors.white70 : Colors.grey;
    final activeIconColor = iconColor ?? AppColors.legalGold;

    return InkWell(
      onTap: () => onDestinationSelected(index),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.navyBlue.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24.sp,
              color: isSelected ? activeIconColor : unselectedColor,
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 11.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? selectedColor : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton(BuildContext context) {
    return GestureDetector(
      onTap: () => onDestinationSelected(3), // Home index
      child: Container(
        width: 60.w,
        height: 60.h,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navyBlue, Color(0xFF003366)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.navyBlue.withValues(alpha: 0.4),
              blurRadius: 15.r,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_rounded,
              color: AppColors.legalGold,
              size: 28.sp,
            ),
            Text(
              'Home'.translate(),
              style: GoogleFonts.cairo(
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = currentIndex == 4;
    final selectedColor = AppColors.navyBlue;
    final unselectedColor = isDark ? Colors.white70 : Colors.grey;

    return InkWell(
      onTap: onOpenDrawer,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.navyBlue.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: 24.sp,
              color: isSelected ? AppColors.legalGold : unselectedColor,
            ),
            SizedBox(height: 4.h),
            Text(
              'Menu'.translate(),
              style: GoogleFonts.cairo(
                fontSize: 11.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? selectedColor : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
