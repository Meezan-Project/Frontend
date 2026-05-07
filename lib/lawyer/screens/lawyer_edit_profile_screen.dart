import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/theme/app_spacing.dart';
import 'package:mezaan/lawyer/screens/lawyer_change_password_screen.dart';

/// Model class for lawyer profile data
class LawyerProfileData {
  final String name;
  final String professionalTitle;
  final String bio;
  final String phoneNumber;
  final String officeAddress;
  final String yearsOfExperience;
  final String syndicateNumber;
  final List<String> specializations;
  final String profileImageUrl;

  const LawyerProfileData({
    this.name = '',
    this.professionalTitle = '',
    this.bio = '',
    this.phoneNumber = '',
    this.officeAddress = '',
    this.yearsOfExperience = '',
    this.syndicateNumber = '',
    this.specializations = const [],
    this.profileImageUrl = '',
  });

  LawyerProfileData copyWith({
    String? name,
    String? professionalTitle,
    String? bio,
    String? phoneNumber,
    String? officeAddress,
    String? yearsOfExperience,
    String? syndicateNumber,
    List<String>? specializations,
    String? profileImageUrl,
  }) {
    return LawyerProfileData(
      name: name ?? this.name,
      professionalTitle: professionalTitle ?? this.professionalTitle,
      bio: bio ?? this.bio,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      officeAddress: officeAddress ?? this.officeAddress,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      syndicateNumber: syndicateNumber ?? this.syndicateNumber,
      specializations: specializations ?? this.specializations,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}

class LawyerEditProfileScreen extends StatefulWidget {
  final LawyerProfileData? initialData;

  const LawyerEditProfileScreen({super.key, this.initialData});

  @override
  State<LawyerEditProfileScreen> createState() => _LawyerEditProfileScreenState();
}

class _LawyerEditProfileScreenState extends State<LawyerEditProfileScreen> {
  // TextEditingControllers for each field
  late TextEditingController _nameController;
  late TextEditingController _titleController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _experienceController;
  late TextEditingController _syndicateController;

  final List<String> _specializations = [
    'Criminal',
    'Civil',
    'Corporate',
    'Personal Status',
  ];
  final Set<String> _selectedSpecs = {'Criminal'};
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    
    _nameController = TextEditingController(text: data?.name ?? '');
    _titleController = TextEditingController(text: data?.professionalTitle ?? '');
    _bioController = TextEditingController(text: data?.bio ?? '');
    _phoneController = TextEditingController(text: data?.phoneNumber ?? '');
    _addressController = TextEditingController(text: data?.officeAddress ?? '');
    _experienceController = TextEditingController(text: data?.yearsOfExperience ?? '');
    _syndicateController = TextEditingController(text: data?.syndicateNumber ?? '');
    
    if (data?.specializations.isNotEmpty ?? false) {
      _selectedSpecs.clear();
      _selectedSpecs.addAll(data!.specializations);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _experienceController.dispose();
    _syndicateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Edit Profile'.translate(),
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w800,
            fontSize: 18.sp,
            color: AppColors.navyBlue,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.navyBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: AppSpacing.screenPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Basic Info - Profile Picture
              Center(
                child: Stack(
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.legalGold, width: 1.5.w),
                      ),
                      child: CircleAvatar(
                        radius: 55.r,
                        backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        backgroundImage: widget.initialData?.profileImageUrl.isNotEmpty ?? false
                            ? NetworkImage(widget.initialData!.profileImageUrl)
                            : null,
                        child: widget.initialData?.profileImageUrl.isEmpty ?? true
                            ? Icon(Icons.person_rounded, size: 60.sp, color: AppColors.navyBlue)
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 4.h,
                      right: 4.w,
                      child: GestureDetector(
                        onTap: () {
                          // Image picker logic can be implemented here
                        },
                        child: Container(
                          padding: EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.legalGold,
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2.w),
                          ),
                          child: Icon(Icons.camera_alt_rounded, size: 16.sp, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.xl),

              // Basic Info Fields
              _buildSectionHeader('Basic Info'.translate()),
              _buildTextField(context, label: 'Full Name'.translate(), hint: 'Enter your full name', controller: _nameController),
              _buildTextField(context, label: 'Professional Title'.translate(), hint: 'e.g. Cassation Lawyer', controller: _titleController),
              _buildTextField(context, label: 'Bio/Summary'.translate(), hint: 'Tell clients about your expertise...', maxLines: 4, controller: _bioController),

              SizedBox(height: AppSpacing.lg),
              // 2. Specializations
              _buildSectionHeader('Specializations'.translate()),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: 0,
                children: _specializations.map((spec) {
                  final isSelected = _selectedSpecs.contains(spec);
                  return FilterChip(
                    label: Text(spec.translate()),
                    selected: isSelected,
                    onSelected: (selected) => setState(() {
                      selected ? _selectedSpecs.add(spec) : _selectedSpecs.remove(spec);
                    }),
                    selectedColor: AppColors.legalGold.withOpacity(0.15), // Already withOpacity
                    checkmarkColor: AppColors.legalGold,
                    labelStyle: GoogleFonts.cairo(
                      fontSize: 12.sp,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.legalGold : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      side: BorderSide(
                        color: isSelected ? AppColors.legalGold : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                      ),
                    ),
                  );
                }).toList(),
              ),

              SizedBox(height: AppSpacing.xl),
              // 3. Professional Details
              _buildSectionHeader('Professional Details'.translate()),
              _buildTextField(context, label: 'Phone Number'.translate(), hint: '+20 123 456 7890', keyboardType: TextInputType.phone, controller: _phoneController),
              _buildTextField(context,
                label: 'Office Address'.translate(),
                hint: 'Office location (Integrated with Maps)',
                suffixIcon: Icons.location_on_rounded,
                controller: _addressController,
              ),
              _buildTextField(context, label: 'Years of Experience'.translate(), hint: 'e.g. 10', keyboardType: TextInputType.number, controller: _experienceController),

              SizedBox(height: AppSpacing.xl),
              // 4. Verification
              _buildSectionHeader('Verification'.translate()),
              _buildTextField(context, label: 'Syndicate Registration Number'.translate(), hint: 'Enter your number', controller: _syndicateController),
              Container(
                padding: AppSpacing.cardPadding(context),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1), // Already withOpacity
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)), // Already withOpacity
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_rounded, color: Colors.blue, size: 24.sp),
                    SizedBox(width: AppSpacing.md),
                    Text(
                      'Account Verified'.translate(),
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        color: Colors.blue,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppSpacing.xl),
              // 5. Account Settings
              _buildSectionHeader('Account Settings'.translate()),
              _buildSettingsAction(
                icon: Icons.lock_reset_rounded,
                title: 'Change Password'.translate(),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LawyerChangePasswordScreen())),
              ),
              SwitchListTile(
                title: Text(
                  'Enable Notifications'.translate(),
                  style: GoogleFonts.cairo(
                    fontSize: 14.sp, 
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.navyBlue,
                  ),
                ),
                value: _notificationsEnabled,
                onChanged: (val) => setState(() => _notificationsEnabled = val),
                activeThumbColor: AppColors.legalGold,
                contentPadding: EdgeInsets.zero,
              ),

              SizedBox(height: 40.h),
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 54.h,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Changes saved successfully!'.translate())),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                    elevation: 2,
                  ),
                  child: Text(
                    'Save Changes'.translate(),
                    style: GoogleFonts.cairo(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 15.h),
      child: Text(
        title,
        style: GoogleFonts.cairo(fontSize: 15.sp, fontWeight: FontWeight.bold, color: AppColors.navyBlue),
      ),
    );
  }

  Widget _buildTextField(BuildContext context, {required String label, required String hint, int maxLines = 1, TextInputType? keyboardType, IconData? suffixIcon, TextEditingController? controller}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 18.h),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.cairo(fontSize: 14.sp, color: isDark ? Colors.white : AppColors.navyBlue),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: AppColors.navyBlue, size: 20.sp) : null,
          labelStyle: GoogleFonts.cairo(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600, fontSize: 13.sp),
          floatingLabelStyle: GoogleFonts.cairo(color: AppColors.navyBlue, fontWeight: FontWeight.bold),
          contentPadding: AppSpacing.inputPadding(context),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.navyBlue, width: 1.2)),
        ),
      ),
    );
  }

  Widget _buildSettingsAction({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.navyBlue, size: 22.sp),
      title: Text(title, style: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      contentPadding: EdgeInsets.zero,
    );
  }
}