import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:image_picker/image_picker.dart';

import 'package:mezaan/shared/services/supabase_storage_service.dart';

import 'package:mezaan/shared/navigation/app_routes.dart';

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

  final _birthDateController = TextEditingController();

  final _genderController = TextEditingController();

  final _nationalIdController = TextEditingController();

  final _countryController = TextEditingController();

  final _governorateController = TextEditingController();

  final _cityController = TextEditingController();

  final _addressController = TextEditingController();

  final _currentPasswordController = TextEditingController();

  final _newPasswordController = TextEditingController();

  final _confirmPasswordController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

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

  String _originalFirstName = '';

  String _originalSecondName = '';

  String _originalEmail = '';

  String _originalPhone = '';

  String _originalCountry = '';

  String _originalGovernorate = '';

  String _originalCity = '';

  String _originalAddress = '';

  String _originalProfilePhotoUrl = '';

  bool _originalShowPasswordFields = false;

  String _profilePhotoUrl = '';

  File? _selectedProfilePhoto;

  bool _removeProfilePhoto = false;

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

    _birthDateController.dispose();

    _genderController.dispose();

    _nationalIdController.dispose();

    _countryController.dispose();

    _governorateController.dispose();

    _cityController.dispose();

    _addressController.dispose();

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

        _birthDateController.text =
            userData['birthDate']?.toString().trim() ?? '';

        _genderController.text = userData['gender']?.toString().trim() ?? '';

        _nationalIdController.text =
            userData['nationalId']?.toString().trim() ?? '';

        _countryController.text = userData['country']?.toString().trim() ?? '';

        _governorateController.text =
            userData['governorate']?.toString().trim() ?? '';

        _cityController.text = userData['city']?.toString().trim() ?? '';

        _addressController.text = userData['address']?.toString().trim() ?? '';

        _birthDate = (userData['birthDate']?.toString().trim() ?? '').isEmpty
            ? 'Not provided'
            : userData['birthDate']?.toString().trim() ?? '';

        _gender = (userData['gender']?.toString().trim() ?? '').isEmpty
            ? 'Not provided'
            : userData['gender']?.toString().trim() ?? '';

        _nationalIdNumber =
            (userData['nationalId']?.toString().trim() ?? '').isEmpty
            ? 'Not provided'
            : userData['nationalId']?.toString().trim() ?? '';

        _profilePhotoUrl =
            userData['profilePhotoUrl']?.toString().trim().isNotEmpty == true
            ? userData['profilePhotoUrl']?.toString().trim() ?? ''
            : (userData['photoUrl']?.toString().trim().isNotEmpty == true
                  ? userData['photoUrl']?.toString().trim() ?? ''
                  : (userData['imageUrl']?.toString().trim().isNotEmpty == true
                        ? userData['imageUrl']?.toString().trim() ?? ''
                        : (currentUser.photoURL?.trim().isNotEmpty == true
                              ? currentUser.photoURL!.trim()
                              : '')));

        _frontIdImageUrl =
            userData['frontNationalIdPhotoUrl']?.toString().trim().isNotEmpty ==
                true
            ? userData['frontNationalIdPhotoUrl']?.toString().trim()
            : (userData['frontIdImageUrl']?.toString().trim().isNotEmpty == true
                  ? userData['frontIdImageUrl']?.toString().trim()
                  : null);

        _backIdImageUrl =
            userData['backNationalIdPhotoUrl']?.toString().trim().isNotEmpty ==
                true
            ? userData['backNationalIdPhotoUrl']?.toString().trim()
            : (userData['backIdImageUrl']?.toString().trim().isNotEmpty == true
                  ? userData['backIdImageUrl']?.toString().trim()
                  : null);

        _originalFirstName = _firstNameController.text.trim();

        _originalSecondName = _secondNameController.text.trim();

        _originalEmail = _emailController.text.trim();

        _originalPhone = _phoneController.text.trim();

        _originalCountry = _countryController.text.trim();

        _originalGovernorate = _governorateController.text.trim();

        _originalCity = _cityController.text.trim();

        _originalAddress = _addressController.text.trim();

        _originalProfilePhotoUrl = _profilePhotoUrl.trim();

        _originalShowPasswordFields = false;

        _isLoadingData = false;
      });

      // Try to load ID images from Firebase Storage URLs if needed

      // For now, they're shown as read-only text fields with image display capability
    } catch (e) {
      if (mounted) {
        _showCenteredResultDialog(
          title: 'Profile Load Failed'.translate(),

          message: 'Error loading profile: $e'.translate(),

          isSuccess: false,
        );

        setState(() => _isLoadingData = false);
      }
    }
  }

  Future<void> _showCenteredResultDialog({
    required String title,

    required String message,

    required bool isSuccess,
  }) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,

      barrierDismissible: true,

      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.r),
          ),

          title: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,

                color: isSuccess ? Colors.green : Colors.red,
              ),

              SizedBox(width: 8.w),

              Expanded(
                child: Text(
                  title,

                  style: TextStyle(
                    fontWeight: FontWeight.w800,

                    color: AppColors.navyBlue,
                  ),
                ),
              ),
            ],
          ),

          content: Text(message),

          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),

              child: Text('OK'.translate()),
            ),
          ],
        );
      },
    );
  }

  void _showQuickStatusPopup({
    required String message,
    required bool isSuccess,
  }) {
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          backgroundColor: isSuccess ? Colors.green : const Color(0xFFC63F3F),
          content: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                color: Colors.white,
              ),
              SizedBox(width: 8.w),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  Future<bool> _validateUniquePersonalInfo(User currentUser) async {
    final firestore = FirebaseFirestore.instance;

    final normalizedEmail = _emailController.text.trim().toLowerCase();

    final normalizedPhone = _phoneController.text.trim();

    final checks = await Future.wait([
      firestore
          .collection('users')
          .where('emailLower', isEqualTo: normalizedEmail)
          .limit(2)
          .get(),

      firestore
          .collection('users')
          .where('email', isEqualTo: _emailController.text.trim())
          .limit(2)
          .get(),

      firestore
          .collection('users')
          .where('phone', isEqualTo: normalizedPhone)
          .limit(2)
          .get(),
    ]);

    bool hasEmailConflict = false;

    bool hasPhoneConflict = false;

    for (final doc in checks[0].docs) {
      if (doc.id != currentUser.uid) {
        hasEmailConflict = true;
      }
    }

    for (final doc in checks[1].docs) {
      if (doc.id != currentUser.uid) {
        hasEmailConflict = true;
      }
    }

    for (final doc in checks[2].docs) {
      if (doc.id != currentUser.uid) {
        hasPhoneConflict = true;
      }
    }

    if (hasEmailConflict || hasPhoneConflict) {
      setState(() {
        if (hasEmailConflict) {
          _emailError = 'This email is already used by another account.'
              .translate();
        }

        if (hasPhoneConflict) {
          _phoneError = 'This phone number is already used by another account.'
              .translate();
        }
      });

      return false;
    }

    return true;
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

  bool get _hasPersonalInfoChanges {
    final currentFirstName = _firstNameController.text.trim();

    final currentSecondName = _secondNameController.text.trim();

    final currentEmail = _emailController.text.trim().toLowerCase();

    final originalEmail = _originalEmail.trim().toLowerCase();

    final currentPhone = _phoneController.text.trim();

    final currentCountry = _countryController.text.trim();

    final currentGovernorate = _governorateController.text.trim();

    final currentCity = _cityController.text.trim();

    final currentAddress = _addressController.text.trim();

    final hasPhotoChanges =
        _selectedProfilePhoto != null ||
        _removeProfilePhoto ||
        _profilePhotoUrl.trim() != _originalProfilePhotoUrl.trim();

    return currentFirstName != _originalFirstName ||
        currentSecondName != _originalSecondName ||
        currentEmail != originalEmail ||
        currentPhone != _originalPhone ||
        currentCountry != _originalCountry ||
        currentGovernorate != _originalGovernorate ||
        currentCity != _originalCity ||
        currentAddress != _originalAddress ||
        hasPhotoChanges ||
        _showPasswordFields != _originalShowPasswordFields ||
        _currentPasswordController.text.isNotEmpty ||
        _newPasswordController.text.isNotEmpty ||
        _confirmPasswordController.text.isNotEmpty;
  }

  bool get _canSaveChanges =>
      !_isLoadingData && !_isSubmitting && _hasPersonalInfoChanges;

  Future<String?> _showSavePasswordPopup() async {
    if (!mounted) {
      return null;
    }

    final passwordController = TextEditingController();

    bool obscurePassword = true;

    final password = await showDialog<String>(
      context: context,

      barrierDismissible: true,

      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canSubmit = passwordController.text.trim().isNotEmpty;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18.r),
              ),

              title: Text(
                'Confirm Password'.translate(),

                style: TextStyle(
                  fontWeight: FontWeight.w800,

                  color: AppColors.navyBlue,
                ),
              ),

              content: Column(
                mainAxisSize: MainAxisSize.min,

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    'Enter your account password to save these changes.'
                        .translate(),
                  ),

                  SizedBox(height: 12.h),

                  TextField(
                    controller: passwordController,

                    obscureText: obscurePassword,

                    onChanged: (_) => setDialogState(() {}),

                    decoration: InputDecoration(
                      labelText: 'Account Password'.translate(),

                      suffixIcon: IconButton(
                        onPressed: () {
                          setDialogState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },

                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),

                  child: Text('Cancel'.translate()),
                ),

                ElevatedButton(
                  onPressed: canSubmit
                      ? () => Navigator.of(
                          context,
                        ).pop(passwordController.text.trim())
                      : null,

                  child: Text('Continue'.translate()),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();

    return password;
  }

  Future<void> _handleSaveChanges() async {
    if (!_validateForm() || !_canSaveChanges) {
      return;
    }

    final password = await _showSavePasswordPopup();

    if (password == null || password.isEmpty) {
      return;
    }

    await _updateProfile(password);
  }

  Future<void> _changeProfilePhoto() async {
    if (_isSubmitting) {
      return;
    }

    final selection = await showModalBottomSheet<String>(
      context: context,

      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),

                title: Text('Take photo'.translate()),

                onTap: () => Navigator.of(context).pop('camera'),
              ),

              ListTile(
                leading: const Icon(Icons.photo_library_outlined),

                title: Text('Choose from gallery'.translate()),

                onTap: () => Navigator.of(context).pop('gallery'),
              ),

              if (_profilePhotoUrl.trim().isNotEmpty ||
                  _selectedProfilePhoto != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline),

                  title: Text('Remove photo'.translate()),

                  onTap: () => Navigator.of(context).pop('remove'),
                ),
            ],
          ),
        );
      },
    );

    if (selection == null || !mounted) {
      return;
    }

    if (selection == 'remove') {
      setState(() {
        _selectedProfilePhoto = null;

        _profilePhotoUrl = '';

        _removeProfilePhoto = true;
      });

      return;
    }

    final source = selection == 'camera'
        ? ImageSource.camera
        : ImageSource.gallery;

    final pickedFile = await _imagePicker.pickImage(
      source: source,

      imageQuality: 78,

      maxWidth: 1200,
    );

    if (pickedFile == null || !mounted) {
      return;
    }

    setState(() {
      _selectedProfilePhoto = File(pickedFile.path);

      _removeProfilePhoto = false;
    });
  }

  Future<void> _updateProfile(String savePassword) async {
    final currentUser = _currentUser;

    if (currentUser == null) {
      if (mounted) {
        _showQuickStatusPopup(
          message: 'Please sign in again.'.translate(),
          isSuccess: false,
        );
      }

      return;
    }

    if (_isSubmitting || !_canSaveChanges) {
      return;
    }

    if (currentUser.email == null || currentUser.email!.trim().isEmpty) {
      _showQuickStatusPopup(
        message: 'This account cannot be verified with password.'.translate(),
        isSuccess: false,
      );

      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final saveCredential = EmailAuthProvider.credential(
        email: currentUser.email!,

        password: savePassword,
      );

      await currentUser.reauthenticateWithCredential(saveCredential);

      final firestore = FirebaseFirestore.instance;

      final isUnique = await _validateUniquePersonalInfo(currentUser);

      if (!isUnique) {
        setState(() => _isSubmitting = false);
        _showQuickStatusPopup(
          message: 'Email or phone is already in use by another account.'
              .translate(),
          isSuccess: false,
        );

        return;
      }

      // Update password if needed

      if (_showPasswordFields && _newPasswordController.text.isNotEmpty) {
        try {
          await currentUser.updatePassword(_newPasswordController.text);
        } on FirebaseAuthException catch (e) {
          if (mounted) {
            _showQuickStatusPopup(
              message:
                  (e.code == 'wrong-password'
                          ? 'Current password is incorrect'
                          : e.message ?? 'Error updating password')
                      .translate(),
              isSuccess: false,
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
            _showQuickStatusPopup(
              message: (e.message ?? 'Error updating email').translate(),
              isSuccess: false,
            );
          }

          setState(() => _isSubmitting = false);

          return;
        }
      }

      var resolvedProfilePhotoUrl = _profilePhotoUrl.trim();

      if (_removeProfilePhoto) {
        resolvedProfilePhotoUrl = '';
      }

      if (_selectedProfilePhoto != null) {
        final storageService = const SupabaseStorageService();

        final uploaded = await storageService.uploadMedia(
          file: _selectedProfilePhoto!,

          folderPath: 'users/${currentUser.uid}/files',

          fileName:
              'profile_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        if (uploaded == null || uploaded.trim().isEmpty) {
          setState(() => _isSubmitting = false);
          _showQuickStatusPopup(
            message: 'Could not upload profile photo. Please try again.'
                .translate(),
            isSuccess: false,
          );

          return;
        }

        resolvedProfilePhotoUrl = uploaded.trim();
      }

      // Update Firestore user document

      await firestore.collection('users').doc(currentUser.uid).set(<
        String,

        dynamic
      >{
        'firstName': _firstNameController.text.trim(),

        'secondName': _secondNameController.text.trim(),

        'fullName':
            '${_firstNameController.text.trim()} ${_secondNameController.text.trim()}'
                .trim(),

        'email': _emailController.text.trim(),

        'emailLower': _emailController.text.trim().toLowerCase(),

        'phone': _phoneController.text.trim(),

        'country': _countryController.text.trim(),

        'governorate': _governorateController.text.trim(),

        'city': _cityController.text.trim(),

        'address': _addressController.text.trim(),

        'profilePhotoUrl': resolvedProfilePhotoUrl,

        'photoUrl': resolvedProfilePhotoUrl,

        'imageUrl': resolvedProfilePhotoUrl,

        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final savedSnapshot = await firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final savedData = savedSnapshot.data() ?? <String, dynamic>{};
      final isVerified =
          savedData['firstName']?.toString().trim() ==
              _firstNameController.text.trim() &&
          savedData['secondName']?.toString().trim() ==
              _secondNameController.text.trim() &&
          savedData['phone']?.toString().trim() == _phoneController.text.trim();
      if (!isVerified) {
        throw Exception('Could not verify profile save in Firestore.');
      }

      _originalFirstName = _firstNameController.text.trim();

      _originalSecondName = _secondNameController.text.trim();

      _originalEmail = _emailController.text.trim();

      _originalPhone = _phoneController.text.trim();

      _originalCountry = _countryController.text.trim();

      _originalGovernorate = _governorateController.text.trim();

      _originalCity = _cityController.text.trim();

      _originalAddress = _addressController.text.trim();

      _profilePhotoUrl = resolvedProfilePhotoUrl;

      _originalProfilePhotoUrl = resolvedProfilePhotoUrl;

      _selectedProfilePhoto = null;

      _removeProfilePhoto = false;

      _originalShowPasswordFields = false;

      _showPasswordFields = false;

      _currentPasswordController.clear();

      _newPasswordController.clear();

      _confirmPasswordController.clear();

      _currentPasswordError = null;

      _newPasswordError = null;

      _confirmPasswordError = null;

      if (mounted) {
        _showQuickStatusPopup(
          message: 'Profile updated successfully'.translate(),
          isSuccess: true,
        );

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        final message = e is FirebaseAuthException
            ? (e.code == 'wrong-password' || e.code == 'invalid-credential'
                  ? 'The password is incorrect.'.translate()
                  : (e.message ?? 'Error saving profile').translate())
            : 'Error: $e'.translate();
        _showQuickStatusPopup(message: message, isSuccess: false);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showDeleteAccountPopup() async {
    if (_isSubmitting || !mounted) {
      return;
    }

    final passwordController = TextEditingController();

    bool showPasswordStep = false;

    bool obscurePassword = true;

    final password = await showDialog<String>(
      context: context,

      barrierDismissible: true,

      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canDelete = passwordController.text.trim().isNotEmpty;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18.r),
              ),

              title: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,

                    color: const Color(0xFFC63F3F),

                    size: 24.sp,
                  ),

                  SizedBox(width: 8.w),

                  Expanded(
                    child: Text(
                      'Delete Account'.translate(),

                      style: TextStyle(
                        fontWeight: FontWeight.w800,

                        color: AppColors.navyBlue,
                      ),
                    ),
                  ),
                ],
              ),

              content: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),

                child: showPasswordStep
                    ? Column(
                        key: const ValueKey('delete_password_step'),

                        mainAxisSize: MainAxisSize.min,

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            'Please enter your account password to activate account deletion.'
                                .translate(),
                          ),

                          SizedBox(height: 12.h),

                          TextField(
                            controller: passwordController,

                            obscureText: obscurePassword,

                            onChanged: (_) => setDialogState(() {}),

                            decoration: InputDecoration(
                              labelText: 'Account Password'.translate(),

                              suffixIcon: IconButton(
                                onPressed: () {
                                  setDialogState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },

                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 10.h),

                          Text(
                            'You can still cancel before final deletion.'
                                .translate(),

                            style: TextStyle(
                              fontSize: 12.sp,

                              color: AppColors.textDark.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        key: const ValueKey('delete_warning_step'),

                        mainAxisSize: MainAxisSize.min,

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            'Before deleting your account, please read this warning carefully:'
                                .translate(),

                            style: TextStyle(
                              fontWeight: FontWeight.w700,

                              color: AppColors.navyBlue,
                            ),
                          ),

                          SizedBox(height: 10.h),

                          Text(
                            '• This action is permanent and cannot be undone.'
                                .translate(),
                          ),

                          SizedBox(height: 6.h),

                          Text(
                            '• Your profile and account access will be removed.'
                                .translate(),
                          ),

                          SizedBox(height: 6.h),

                          Text(
                            '• You will need to create a new account to use this app again.'
                                .translate(),
                          ),
                        ],
                      ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    if (showPasswordStep) {
                      setDialogState(() {
                        showPasswordStep = false;
                      });

                      return;
                    }

                    Navigator.of(context).pop();
                  },

                  child: Text(
                    showPasswordStep
                        ? 'Back'.translate()
                        : 'Cancel'.translate(),
                  ),
                ),

                ElevatedButton(
                  onPressed: !showPasswordStep
                      ? () {
                          setDialogState(() {
                            showPasswordStep = true;
                          });
                        }
                      : canDelete
                      ? () => Navigator.of(
                          context,
                        ).pop(passwordController.text.trim())
                      : null,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC63F3F),

                    foregroundColor: Colors.white,
                  ),

                  child: Text(
                    !showPasswordStep
                        ? 'Continue'.translate()
                        : 'Delete Account'.translate(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();

    if (password == null || password.isEmpty) {
      return;
    }

    await _deleteAccount(password);
  }

  Future<void> _deleteAccount(String password) async {
    final currentUser = _currentUser;

    if (currentUser == null) {
      await _showCenteredResultDialog(
        title: 'Session Expired'.translate(),

        message: 'Please sign in again.'.translate(),

        isSuccess: false,
      );

      return;
    }

    if (currentUser.email == null || currentUser.email!.trim().isEmpty) {
      await _showCenteredResultDialog(
        title: 'Delete Failed'.translate(),

        message: 'This account cannot be verified with password.'.translate(),

        isSuccess: false,
      );

      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,

        password: password,
      );

      await currentUser.reauthenticateWithCredential(credential);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .delete();

      await currentUser.delete();

      if (!mounted) return;

      await _showCenteredResultDialog(
        title: 'Account Deleted'.translate(),

        message: 'Your account has been deleted successfully.'.translate(),

        isSuccess: true,
      );

      if (!mounted) return;

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.auth, (route) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      final message = switch (e.code) {
        'wrong-password' ||
        'invalid-credential' => 'The password is incorrect.'.translate(),

        'requires-recent-login' =>
          'Please sign in again, then try deleting your account.'.translate(),

        _ => (e.message ?? 'Unable to delete account right now.').translate(),
      };

      await _showCenteredResultDialog(
        title: 'Delete Failed'.translate(),

        message: message,

        isSuccess: false,
      );
    } catch (e) {
      if (!mounted) return;

      await _showCenteredResultDialog(
        title: 'Delete Failed'.translate(),

        message: 'Error: $e'.translate(),

        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final isTablet = screenWidth > 700;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F1726)
          : const Color(0xFFF4F7FB),

      body: SafeArea(
        child: _isLoadingData
            ? const Center(child: CircularProgressIndicator())
            : _currentUser == null
            ? Center(
                child: Padding(
                  padding: EdgeInsets.all(24.r),

                  child: Container(
                    padding: EdgeInsets.all(18.r),

                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF24344C) : Colors.white,

                      borderRadius: BorderRadius.circular(22.r),

                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2A3550)
                            : const Color(0xFFE6ECF5),
                      ),

                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF0D2345,
                          ).withValues(alpha: 0.06),

                          blurRadius: 18,

                          offset: Offset(0, 10.h),
                        ),
                      ],
                    ),

                    child: Column(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        Container(
                          width: 60.w,

                          height: 60.h,

                          decoration: BoxDecoration(
                            color: AppColors.navyBlue.withValues(alpha: 0.08),

                            shape: BoxShape.circle,
                          ),

                          child: Icon(
                            Icons.lock_outline_rounded,

                            color: AppColors.navyBlue,

                            size: 30.sp,
                          ),
                        ),

                        SizedBox(height: 14.h),

                        Text(
                          'No signed in user found'.translate(),

                          textAlign: TextAlign.center,

                          style: GoogleFonts.cairo(
                            fontSize: 18.sp,

                            fontWeight: FontWeight.w800,

                            color: AppColors.navyBlue,
                          ),
                        ),

                        SizedBox(height: 8.h),

                        Text(
                          'Please login again to edit your profile.'
                              .translate(),

                          textAlign: TextAlign.center,

                          style: TextStyle(
                            fontSize: 14.sp,

                            height: 1.35,

                            color: (isDark ? Colors.white : AppColors.textDark)
                                .withValues(alpha: 0.72),
                          ),
                        ),

                        SizedBox(height: 14.h),

                        SizedBox(
                          height: 46.h,

                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).maybePop(),

                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navyBlue,

                              foregroundColor: Colors.white,

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                            ),

                            child: Text(
                              'Back'.translate(),

                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    _EditProfileHeader(
                      title: 'Edit Profile'.translate(),

                      subtitle:
                          'Update your personal details and security settings'
                              .translate(),
                    ),

                    Transform.translate(
                      offset: Offset(0, -58.h),

                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),

                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isTablet ? 700 : double.infinity,
                            ),

                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,

                              children: [
                                _buildProfileFormFields(),

                                SizedBox(height: 24.h),

                                _buildSaveActions(),

                                SizedBox(height: 24.h),
                              ],
                            ),
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

  Widget _buildProfileFormFields() {
    return Column(
      children: [
        _ModernSectionCard(
          title: 'Profile Photo'.translate(),

          icon: Icons.photo_camera_back_outlined,

          child: Column(
            children: [
              SizedBox(height: 10.h),

              _buildProfilePhotoEditor(),
            ],
          ),
        ),

        SizedBox(height: 14.h),

        _ModernSectionCard(
          title: 'Personal Information'.translate(),

          icon: Icons.person_outline_rounded,

          child: Column(
            children: [
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

        SizedBox(height: 14.h),

        _ModernSectionCard(
          title: 'Change Password'.translate(),

          icon: Icons.lock_outline_rounded,

          trailing: GestureDetector(
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

            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),

              width: 36.w,

              height: 36.h,

              decoration: BoxDecoration(
                color: AppColors.navyBlue.withValues(alpha: 0.08),

                borderRadius: BorderRadius.circular(12.r),
              ),

              child: Icon(
                _showPasswordFields
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,

                color: AppColors.navyBlue,
              ),
            ),
          ),

          child: AnimatedCrossFade(
            firstChild: Padding(
              padding: EdgeInsets.only(top: 8.h),

              child: Align(
                alignment: Alignment.centerLeft,

                child: Text(
                  'Tap to change your password'.translate(),

                  style: TextStyle(
                    color: AppColors.textDark.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),

            secondChild: Column(
              children: [
                SizedBox(height: 12.h),

                _buildPasswordField(
                  controller: _currentPasswordController,

                  label: 'Current Password'.translate(),

                  error: _currentPasswordError,

                  showPassword: _showCurrentPassword,

                  onToggle: () {
                    setState(
                      () => _showCurrentPassword = !_showCurrentPassword,
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
                    setState(() => _showNewPassword = !_showNewPassword);
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
                      () => _showConfirmPassword = !_showConfirmPassword,
                    );
                  },

                  onChanged: (_) {
                    setState(() => _confirmPasswordError = null);
                  },
                ),
              ],
            ),

            crossFadeState: _showPasswordFields
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,

            duration: const Duration(milliseconds: 220),
          ),
        ),

        SizedBox(height: 14.h),

        _ModernSectionCard(
          title: 'Account Information'.translate(),

          icon: Icons.badge_outlined,

          child: Padding(
            padding: EdgeInsets.only(top: 8.h),

            child: Column(
              children: [
                _buildAccountInfoTile(
                  icon: Icons.cake_outlined,

                  label: 'Birth Date'.translate(),

                  value: _birthDate,
                ),

                SizedBox(height: 10.h),

                _buildAccountInfoTile(
                  icon: Icons.wc_outlined,

                  label: 'Gender'.translate(),

                  value: _gender,
                ),

                SizedBox(height: 10.h),

                _buildAccountInfoTile(
                  icon: Icons.badge_outlined,

                  label: 'National ID Number'.translate(),

                  value: _nationalIdNumber,
                ),

                SizedBox(height: 12.h),

                _buildTextField(
                  controller: _countryController,

                  label: 'Country'.translate(),

                  onChanged: (_) => setState(() {}),
                ),

                SizedBox(height: 12.h),

                _buildTextField(
                  controller: _governorateController,

                  label: 'Governorate'.translate(),

                  onChanged: (_) => setState(() {}),
                ),

                SizedBox(height: 12.h),

                _buildTextField(
                  controller: _cityController,

                  label: 'City'.translate(),

                  onChanged: (_) => setState(() {}),
                ),

                SizedBox(height: 12.h),

                _buildTextField(
                  controller: _addressController,

                  label: 'Address'.translate(),

                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 14.h),

        _ModernSectionCard(
          title: 'National ID Documents'.translate(),

          icon: Icons.credit_card_outlined,

          child: Column(
            children: [
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveActions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final canSaveChanges = _canSaveChanges;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.of(context).maybePop(),

                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.navyBlue, width: 1.6),

                  foregroundColor: AppColors.navyBlue,

                  backgroundColor: isDark
                      ? const Color(0xFF1C2A40)
                      : Colors.white,

                  padding: EdgeInsets.symmetric(vertical: 14.h),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),

                child: Text(
                  'Cancel'.translate(),

                  style: GoogleFonts.cairo(
                    fontSize: 15.sp,

                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

            SizedBox(width: 12.w),

            Expanded(
              child: ElevatedButton(
                onPressed: canSaveChanges ? _handleSaveChanges : null,

                style: ElevatedButton.styleFrom(
                  backgroundColor: canSaveChanges
                      ? AppColors.navyBlue
                      : (isDark
                            ? const Color(0xFF41516B)
                            : const Color(0xFFB8C4D7)),

                  foregroundColor: Colors.white,

                  elevation: 0,

                  padding: EdgeInsets.symmetric(vertical: 14.h),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),

                child: _isSubmitting
                    ? SizedBox(
                        height: 20.h,

                        width: 20.w,

                        child: const CircularProgressIndicator(
                          strokeWidth: 2,

                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        'Save Changes'.translate(),

                        style: GoogleFonts.cairo(
                          fontSize: 15.sp,

                          fontWeight: FontWeight.w800,

                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),

        SizedBox(height: 12.h),

        SizedBox(
          width: double.infinity,

          child: OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _showDeleteAccountPopup,

            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFC63F3F), width: 1.4),

              foregroundColor: const Color(0xFFC63F3F),

              backgroundColor: isDark
                  ? const Color(0xFF3A2830)
                  : const Color(0xFFFFF5F5),

              padding: EdgeInsets.symmetric(vertical: 13.h),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),

            icon: const Icon(Icons.delete_forever),

            label: Text(
              'Delete Account'.translate(),

              style: GoogleFonts.cairo(
                fontSize: 14.sp,

                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ModernSectionCard({
    required String title,

    required IconData icon,

    required Widget child,

    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(16.r),

      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24344C) : Colors.white,

        borderRadius: BorderRadius.circular(22.r),

        border: Border.all(
          color: isDark ? const Color(0xFF2A3550) : const Color(0xFFE6ECF5),
        ),

        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D2345).withValues(alpha: 0.05),

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
              Container(
                width: 38.w,

                height: 38.h,

                decoration: BoxDecoration(
                  color: AppColors.navyBlue.withValues(alpha: 0.08),

                  borderRadius: BorderRadius.circular(12.r),
                ),

                child: Icon(icon, color: AppColors.navyBlue, size: 20.sp),
              ),

              SizedBox(width: 10.w),

              Expanded(
                child: Text(
                  title,

                  style: GoogleFonts.cairo(
                    fontSize: 16.sp,

                    fontWeight: FontWeight.w800,

                    color: AppColors.navyBlue,
                  ),
                ),
              ),

              ?trailing,
            ],
          ),

          child,
        ],
      ),
    );
  }

  Widget _buildProfilePhotoEditor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasNetworkImage = _profilePhotoUrl.trim().isNotEmpty;

    final hasLocalImage = _selectedProfilePhoto != null;

    return Column(
      children: [
        Container(
          width: 108.w,

          height: 108.h,

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            border: Border.all(
              color: isDark ? const Color(0xFF3D5270) : const Color(0xFFE1E8F4),

              width: 2,
            ),

            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D2345).withValues(alpha: 0.1),

                blurRadius: 14,

                offset: Offset(0, 8.h),
              ),
            ],
          ),

          child: ClipOval(
            child: hasLocalImage
                ? Image.file(_selectedProfilePhoto!, fit: BoxFit.cover)
                : hasNetworkImage
                ? Image.network(
                    _profilePhotoUrl,

                    fit: BoxFit.cover,

                    errorBuilder: (_, _, _) => Container(
                      color: isDark
                          ? const Color(0xFF1C2A40)
                          : const Color(0xFFF5F8FD),

                      child: Icon(
                        Icons.person_rounded,

                        size: 54.sp,

                        color: AppColors.navyBlue,
                      ),
                    ),
                  )
                : Container(
                    color: isDark
                        ? const Color(0xFF1C2A40)
                        : const Color(0xFFF5F8FD),

                    child: Icon(
                      Icons.person_rounded,

                      size: 54.sp,

                      color: AppColors.navyBlue,
                    ),
                  ),
          ),
        ),

        SizedBox(height: 12.h),

        Wrap(
          spacing: 10.w,

          runSpacing: 8.h,

          alignment: WrapAlignment.center,

          children: [
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _changeProfilePhoto,

              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navyBlue,

                foregroundColor: Colors.white,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),

              icon: const Icon(Icons.edit_rounded),

              label: Text('Change Photo'.translate()),
            ),

            if (hasNetworkImage || hasLocalImage)
              OutlinedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        setState(() {
                          _selectedProfilePhoto = null;

                          _profilePhotoUrl = '';

                          _removeProfilePhoto = true;
                        });
                      },

                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC63F3F),

                  side: const BorderSide(color: Color(0xFFC63F3F)),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),

                icon: const Icon(Icons.delete_outline_rounded),

                label: Text('Remove'.translate()),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,

    required String label,

    String? error,

    TextInputType keyboardType = TextInputType.text,

    required ValueChanged<String> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,

      keyboardType: keyboardType,

      onChanged: onChanged,

      decoration: InputDecoration(
        labelText: label,

        labelStyle: TextStyle(
          color: isDark
              ? Colors.white.withValues(alpha: 0.78)
              : AppColors.navyBlue.withValues(alpha: 0.72),
        ),

        filled: true,

        fillColor: isDark ? const Color(0xFF1C2A40) : const Color(0xFFF8FAFD),

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),

          borderSide: BorderSide(
            color: error == null
                ? (isDark ? const Color(0xFF334866) : const Color(0xFFE2E8F0))
                : Colors.red,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),

          borderSide: BorderSide(
            color: error == null ? AppColors.legalGold : Colors.red,

            width: 1.6,
          ),
        ),

        errorText: error?.translate(),

        isDense: true,

        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      ),

      style: TextStyle(color: isDark ? Colors.white : AppColors.textDark),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,

      obscureText: !showPassword,

      onChanged: onChanged,

      decoration: InputDecoration(
        labelText: label,

        labelStyle: TextStyle(
          color: isDark
              ? Colors.white.withValues(alpha: 0.78)
              : AppColors.navyBlue.withValues(alpha: 0.72),
        ),

        filled: true,

        fillColor: isDark ? const Color(0xFF1C2A40) : const Color(0xFFF8FAFD),

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),

          borderSide: BorderSide(
            color: error == null
                ? (isDark ? const Color(0xFF334866) : const Color(0xFFE2E8F0))
                : Colors.red,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),

          borderSide: BorderSide(
            color: error == null ? AppColors.legalGold : Colors.red,

            width: 1.6,
          ),
        ),

        suffixIcon: IconButton(
          onPressed: onToggle,

          icon: Icon(
            showPassword ? Icons.visibility : Icons.visibility_off,

            color: isDark ? const Color(0xFFD8E4FF) : Colors.grey[600],
          ),
        ),

        errorText: error?.translate(),

        isDense: true,

        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      ),

      style: TextStyle(color: isDark ? Colors.white : AppColors.textDark),
    );
  }

  Widget _buildAccountInfoTile({
    required IconData icon,

    required String label,

    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,

      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),

      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2A40) : const Color(0xFFF8FAFD),

        borderRadius: BorderRadius.circular(14.r),

        border: Border.all(
          color: isDark ? const Color(0xFF334866) : const Color(0xFFE2E8F0),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 36.w,

            height: 36.h,

            decoration: BoxDecoration(
              color: AppColors.navyBlue.withValues(alpha: 0.08),

              borderRadius: BorderRadius.circular(11.r),
            ),

            child: Icon(icon, size: 18.sp, color: AppColors.navyBlue),
          ),

          SizedBox(width: 10.w),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  label,

                  style: TextStyle(
                    fontSize: 11.sp,

                    fontWeight: FontWeight.w600,

                    color: (isDark ? Colors.white : AppColors.textDark)
                        .withValues(alpha: 0.62),
                  ),
                ),

                SizedBox(height: 2.h),

                Text(
                  value,

                  style: TextStyle(
                    fontSize: 13.sp,

                    fontWeight: FontWeight.w700,

                    color: isDark ? Colors.white : AppColors.navyBlue,
                  ),
                ),
              ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 150.h,

      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2A40) : const Color(0xFFF8FAFD),

        borderRadius: BorderRadius.circular(16.r),

        border: Border.all(
          color: isDark ? const Color(0xFF334866) : const Color(0xFFE2E8F0),
        ),
      ),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),

        child: imageUrl == null || imageUrl.isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Icon(
                    Icons.sd_card_outlined,

                    size: 40.sp,

                    color: AppColors.textDark.withValues(alpha: 0.3),
                  ),

                  SizedBox(height: 8.h),

                  Text(
                    label,

                    style: TextStyle(
                      fontSize: 12.sp,

                      color: AppColors.textDark.withValues(alpha: 0.6),
                    ),
                  ),

                  SizedBox(height: 4.h),

                  Text(
                    'Not available'.translate(),

                    style: TextStyle(
                      fontSize: 11.sp,

                      color: AppColors.textDark.withValues(alpha: 0.45),
                    ),
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

class _EditProfileHeader extends StatelessWidget {
  final String title;

  final String subtitle;

  const _EditProfileHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SizedBox(
      height: size.height * 0.30,

      width: double.infinity,

      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.95,

          child: Container(
            padding: EdgeInsets.all(18.r),

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24.r),

              gradient: const LinearGradient(
                colors: [Color(0xFF042A52), Color(0xFF0B5E55)],

                begin: Alignment.topLeft,

                end: Alignment.bottomRight,
              ),

              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D2345).withValues(alpha: 0.22),

                  blurRadius: 22,

                  offset: Offset(0, 12.h),
                ),
              ],
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    Container(
                      width: 42.w,

                      height: 42.h,

                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),

                        borderRadius: BorderRadius.circular(14.r),
                      ),

                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,

                          color: Colors.white,
                        ),

                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),

                    SizedBox(width: 12.w),

                    Expanded(
                      child: Text(
                        title,

                        style: GoogleFonts.cairo(
                          color: Colors.white,

                          fontSize: 24.sp,

                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8.h),

                Text(
                  subtitle,

                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),

                    height: 1.35,
                  ),
                ),

                SizedBox(height: 16.h),

                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,

                    vertical: 14.h,
                  ),

                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),

                    borderRadius: BorderRadius.circular(18.r),

                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),

                  child: Row(
                    children: [
                      const Icon(Icons.person_rounded, color: Colors.white),

                      SizedBox(width: 10.w),

                      Expanded(
                        child: Text(
                          'Keep your account information up to date'
                              .translate(),

                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
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
      ),
    );
  }
}
