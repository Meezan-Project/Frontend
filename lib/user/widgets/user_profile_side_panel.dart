import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class UserProfileSidePanel extends StatelessWidget {
  final String userName;
  final Uint8List? profileImageBytes;
  final String? profileImageUrl;
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final VoidCallback? onClose;
  final VoidCallback onEditProfile;
  final VoidCallback onLanguage;
  final VoidCallback onSavedCards;
  final VoidCallback onSettings;
  final VoidCallback onEmergencyContacts;
  final VoidCallback onPrivacy;
  final VoidCallback onHelp;
  final VoidCallback onLogout;

  const UserProfileSidePanel({
    super.key,
    required this.userName,
    required this.profileImageBytes,
    this.profileImageUrl,
    required this.isDarkMode,
    required this.onDarkModeChanged,
    this.onClose,
    required this.onEditProfile,
    required this.onLanguage,
    required this.onSavedCards,
    required this.onSettings,
    required this.onEmergencyContacts,
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
                                return Icon(
                                  Icons.person_rounded,
                                  size: 36.sp,
                                  color: AppColors.navyBlue,
                                );
                              },
                            ),
                          )
                        else
                          CircleAvatar(
                            radius: 34.r,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.person_rounded,
                              size: 36.sp,
                              color: AppColors.navyBlue,
                            ),
                          ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Manage your account'.translate(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
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
                            tooltip: 'Close',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 16.h),
                  children: [
                    _PanelTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Edit Profile'.translate(),
                      onTap: onEditProfile,
                    ),
                    _PanelTile(
                      icon: Icons.language_rounded,
                      title: 'Language'.translate(),
                      subtitle: 'Arabic / English'.translate(),
                      onTap: onLanguage,
                    ),
                    _PanelTile(
                      icon: Icons.credit_card_rounded,
                      title: 'Saved Cards'.translate(),
                      onTap: onSavedCards,
                    ),
                    _PanelTile(
                      icon: Icons.emergency_share_rounded,
                      title: 'Emergency Contacts'.translate(),
                      onTap: onEmergencyContacts,
                    ),
                    _PanelTile(
                      icon: Icons.settings_outlined,
                      title: 'Settings'.translate(),
                      onTap: onSettings,
                    ),
                    _PanelTile(
                      icon: Icons.verified_user_outlined,
                      title: 'Privacy & Security'.translate(),
                      onTap: onPrivacy,
                    ),
                    _PanelTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Need Help?'.translate(),
                      onTap: onHelp,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                child: Column(
                  children: [
                    Container(
                      height: 1.h,
                      color: isDark
                          ? const Color(0xFF334766)
                          : const Color(0xFFE5E7EB),
                      margin: EdgeInsets.only(bottom: 14.h),
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
                    SizedBox(height: 14.h),
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

class _PanelTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isDanger;
  final VoidCallback onTap;

  const _PanelTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.isDanger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColor = isDark ? const Color(0xFF24344C) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2A3550)
        : const Color(0xFFE1EAF8);
    final titleColor = isDanger
        ? const Color(0xFFB91C1C)
        : (isDark ? Colors.white : AppColors.navyBlue);
    final iconColor = isDanger
        ? const Color(0xFFB91C1C)
        : (isDark ? const Color(0xFFD8E4FF) : AppColors.navyBlue);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.black.withValues(alpha: 0.58);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        leading: CircleAvatar(
          radius: 18.r,
          backgroundColor: iconColor.withValues(alpha: 0.12),
          child: Icon(icon, color: iconColor, size: 19.sp),
        ),
        title: Text(
          title,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: TextStyle(color: subtitleColor, fontSize: 12.sp),
              ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: iconColor,
          size: 24.sp,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _PanelSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PanelSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColor = isDark ? const Color(0xFF24344C) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2A3550)
        : const Color(0xFFE1EAF8);
    final switchTextColor = isDark ? Colors.white : AppColors.navyBlue;
    final iconColor = isDark ? const Color(0xFFD8E4FF) : AppColors.navyBlue;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18.r,
            backgroundColor: iconColor.withValues(alpha: 0.12),
            child: Icon(icon, color: iconColor, size: 19.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700,
                color: switchTextColor,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: const Color(0xFF0B5E55),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
