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

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          margin: EdgeInsets.only(
            top: 24.h,
          ), // Space for floating button to overlap seamlessly
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
            top: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Left Item 1: Rescue (SOS)
                  Expanded(
                    child: _buildNavItem(
                      context: context,
                      index: 0,
                      icon: Icons.emergency_rounded,
                      label: 'Rescue'.translate(),
                      isSelected: currentIndex == 0,
                      iconColor: AppColors.sosRed,
                    ),
                  ),
                  // Left Item 2: Cases
                  Expanded(
                    child: _buildNavItem(
                      context: context,
                      index: 1,
                      icon: Icons.work_rounded,
                      label: 'Cases'.translate(),
                      isSelected: currentIndex == 1,
                    ),
                  ),
                  // Left Item 3: Office
                  Expanded(
                    child: _buildNavItem(
                      context: context,
                      index: 2,
                      icon: Icons.business_rounded,
                      label: 'Office'.translate(),
                      isSelected: currentIndex == 2,
                    ),
                  ),
                  // Center space for the floating home button
                  SizedBox(width: 60.r),
                  // Right Item 1: Messages
                  Expanded(
                    child: _buildNavItem(
                      context: context,
                      index: 4,
                      icon: Icons.message_rounded,
                      label: 'Messages'.translate(),
                      isSelected: currentIndex == 4,
                    ),
                  ),
                  // Right Item 2: Schedule
                  Expanded(
                    child: _buildNavItem(
                      context: context,
                      index: 5,
                      icon: Icons.calendar_month_rounded,
                      label: 'Schedule'.translate(),
                      isSelected: currentIndex == 5,
                    ),
                  ),
                  // Right Item 3: Menu (Opens Drawer)
                  Expanded(child: _buildMenuItem(context)),
                ],
              ),
            ),
          ),
        ),
        // Floating Center Button overlapping the nav bar
        Positioned(top: 0, child: _buildCenterButton(context, backgroundColor)),
      ],
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
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.navyBlue.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22.sp,
              color: isSelected ? activeIconColor : unselectedColor,
            ),
            SizedBox(height: 4.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.w),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 10.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? selectedColor : unselectedColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton(BuildContext context, Color bgColor) {
    return GestureDetector(
      onTap: () => onDestinationSelected(3), // Home index
      child: Container(
        width: 60.r,
        height: 60.r,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navyBlue, Color(0xFF003366)],
          ),
          shape: BoxShape.circle,
          border: Border.all(color: bgColor, width: 4.w),
          boxShadow: [
            BoxShadow(
              color: AppColors.navyBlue.withValues(alpha: 0.3),
              blurRadius: 10.r,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.home_rounded,
            color: AppColors.legalGold,
            size: 26.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = currentIndex == 6;
    final selectedColor = AppColors.navyBlue;
    final unselectedColor = isDark ? Colors.white70 : Colors.grey;

    return InkWell(
      onTap: onOpenDrawer,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.navyBlue.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: 22.sp,
              color: isSelected ? AppColors.legalGold : unselectedColor,
            ),
            SizedBox(height: 4.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.w),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Menu'.translate(),
                  style: GoogleFonts.cairo(
                    fontSize: 10.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? selectedColor : unselectedColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
