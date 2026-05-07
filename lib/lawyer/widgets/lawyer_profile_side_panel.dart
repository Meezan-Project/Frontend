import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/theme/app_spacing.dart';
import 'package:mezaan/lawyer/screens/lawyer_change_password_screen.dart';

class LawyerProfileSidePanel extends StatefulWidget {
  final String lawyerName;
  final String specialization;
  final String rating;
  final Uint8List? profileImageBytes;
  final String? profileImageUrl;
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final VoidCallback? onClose;
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
    required this.onLanguage,
    required this.onSchedule,
    required this.onSettings,
    required this.onPrivacy,
    required this.onHelp,
    required this.onLogout,
  });

  @override
  State<LawyerProfileSidePanel> createState() => _LawyerProfileSidePanelState();
}

class _LawyerProfileSidePanelState extends State<LawyerProfileSidePanel> {
  bool _isEditing = false;
  final List<String> _specializations = [
    'Criminal',
    'Civil',
    'Corporate',
    'Personal Status',
  ];
  final Set<String> _selectedSpecs = {'Criminal'};
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelBackground = isDark ? const Color(0xFF0F1726) : const Color(0xFFF6F9FF);
    final hasNetworkProfileImage = widget.profileImageUrl != null && widget.profileImageUrl!.trim().isNotEmpty;

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
                      color: const Color(0xFF03264A).withOpacity(0.26),
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
                        if (widget.profileImageBytes != null)
                          CircleAvatar(
                            radius: 34.r,
                            backgroundColor: Colors.white,
                            backgroundImage: MemoryImage(widget.profileImageBytes!),
                          )
                        else if (hasNetworkProfileImage)
                          Container(
                            width: 68.w,
                            height: 68.h,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.legalGold, width: 1.w),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              widget.profileImageUrl!.trim(),
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
                                widget.lawyerName,
                                style: GoogleFonts.cairo(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                widget.specialization,
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
                                    widget.rating,
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
                        if (widget.onClose != null)
                          IconButton(
                            onPressed: widget.onClose,
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
              _isEditing ? _buildEditForm(isDark) : _buildMenu(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              children: [
                _MenuItem(
                  icon: Icons.edit_rounded,
                  label: 'Edit Profile'.translate(),
                  onTap: () => setState(() => _isEditing = true),
                  isDark: isDark,
                ),
                _MenuItem(icon: Icons.calendar_today_rounded, label: 'Manage Schedule'.translate(), onTap: widget.onSchedule, isDark: isDark),
                _MenuItem(icon: Icons.settings_rounded, label: 'Settings'.translate(), onTap: widget.onSettings, isDark: isDark),
                _MenuItem(icon: Icons.language_rounded, label: 'Language'.translate(), onTap: widget.onLanguage, isDark: isDark),
                _MenuItem(icon: Icons.privacy_tip_rounded, label: 'Privacy Policy'.translate(), onTap: widget.onPrivacy, isDark: isDark),
                _MenuItem(icon: Icons.help_outline_rounded, label: 'Help & Support'.translate(), onTap: widget.onHelp, isDark: isDark),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
            child: Column(
              children: [
                Container(
                  height: 1.h,
                  color: isDark ? const Color(0xFF334766) : const Color(0xFFE5E7EB),
                  margin: EdgeInsets.only(bottom: 16.h),
                ),
                Row(
                  children: [
                    Icon(widget.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded, size: 20.sp, color: isDark ? Colors.white : AppColors.navyBlue),
                    SizedBox(width: 12.w),
                    Expanded(child: Text('Dark Mode'.translate(), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.navyBlue))),
                    Switch(value: widget.isDarkMode, onChanged: widget.onDarkModeChanged, activeThumbColor: AppColors.navyBlue),
                  ],
                ),
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: widget.onLogout,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF6A6A).withOpacity(0.1), foregroundColor: const Color(0xFFEF6A6A), padding: EdgeInsets.symmetric(vertical: 12.h)),
                    child: Text('Logout'.translate(), style: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(bool isDark) {
    return Expanded(
      child: ListView(
        padding: AppSpacing.screenPadding(context),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _isEditing = false),
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18.sp, color: isDark ? Colors.white : AppColors.navyBlue),
              ),
              Expanded(
                child: Text(
                  'Edit Profile'.translate(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(fontSize: 16.sp, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.navyBlue),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 40.r,
                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  child: Icon(Icons.person, size: 44.sp, color: AppColors.navyBlue),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(color: AppColors.legalGold, shape: BoxShape.circle, border: Border.all(color: isDark ? const Color(0xFF0F1726) : Colors.white, width: 2.w)),
                    child: Icon(Icons.camera_alt_rounded, size: 14.sp, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          _buildSectionTitle('Basic Info'.translate()),
          _buildField('Full Name'.translate(), widget.lawyerName, isDark),
          _buildField('Professional Title'.translate(), widget.specialization, isDark),
          _buildField('Bio'.translate(), 'Professional background...', isDark, maxLines: 3),
          SizedBox(height: 16.h),
          _buildSectionTitle('Professional Info'.translate()),
          _buildField('Syndicate Registration Number'.translate(), '12345678', isDark),
          _buildField('Years of Experience'.translate(), '10', isDark, keyboardType: TextInputType.number),
          SizedBox(height: 8.h),
          Text('Specializations'.translate(), style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.grey, fontWeight: FontWeight.w600)),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 6.w,
            children: _specializations.map((spec) {
              final isSelected = _selectedSpecs.contains(spec);
              return FilterChip(
                label: Text(spec.translate(), style: GoogleFonts.cairo(fontSize: 10.sp, color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.navyBlue))),
                selected: isSelected,
                onSelected: (val) => setState(() => val ? _selectedSpecs.add(spec) : _selectedSpecs.remove(spec)),
                selectedColor: AppColors.legalGold,
                checkmarkColor: Colors.white,
                labelPadding: EdgeInsets.symmetric(horizontal: 4.w),
              );
            }).toList(),
          ),
          SizedBox(height: 16.h),
          _buildSectionTitle('Contact Info'.translate()),
          _buildField('Phone Number'.translate(), '+20 123 456 7890', isDark, keyboardType: TextInputType.phone),
          _buildField('Office Address'.translate(), 'Cairo, Egypt', isDark, suffixIcon: Icons.location_on_rounded),
          SizedBox(height: 16.h),
          _buildSectionTitle('Account Settings'.translate()),
          SwitchListTile(
            title: Text('Enable Notifications'.translate(), style: GoogleFonts.cairo(fontSize: 13.sp, color: isDark ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.w600)),
            value: _notificationsEnabled,
            onChanged: (val) => setState(() => _notificationsEnabled = val),
            activeThumbColor: AppColors.legalGold,
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LawyerChangePasswordScreen())),
            leading: Icon(Icons.lock_reset_rounded, size: 20.sp, color: AppColors.navyBlue),
            title: Text('Change Password'.translate(), style: GoogleFonts.cairo(fontSize: 13.sp, fontWeight: FontWeight.w600)),
            trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12.sp),
            contentPadding: EdgeInsets.zero,
          ),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _isEditing = false),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navyBlue,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
              child: Text('Save Changes'.translate(), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(title, style: GoogleFonts.cairo(fontSize: 13.sp, fontWeight: FontWeight.bold, color: AppColors.legalGold)),
    );
  }

  Widget _buildField(String label, String hint, bool isDark, {int maxLines = 1, TextInputType? keyboardType, IconData? suffixIcon}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.cairo(fontSize: 11.sp, color: Colors.grey, fontWeight: FontWeight.w600)),
          SizedBox(height: 4.h),
          TextField(
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: GoogleFonts.cairo(fontSize: 13.sp, color: isDark ? Colors.white : AppColors.navyBlue),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13.sp),
              suffixIcon: suffixIcon != null ? Icon(suffixIcon, size: 18.sp, color: AppColors.navyBlue) : null,
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide.none),
            ),
          ),
        ],
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                color: itemTextColor.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
