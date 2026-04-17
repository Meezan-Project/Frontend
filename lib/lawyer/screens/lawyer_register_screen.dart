import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mezaan/shared/localization/localization_controller.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/widgets/language_toggle_button.dart';

class LawyerRegisterScreen extends StatefulWidget {
  const LawyerRegisterScreen({super.key});

  @override
  State<LawyerRegisterScreen> createState() => _LawyerRegisterScreenState();
}

class _LawyerRegisterScreenState extends State<LawyerRegisterScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _secondNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _licenseNumberController =
      TextEditingController();
  final TextEditingController _specializationController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  DateTime? _selectedDob;
  XFile? _licenseImage;
  XFile? _profileImage;
  bool _isUnder18 = false;

  String? _firstNameError;
  String? _secondNameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _dobError;
  String? _licenseNumberError;
  String? _specializationError;
  String? _phoneError;
  String? _licenseImageError;
  String? _profileImageError;

  @override
  void dispose() {
    _firstNameController.dispose();
    _secondNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dobController.dispose();
    _licenseNumberController.dispose();
    _specializationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String get _password => _passwordController.text;

  bool get _hasMinLength => _password.length >= 8;
  bool get _hasUpper => RegExp(r'[A-Z]').hasMatch(_password);
  bool get _hasLower => RegExp(r'[a-z]').hasMatch(_password);
  bool get _hasSpecial =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\\/\[\]`~+=;]').hasMatch(_password);
  bool get _hasNumber => RegExp(r'\d').hasMatch(_password);

  bool get _isPasswordValid =>
      _hasMinLength && _hasUpper && _hasLower && _hasSpecial && _hasNumber;

  bool get _isConfirmMatched =>
      _confirmPasswordController.text.isNotEmpty &&
      _confirmPasswordController.text == _passwordController.text;

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 21, now.month, now.day),
    );

    if (selected == null) return;

    final age = _calculateAge(selected);
    setState(() {
      _selectedDob = selected;
      _dobController.text =
          '${selected.day.toString().padLeft(2, '0')}/${selected.month.toString().padLeft(2, '0')}/${selected.year}';
      _isUnder18 = age < 21;
    });
  }

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    final hasNotHadBirthdayThisYear =
        now.month < dob.month || (now.month == dob.month && now.day < dob.day);
    if (hasNotHadBirthdayThisYear) {
      age--;
    }
    return age;
  }

  Future<void> _captureLicenseImage() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (photo == null) return;

    setState(() {
      _licenseImage = photo;
      _licenseImageError = null;
    });
  }

  Future<void> _captureProfileImage() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );

    if (photo == null) return;

    setState(() {
      _profileImage = photo;
      _profileImageError = null;
    });
  }

  bool _validateForm() {
    final firstName = _firstNameController.text.trim();
    final secondName = _secondNameController.text.trim();
    final email = _emailController.text.trim();
    final licenseNumber = _licenseNumberController.text.trim();
    final specialization = _specializationController.text.trim();
    final phone = _phoneController.text.trim();

    String? firstNameError;
    String? secondNameError;
    String? emailError;
    String? passwordError;
    String? confirmPasswordError;
    String? dobError;
    String? licenseNumberError;
    String? specializationError;
    String? phoneError;
    String? licenseImageError;
    String? profileImageError;

    if (firstName.isEmpty) {
      firstNameError = 'First name is required';
    }
    if (secondName.isEmpty) {
      secondNameError = 'Second name is required';
    }
    if (email.isEmpty) {
      emailError = 'Email is required';
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      emailError = 'Enter a valid email address';
    }
    if (_passwordController.text.isEmpty) {
      passwordError = 'Password is required';
    } else if (!_isPasswordValid) {
      passwordError = 'Password does not meet the required rules';
    }
    if (_confirmPasswordController.text.isEmpty) {
      confirmPasswordError = 'Please re-enter password';
    } else if (!_isConfirmMatched) {
      confirmPasswordError = 'Passwords must match';
    }
    if (_selectedDob == null || _dobController.text.trim().isEmpty) {
      dobError = 'Date of birth is required';
    } else if (_isUnder18) {
      dobError = '+21 only';
    }
    if (licenseNumber.isEmpty) {
      licenseNumberError = 'License number is required';
    }
    if (specialization.isEmpty) {
      specializationError = 'Specialization is required';
    }
    if (phone.isEmpty) {
      phoneError = 'Phone number is required';
    } else if (phone.length < 10) {
      phoneError = 'Phone number must be at least 10 digits';
    }
    if (_licenseImage == null) {
      licenseImageError = 'Capture license photo from camera';
    }
    if (_profileImage == null) {
      profileImageError = 'Capture profile photo from camera';
    }

    setState(() {
      _firstNameError = firstNameError;
      _secondNameError = secondNameError;
      _emailError = emailError;
      _passwordError = passwordError;
      _confirmPasswordError = confirmPasswordError;
      _dobError = dobError;
      _licenseNumberError = licenseNumberError;
      _specializationError = specializationError;
      _phoneError = phoneError;
      _licenseImageError = licenseImageError;
      _profileImageError = profileImageError;
    });

    return firstNameError == null &&
        secondNameError == null &&
        emailError == null &&
        passwordError == null &&
        confirmPasswordError == null &&
        dobError == null &&
        licenseNumberError == null &&
        specializationError == null &&
        phoneError == null &&
        licenseImageError == null &&
        profileImageError == null;
  }

  void _handleRegister() {
    if (!_validateForm()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fix highlighted fields'.translate())),
      );
      return;
    }

    final registrationPayload = {
      'firstName': _firstNameController.text.trim(),
      'secondName': _secondNameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text,
      'dateOfBirth': _dobController.text.trim(),
      'licenseNumber': _licenseNumberController.text.trim(),
      'specialization': _specializationController.text.trim(),
      'phone': _phoneController.text.trim(),
      'licenseImagePath': _licenseImage?.path,
      'profileImagePath': _profileImage?.path,
    };

    debugPrint('Ready to save lawyer payload: $registrationPayload');

    LoadingNavigator.pushReplacementNamed(context, AppRoutes.lawyerHome);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.width > 700;
    final localizationController = LocalizationController.instance;

    return Obx(() {
      localizationController.currentLanguage.value;

      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _LawyerRegisterHeader(),
              Transform.translate(
                offset: Offset(0, -42.h),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18.w),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 620 : double.infinity,
                    ),
                    child: Container(
                      padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 22.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 22,
                            offset: Offset(0, 10.h),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Lawyer Registration'.translate(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.w900,
                              color: AppColors.legalGold,
                            ),
                          ),
                          SizedBox(height: 20.h),
                          Row(
                            children: [
                              Expanded(
                                child: _CustomTextField(
                                  controller: _firstNameController,
                                  label: 'First Name',
                                  hintText: 'e.g. Ahmed',
                                  icon: Icons.person_outline,
                                  errorText: _firstNameError,
                                  onChanged: (_) => setState(() {
                                    _firstNameError = null;
                                  }),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: _CustomTextField(
                                  controller: _secondNameController,
                                  label: 'Second Name',
                                  hintText: 'e.g. Ali',
                                  icon: Icons.person_2_outlined,
                                  errorText: _secondNameError,
                                  onChanged: (_) => setState(() {
                                    _secondNameError = null;
                                  }),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          _CustomTextField(
                            controller: _emailController,
                            label: 'Email',
                            hintText: 'e.g. ahmed.ali@gmail.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            errorText: _emailError,
                            onChanged: (_) => setState(() {
                              _emailError = null;
                            }),
                          ),
                          SizedBox(height: 16.h),
                          _CustomTextField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            hintText: 'e.g. 01234567890',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            errorText: _phoneError,
                            onChanged: (_) => setState(() {
                              _phoneError = null;
                            }),
                          ),
                          SizedBox(height: 16.h),
                          _CustomTextField(
                            controller: _licenseNumberController,
                            label: 'License Number',
                            hintText: 'e.g. LAW123456789',
                            icon: Icons.badge_outlined,
                            errorText: _licenseNumberError,
                            onChanged: (_) => setState(() {
                              _licenseNumberError = null;
                            }),
                          ),
                          SizedBox(height: 16.h),
                          _CustomTextField(
                            controller: _specializationController,
                            label: 'Specialization',
                            hintText: 'e.g. Criminal Law',
                            icon: Icons.school_outlined,
                            errorText: _specializationError,
                            onChanged: (_) => setState(() {
                              _specializationError = null;
                            }),
                          ),
                          SizedBox(height: 16.h),
                          _CustomTextField(
                            controller: _passwordController,
                            label: 'Password',
                            hintText: 'e.g. Aa@12345',
                            icon: Icons.lock_outline,
                            obscureText: true,
                            errorText: _passwordError,
                            onChanged: (_) => setState(() {
                              _passwordError = null;
                            }),
                          ),
                          SizedBox(height: 10.h),
                          _PasswordRuleItem(
                            text: 'At least 8 characters',
                            passed: _hasMinLength,
                          ),
                          _PasswordRuleItem(
                            text: 'One uppercase letter',
                            passed: _hasUpper,
                          ),
                          _PasswordRuleItem(
                            text: 'One lowercase letter',
                            passed: _hasLower,
                          ),
                          _PasswordRuleItem(
                            text: 'One special character',
                            passed: _hasSpecial,
                          ),
                          _PasswordRuleItem(
                            text: 'One number',
                            passed: _hasNumber,
                          ),
                          SizedBox(height: 16.h),
                          _CustomTextField(
                            controller: _confirmPasswordController,
                            label: 'Re-enter Password',
                            hintText: 'Enter the same password',
                            icon: Icons.lock_reset,
                            obscureText: true,
                            errorText: _confirmPasswordError,
                            onChanged: (_) => setState(() {
                              _confirmPasswordError = null;
                            }),
                          ),
                          SizedBox(height: 16.h),
                          _CustomTextField(
                            controller: _dobController,
                            label: 'Date of Birth',
                            hintText: 'DD/MM/YYYY',
                            icon: Icons.calendar_today_outlined,
                            readOnly: true,
                            onTap: _pickDateOfBirth,
                            errorText: _dobError,
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: 6.h),
                            child: _PasswordRuleItem(
                              text: 'Must be +21',
                              passed: false,
                            ),
                          ),
                          SizedBox(height: 18.h),
                          _IdCaptureCard(
                            title: 'License Photo',
                            imagePath: _licenseImage?.path,
                            errorText: _licenseImageError,
                            onCapturePressed: _captureLicenseImage,
                          ),
                          SizedBox(height: 12.h),
                          _IdCaptureCard(
                            title: 'Profile Photo',
                            imagePath: _profileImage?.path,
                            errorText: _profileImageError,
                            onCapturePressed: _captureProfileImage,
                          ),
                          SizedBox(height: 22.h),
                          SizedBox(
                            height: 56.h,
                            child: ElevatedButton(
                              onPressed: _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.legalGold,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Create Account'.translate(),
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 18.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account? '.translate(),
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13.sp,
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    LoadingNavigator.pushReplacementNamed(
                                      context,
                                      AppRoutes.login,
                                    ),
                                child: Text(
                                  'Login'.translate(),
                                  style: TextStyle(
                                    color: AppColors.legalGold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _LawyerRegisterHeader extends StatelessWidget {
  const _LawyerRegisterHeader();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      height: size.height * 0.31,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B7500), AppColors.legalGold, Color(0xFF6B5900)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(56)),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: LanguageToggleButton(
                  backgroundColor: Colors.white24,
                  iconColor: Colors.white,
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gavel_rounded, color: Colors.white, size: 62),
                SizedBox(height: 10.h),
                Text(
                  'Join as Lawyer'.translate(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                Text(
                  'Serve Justice & Help Communities'.translate(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final bool readOnly;
  final TextInputType keyboardType;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final String? errorText;

  const _CustomTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.onTap,
    this.onChanged,
    this.errorText,
  });

  @override
  State<_CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<_CustomTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.translate(),
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.navyBlue,
          ),
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: widget.controller,
          obscureText: _obscureText,
          readOnly: widget.readOnly,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          onTap: widget.onTap,
          decoration: InputDecoration(
            hintText: widget.hintText.translate(),
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.sp),
            prefixIcon: Icon(widget.icon, color: AppColors.legalGold),
            suffixIcon: widget.obscureText
                ? GestureDetector(
                    onTap: () => setState(() => _obscureText = !_obscureText),
                    child: Icon(
                      _obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.legalGold,
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(
                color: Color(0xFFE0E0E0),
                width: 1.2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(
                color: Color(0xFFE0E0E0),
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(
                color: AppColors.legalGold,
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Colors.red, width: 1.2),
            ),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding: EdgeInsets.symmetric(
              vertical: 12.h,
              horizontal: 14.w,
            ),
          ),
        ),
        if (widget.errorText != null)
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Text(
              widget.errorText!.translate(),
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class _PasswordRuleItem extends StatelessWidget {
  final String text;
  final bool passed;

  const _PasswordRuleItem({required this.text, required this.passed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3.h),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16.sp,
            color: passed ? Colors.green : Colors.grey,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text.translate(),
              style: TextStyle(
                fontSize: 12.sp,
                color: passed ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdCaptureCard extends StatelessWidget {
  final String title;
  final String? imagePath;
  final String? errorText;
  final VoidCallback onCapturePressed;

  const _IdCaptureCard({
    required this.title,
    this.imagePath,
    this.errorText,
    required this.onCapturePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.translate(),
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.navyBlue,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          height: 160.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: errorText != null
                  ? Colors.red
                  : imagePath != null
                  ? AppColors.legalGold
                  : const Color(0xFFE0E0E0),
              width: 1.5,
            ),
            color: const Color(0xFFFAFAFA),
          ),
          child: imagePath != null
              ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11.r),
                      child: Image.file(
                        File(imagePath!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    Positioned(
                      right: 8.w,
                      top: 8.h,
                      child: GestureDetector(
                        onTap: onCapturePressed,
                        child: Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: BoxDecoration(
                            color: AppColors.legalGold,
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20.sp,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        color: AppColors.legalGold,
                        size: 40.sp,
                      ),
                      SizedBox(height: 8.h),
                      GestureDetector(
                        onTap: onCapturePressed,
                        child: Text(
                          'Capture Photo'.translate(),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.legalGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        if (errorText != null)
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Text(
              errorText!.translate(),
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
