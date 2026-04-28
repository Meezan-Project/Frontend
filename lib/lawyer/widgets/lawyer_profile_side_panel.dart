import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class LawyerProfileSidePanel extends StatelessWidget {
  final String lawyerName;
  final String specialization;
  final String rating;
  final Uint8List? profileImageBytes;
  final String? profileImageUrl;
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final VoidCallback? onClose;
  final VoidCallback onEditProfile;
  final VoidCallback onLanguage;
  final VoidCallback onSchedule;
  final VoidCallback onSettings;
  final VoidCallback onPrivacy;
  final VoidCallback onHelp;
  final VoidCallback onLogout;

  const LawyerProfileSidePanel({
    super.key,
    required this.lawyerName,
    required this.specialization,
    required this.rating,
    required this.profileImageBytes,
    this.profileImageUrl,
    required this.isDarkMode,
    required this.onDarkModeChanged,
    this.onClose,
    required this.onEditProfile,
    required this.onLanguage,
    required this.onSchedule,
    required this.onSettings,
    required this.onPrivacy,
    required this.onHelp,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelBackground = isDark
        ? const Color(0xFF0F1726)
        : const Color(0xFFF6F9FF);
    final hasNetworkProfileImage =
        profileImageUrl != null && profileImageUrl!.trim().isNotEmpty;

    return Material(
      color: panelBackground,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.66,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(18.w, 16.h, 14.w, 18.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF03264A), Color(0xFF0B5E55)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF03264A).withValues(alpha: 0.26),
                      blurRadius: 18,
                      offset: Offset(0, 10.h),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (profileImageBytes != null)
                          CircleAvatar(
                            radius: 34.r,
                            backgroundColor: Colors.white,
                            backgroundImage: MemoryImage(profileImageBytes!),
                          )
                        else if (hasNetworkProfileImage)
                          Container(
                            width: 68.w,
                            height: 68.h,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              profileImageUrl!.trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(Icons.person, size: 32.sp),
                                );
                              },
                            ),
                          )
                        else
                          CircleAvatar(
                            radius: 34.r,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.person,
                              size: 36.sp,
                              color: AppColors.navyBlue,
                            ),
                          ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                lawyerName,
                                style: GoogleFonts.cairo(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                specialization,
                                style: GoogleFonts.cairo(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 6.h),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    color: const Color(0xFFFFC107),
                                    size: 14.sp,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    rating,
                                    style: GoogleFonts.cairo(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (onClose != null)
                          IconButton(
                            onPressed: onClose,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                            splashRadius: 20.r,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  children: [
                    _MenuItem(
                      icon: Icons.edit_rounded,
                      label: 'Edit Profile'.translate(),
                      onTap: onEditProfile,
                      isDark: isDark,
                    ),
                    _MenuItem(
                      icon: Icons.calendar_today_rounded,
                      label: 'Manage Schedule'.translate(),
                      onTap: onSchedule,
                      isDark: isDark,
                    ),
                    _MenuItem(
                      icon: Icons.settings_rounded,
                      label: 'Settings'.translate(),
                      onTap: onSettings,
                      isDark: isDark,
                    ),
                    _MenuItem(
                      icon: Icons.language_rounded,
                      label: 'Language'.translate(),
                      onTap: onLanguage,
                      isDark: isDark,
                    ),
                    _MenuItem(
                      icon: Icons.privacy_tip_rounded,
                      label: 'Privacy Policy'.translate(),
                      onTap: onPrivacy,
                      isDark: isDark,
                    ),
                    _MenuItem(
                      icon: Icons.help_outline_rounded,
                      label: 'Help & Support'.translate(),
                      onTap: onHelp,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
                child: Column(
                  children: [
                    Container(
                      height: 1.h,
                      color: isDark
                          ? const Color(0xFF334766)
                          : const Color(0xFFE5E7EB),
                      margin: EdgeInsets.only(bottom: 16.h),
                    ),
                    Row(
                      children: [
                        Icon(
                          isDarkMode
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          size: 20.sp,
                          color: isDark ? Colors.white : AppColors.navyBlue,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'Dark Mode'.translate(),
                            style: GoogleFonts.cairo(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.navyBlue,
                            ),
                          ),
                        ),
                        Switch(
                          value: isDarkMode,
                          onChanged: onDarkModeChanged,
                          activeThumbColor: AppColors.navyBlue,
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: onLogout,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(
                            0xFFEF6A6A,
                          ).withValues(alpha: 0.1),
                          foregroundColor: const Color(0xFFEF6A6A),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                        child: Text(
                          'Logout'.translate(),
                          style: GoogleFonts.cairo(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final itemBgColor = isDark
        ? const Color(0xFF182A42)
        : const Color(0xFFF0F4FA);
    final itemTextColor = isDark ? Colors.white : AppColors.navyBlue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: itemBgColor,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, color: itemTextColor, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: itemTextColor,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14.sp,
                color: itemTextColor.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
