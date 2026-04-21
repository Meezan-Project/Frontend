import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class UserEditProfileScreen extends StatefulWidget {
  const UserEditProfileScreen({super.key});

  @override
  State<UserEditProfileScreen> createState() => _UserEditProfileScreenState();
}

class _UserEditProfileScreenState extends State<UserEditProfileScreen> {
  final _firstNameController = TextEditingController();
  final _secondNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _firstNameError;
  String? _secondNameError;
  String? _emailError;
  String? _phoneError;
  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;

  bool _isLoadingData = true;
  bool _isSubmitting = false;
  bool _showPasswordFields = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  // Read-only fields
  String _birthDate = '';
  String _gender = '';
  String _nationalIdNumber = '';
  String? _frontIdImageUrl;
  String? _backIdImageUrl;

  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser == null) {
      _isLoadingData = false;
    } else {
      _loadUserData();
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _secondNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final currentUser = _currentUser;
    if (currentUser == null) {
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!mounted) return;

      final userData = userDoc.data() ?? <String, dynamic>{};

      setState(() {
        _firstNameController.text =
            userData['firstName']?.toString().trim() ?? '';
        _secondNameController.text =
            userData['secondName']?.toString().trim() ?? '';
        _emailController.text =
            userData['email']?.toString().trim() ?? currentUser.email ?? '';
        _phoneController.text = userData['phone']?.toString().trim() ?? '';

        _birthDate = userData['birthDate']?.toString().trim() ?? 'Not provided';
        _gender = userData['gender']?.toString().trim() ?? 'Not provided';
        _nationalIdNumber =
            userData['nationalId']?.toString().trim() ?? 'Not provided';
        _frontIdImageUrl =
            userData['frontNationalIdPhotoUrl']?.toString().trim().isNotEmpty ==
                true
            ? userData['frontNationalIdPhotoUrl']?.toString().trim()
            : null;
        _backIdImageUrl =
            userData['backNationalIdPhotoUrl']?.toString().trim().isNotEmpty ==
                true
            ? userData['backNationalIdPhotoUrl']?.toString().trim()
            : null;

        _isLoadingData = false;
      });

      // Try to load ID images from Firebase Storage URLs if needed
      // For now, they're shown as read-only text fields with image display capability
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e'.translate())),
        );
        setState(() => _isLoadingData = false);
      }
    }
  }

  String? _validateFirstName(String value) {
    if (value.trim().isEmpty) {
      return 'First name is required';
    }
    if (value.length < 2) {
      return 'First name must be at least 2 characters';
    }
    return null;
  }

  String? _validateSecondName(String value) {
    if (value.trim().isEmpty) {
      return 'Second name is required';
    }
    if (value.length < 2) {
      return 'Second name must be at least 2 characters';
    }
    return null;
  }

  String? _validateEmail(String value) {
    if (value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePhone(String value) {
    if (value.isEmpty) {
      return 'Phone number is required';
    }
    if (!value.startsWith('+2')) {
      return 'Must start with +2';
    }
    if (value.length != 13) {
      return 'Must be exactly 11 digits after +2';
    }
    final digits = value.substring(2);
    if (!RegExp(r'^[0-9]{11}$').hasMatch(digits)) {
      return 'Must contain exactly 11 digits after +2';
    }
    return null;
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Must contain an uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Must contain a lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Must contain a number';
    }
    return null;
  }

  String? _validateConfirmPassword(String value) {
    if (value.isEmpty) {
      return 'Please confirm password';
    }
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  bool _validateForm() {
    _firstNameError = _validateFirstName(_firstNameController.text);
    _secondNameError = _validateSecondName(_secondNameController.text);
    _emailError = _validateEmail(_emailController.text.trim());
    _phoneError = _validatePhone(_phoneController.text);

    bool hasErrors =
        _firstNameError != null ||
        _secondNameError != null ||
        _emailError != null ||
        _phoneError != null;

    if (_showPasswordFields) {
      _currentPasswordError = _currentPasswordController.text.isEmpty
          ? 'Enter current password'
          : null;
      _newPasswordError = _validatePassword(_newPasswordController.text);
      _confirmPasswordError = _validateConfirmPassword(
        _confirmPasswordController.text,
      );

      hasErrors =
          hasErrors ||
          _currentPasswordError != null ||
          _newPasswordError != null ||
          _confirmPasswordError != null;
    }

    setState(() {});
    return !hasErrors;
  }

  Future<void> _updateProfile() async {
    final currentUser = _currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please sign in again.'.translate())),
        );
      }
      return;
    }

    if (!_validateForm()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final firestore = FirebaseFirestore.instance;

      // Update password if needed
      if (_showPasswordFields && _newPasswordController.text.isNotEmpty) {
        try {
          final credential = EmailAuthProvider.credential(
            email: currentUser.email!,
            password: _currentPasswordController.text,
          );
          await currentUser.reauthenticateWithCredential(credential);
          await currentUser.updatePassword(_newPasswordController.text);
        } on FirebaseAuthException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  e.code == 'wrong-password'
                      ? 'Current password is incorrect'
                      : e.message ?? 'Error updating password',
                ),
              ),
            );
          }
          setState(() => _isSubmitting = false);
          return;
        }
      }

      // Update email if changed
      if (_emailController.text.trim() != (_currentUser?.email ?? '')) {
        try {
          await currentUser.verifyBeforeUpdateEmail(
            _emailController.text.trim(),
          );
        } on FirebaseAuthException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.message ?? 'Error updating email')),
            );
          }
          setState(() => _isSubmitting = false);
          return;
        }
      }

      // Update Firestore user document
      await firestore
          .collection('users')
          .doc(currentUser.uid)
          .set(<String, dynamic>{
            'firstName': _firstNameController.text.trim(),
            'secondName': _secondNameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully'.translate()),
            backgroundColor: Colors.green,
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Get.back();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e'.translate())));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'.translate()),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(24.r),
                child: Text(
                  'No signed in user found. Please login again.'.translate(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.navyBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Editable Section
                  Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Information'.translate(),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navyBlue,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        _buildTextField(
                          controller: _firstNameController,
                          label: 'First Name'.translate(),
                          error: _firstNameError,
                          onChanged: (_) {
                            setState(() {
                              _firstNameError = null;
                            });
                          },
                        ),
                        SizedBox(height: 12.h),
                        _buildTextField(
                          controller: _secondNameController,
                          label: 'Second Name'.translate(),
                          error: _secondNameError,
                          onChanged: (_) {
                            setState(() {
                              _secondNameError = null;
                            });
                          },
                        ),
                        SizedBox(height: 12.h),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email Address'.translate(),
                          error: _emailError,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) {
                            setState(() {
                              _emailError = null;
                            });
                          },
                        ),
                        SizedBox(height: 12.h),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Phone Number'.translate(),
                          error: _phoneError,
                          keyboardType: TextInputType.phone,
                          onChanged: (_) {
                            setState(() {
                              _phoneError = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Password Change Section
                  Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: Colors.blue,
                          size: 18.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Change Password'.translate(),
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showPasswordFields = !_showPasswordFields;
                              if (!_showPasswordFields) {
                                _currentPasswordController.clear();
                                _newPasswordController.clear();
                                _confirmPasswordController.clear();
                                _currentPasswordError = null;
                                _newPasswordError = null;
                                _confirmPasswordError = null;
                              }
                            });
                          },
                          child: Icon(
                            _showPasswordFields
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_showPasswordFields) ...[
                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: [
                          _buildPasswordField(
                            controller: _currentPasswordController,
                            label: 'Current Password'.translate(),
                            error: _currentPasswordError,
                            showPassword: _showCurrentPassword,
                            onToggle: () {
                              setState(
                                () => _showCurrentPassword =
                                    !_showCurrentPassword,
                              );
                            },
                            onChanged: (_) {
                              setState(() => _currentPasswordError = null);
                            },
                          ),
                          SizedBox(height: 12.h),
                          _buildPasswordField(
                            controller: _newPasswordController,
                            label: 'New Password'.translate(),
                            error: _newPasswordError,
                            showPassword: _showNewPassword,
                            onToggle: () {
                              setState(
                                () => _showNewPassword = !_showNewPassword,
                              );
                            },
                            onChanged: (_) {
                              setState(() => _newPasswordError = null);
                            },
                          ),
                          SizedBox(height: 12.h),
                          _buildPasswordField(
                            controller: _confirmPasswordController,
                            label: 'Confirm New Password'.translate(),
                            error: _confirmPasswordError,
                            showPassword: _showConfirmPassword,
                            onToggle: () {
                              setState(
                                () => _showConfirmPassword =
                                    !_showConfirmPassword,
                              );
                            },
                            onChanged: (_) {
                              setState(() => _confirmPasswordError = null);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 16.h),

                  // Read-only Section
                  Text(
                    'Account Information (Read-Only)'.translate(),
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: [
                        _buildReadOnlyField(
                          label: 'Birth Date'.translate(),
                          value: _birthDate,
                        ),
                        SizedBox(height: 12.h),
                        _buildReadOnlyField(
                          label: 'Gender'.translate(),
                          value: _gender,
                        ),
                        SizedBox(height: 12.h),
                        _buildReadOnlyField(
                          label: 'National ID Number'.translate(),
                          value: _nationalIdNumber,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // ID Images Section
                  Text(
                    'National ID Documents'.translate(),
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReadOnlyImageCard(
                          label: 'Front'.translate(),
                          imageUrl: _frontIdImageUrl,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildReadOnlyImageCard(
                          label: 'Back'.translate(),
                          imageUrl: _backIdImageUrl,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting ? null : () => Get.back(),
                          child: Text('Cancel'.translate()),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _updateProfile,
                          child: _isSubmitting
                              ? SizedBox(
                                  height: 20.h,
                                  width: 20.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text('Save Changes'.translate()),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? error,
    TextInputType keyboardType = TextInputType.text,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: error == null ? const Color(0xFFE5E7EB) : Colors.red,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: error == null ? AppColors.legalGold : Colors.red,
            width: 1.6,
          ),
        ),
        errorText: error?.translate(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    String? error,
    required bool showPassword,
    required VoidCallback onToggle,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: !showPassword,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: error == null ? const Color(0xFFE5E7EB) : Colors.red,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: error == null ? AppColors.legalGold : Colors.red,
            width: 1.6,
          ),
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            showPassword ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey[600],
          ),
        ),
        errorText: error?.translate(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      ),
    );
  }

  Widget _buildReadOnlyField({required String label, required String value}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.navyBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyImageCard({
    required String label,
    required String? imageUrl,
  }) {
    return Container(
      height: 150.h,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: imageUrl == null || imageUrl.isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sd_card_outlined,
                    size: 40.sp,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    label,
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Not available'.translate(),
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          size: 40.sp,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 8.w,
                    right: 8.w,
                    bottom: 8.h,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
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
