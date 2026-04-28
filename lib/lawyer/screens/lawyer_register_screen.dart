import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mezaan/shared/localization/localization_controller.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';
import 'package:mezaan/shared/services/supabase_storage_service.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/widgets/language_toggle_button.dart';
import 'package:mezaan/lawyer/screens/lawyer_onboarding_screen.dart';

class LawyerRegisterScreen extends StatefulWidget {
  const LawyerRegisterScreen({super.key});

  @override
  State<LawyerRegisterScreen> createState() => _LawyerRegisterScreenState();
}

class _LawyerRegisterScreenState extends State<LawyerRegisterScreen> {
  static const List<String> _genderOptions = <String>['Male', 'Female'];

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _secondNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _licenseNumberController =
      TextEditingController();
  final TextEditingController _nationalIdController = TextEditingController();
  final TextEditingController _specializationController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController(
    text: '+2',
  );
  final TextEditingController _countryController = TextEditingController(
    text: 'Egypt',
  );
  final TextEditingController _addressController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  DateTime? _selectedDob;
  XFile? _licenseFrontImage;
  XFile? _licenseBackImage;
  XFile? _nationalIdFrontImage;
  XFile? _nationalIdBackImage;
  XFile? _profileImage;
  bool _isBelowRequiredAge = false;
  bool _isSubmitting = false;
  bool _isLoadingSpecializations = true;
  String? _selectedGender;
  String? _selectedGovernorate;
  String? _selectedCity;
  Map<String, List<String>> _governoratesWithCities = <String, List<String>>{};
  final List<String> _selectedSpecializations = <String>[];
  List<String> _specializationOptions = <String>[];
  String? _specializationOptionsError;

  String? _firstNameError;
  String? _secondNameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _dobError;
  String? _licenseNumberError;
  String? _nationalIdError;
  String? _specializationError;
  String? _phoneError;
  String? _countryError;
  String? _governorateError;
  String? _cityError;
  String? _addressError;
  String? _genderError;
  String? _licenseFrontImageError;
  String? _licenseBackImageError;
  String? _nationalIdFrontImageError;
  String? _nationalIdBackImageError;
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
    _nationalIdController.dispose();
    _specializationController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSpecializationOptions();
    _loadGovernoratesFromFirebase();
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
      lastDate: DateTime(now.year - 23, now.month, now.day),
    );

    if (selected == null) return;

    final age = _calculateAge(selected);
    setState(() {
      _selectedDob = selected;
      _dobController.text =
          '${selected.day.toString().padLeft(2, '0')}/${selected.month.toString().padLeft(2, '0')}/${selected.year}';
      _isBelowRequiredAge = age <= 22;
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

  Future<void> _captureLicenseFrontImage() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (photo == null) return;

    setState(() {
      _licenseFrontImage = photo;
      _licenseFrontImageError = null;
    });
  }

  Future<void> _captureLicenseBackImage() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (photo == null) return;

    setState(() {
      _licenseBackImage = photo;
      _licenseBackImageError = null;
    });
  }

  Future<void> _captureNationalIdFrontImage() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (photo == null) return;

    setState(() {
      _nationalIdFrontImage = photo;
      _nationalIdFrontImageError = null;
    });
  }

  Future<void> _captureNationalIdBackImage() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (photo == null) return;

    setState(() {
      _nationalIdBackImage = photo;
      _nationalIdBackImageError = null;
    });
  }

  Future<void> _pickProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text('Take photo'.translate()),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('Choose from gallery'.translate()),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            if (_profileImage != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  'Remove current photo'.translate(),
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _profileImage = null;
                  });
                },
              ),
          ],
        ),
      ),
    );

    if (source == null) {
      return;
    }

    final selectedFile = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.front,
    );

    if (selectedFile == null || !mounted) {
      return;
    }

    setState(() {
      _profileImage = selectedFile;
      _profileImageError = null;
    });
  }

  Future<void> _showSpecializationPicker() async {
    if (_isLoadingSpecializations) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loading specializations...'.translate())),
      );
      return;
    }

    if (_specializationOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No specialization options are available right now.'.translate(),
          ),
        ),
      );
      return;
    }

    final initialSelected = _selectedSpecializations.toSet();
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        final tempSelected = initialSelected.toSet();
        return StatefulBuilder(
          builder: (context, setBottomState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 18.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select specializations'.translate(),
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navyBlue,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Choose one or more'.translate(),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: _specializationOptions.map((item) {
                            final selected = tempSelected.contains(item);
                            return FilterChip(
                              label: Text(item.translate()),
                              selected: selected,
                              showCheckmark: false,
                              selectedColor: AppColors.legalGold.withValues(
                                alpha: 0.22,
                              ),
                              backgroundColor: const Color(0xFFF5F7FA),
                              side: BorderSide(
                                color: selected
                                    ? AppColors.legalGold
                                    : const Color(0xFFE2E7EE),
                              ),
                              labelStyle: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? AppColors.navyBlue
                                    : AppColors.textDark,
                              ),
                              onSelected: (value) {
                                setBottomState(() {
                                  if (value) {
                                    tempSelected.add(item);
                                  } else {
                                    tempSelected.remove(item);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(tempSelected.toList()..sort()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navyBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text('Apply'.translate()),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _selectedSpecializations
        ..clear()
        ..addAll(result);
      _specializationController.text = _selectedSpecializations.join(', ');
      _specializationError = null;
    });
  }

  Future<void> _loadSpecializationOptions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('lawyer_specializations')
          .get();

      final loadedOptions =
          snapshot.docs
              .map((doc) {
                final data = doc.data();
                final name = data['name']?.toString().trim() ?? '';
                final title = data['title']?.toString().trim() ?? '';
                final sortOrder = data['sortOrder'];
                final label = name.isNotEmpty
                    ? name
                    : (title.isNotEmpty ? title : doc.id);
                final enabled = data['enabled'] != false;

                if (!enabled || label.isEmpty) {
                  return null;
                }

                return <String, Object?>{
                  'label': label,
                  'sortOrder': sortOrder is int ? sortOrder : 9999,
                };
              })
              .whereType<Map<String, Object?>>()
              .toList()
            ..sort((left, right) {
              final leftOrder = left['sortOrder'] as int;
              final rightOrder = right['sortOrder'] as int;
              final orderCompare = leftOrder.compareTo(rightOrder);
              if (orderCompare != 0) {
                return orderCompare;
              }
              return (left['label'] as String).toLowerCase().compareTo(
                (right['label'] as String).toLowerCase(),
              );
            });

      final options = loadedOptions
          .map((item) => item['label'] as String)
          .toList(growable: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _specializationOptions = options;
        _specializationOptionsError = null;
        _isLoadingSpecializations = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _specializationOptions = <String>[];
        _specializationOptionsError = error.toString();
        _isLoadingSpecializations = false;
      });
    }
  }

  Future<void> _loadGovernoratesFromFirebase() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('government')
          .get();

      final loaded = <String, List<String>>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name']?.toString().trim() ?? doc.id;
        final citiesRaw = data['cities'];
        final cities = <String>[];
        if (citiesRaw is List) {
          cities.addAll(citiesRaw.map((e) => e.toString()));
        }
        loaded[name] = cities..sort();
      }

      if (mounted) {
        setState(() {
          _governoratesWithCities = loaded;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _governorateError = 'Failed to load governorates';
        });
      }
    }
  }

  String _formatDateForApi(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<bool> _validateUniqueRegistrationIdentity() async {
    final emailLower = _emailController.text.trim().toLowerCase();
    final phone = _phoneController.text.trim();
    final nationalId = _nationalIdController.text.trim();

    final lawyersCollection = FirebaseFirestore.instance.collection('lawyers');

    final existingEmail = await lawyersCollection
        .where('emailLower', isEqualTo: emailLower)
        .limit(1)
        .get();
    if (existingEmail.docs.isNotEmpty) {
      return false;
    }

    final existingPhone = await lawyersCollection
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    if (existingPhone.docs.isNotEmpty) {
      return false;
    }

    final existingNationalId = await lawyersCollection
        .where('national_ID', isEqualTo: nationalId)
        .limit(1)
        .get();
    return existingNationalId.docs.isEmpty;
  }

  Future<String?> _uploadImageToStorage({
    required String uid,
    required XFile? file,
    required String fileName,
  }) async {
    if (file == null) {
      return null;
    }

    final storageService = const SupabaseStorageService();
    return storageService.uploadMedia(
      file: File(file.path),
      folderPath: 'lawyers/$uid/files',
      fileName: fileName,
    );
  }

  Future<void> _syncRegistrationToFirebase() async {
    final email = _emailController.text.trim();
    final emailLower = email.toLowerCase();
    final password = _passwordController.text;

    final isUnique = await _validateUniqueRegistrationIdentity();
    if (!isUnique) {
      throw Exception(
        'Email, phone number, or national ID is already registered. Please use unique values.',
      );
    }

    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);

    final firebaseUser = credential.user ?? FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      throw Exception('Firebase user not available after registration sync.');
    }

    debugPrint(
      'Starting lawyer Firestore sync for uid=${firebaseUser.uid} email=$email',
    );

    final profilePhotoUrl = await _uploadImageToStorage(
      uid: firebaseUser.uid,
      file: _profileImage,
      fileName: 'profile_photo.jpg',
    );
    final licenseFrontUrl = await _uploadImageToStorage(
      uid: firebaseUser.uid,
      file: _licenseFrontImage,
      fileName: 'license_front.jpg',
    );
    final licenseBackUrl = await _uploadImageToStorage(
      uid: firebaseUser.uid,
      file: _licenseBackImage,
      fileName: 'license_back.jpg',
    );
    final nationalFrontUrl = await _uploadImageToStorage(
      uid: firebaseUser.uid,
      file: _nationalIdFrontImage,
      fileName: 'national_id_front.jpg',
    );
    final nationalBackUrl = await _uploadImageToStorage(
      uid: firebaseUser.uid,
      file: _nationalIdBackImage,
      fileName: 'national_id_back.jpg',
    );

    final lawyerDocRef = FirebaseFirestore.instance
        .collection('lawyers')
        .doc(firebaseUser.uid);

    await lawyerDocRef
        .set(<String, dynamic>{
          'uid': firebaseUser.uid,
          'first_name': _firstNameController.text.trim(),
          'second_name': _secondNameController.text.trim(),
          'name':
              '${_firstNameController.text.trim()} ${_secondNameController.text.trim()}'
                  .trim(),
          'email': email,
          'emailLower': emailLower,
          'phone': _phoneController.text.trim(),
          'gender': _selectedGender ?? '',
          'national_ID': _nationalIdController.text.trim(),
          'specialization': _selectedSpecializations,
          'specializationText': _specializationController.text.trim(),
          'birthDate': _selectedDob != null
              ? _formatDateForApi(_selectedDob!)
              : '',
          'address': {
            'country': _countryController.text.trim(),
            'govern': _selectedGovernorate ?? '',
            'city': _selectedCity ?? '',
            'details': _addressController.text.trim(),
          },
          'license_ID': _licenseNumberController.text.trim(),
          'status': 'pending',
          'rating': 0,
          'profile_photo': profilePhotoUrl ?? '',
          'photo_national_ID': {
            'front_side': nationalFrontUrl ?? '',
            'back_side': nationalBackUrl ?? '',
          },
          'photo_license_ID': {
            'front_side': licenseFrontUrl ?? '',
            'back_side': licenseBackUrl ?? '',
          },
          'role': 'lawyer',
          'onboardingCompleted': false,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'source': 'lawyer_register_screen',
        }, SetOptions(merge: true))
        .timeout(const Duration(seconds: 20));

    final savedSnapshot = await lawyerDocRef.get().timeout(
      const Duration(seconds: 20),
    );

    if (!savedSnapshot.exists) {
      throw Exception('Lawyer Firestore document was not created.');
    }

    debugPrint('Lawyer Firestore sync complete for ${lawyerDocRef.path}');
  }

  String _firebaseRegisterErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Invalid email for Firebase account.';
      case 'weak-password':
        return 'Password is too weak for Firebase account.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is disabled in Firebase Auth.';
      case 'network-request-failed':
        return 'Firebase network error. Check internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'email-already-in-use':
        return 'Email is already in use.';
      default:
        return error.message ?? 'Firebase registration sync failed.';
    }
  }

  bool _validateForm() {
    final firstName = _firstNameController.text.trim();
    final secondName = _secondNameController.text.trim();
    final email = _emailController.text.trim();
    final nationalId = _nationalIdController.text.trim();
    final licenseNumber = _licenseNumberController.text.trim();
    final specialization = _specializationController.text.trim();
    final phone = _phoneController.text.trim();
    final country = _countryController.text.trim();
    final governorate = _selectedGovernorate ?? '';
    final city = _selectedCity ?? '';
    final address = _addressController.text.trim();

    String? firstNameError;
    String? secondNameError;
    String? emailError;
    String? passwordError;
    String? confirmPasswordError;
    String? dobError;
    String? licenseNumberError;
    String? nationalIdError;
    String? specializationError;
    String? phoneError;
    String? countryError;
    String? governorateError;
    String? cityError;
    String? addressError;
    String? genderError;
    String? licenseFrontImageError;
    String? licenseBackImageError;
    String? nationalIdFrontImageError;
    String? nationalIdBackImageError;
    String? profileImageError;

    if (firstName.isEmpty) {
      firstNameError = 'First name is required';
    }
    if (secondName.isEmpty) {
      secondNameError = 'Second name is required';
    }
    if (email.isEmpty) {
      emailError = 'Email is required';
    } else if (!email.toLowerCase().endsWith('@gmail.com')) {
      emailError = 'Email must strictly end with @gmail.com';
    }
    if (phone.isEmpty) {
      phoneError = 'Phone number is required';
    } else if (!phone.startsWith('+2')) {
      phoneError = 'Must start with +2';
    } else if (phone.length != 13) {
      phoneError = 'Must be exactly 11 digits after +2';
    } else if (!RegExp(r'^\+2[0-9]{11}$').hasMatch(phone)) {
      phoneError = 'Must contain exactly 11 digits after +2';
    }
    if (_selectedGender == null || _selectedGender!.isEmpty) {
      genderError = 'Gender is required';
    }
    if (country.isEmpty) {
      countryError = 'Country is required';
    }
    if (governorate.isEmpty) {
      governorateError = 'Governorate is required';
    }
    if (city.isEmpty) {
      cityError = 'City is required';
    }
    if (address.isEmpty) {
      addressError = 'Address is required';
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
    } else if (_isBelowRequiredAge) {
      dobError = 'Age must be more than 22';
    }
    if (licenseNumber.isEmpty) {
      licenseNumberError = 'License number is required';
    } else if (!RegExp(r'^[0-9]{6,7}$').hasMatch(licenseNumber)) {
      licenseNumberError = 'License ID must be strictly 6 or 7 digits';
    }
    if (nationalId.isEmpty) {
      nationalIdError = 'National ID is required';
    } else if (!RegExp(r'^[0-9]{14}$').hasMatch(nationalId)) {
      nationalIdError = 'National ID must be exactly 14 digits';
    }
    if (_selectedSpecializations.isEmpty || specialization.isEmpty) {
      specializationError = 'Specialization is required';
    }
    if (_licenseFrontImage == null) {
      licenseFrontImageError = 'Capture license front photo from camera';
    }
    if (_licenseBackImage == null) {
      licenseBackImageError = 'Capture license back photo from camera';
    }
    if (_nationalIdFrontImage == null) {
      nationalIdFrontImageError = 'Capture national ID front photo from camera';
    }
    if (_nationalIdBackImage == null) {
      nationalIdBackImageError = 'Capture national ID back photo from camera';
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
      _nationalIdError = nationalIdError;
      _specializationError = specializationError;
      _phoneError = phoneError;
      _countryError = countryError;
      _governorateError = governorateError;
      _cityError = cityError;
      _addressError = addressError;
      _genderError = genderError;
      _licenseFrontImageError = licenseFrontImageError;
      _licenseBackImageError = licenseBackImageError;
      _nationalIdFrontImageError = nationalIdFrontImageError;
      _nationalIdBackImageError = nationalIdBackImageError;
      _profileImageError = profileImageError;
    });

    return firstNameError == null &&
        secondNameError == null &&
        emailError == null &&
        phoneError == null &&
        genderError == null &&
        countryError == null &&
        governorateError == null &&
        cityError == null &&
        addressError == null &&
        passwordError == null &&
        confirmPasswordError == null &&
        dobError == null &&
        licenseNumberError == null &&
        nationalIdError == null &&
        specializationError == null &&
        licenseFrontImageError == null &&
        licenseBackImageError == null &&
        nationalIdFrontImageError == null &&
        nationalIdBackImageError == null &&
        profileImageError == null;
  }

  Future<void> _handleRegister() async {
    if (!_validateForm()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fix highlighted fields'.translate())),
      );
      return;
    }

    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _syncRegistrationToFirebase();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text('Register successfully'.translate()),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LawyerOnboardingScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(_firebaseRegisterErrorMessage(e).translate()),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            (e.message ?? 'Firebase operation failed. Please try again.')
                .translate(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Register failed: ${e.toString()}'.translate()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
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
                          _buildProfilePhotoPicker(),
                          SizedBox(height: 18.h),
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
                          _CustomDropdownField(
                            label: 'Gender',
                            icon: Icons.wc_outlined,
                            value: _selectedGender,
                            items: _genderOptions,
                            errorText: _genderError,
                            onChanged: (value) => setState(() {
                              _selectedGender = value;
                              _genderError = null;
                            }),
                          ),
                          SizedBox(height: 16.h),
                          _CustomTextField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            hintText: '+201xxxxxxxxx',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            errorText: _phoneError,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(13),
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[\+0-9]'),
                              ),
                            ],
                            onChanged: (_) => setState(() {
                              _phoneError = null;
                            }),
                          ),
                          SizedBox(height: 16.h),
                          _CustomTextField(
                            controller: _countryController,
                            label: 'Country',
                            hintText: 'e.g. Egypt',
                            icon: Icons.public_outlined,
                            errorText: _countryError,
                            onChanged: (_) => setState(() {
                              _countryError = null;
                            }),
                          ),
                          SizedBox(height: 16.h),
                          Row(
                            children: [
                              Expanded(
                                child: _CustomDropdownField(
                                  label: 'Governorate',
                                  icon: Icons.map_outlined,
                                  value: _selectedGovernorate,
                                  items: _governoratesWithCities.keys.toList()
                                    ..sort(),
                                  errorText: _governorateError,
                                  onChanged: (val) => setState(() {
                                    _selectedGovernorate = val;
                                    _selectedCity = null;
                                    _governorateError = null;
                                  }),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: _CustomDropdownField(
                                  label: 'City',
                                  icon: Icons.location_city_outlined,
                                  value: _selectedCity,
                                  items: _selectedGovernorate == null
                                      ? <String>[]
                                      : (_governoratesWithCities[_selectedGovernorate] ??
                                            <String>[]),
                                  errorText: _cityError,
                                  onChanged: (val) => setState(() {
                                    _selectedCity = val;
                                    _cityError = null;
                                  }),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          _CustomTextField(
                            controller: _addressController,
                            label: 'Address',
                            hintText: 'Street, building, floor',
                            icon: Icons.home_outlined,
                            errorText: _addressError,
                            onChanged: (_) => setState(() {
                              _addressError = null;
                            }),
                          ),
                          SizedBox(height: 16.h),
                          _CustomTextField(
                            controller: _licenseNumberController,
                            label: 'License ID',
                            hintText: '6 or 7 digits',
                            icon: Icons.badge_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(7),
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            errorText: _licenseNumberError,
                            onChanged: (_) => setState(() {
                              _licenseNumberError = null;
                            }),
                          ),
                          SizedBox(height: 16.h),
                          _CustomTextField(
                            controller: _nationalIdController,
                            label: 'National ID',
                            hintText: '14-digit national ID',
                            icon: Icons.credit_card_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(14),
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            errorText: _nationalIdError,
                            onChanged: (_) => setState(() {
                              _nationalIdError = null;
                            }),
                          ),
                          SizedBox(height: 16.h),
                          _SpecializationPickerField(
                            controller: _specializationController,
                            selectedSpecializations: _selectedSpecializations,
                            isLoading: _isLoadingSpecializations,
                            optionsError: _specializationOptionsError,
                            errorText: _specializationError,
                            onTap: _showSpecializationPicker,
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
                              text: 'Must be more than 22',
                              passed:
                                  _selectedDob != null && !_isBelowRequiredAge,
                            ),
                          ),
                          SizedBox(height: 18.h),
                          _IdCaptureCard(
                            title: 'License Photo (Front Side)',
                            imagePath: _licenseFrontImage?.path,
                            errorText: _licenseFrontImageError,
                            onCapturePressed: _captureLicenseFrontImage,
                          ),
                          SizedBox(height: 12.h),
                          _IdCaptureCard(
                            title: 'License Photo (Back Side)',
                            imagePath: _licenseBackImage?.path,
                            errorText: _licenseBackImageError,
                            onCapturePressed: _captureLicenseBackImage,
                          ),
                          SizedBox(height: 12.h),
                          _IdCaptureCard(
                            title: 'National ID Photo (Front Side)',
                            imagePath: _nationalIdFrontImage?.path,
                            errorText: _nationalIdFrontImageError,
                            onCapturePressed: _captureNationalIdFrontImage,
                          ),
                          SizedBox(height: 12.h),
                          _IdCaptureCard(
                            title: 'National ID Photo (Back Side)',
                            imagePath: _nationalIdBackImage?.path,
                            errorText: _nationalIdBackImageError,
                            onCapturePressed: _captureNationalIdBackImage,
                          ),
                          SizedBox(height: 22.h),
                          SizedBox(
                            height: 56.h,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.legalGold,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                                elevation: 0,
                              ),
                              child: _isSubmitting
                                  ? SizedBox(
                                      width: 20.w,
                                      height: 20.h,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
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

  Widget _buildProfilePhotoPicker() {
    return Column(
      children: [
        Text(
          'Profile Photo'.translate(),
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 12.h),
        Center(
          child: GestureDetector(
            onTap: _pickProfilePhoto,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 112.w,
                  height: 112.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.legalGold.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: _profileImageError != null
                          ? Colors.red
                          : AppColors.legalGold,
                      width: 2.5.w,
                    ),
                    color: Colors.white,
                  ),
                  child: ClipOval(
                    child: _profileImage == null
                        ? Icon(
                            Icons.person_outline,
                            size: 48.sp,
                            color: Colors.grey[400],
                          )
                        : Image.file(
                            File(_profileImage!.path),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                Positioned(
                  right: -4.w,
                  bottom: 4.h,
                  child: Container(
                    width: 36.w,
                    height: 36.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.navyBlue,
                      border: Border.all(color: Colors.white, width: 2.5.w),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: 16.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          'Tap to add or change photo'.translate(),
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
        ),
        if (_profileImageError != null)
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Text(
              _profileImageError!.translate(),
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
  final List<TextInputFormatter>? inputFormatters;
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
    this.inputFormatters,
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
          inputFormatters: widget.inputFormatters,
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

class _CustomDropdownField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<String> items;
  final String? errorText;
  final ValueChanged<String?> onChanged;

  const _CustomDropdownField({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.errorText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedValue = value != null && items.contains(value)
        ? value
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.translate(),
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.navyBlue,
          ),
        ),
        SizedBox(height: 6.h),
        DropdownButtonFormField<String>(
          initialValue: normalizedValue,
          isExpanded: true,
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item.translate()),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.legalGold),
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

class _SpecializationPickerField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> selectedSpecializations;
  final bool isLoading;
  final String? optionsError;
  final String? errorText;
  final VoidCallback onTap;

  const _SpecializationPickerField({
    required this.controller,
    required this.selectedSpecializations,
    required this.isLoading,
    required this.optionsError,
    required this.errorText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Specialization'.translate(),
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.navyBlue,
          ),
        ),
        SizedBox(height: 6.h),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: errorText != null ? Colors.red : const Color(0xFFE0E0E0),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.school_outlined,
                      color: AppColors.legalGold,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        isLoading
                            ? 'Loading specializations...'.translate()
                            : selectedSpecializations.isEmpty
                            ? 'Choose specializations'.translate()
                            : 'Tap to edit specializations'.translate(),
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: isLoading
                              ? Colors.grey[500]
                              : selectedSpecializations.isEmpty
                              ? Colors.grey[500]
                              : AppColors.textDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    isLoading
                        ? SizedBox(
                            width: 18.w,
                            height: 18.h,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.legalGold,
                            ),
                          )
                        : Icon(
                            Icons.expand_more_rounded,
                            color: Colors.grey[600],
                          ),
                  ],
                ),
                if (optionsError != null) ...[
                  SizedBox(height: 6.h),
                  Text(
                    'Could not load specialization options from Firebase.'
                        .translate(),
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (selectedSpecializations.isNotEmpty) ...[
                  SizedBox(height: 10.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: selectedSpecializations
                        .map(
                          (item) => Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 5.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.legalGold.withValues(
                                alpha: 0.18,
                              ),
                              borderRadius: BorderRadius.circular(999.r),
                              border: Border.all(
                                color: AppColors.legalGold.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: Text(
                              item.translate(),
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.navyBlue,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
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
