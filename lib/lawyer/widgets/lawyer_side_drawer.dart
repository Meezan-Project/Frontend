import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/lawyer/screens/lawyer_change_password_screen.dart';
import 'package:mezaan/lawyer/screens/lawyer_edit_profile_screen.dart';

class LawyerSideDrawer extends StatelessWidget {
  final String lawyerName;
  final String? profileImageUrl;
  final String specialties;
  final String rating;
  final int templatesCount;
  final int documentsCount;
  final bool hasConflict;
  final bool isDarkMode;
  final String currentLanguage;
  final ValueChanged<bool> onDarkModeChanged;
  // onEditProfile removed - navigation handled directly in drawer
  final VoidCallback onManageSchedule;
  final VoidCallback onQuickTemplates;
  final VoidCallback onLegalLibrary;
  final VoidCallback onConflictChecker;
  final VoidCallback onPrivacyPolicy;
  final VoidCallback onHelpSupport;
  final VoidCallback onLogout;
  final ValueChanged<String> onLanguageChanged;

  const LawyerSideDrawer({
    super.key,
    required this.lawyerName,
    this.profileImageUrl,
    required this.specialties,
    required this.rating,
    this.templatesCount = 0,
    this.documentsCount = 0,
    this.hasConflict = false,
    required this.isDarkMode,
    required this.currentLanguage,
    required this.onDarkModeChanged,
    // onEditProfile removed - navigation handled directly in drawer
    required this.onManageSchedule,
    required this.onQuickTemplates,
    required this.onLegalLibrary,
    required this.onConflictChecker,
    required this.onPrivacyPolicy,
    required this.onHelpSupport,
    required this.onLogout,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawerWidth = MediaQuery.of(context).size.width * 0.78;
    final cardBg = isDark ? const Color(0xFF1A2940) : Colors.white;
    final borderColor = isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5);
    final appBg = isDark ? const Color(0xFF0F1419) : const Color(0xFFFCFDFF);

    return Container(
      width: drawerWidth,
      decoration: BoxDecoration(
        color: appBg,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20.r),
          bottomRight: Radius.circular(20.r),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 1. Header Section
            _buildHeader(context, isDark),

            // 2. Main Content Section
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                children: [
                  // Edit Profile (Moved outside)
                  _DrawerItem(
                    icon: Icons.person_outline_rounded,
                    title: 'Edit Profile'.translate(),
                    onTap: () => _navigateToEditProfile(context),
                  ),
                  Divider(color: borderColor, thickness: 0.5, height: 20.h),

                  // Main Features
                  _DrawerItem(
                    icon: Icons.description_outlined,
                    title: 'Quick Templates'.translate(),
                    onTap: onQuickTemplates,
                    trailing: _buildBadge(templatesCount.toString()),
                  ),
                  _DrawerItem(
                    icon: Icons.library_books_outlined,
                    title: 'My Legal Library'.translate(),
                    onTap: onLegalLibrary,
                    trailing: _buildBadge(documentsCount.toString()),
                  ),
                  _DrawerItem(
                    icon: Icons.person_search_outlined,
                    title: 'Conflict Checker'.translate(),
                    onTap: onConflictChecker,
                    trailing: hasConflict
                        ? Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700, size: 20.sp)
                        : null,
                  ),
                  SizedBox(height: 8.h),

                  // Settings (ExpansionTile)
                  _buildSettingsSection(context, isDark, cardBg, borderColor),
                  SizedBox(height: 8.h),

                  // Support & Privacy
                  _DrawerItem(
                    icon: Icons.lock_outline_rounded,
                    title: 'Privacy Policy'.translate(),
                    onTap: onPrivacyPolicy,
                  ),
                  _DrawerItem(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support'.translate(),
                    onTap: onHelpSupport,
                  ),
                ],
              ),
            ),

            // 3. Bottom Section (Dark Mode & Logout)
            _buildBottomSection(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final hasImage = profileImageUrl != null && profileImageUrl!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18.w, 16.h, 14.w, 18.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF03264A), Color(0xFF0B5E55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF03264A).withOpacity(0.26),
            blurRadius: 18,
            offset: Offset(0, 10.h),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34.r,
            backgroundColor: Colors.white,
            child: ClipOval(
              child: hasImage
                  ? Image.network(
                      profileImageUrl!,
                      fit: BoxFit.cover,
                      width: 68.w,
                      height: 68.h,
                      errorBuilder: (_, _, _) => _buildInitialText(),
                    )
                  : _buildInitialText(),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lawyerName,
                  style: GoogleFonts.cairo(fontSize: 16.sp, fontWeight: FontWeight.w800, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  specialties,
                  style: GoogleFonts.cairo(fontSize: 12.sp, fontWeight: FontWeight.w500, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Icon(Icons.star_rounded, color: const Color(0xFFFFC107), size: 14.sp),
                    SizedBox(width: 4.w),
                    Text(rating, style: GoogleFonts.cairo(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialText() {
    return Text(
      lawyerName.isNotEmpty ? lawyerName[0].toUpperCase() : '?',
      style: GoogleFonts.cairo(fontSize: 28.sp, fontWeight: FontWeight.w800, color: AppColors.navyBlue),
    );
  }

  Widget _buildBadge(String count) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppColors.legalGold.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(count, style: GoogleFonts.cairo(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppColors.legalGold)),
    );
  }

  Widget _buildSettingsSection(BuildContext context, bool isDark, Color cardBg, Color borderColor) {
    final subtitleText = isDark ? Colors.grey.shade500 : Colors.grey.shade600;
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 12.w),
          leading: Icon(Icons.settings_outlined, size: 20.sp, color: subtitleText),
          title: Text(
            'Settings'.translate(),
            style: GoogleFonts.cairo(fontSize: 13.sp, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
          children: [
            _DrawerItem(
              icon: Icons.language_rounded,
              title: 'Change Language'.translate(),
              onTap: () => _showLanguageBottomSheet(context, isDark, cardBg, borderColor),
              trailing: Text(currentLanguage, style: GoogleFonts.cairo(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.legalGold)),
              isNested: true,
            ),
            _DrawerItem(
              icon: Icons.lock_outline_rounded,
              title: 'Change Password'.translate(),
              onTap: () => _navigateToChangePassword(context),
              isNested: true,
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageBottomSheet(BuildContext context, bool isDark, Color cardBg, Color borderColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2.r)))),
            SizedBox(height: 20.h),
            Text('Select Language'.translate(), style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.w700)),
            SizedBox(height: 16.h),
            _LanguageOption(language: 'العربية', isSelected: currentLanguage == 'العربية', isDark: isDark, cardBg: cardBg, borderColor: borderColor, onTap: () { onLanguageChanged('العربية'); Navigator.pop(context); }),
            SizedBox(height: 8.h),
            _LanguageOption(language: 'English', isSelected: currentLanguage == 'English', isDark: isDark, cardBg: cardBg, borderColor: borderColor, onTap: () { onLanguageChanged('English'); Navigator.pop(context); }),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  void _navigateToEditProfile(BuildContext context) {
    Navigator.pop(context); // Close the drawer first
    // Create profile data from available drawer fields
    final profileData = LawyerProfileData(
      name: lawyerName,
      professionalTitle: specialties,
      bio: '',
      phoneNumber: '',
      officeAddress: '',
      yearsOfExperience: '',
      syndicateNumber: '',
      specializations: specialties.isNotEmpty 
          ? specialties.split(',').map((s) => s.trim()).toList() 
          : [],
      profileImageUrl: profileImageUrl ?? '',
    );
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => LawyerEditProfileScreen(initialData: profileData),
      ),
    );
  }

  void _navigateToChangePassword(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const LawyerChangePasswordScreen()));
  }

  Widget _buildBottomSection(BuildContext context, bool isDark) {
    final borderColor = isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5);
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: borderColor))),
      child: Column(
        children: [
          Row(
            children: [
              Icon(isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded, size: 20.sp),
              SizedBox(width: 12.w),
              Expanded(child: Text('Dark Mode'.translate(), style: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.w600))),
              Switch(value: isDarkMode, onChanged: onDarkModeChanged, activeThumbColor: AppColors.legalGold),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: () => _showLogoutDialog(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF6A6A).withOpacity(0.1),
                foregroundColor: const Color(0xFFEF6A6A),
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, size: 20.sp),
                  SizedBox(width: 8.w),
                  Text('Logout'.translate(), style: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Text('Mezaan v1.0.0', style: GoogleFonts.cairo(fontSize: 10.sp, color: Colors.grey)),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'.translate()),
        content: Text('Are you sure you want to logout?'.translate()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'.translate(), style: const TextStyle(color: Colors.grey))),
          FilledButton(onPressed: onLogout, style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF6A6A)), child: Text('Logout'.translate())),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isNested;

  const _DrawerItem({required this.icon, required this.title, required this.onTap, this.trailing, this.isNested = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h, left: isNested ? 12.w : 0),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        leading: Icon(icon, size: 22.sp, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
        title: Text(
          title,
          style: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.navyBlue),
        ),
        trailing: trailing,
        dense: true,
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String language;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;

  const _LanguageOption({required this.language, required this.isSelected, required this.onTap, required this.isDark, required this.cardBg, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: isSelected ? AppColors.legalGold : borderColor, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Text(language, style: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle, color: AppColors.legalGold, size: 20.sp),
          ],
        ),
      ),
    );
  }
}