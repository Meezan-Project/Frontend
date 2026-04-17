import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class UserBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onCenterButtonTap;

  const UserBottomNavBar({
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
              icon: Icons.local_police_outlined,
              activeIcon: Icons.local_police_rounded,
              label: 'Rescue'.translate(),
            ),
            _buildNavItem(
              context: context,
              index: 1,
              icon: Icons.folder_shared_outlined,
              activeIcon: Icons.folder_shared_rounded,
              label: 'Cases'.translate(),
            ),
            _buildCenterAction(context),
            _buildNavItem(
              context: context,
              index: 3,
              icon: Icons.mark_chat_unread_outlined,
              activeIcon: Icons.mark_chat_unread_rounded,
              label: 'Messages'.translate(),
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
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14.w : 10.w,
          vertical: 9.h,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? selectedColor : unselectedColor,
              size: 25.sp,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    SizedBox(width: 7.w),
                    Text(
                      label,
                      style: GoogleFonts.cairo(
                        color: selectedColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterAction(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onCenterButtonTap != null) {
          onCenterButtonTap!();
          return;
        }

        LoadingNavigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.userHome,
          (route) => false,
        );
      },
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD12F2F), Color(0xFF8E1919)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB91C1C).withValues(alpha: 0.36),
              blurRadius: 14,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: Icon(Icons.home_rounded, color: Colors.white, size: 26.sp),
      ),
    );
  }
}
