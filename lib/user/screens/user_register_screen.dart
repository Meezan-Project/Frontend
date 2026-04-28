import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart' as image_picker;
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';
import 'package:mezaan/shared/services/supabase_storage_service.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/localization/localization_controller.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/widgets/language_toggle_button.dart';

class UserRegisterScreen extends StatefulWidget {
  const UserRegisterScreen({super.key});

  @override
  State<UserRegisterScreen> createState() => _UserRegisterScreenState();
}

class _UserRegisterScreenState extends State<UserRegisterScreen> {
  static const List<String> _emergencyRelations = <String>[
    'Father',
    'Mother',
    'Brother',
    'Sister',
    'Spouse',
    'Friend',
    'Other',
  ];

  final _firstNameController = TextEditingController();
  final _secondNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController(text: '+2');
  final _countryController = TextEditingController(text: 'Egypt');
  final _addressController = TextEditingController();
  final _dobController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final List<_EmergencyContactEntry> _emergencyContacts =
      <_EmergencyContactEntry>[_EmergencyContactEntry()];
  late final OnDeviceTranslator _arabicToEnglishTranslator;
  Map<String, List<String>> _governoratesWithCities = <String, List<String>>{};
  bool _isLoadingGovernorates = false;

  DateTime? _selectedDob;
  XFile? _profilePhotoImage;
  XFile? _frontIdImage;
  XFile? _backIdImage;
  bool _isUnder18 = false;
  final bool _isExtractingIdData = false;
  bool _isSubmitting = false;

  String? _selectedGender;
  String? _selectedGovernorate;
  String? _selectedCity;

  String? _firstNameError;
  String? _secondNameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _phoneError;
  String? _genderError;
  String? _governorateError;
  String? _cityError;
  String? _addressError;
  String? _dobError;
  String? _nationalIdError;
  String? _frontIdError;
  String? _backIdError;
  String? _emergencyContactsError;

  @override
  void initState() {
    super.initState();
    _arabicToEnglishTranslator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.arabic,
      targetLanguage: TranslateLanguage.english,
    );

    // Warm translation models in background to reduce first-scan latency.
    _loadGovernoratesFromFirebase();
  }

  @override
  void dispose() {
    _arabicToEnglishTranslator.close();
    _firstNameController.dispose();
    _secondNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    _nationalIdController.dispose();
    for (final contact in _emergencyContacts) {
      contact.dispose();
    }
    super.dispose();
  }

  Future<void> _loadGovernoratesFromFirebase() async {
    if (_isLoadingGovernorates) {
      return;
    }

    setState(() {
      _isLoadingGovernorates = true;
    });

    try {
      final loaded = <String, List<String>>{};

      Future<void> loadFromCollection(String collectionName) async {
        final snapshot = await FirebaseFirestore.instance
            .collection(collectionName)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final rawName =
              data['name']?.toString().trim() ??
              data['governorate']?.toString().trim() ??
              doc.id.trim();
          final name = rawName.trim();
          if (name.isEmpty) {
            continue;
          }

          final citySet = <String>{};

          final citiesRaw = data['cities'];
          if (citiesRaw is List) {
            for (final item in citiesRaw) {
              final city = item?.toString().trim() ?? '';
              if (city.isNotEmpty) {
                citySet.add(city);
              }
            }
          }

          final singleCity = data['city']?.toString().trim() ?? '';
          if (singleCity.isNotEmpty) {
            citySet.add(singleCity);
          }

          // Support nested structure: governorates/{id}/cities/{cityDoc}
          for (final subCollectionName in const <String>[
            'cities',
            'Cities',
            'cites',
            'Cites',
            'city',
            'City',
          ]) {
            try {
              final citiesSnapshot = await doc.reference
                  .collection(subCollectionName)
                  .get();
              for (final cityDoc in citiesSnapshot.docs) {
                final cityData = cityDoc.data();
                final cityName =
                    cityData['name']?.toString().trim() ?? cityDoc.id.trim();
                if (cityName.isNotEmpty) {
                  citySet.add(cityName);
                }
              }
            } catch (_) {}
          }

          final mergedCitySet = <String>{...(loaded[name] ?? const <String>[])};
          mergedCitySet.addAll(citySet);
          loaded[name] = mergedCitySet.toList()..sort();
        }
      }

      // Load from common naming variants and merge all results.
      for (final collectionName in const <String>[
        'governorates',
        'government',
        'governments',
        'Governorates',
        'Government',
      ]) {
        try {
          await loadFromCollection(collectionName);
        } catch (_) {}
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _governoratesWithCities = loaded;
        if (_governoratesWithCities.isEmpty) {
          _governorateError = 'No governorates found in Firebase';
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load governorates and cities from Firebase.'.translate(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGovernorates = false;
        });
      }
    }
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

  Future<void> _captureNationalId({required bool isFront}) async {
    final photo = await _openIdCameraWithGrid(isFront: isFront);
    if (photo == null) return;

    setState(() {
      if (isFront) {
        _frontIdImage = photo;
        _frontIdError = null;
      } else {
        _backIdImage = photo;
        _backIdError = null;
      }
    });
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate =
        _selectedDob ?? DateTime(now.year - 20, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDob = picked;
      _dobController.text = _formatDate(picked);
      _isUnder18 = _calculateAge(picked) < 18;
      _dobError = _isUnder18 ? '+18 only' : null;
    });
  }

  Future<void> _pickProfilePhoto() async {
    final source = await showModalBottomSheet<image_picker.ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Take photo'),
                  onTap: () => Navigator.of(
                    context,
                  ).pop(image_picker.ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.of(
                    context,
                  ).pop(image_picker.ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove selected photo'),
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _profilePhotoImage = null;
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    try {
      final picker = image_picker.ImagePicker();
      final selectedFile = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1400,
      );

      if (selectedFile == null) {
        return;
      }

      setState(() {
        _profilePhotoImage = selectedFile;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select profile photo.'.translate())),
      );
    }
  }

  void _addEmergencyContact() {
    if (_emergencyContacts.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum 4 emergency contacts allowed.'.translate()),
        ),
      );
      return;
    }

    setState(() {
      _emergencyContacts.add(_EmergencyContactEntry());
      _emergencyContactsError = null;
    });
  }

  void _removeEmergencyContact(int index) {
    if (_emergencyContacts.length <= 1) {
      return;
    }

    setState(() {
      final removed = _emergencyContacts.removeAt(index);
      removed.dispose();
      _emergencyContactsError = null;
    });
  }

  String _normalizeToEmergencyLocal11(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11 && digits.startsWith('0')) {
      return digits;
    }
    if (digits.length == 12 && digits.startsWith('20')) {
      return '0${digits.substring(2)}';
    }
    if (digits.length == 14 && digits.startsWith('0020')) {
      return '0${digits.substring(4)}';
    }
    return digits;
  }

  String? _validateEmergencyPhone(String value) {
    final phone = _normalizeToEmergencyLocal11(value);
    if (phone.isEmpty) {
      return 'Emergency contact number is required';
    }
    if (!RegExp(r'^0[0-9]{10}$').hasMatch(phone)) {
      return 'Emergency number must be exactly 11 digits';
    }
    return null;
  }

  bool _isContactCompletelyEmpty(_EmergencyContactEntry contact) {
    final hasName = contact.nameController.text.trim().isNotEmpty;
    final hasPhone = contact.phoneController.text.trim().isNotEmpty;
    final hasRelation = (contact.relation ?? '').trim().isNotEmpty;
    return !hasName && !hasPhone && !hasRelation;
  }

  Future<void> _pickEmergencyContactFromDevice(int index) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Contact picker is available only on Android and iOS.'.translate(),
          ),
        ),
      );
      return;
    }

    try {
      final hasPermission = await FlutterContacts.requestPermission(
        readonly: true,
      );
      if (!hasPermission) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contacts permission is required.'.translate()),
          ),
        );
        return;
      }

      final picked = await FlutterContacts.openExternalPick();
      if (picked == null) {
        return;
      }

      final fullContact = await FlutterContacts.getContact(
        picked.id,
        withProperties: true,
      );
      final firstPhoneRaw = fullContact?.phones.isNotEmpty == true
          ? fullContact!.phones.first.number
          : '';
      final normalized = _normalizeToEmergencyLocal11(firstPhoneRaw);

      if (normalized.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected contact has no phone number.'.translate()),
          ),
        );
        return;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        final entry = _emergencyContacts[index];
        final pickedName = fullContact?.displayName.trim() ?? '';
        if (pickedName.isNotEmpty) {
          entry.nameController.text = pickedName;
          entry.nameError = null;
        }
        entry.phoneController.text = normalized;
        entry.phoneError = _validateEmergencyPhone(normalized);
        _emergencyContactsError = null;
      });
    } on MissingPluginException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Contact plugin is not initialized. Stop the app and run it again (full restart).'
                .translate(),
          ),
        ),
      );
    }
  }

  String? _validateEmergencyContacts() {
    if (_emergencyContacts.isEmpty) {
      return 'At least one emergency contact is required';
    }

    if (_emergencyContacts.length > 4) {
      return 'Maximum 4 emergency contacts allowed';
    }

    bool hasEntryError = false;
    var hasAnyFilledContact = false;
    final seenNumbers = <String>{};

    for (final contact in _emergencyContacts) {
      if (_isContactCompletelyEmpty(contact)) {
        contact.nameError = null;
        contact.phoneError = null;
        contact.relationError = null;
        continue;
      }

      hasAnyFilledContact = true;
      final nameError = contact.nameController.text.trim().isEmpty
          ? 'Emergency contact name is required'
          : null;
      final normalizedPhone = _normalizeToEmergencyLocal11(
        contact.phoneController.text,
      );
      final phoneError = _validateEmergencyPhone(normalizedPhone);
      final relationError =
          (contact.relation == null || contact.relation!.isEmpty)
          ? 'Select relation'
          : null;
      contact.nameError = nameError;
      if (phoneError == null && seenNumbers.contains(normalizedPhone)) {
        contact.phoneError = 'Duplicate emergency number';
        hasEntryError = true;
      } else {
        contact.phoneError = phoneError;
        if (phoneError == null) {
          seenNumbers.add(normalizedPhone);
        }
      }
      contact.relationError = relationError;

      if (contact.nameError != null ||
          contact.phoneError != null ||
          contact.relationError != null) {
        hasEntryError = true;
      }
    }

    if (!hasAnyFilledContact) {
      return 'At least one emergency contact is required';
    }

    if (hasEntryError) {
      return 'Please complete emergency contacts correctly';
    }

    return null;
  }

  Future<XFile?> _openIdCameraWithGrid({required bool isFront}) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No camera available on this device'.translate()),
            ),
          );
        }
        return null;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      if (!mounted) {
        return null;
      }

      return Navigator.of(context).push<XFile>(
        MaterialPageRoute(
          builder: (_) => _IdCameraCaptureScreen(
            cameraDescription: selectedCamera,
            captureLabel: isFront ? 'Front Side' : 'Back Side',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open camera right now'.translate()),
          ),
        );
      }
      return null;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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

  String? _validateRequiredName(String value, String fieldName) {
    if (value.isEmpty) {
      return '$fieldName is required';
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

  String? _validatePassword(String value) {
    if (value.isEmpty) {
      return 'Password is required';
    }
    if (!_isPasswordValid) {
      return 'Password does not meet the required rules';
    }
    return null;
  }

  String? _validateConfirmPassword(String value) {
    if (value.isEmpty) {
      return 'Please re-enter password';
    }
    if (!_isConfirmMatched) {
      return 'Passwords must match';
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

  String? _validateDob() {
    if (_selectedDob == null || _dobController.text.trim().isEmpty) {
      return 'Birth date is required';
    }
    if (_isUnder18) {
      return '+18 only';
    }
    return null;
  }

  String? _validateNationalId() {
    final nationalId = _nationalIdController.text.trim();
    if (nationalId.isEmpty) {
      return 'National ID is required';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(nationalId)) {
      return 'National ID must contain digits only';
    }
    if (nationalId.length != 14) {
      return 'National ID must be exactly 14 digits';
    }
    return null;
  }

  String? _validateAddress(String value) {
    if (value.isEmpty) {
      return 'Address is required';
    }
    if (value.length < 8) {
      return 'Enter a more detailed address';
    }
    return null;
  }

  Future<void> _showCenteredResultMessage({
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
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
                  isSuccess
                      ? 'Registration Success'.translate()
                      : 'Registration Failed'.translate(),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message.translate(),
            style: TextStyle(color: AppColors.textDark),
          ),
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

  Future<bool> _validateUniqueRegistrationIdentity() async {
    final firestore = FirebaseFirestore.instance;
    final email = _emailController.text.trim();
    final emailLower = email.toLowerCase();
    final phone = _phoneController.text.trim();
    final nationalId = _nationalIdController.text.trim();

    final results = await Future.wait([
      firestore
          .collection('users')
          .where('emailLower', isEqualTo: emailLower)
          .limit(1)
          .get(),
      firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get(),
      firestore
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get(),
      firestore
          .collection('users')
          .where('nationalId', isEqualTo: nationalId)
          .limit(1)
          .get(),
    ]);

    final emailLowerExists = (results[0]).docs.isNotEmpty;
    final emailExists = (results[1]).docs.isNotEmpty;
    final phoneExists = (results[2]).docs.isNotEmpty;
    final nationalIdExists = (results[3]).docs.isNotEmpty;

    String? emailError;
    String? phoneError;
    String? nationalIdError;

    if (emailLowerExists || emailExists) {
      emailError = 'This email is already registered and cannot be used again.';
    }
    if (phoneExists) {
      phoneError =
          'This phone number is already registered and cannot be used again.';
    }
    if (nationalIdExists) {
      nationalIdError =
          'This national ID is already registered and cannot be used again.';
    }

    if (emailError != null || phoneError != null || nationalIdError != null) {
      if (mounted) {
        setState(() {
          _emailError = emailError ?? _emailError;
          _phoneError = phoneError ?? _phoneError;
          _nationalIdError = nationalIdError ?? _nationalIdError;
        });
      }
      return false;
    }

    return true;
  }

  bool _validateForm() {
    final firstNameError = _validateRequiredName(
      _firstNameController.text.trim(),
      'First name',
    );
    final secondNameError = _validateRequiredName(
      _secondNameController.text.trim(),
      'Second name',
    );
    final emailError = _validateEmail(_emailController.text.trim());
    final passwordError = _validatePassword(_passwordController.text);
    final confirmPasswordError = _validateConfirmPassword(
      _confirmPasswordController.text,
    );
    final phoneError = _validatePhone(_phoneController.text);
    final genderError = _selectedGender == null
        ? 'Gender selection is required'
        : null;
    final governorateError = _selectedGovernorate == null
        ? 'Governorate is required'
        : null;
    final cityError = _selectedCity == null ? 'City is required' : null;
    final addressError = _validateAddress(_addressController.text.trim());
    final dobError = _validateDob();
    final nationalIdError = _validateNationalId();
    final frontIdError = _frontIdImage == null
        ? 'Capture front ID photo from camera'
        : null;
    final backIdError = _backIdImage == null
        ? 'Capture back ID photo from camera'
        : null;
    final emergencyContactsError = _validateEmergencyContacts();

    setState(() {
      _firstNameError = firstNameError;
      _secondNameError = secondNameError;
      _emailError = emailError;
      _passwordError = passwordError;
      _confirmPasswordError = confirmPasswordError;
      _phoneError = phoneError;
      _genderError = genderError;
      _governorateError = governorateError;
      _cityError = cityError;
      _addressError = addressError;
      _dobError = dobError;
      _nationalIdError = nationalIdError;
      _frontIdError = frontIdError;
      _backIdError = backIdError;
      _emergencyContactsError = emergencyContactsError;
    });

    return firstNameError == null &&
        secondNameError == null &&
        emailError == null &&
        passwordError == null &&
        confirmPasswordError == null &&
        phoneError == null &&
        genderError == null &&
        governorateError == null &&
        cityError == null &&
        addressError == null &&
        dobError == null &&
        nationalIdError == null &&
        frontIdError == null &&
        backIdError == null &&
        emergencyContactsError == null;
  }

  String _formatDateForApi(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
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
      folderPath: 'users/$uid/files',
      fileName: fileName,
    );
  }

  Future<void> _syncRegistrationToFirebase() async {
    final email = _emailController.text.trim();
    final emailLower = email.toLowerCase();
    final phone = _phoneController.text.trim();
    final nationalId = _nationalIdController.text.trim();
    final password = _passwordController.text;

    final isUnique = await _validateUniqueRegistrationIdentity();
    if (!isUnique) {
      throw Exception(
        'Email, phone number, or national ID is already registered. Please use unique values.',
      );
    }

    UserCredential credential;
    try {
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException {
      rethrow;
    }

    final firebaseUser = credential.user ?? FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      throw Exception('Firebase user not available after registration sync.');
    }

    final profilePhotoUrl = await _uploadImageToStorage(
      uid: firebaseUser.uid,
      file: _profilePhotoImage,
      fileName: 'profile_photo.jpg',
    );
    final frontIdPhotoUrl = await _uploadImageToStorage(
      uid: firebaseUser.uid,
      file: _frontIdImage,
      fileName: 'id_front.jpg',
    );
    final backIdPhotoUrl = await _uploadImageToStorage(
      uid: firebaseUser.uid,
      file: _backIdImage,
      fileName: 'id_back.jpg',
    );

    final emergencyContacts = _emergencyContacts
        .where((contact) => !_isContactCompletelyEmpty(contact))
        .map(
          (contact) => <String, String>{
            'name': contact.nameController.text.trim(),
            'phone': _normalizeToEmergencyLocal11(contact.phoneController.text),
            'relation': contact.relation ?? '',
          },
        )
        .toList();

    await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).set({
      'uid': firebaseUser.uid,
      'email': email,
      'emailLower': emailLower,
      'firstName': _firstNameController.text.trim(),
      'secondName': _secondNameController.text.trim(),
      'fullName':
          '${_firstNameController.text.trim()} ${_secondNameController.text.trim()}'
              .trim(),
      'phone': phone,
      'gender': _selectedGender ?? '',
      'country': _countryController.text.trim(),
      'governorate': _selectedGovernorate ?? '',
      'city': _selectedCity ?? '',
      'address': _addressController.text.trim(),
      'birthDate': _selectedDob != null ? _formatDateForApi(_selectedDob!) : '',
      'nationalId': nationalId,
      'profilePhotoUrl': profilePhotoUrl ?? '',
      'frontNationalIdPhotoUrl': frontIdPhotoUrl ?? '',
      'backNationalIdPhotoUrl': backIdPhotoUrl ?? '',
      'emergencyContacts': emergencyContacts,
      'role': 'user',
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'source': 'user_register_screen',
    }, SetOptions(merge: true));
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
      case 'user-disabled':
        return 'This Firebase account is disabled.';
      case 'user-not-found':
      case 'wrong-password':
        return 'Firebase account exists but password does not match.';
      default:
        return error.message ?? 'Firebase registration sync failed.';
    }
  }

  Future<void> _handleRegister() async {
    if (!_validateForm()) {
      await _showCenteredResultMessage(
        message: 'Register failed. Please fix highlighted fields.',
        isSuccess: false,
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

      await _showCenteredResultMessage(
        message: 'Register successfully',
        isSuccess: true,
      );

      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) {
          return;
        }
        LoadingNavigator.pushReplacementNamed(context, AppRoutes.userHome);
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      debugPrint('Firebase register failed: ${e.code} ${e.message ?? ''}');
      await _showCenteredResultMessage(
        message: _firebaseRegisterErrorMessage(e),
        isSuccess: false,
      );
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }
      debugPrint('Firebase data/storage error: ${e.code} ${e.message ?? ''}');
      await _showCenteredResultMessage(
        message: e.message ?? 'Firebase operation failed. Please try again.',
        isSuccess: false,
      );
    } catch (e, stackTrace) {
      if (!mounted) {
        return;
      }
      debugPrint('Register unexpected Firebase flow error: $e');
      debugPrint('$stackTrace');
      await _showCenteredResultMessage(
        message: 'Register failed: ${e.toString()}',
        isSuccess: false,
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
        backgroundColor: const Color(0xFFF0F4F8),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _ModernRegisterHeader(),
              Transform.translate(
                offset: Offset(0, -42.h),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18.w),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 620 : double.infinity,
                    ),
                    child: Container(
                      padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 32.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 36,
                            offset: Offset(0, 12.h),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 20,
                                  color: AppColors.navyBlue,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                              Expanded(
                                child: Text(
                                  'User Registration'.translate(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 28.sp,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.navyBlue,
                                  ),
                                ),
                              ),
                              SizedBox(width: 48.w),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          _buildFormFields(),
                          SizedBox(height: 30.h),
                          _buildSubmitButton(),
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

  Widget _buildFormFields() {
    return Column(
      children: [
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
                onChanged: (value) => setState(() {
                  _firstNameError = _validateRequiredName(
                    value.trim(),
                    'First name',
                  );
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
                onChanged: (value) => setState(() {
                  _secondNameError = _validateRequiredName(
                    value.trim(),
                    'Second name',
                  );
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
          onChanged: (value) => setState(() {
            _emailError = _validateEmail(value.trim());
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
          onChanged: (value) => setState(() {
            _passwordError = _validatePassword(value);
            _confirmPasswordError = _validateConfirmPassword(
              _confirmPasswordController.text,
            );
          }),
        ),
        SizedBox(height: 10.h),
        _PasswordRuleItem(text: 'At least 8 characters', passed: _hasMinLength),
        _PasswordRuleItem(text: 'One uppercase letter', passed: _hasUpper),
        _PasswordRuleItem(text: 'One lowercase letter', passed: _hasLower),
        _PasswordRuleItem(text: 'One special character', passed: _hasSpecial),
        _PasswordRuleItem(text: 'One number', passed: _hasNumber),
        SizedBox(height: 16.h),
        _CustomTextField(
          controller: _confirmPasswordController,
          label: 'Re-enter Password',
          hintText: 'Enter the same password',
          icon: Icons.lock_reset,
          obscureText: true,
          errorText: _confirmPasswordError,
          onChanged: (value) => setState(() {
            _confirmPasswordError = _validateConfirmPassword(value);
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
            FilteringTextInputFormatter.allow(RegExp(r'[\+0-9]')),
          ],
          onChanged: (value) => setState(() {
            _phoneError = _validatePhone(value);
          }),
        ),
        SizedBox(height: 16.h),
        _buildEmergencyContactsSection(),
        SizedBox(height: 16.h),
        _GenderSelector(
          selectedGender: _selectedGender,
          errorText: _genderError,
          onChanged: (value) {
            setState(() {
              _selectedGender = value;
              _genderError = null;
            });
          },
        ),
        SizedBox(height: 16.h),
        _CustomTextField(
          controller: _countryController,
          label: 'Country',
          hintText: 'Egypt',
          icon: Icons.public,
          readOnly: true,
          enabled: false,
        ),
        SizedBox(height: 16.h),
        _CustomDropdownField(
          label: 'Governorate',
          icon: Icons.map_outlined,
          hintText: _isLoadingGovernorates
              ? 'Loading governorates...'
              : (_governoratesWithCities.isEmpty
                    ? 'No governorates found in Firebase'
                    : 'Select Governorate'),
          value: _selectedGovernorate,
          items: _governoratesWithCities.keys.toList()..sort(),
          enabled:
              !_isLoadingGovernorates && _governoratesWithCities.isNotEmpty,
          errorText: _governorateError,
          onChanged: (value) {
            setState(() {
              _selectedGovernorate = value;
              _selectedCity = null;
              _governorateError = value == null
                  ? 'Governorate is required'
                  : null;
              _cityError = 'City is required';
            });
          },
        ),
        SizedBox(height: 16.h),
        _CustomDropdownField(
          label: 'City',
          icon: Icons.location_city_outlined,
          hintText: 'Select City',
          value: _selectedCity,
          items: _selectedGovernorate == null
              ? const []
              : (_governoratesWithCities[_selectedGovernorate] ?? const []),
          enabled:
              _selectedGovernorate != null &&
              (_governoratesWithCities[_selectedGovernorate]?.isNotEmpty ??
                  false),
          errorText: _cityError,
          onChanged: (value) {
            setState(() {
              _selectedCity = value;
              _cityError = value == null ? 'City is required' : null;
            });
          },
        ),
        SizedBox(height: 16.h),
        _CustomTextField(
          controller: _addressController,
          label: 'Address',
          hintText: 'Street, building, floor, apartment, landmark...',
          icon: Icons.home_outlined,
          keyboardType: TextInputType.streetAddress,
          maxLines: 3,
          errorText: _addressError,
          onChanged: (value) => setState(() {
            _addressError = _validateAddress(value.trim());
          }),
        ),
        SizedBox(height: 16.h),
        _CustomTextField(
          controller: _dobController,
          label: 'Birth Date',
          hintText: 'DD/MM/YYYY',
          icon: Icons.calendar_today_outlined,
          readOnly: true,
          enabled: true,
          onTap: _pickBirthDate,
          errorText: _dobError,
        ),
        Padding(
          padding: EdgeInsets.only(top: 6.h),
          child: _PasswordRuleItem(
            text: 'Must be +18',
            passed: _selectedDob != null && !_isUnder18,
          ),
        ),
        SizedBox(height: 16.h),
        _CustomTextField(
          controller: _nationalIdController,
          label: 'National ID Number',
          hintText: 'e.g. 29801011234567',
          icon: Icons.badge_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [
            LengthLimitingTextInputFormatter(14),
            FilteringTextInputFormatter.digitsOnly,
          ],
          errorText: _nationalIdError,
          onChanged: (value) => setState(() {
            _nationalIdError = _validateNationalId();
          }),
        ),
        SizedBox(height: 16.h),
        _IdCaptureCard(
          title: 'National ID (Front)',
          imagePath: _frontIdImage?.path,
          errorText: _frontIdError,
          isProcessing: _isExtractingIdData,
          onCapturePressed: () => _captureNationalId(isFront: true),
        ),
        SizedBox(height: 6.h),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Captured images are stored as National ID photos only. Enter Birth Date and National ID manually.'
                .translate(),
            style: TextStyle(fontSize: 11.sp, color: Colors.grey),
          ),
        ),
        SizedBox(height: 12.h),
        _IdCaptureCard(
          title: 'National ID (Back)',
          imagePath: _backIdImage?.path,
          errorText: _backIdError,
          onCapturePressed: () => _captureNationalId(isFront: false),
        ),
      ],
    );
  }

  Widget _buildEmergencyContactsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Emergency Contacts'.translate(),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navyBlue,
                ),
              ),
            ),
            Text(
              '${_emergencyContacts.length}/4',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          'Required: add at least 1 contact. Phone must be 11 digits.'
              .translate(),
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
        ),
        SizedBox(height: 10.h),
        ...List<Widget>.generate(_emergencyContacts.length, (index) {
          final contact = _emergencyContacts[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${'Contact'.translate()} ${index + 1}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navyBlue,
                          ),
                        ),
                      ),
                      if (_emergencyContacts.length > 1)
                        IconButton(
                          onPressed: () => _removeEmergencyContact(index),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          tooltip: 'Remove'.translate(),
                        ),
                    ],
                  ),
                  TextField(
                    controller: contact.nameController,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      setState(() {
                        contact.nameError =
                            contact.nameController.text.trim().isEmpty
                            ? 'Emergency contact name is required'
                            : null;
                        _emergencyContactsError = null;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Emergency Contact Name'.translate(),
                      hintText: 'Full name'.translate(),
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: contact.nameError == null
                              ? const Color(0xFFE5E7EB)
                              : Colors.red,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: contact.nameError == null
                              ? AppColors.legalGold
                              : Colors.red,
                          width: 1.6,
                        ),
                      ),
                      errorText: contact.nameError?.translate(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 12.h,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  TextField(
                    controller: contact.phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(11),
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) {
                      setState(() {
                        contact.phoneError = _validateEmergencyPhone(value);
                        _emergencyContactsError = null;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Emergency Phone Number'.translate(),
                      hintText: '01XXXXXXXXX'.translate(),
                      prefixIcon: const Icon(Icons.phone_in_talk_outlined),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: contact.phoneError == null
                              ? const Color(0xFFE5E7EB)
                              : Colors.red,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: contact.phoneError == null
                              ? AppColors.legalGold
                              : Colors.red,
                          width: 1.6,
                        ),
                      ),
                      errorText: contact.phoneError?.translate(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 12.h,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  DropdownButtonFormField<String>(
                    initialValue: contact.relation,
                    items: _emergencyRelations
                        .map(
                          (relation) => DropdownMenuItem<String>(
                            value: relation,
                            child: Text(
                              relation.translate(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        contact.relation = value;
                        contact.relationError = value == null
                            ? 'Select relation'
                            : null;
                        _emergencyContactsError = null;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Relation'.translate(),
                      prefixIcon: const Icon(Icons.people_alt_outlined),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: contact.relationError == null
                              ? const Color(0xFFE5E7EB)
                              : Colors.red,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: contact.relationError == null
                              ? AppColors.legalGold
                              : Colors.red,
                          width: 1.6,
                        ),
                      ),
                      errorText: contact.relationError?.translate(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 12.h,
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _pickEmergencyContactFromDevice(index),
                      icon: const Icon(Icons.contacts_outlined),
                      label: Text('Pick from device'.translate()),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (_emergencyContacts.length < 4)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addEmergencyContact,
              icon: const Icon(Icons.add_circle_outline),
              label: Text('Add Emergency Contact'.translate()),
            ),
          ),
        if (_emergencyContactsError != null)
          Padding(
            padding: EdgeInsets.only(top: 2.h),
            child: Text(
              _emergencyContactsError!.translate(),
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

  Widget _buildProfilePhotoPicker() {
    return Column(
      children: [
        Text(
          'Profile Photo (Optional)'.translate(),
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
                      color: AppColors.legalGold,
                      width: 2.5.w,
                    ),
                    color: Colors.white,
                  ),
                  child: ClipOval(
                    child: _profilePhotoImage == null
                        ? Icon(
                            Icons.person_outline,
                            size: 48.sp,
                            color: Colors.grey[400],
                          )
                        : Image.file(
                            File(_profilePhotoImage!.path),
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
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      height: 56.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        gradient: const LinearGradient(
          colors: [AppColors.navyBlue, Color(0xFF1E4C90)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyBlue.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _handleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 22.w,
                height: 22.h,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                'register_button'.translate(),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
      ),
    );
  }
}

class _ModernRegisterHeader extends StatelessWidget {
  const _ModernRegisterHeader();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return ClipPath(
      clipper: _HeaderClipper(),
      child: Container(
        height: size.height * 0.35,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A2E63), AppColors.navyBlue],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
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
                  const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 62,
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    'Join as User'.translate(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                  Text(
                    'Access Legal Services with Ease'.translate(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
  final bool enabled;
  final int maxLines;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;

  const _CustomTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.onTap,
    this.errorText,
    this.inputFormatters,
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
    final hasError = widget.errorText != null;
    final borderColor = hasError ? Colors.red : Colors.transparent;
    final focusedBorderColor = hasError ? Colors.red : AppColors.legalGold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          obscureText: _obscureText,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          onChanged: widget.onChanged,
          onTap: widget.onTap,
          decoration: InputDecoration(
            labelText: widget.label.translate(),
            labelStyle: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: hasError ? Colors.red : Colors.grey[600],
            ),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            hintText: widget.hintText.translate(),
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13.sp),
            prefixIcon: Icon(
              widget.icon,
              color: hasError
                  ? Colors.red
                  : AppColors.navyBlue.withValues(alpha: 0.6),
            ),
            suffixIcon: widget.obscureText && widget.maxLines == 1
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                    child: Icon(
                      _obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: hasError ? Colors.red : AppColors.legalGold,
                    ),
                  )
                : null,
            filled: true,
            fillColor: hasError
                ? const Color(0xFFFFEBEE)
                : (widget.enabled
                      ? const Color(0xFFF8F9FA)
                      : const Color(0xFFF1F1F1)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(color: borderColor, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(color: focusedBorderColor, width: 1.8),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(
                color: hasError ? Colors.red : Colors.transparent,
                width: 1.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: const BorderSide(color: Colors.red, width: 1.2),
            ),
            contentPadding: EdgeInsets.symmetric(
              vertical: 16.h,
              horizontal: 16.w,
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

class _GenderSelector extends StatelessWidget {
  final String? selectedGender;
  final String? errorText;
  final ValueChanged<String> onChanged;

  const _GenderSelector({
    required this.selectedGender,
    required this.errorText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender'.translate(),
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          decoration: BoxDecoration(
            color: hasError ? const Color(0xFFFFEBEE) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: hasError ? Colors.red : Colors.transparent,
              width: 1.0,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
          child: Row(
            children: [
              Expanded(
                child: _GenderChip(
                  label: 'Male',
                  icon: Icons.male,
                  selected: selectedGender == 'Male',
                  onTap: () => onChanged('Male'),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _GenderChip(
                  label: 'Female',
                  icon: Icons.female,
                  selected: selectedGender == 'Female',
                  onTap: () => onChanged('Female'),
                ),
              ),
            ],
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

class _GenderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.navyBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.navyBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18.sp,
              color: selected ? Colors.white : AppColors.navyBlue,
            ),
            SizedBox(width: 6.w),
            Text(
              label.translate(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.navyBlue,
                fontSize: 13.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomDropdownField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String hintText;
  final String? value;
  final List<String> items;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String?> onChanged;

  const _CustomDropdownField({
    required this.label,
    required this.icon,
    required this.hintText,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final normalizedValue = value != null && items.contains(value)
        ? value
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: normalizedValue,
          onChanged: enabled && items.isNotEmpty ? onChanged : null,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: hasError ? Colors.red : AppColors.navyBlue,
          ),
          style: TextStyle(
            color: AppColors.navyBlue,
            fontSize: 14.sp,
            overflow: TextOverflow.ellipsis,
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  enabled: true,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          decoration: InputDecoration(
            labelText: label.translate(),
            labelStyle: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: hasError ? Colors.red : Colors.grey[600],
            ),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            hintText: hintText.translate(),
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13.sp),
            prefixIcon: Icon(
              icon,
              color: hasError
                  ? Colors.red
                  : AppColors.navyBlue.withValues(alpha: 0.6),
            ),
            filled: true,
            fillColor: hasError
                ? const Color(0xFFFFEBEE)
                : (enabled ? const Color(0xFFF8F9FA) : const Color(0xFFF1F1F1)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(
                color: hasError ? Colors.red : Colors.transparent,
                width: 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(
                color: hasError ? Colors.red : AppColors.legalGold,
                width: 1.8,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              vertical: 16.h,
              horizontal: 16.w,
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
  final bool isProcessing;
  final VoidCallback onCapturePressed;

  const _IdCaptureCard({
    required this.title,
    this.imagePath,
    this.errorText,
    this.isProcessing = false,
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
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 8.h),
        GestureDetector(
          onTap: onCapturePressed,
          child: Container(
            height: 140.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: errorText != null
                  ? const Color(0xFFFFEBEE)
                  : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: errorText != null ? Colors.red : Colors.grey[300]!,
                width: 1.5,
              ),
            ),
            child: imagePath == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isProcessing)
                        SizedBox(
                          width: 26.w,
                          height: 26.h,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.legalGold,
                          ),
                        )
                      else
                        Container(
                          padding: EdgeInsets.all(12.r),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.camera_alt_outlined,
                            color: AppColors.navyBlue.withValues(alpha: 0.6),
                            size: 28.sp,
                          ),
                        ),
                      SizedBox(height: 12.h),
                      Text(
                        isProcessing
                            ? 'Reading ID data...'.translate()
                            : 'Tap to capture'.translate(),
                        style: TextStyle(
                          color: AppColors.navyBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child: Image.file(File(imagePath!), fit: BoxFit.cover),
                  ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8),
            child: Text(
              errorText!.translate(),
              style: const TextStyle(color: Colors.red, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class _IdCameraCaptureScreen extends StatefulWidget {
  final CameraDescription cameraDescription;
  final String captureLabel;

  const _IdCameraCaptureScreen({
    required this.cameraDescription,
    required this.captureLabel,
  });

  @override
  State<_IdCameraCaptureScreen> createState() => _IdCameraCaptureScreenState();
}

class _IdCameraCaptureScreenState extends State<_IdCameraCaptureScreen> {
  late final CameraController _controller;
  late final Future<void> _initializeControllerFuture;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      if (mounted) {
        final croppedImage = await _cropToIdCard(image, context);
        if (mounted) {
          Navigator.of(context).pop(croppedImage);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Capture failed. Please try again.'.translate()),
          ),
        );
      }
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<XFile> _cropToIdCard(XFile rawImage, BuildContext context) async {
    try {
      final bytes = await rawImage.readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return rawImage;
      image = img.bakeOrientation(image);

      final screenWidth = MediaQuery.of(context).size.width;
      final cardWidthRatio = (screenWidth - 40) / screenWidth;

      final int cropWidth = (image.width * cardWidthRatio).round();
      final int cropHeight = (cropWidth / 1.58).round();

      final int startX = ((image.width - cropWidth) / 2).round();
      final int startY = ((image.height - cropHeight) / 2).round();

      final croppedImage = img.copyCrop(
        image,
        x: startX,
        y: startY,
        width: cropWidth,
        height: cropHeight,
      );

      final outputPath =
          '${Directory.systemTemp.path}/cropped_id_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(
        outputPath,
      ).writeAsBytes(img.encodeJpg(croppedImage, quality: 90));

      return XFile(outputPath);
    } catch (e) {
      debugPrint('Crop failed: $e');
      return rawImage;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            final isFront = widget.captureLabel == 'Front Side';
            return Stack(
              children: [
                Positioned.fill(child: CameraPreview(_controller)),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: AspectRatio(
                    aspectRatio: 1.58,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Stack(
                        children: [
                          CustomPaint(
                            painter: _IdGridPainter(isFront: isFront),
                            child: const SizedBox.expand(),
                          ),
                          Positioned(
                            left: 14,
                            right: 14,
                            bottom: 16,
                            child: IgnorePointer(
                              child: Text(
                                isFront
                                    ? '14-Digit National ID Number'.translate()
                                    : 'Issue Date / Details'.translate(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.greenAccent.withValues(
                                    alpha: 0.9,
                                  ),
                                  shadows: const [
                                    Shadow(color: Colors.black, blurRadius: 4),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 130,
                  child: Column(
                    children: [
                      Text(
                        'Align National ID ${widget.captureLabel} inside the grid'
                            .translate(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Center the whole card, then align ID number with the yellow band'
                            .translate(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 36,
                  child: Center(
                    child: GestureDetector(
                      onTap: _capture,
                      child: Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: _isCapturing
                              ? Colors.white54
                              : Colors.transparent,
                        ),
                        child: _isCapturing
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.black,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 34,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IdGridPainter extends CustomPainter {
  final bool isFront;

  _IdGridPainter({required this.isFront});

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final fillPaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    if (isFront) {
      // Photo Box (Top Right)
      final photoRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.70,
          size.height * 0.08,
          size.width * 0.25,
          size.height * 0.55,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(photoRect, fillPaint);
      canvas.drawRRect(photoRect, borderPaint);

      // Birth Date Box (Top Left)
      final dobRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.05,
          size.height * 0.08,
          size.width * 0.25,
          size.height * 0.35,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(dobRect, borderPaint);

      // National ID Number Box (Bottom)
      final idNumberRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.05,
          size.height * 0.75,
          size.width * 0.90,
          size.height * 0.18,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(idNumberRect, borderPaint);
      canvas.drawRRect(idNumberRect, fillPaint);
    } else {
      // BACK OF ID DESIGN
      // Barcode Box (Top Right)
      final barcodeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.65,
          size.height * 0.08,
          size.width * 0.30,
          size.height * 0.25,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(barcodeRect, fillPaint);
      canvas.drawRRect(barcodeRect, borderPaint);

      // National ID / Issue Date Box (Bottom)
      final bottomRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.05,
          size.height * 0.75,
          size.width * 0.90,
          size.height * 0.18,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(bottomRect, borderPaint);

      // Middle Details Guide
      final infoRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.15,
          size.height * 0.35,
          size.width * 0.70,
          size.height * 0.35,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(infoRect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width / 4,
      size.height,
      size.width / 2,
      size.height - 30,
    );
    path.quadraticBezierTo(
      size.width * 3 / 4,
      size.height - 60,
      size.width,
      size.height - 20,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _EmergencyContactEntry {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  String? relation;
  String? nameError;
  String? phoneError;
  String? relationError;

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
  }
}
