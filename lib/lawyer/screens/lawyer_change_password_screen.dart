import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class LawyerChangePasswordScreen extends StatefulWidget {
  const LawyerChangePasswordScreen({super.key});

  @override
  State<LawyerChangePasswordScreen> createState() => _LawyerChangePasswordScreenState();
}

class _LawyerChangePasswordScreenState extends State<LawyerChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your current password'.translate();
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a new password'.translate();
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters'.translate();
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your new password'.translate();
    }
    if (value != _newPasswordController.text) {
      return 'Passwords do not match'.translate();
    }
    return null;
  }

  void _submitPasswordChange() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Placeholder for actual password change logic
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Password changed successfully'.translate()),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1A2940) : Colors.white;
    final borderColor = isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5);
    final appBg = isDark ? const Color(0xFF0F1419) : const Color(0xFFFCFDFF);

    return Scaffold(
      backgroundColor: appBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isDark ? Colors.white : AppColors.navyBlue,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Change Password'.translate(),
          style: GoogleFonts.cairo(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.navyBlue,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Password
              _buildPasswordField(
                controller: _currentPasswordController,
                label: 'Current Password'.translate(),
                hint: 'Enter your current password'.translate(),
                obscureText: _obscureCurrentPassword,
                onToggle: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
                validator: _validateCurrentPassword,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
              ),
              SizedBox(height: 16.h),

              // New Password
              _buildPasswordField(
                controller: _newPasswordController,
                label: 'New Password'.translate(),
                hint: 'Enter your new password'.translate(),
                obscureText: _obscureNewPassword,
                onToggle: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                validator: _validateNewPassword,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
              ),
              SizedBox(height: 16.h),

              // Confirm New Password
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Confirm New Password'.translate(),
                hint: 'Re-enter your new password'.translate(),
                obscureText: _obscureConfirmPassword,
                onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                validator: _validateConfirmPassword,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
              ),
              SizedBox(height: 32.h),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submitPasswordChange,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.legalGold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20.sp,
                          height: 20.sp,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Change Password'.translate(),
                          style: GoogleFonts.cairo(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: GoogleFonts.cairo(
            fontSize: 14.sp,
            color: isDark ? Colors.white : AppColors.navyBlue,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.cairo(
              fontSize: 14.sp,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
            ),
            filled: true,
            fillColor: cardBg,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: BorderSide(color: AppColors.legalGold, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: const BorderSide(color: Colors.red),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                size: 20.sp,
              ),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }
}