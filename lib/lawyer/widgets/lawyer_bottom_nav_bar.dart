import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class LawyerBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onCenterButtonTap;

  const LawyerBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.onCenterButtonTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBackground = isDark
        ? const Color(0xFF18253A)
        : const Color(0xFFFCFDFF);
    final navBorder = isDark
        ? const Color(0xFF304563)
        : const Color(0xFFDCE6F5);

    return SafeArea(
      child: Container(
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 18.h),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: navBackground,
          borderRadius: BorderRadius.circular(38.r),
          border: Border.all(color: navBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.1),
              blurRadius: 24,
              offset: Offset(0, 10.h),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(
              context: context,
              index: 0,
              icon: Icons.calendar_today_outlined,
              activeIcon: Icons.calendar_today_rounded,
              label: 'Schedule'.translate(),
            ),
            _buildNavItem(
              context: context,
              index: 1,
              icon: Icons.assignment_outlined,
              activeIcon: Icons.assignment_rounded,
              label: 'Cases'.translate(),
            ),
            _buildCenterAction(context),
            _buildNavItem(
              context: context,
              index: 3,
              icon: Icons.chat_bubble_outline_rounded,
              activeIcon: Icons.chat_bubble_rounded,
              label: 'Chat'.translate(),
            ),
            _buildNavItem(
              context: context,
              index: 4,
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile'.translate(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final bool isSelected = currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = isDark ? const Color(0xFFE7EEFF) : AppColors.navyBlue;
    final unselectedColor = isDark
        ? const Color(0xFF9FB0CA)
        : const Color(0xFF98A3B3);

    return GestureDetector(
      onTap: () => onDestinationSelected(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? selectedColor : unselectedColor,
            size: 24.sp,
          ),
          if (isSelected) ...[
            SizedBox(height: 4.h),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: selectedColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCenterAction(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 50.h,
      width: 50.w,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyBlue, Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyBlue.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onCenterButtonTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Icon(Icons.add_rounded, color: Colors.white, size: 28.sp),
        ),
      ),
    );
  }
}
