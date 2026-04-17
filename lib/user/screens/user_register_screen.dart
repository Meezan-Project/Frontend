import 'dart:io';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart' as image_picker;
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';
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
  static const String _registerApiPath = '/Mezaan-API/user/register.php';

  final _firstNameController = TextEditingController();
  final _secondNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _countryController = TextEditingController(text: 'Egypt');
  final _addressController = TextEditingController();
  final _dobController = TextEditingController();
  final _nationalIdController = TextEditingController();

  static const Map<String, List<String>> _governoratesWithCities = {
    'Alexandria': ['Montaza', 'Raml', 'Borg El Arab'],
    'Aswan': ['Aswan', 'Kom Ombo', 'Edfu'],
    'Assiut': ['Assiut', 'Dairut', 'Manfalut'],
    'Beheira': ['Damanhour', 'Kafr El Dawwar', 'Rashid'],
    'Beni Suef': ['Beni Suef', 'Al Wasta', 'Nasser'],
    'Cairo': ['Nasr City', 'Heliopolis', 'Maadi', 'Shubra'],
    'Dakahlia': ['Mansoura', 'Talkha', 'Mit Ghamr'],
    'Damietta': ['Damietta', 'Ras El Bar', 'Kafr Saad'],
    'Fayoum': ['Fayoum', 'Itsa', 'Senuris'],
    'Gharbia': ['Tanta', 'El Mahalla El Kubra', 'Kafr El Zayat'],
    'Giza': ['Dokki', '6th of October', 'Haram', 'Sheikh Zayed'],
    'Ismailia': ['Ismailia', 'Fayed', 'Qantara'],
    'Kafr El Sheikh': ['Kafr El Sheikh', 'Desouk', 'Baltim'],
    'Luxor': ['Luxor', 'Armant', 'Esna'],
    'Matrouh': ['Marsa Matrouh', 'El Alamein', 'Siwa'],
    'Menofia': ['Shibin El Kom', 'Sadat City', 'Ashmoun'],
    'Minya': ['Minya', 'Mallawi', 'Beni Mazar'],
    'New Valley': ['Kharga', 'Dakhla', 'Farafra'],
    'North Sinai': ['Arish', 'Sheikh Zuweid', 'Rafah'],
    'Port Said': ['Port Said', 'Port Fouad'],
    'Qalyubia': ['Banha', 'Qalyub', 'Shubra El Kheima'],
    'Qena': ['Qena', 'Nag Hammadi', 'Qus'],
    'Red Sea': ['Hurghada', 'Safaga', 'Marsa Alam'],
    'Sharqia': ['Zagazig', 'Belbeis', '10th of Ramadan'],
    'Sohag': ['Sohag', 'Akhmim', 'Tahta'],
    'South Sinai': ['Sharm El Sheikh', 'El Tor', 'Dahab'],
    'Suez': ['Suez', 'Ataqah', 'Faisal'],
  };

  DateTime? _selectedDob;
  XFile? _profilePhotoImage;
  XFile? _frontIdImage;
  XFile? _backIdImage;
  bool _isUnder18 = false;
  bool _isExtractingIdData = false;
  bool _isSubmitting = false;

  String? _selectedGender;
  String? _selectedGovernorate;
  String? _selectedCity;

  String? _firstNameError;
  String? _secondNameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _genderError;
  String? _governorateError;
  String? _cityError;
  String? _addressError;
  String? _dobError;
  String? _nationalIdError;
  String? _frontIdError;
  String? _backIdError;

  @override
  void dispose() {
    _firstNameController.dispose();
    _secondNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _countryController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    _nationalIdController.dispose();
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

    if (isFront) {
      await _extractNationalIdData(photo.path);
    }
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

  Future<void> _extractNationalIdData(String imagePath) async {
    setState(() {
      _isExtractingIdData = true;
      _frontIdError = null;
      _nationalIdError = null;
      _dobError = null;
    });

    final recognizer = TextRecognizer();
    String? fallbackCropPath;

    try {
      final fullImage = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      String? nationalId = _findBestNationalIdCandidate(fullImage);

      if (nationalId == null) {
        fallbackCropPath = await _createBottomThirdCrop(imagePath);
        if (fallbackCropPath != null) {
          final cropImage = await recognizer.processImage(
            InputImage.fromFilePath(fallbackCropPath),
          );
          nationalId = _findBestNationalIdCandidate(cropImage);
        }
      }

      if (nationalId == null) {
        setState(() {
          _nationalIdController.clear();
          _dobController.clear();
          _selectedDob = null;
          _isUnder18 = false;
          _frontIdError =
              'Could not detect a valid 14-digit National ID. Retake the front photo clearly.';
        });
        return;
      }

      _nationalIdController.text = nationalId;

      final dob = _extractBirthDateFromNationalId(nationalId);

      if (dob == null) {
        setState(() {
          _dobController.clear();
          _selectedDob = null;
          _isUnder18 = false;
          _frontIdError = null;
          _nationalIdError = null;
          _dobError = 'Birth date could not be confirmed from OCR.';
        });
        return;
      }

      setState(() {
        _selectedDob = dob;
        _dobController.text = _formatDate(dob);
        _isUnder18 = _calculateAge(dob) < 18;
        _frontIdError = null;
        _nationalIdError = null;
        _dobError = _isUnder18 ? '+18 only' : null;
      });
    } catch (_) {
      setState(() {
        _frontIdError = 'Failed to read National ID. Please retake the photo';
      });
    } finally {
      if (fallbackCropPath != null) {
        final file = File(fallbackCropPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      await recognizer.close();
      if (mounted) {
        setState(() {
          _isExtractingIdData = false;
        });
      }
    }
  }

  Future<String?> _createBottomThirdCrop(String imagePath) async {
    final inputBytes = await File(imagePath).readAsBytes();
    final source = img.decodeImage(inputBytes);
    if (source == null) {
      return null;
    }

    final cropY = (source.height * (2 / 3)).round();
    final cropHeight = source.height - cropY;
    if (cropHeight < 30) {
      return null;
    }

    final cropped = img.copyCrop(
      source,
      x: 0,
      y: cropY,
      width: source.width,
      height: cropHeight,
    );

    final outputPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}id_bottom_${DateTime.now().microsecondsSinceEpoch}.jpg';

    await File(
      outputPath,
    ).writeAsBytes(img.encodeJpg(cropped, quality: 95), flush: true);

    return outputPath;
  }

  DateTime? _extractBirthDateFromNationalId(String nationalId) {
    if (nationalId.length != 14) {
      return null;
    }

    final centuryDigit = int.tryParse(nationalId[0]);
    final yy = int.tryParse(nationalId.substring(1, 3));
    final mm = int.tryParse(nationalId.substring(3, 5));
    final dd = int.tryParse(nationalId.substring(5, 7));
    if (centuryDigit == null || yy == null || mm == null || dd == null) {
      return null;
    }

    final centuryBase = switch (centuryDigit) {
      2 => 1900,
      3 => 2000,
      _ => -1,
    };
    if (centuryBase == -1) {
      return null;
    }

    final year = centuryBase + yy;
    final dob = DateTime(year, mm, dd);
    if (dob.year != year || dob.month != mm || dob.day != dd) {
      return null;
    }
    if (dob.isAfter(DateTime.now())) {
      return null;
    }
    return dob;
  }

  String _normalizeOcrDigits(String input) {
    const digitMap = <String, String>{
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };

    const confusionMap = <String, String>{
      'O': '0',
      'Q': '0',
      'D': '0',
      'I': '1',
      'L': '1',
      'T': '1',
      '!': '1',
      '|': '1',
      'Z': '2',
      'S': '5',
      'G': '6',
      'B': '8',
    };

    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final originalChar = String.fromCharCode(rune);
      final digitNormalized = digitMap[originalChar] ?? originalChar;
      final upperChar = digitNormalized.toUpperCase();
      final mapped = confusionMap[upperChar] ?? upperChar;

      if (RegExp(r'[\s\-–—_]').hasMatch(mapped)) {
        continue;
      }
      buffer.write(mapped);
    }

    return buffer.toString();
  }

  String? _findBestNationalIdCandidate(RecognizedText recognized) {
    final candidateSources = <String>[
      ...recognized.blocks.expand(
        (block) => block.lines.map((line) => line.text),
      ),
      recognized.text,
    ];

    final exact14Regex = RegExp(r'(?<!\d)\d{14}(?!\d)');

    String? bestFromDigitsStream(String normalized) {
      final digitsOnly = normalized.replaceAll(RegExp(r'[^0-9]'), '');
      if (digitsOnly.length < 14) {
        return null;
      }

      for (var i = 0; i <= digitsOnly.length - 14; i++) {
        final candidate = digitsOnly.substring(i, i + 14);
        if (_extractBirthDateFromNationalId(candidate) != null) {
          return candidate;
        }
      }

      return null;
    }

    for (final source in candidateSources) {
      final normalized = _normalizeOcrDigits(source);

      for (final match in exact14Regex.allMatches(normalized)) {
        final candidate = match.group(0);
        if (candidate != null &&
            _extractBirthDateFromNationalId(candidate) != null) {
          return candidate;
        }
      }

      final streamCandidate = bestFromDigitsStream(normalized);
      if (streamCandidate != null) {
        return streamCandidate;
      }
    }

    return null;
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

  String? _validateDob() {
    if (_selectedDob == null || _dobController.text.trim().isEmpty) {
      if (_nationalIdController.text.trim().isNotEmpty) {
        return null;
      }
      return 'Birth date is required (captured from National ID)';
    }
    if (_isUnder18) {
      return '+18 only';
    }
    return null;
  }

  String? _validateNationalId() {
    final nationalId = _nationalIdController.text.trim();
    if (nationalId.isEmpty) {
      return 'National ID is required (captured from National ID image)';
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

    setState(() {
      _firstNameError = firstNameError;
      _secondNameError = secondNameError;
      _emailError = emailError;
      _passwordError = passwordError;
      _confirmPasswordError = confirmPasswordError;
      _genderError = genderError;
      _governorateError = governorateError;
      _cityError = cityError;
      _addressError = addressError;
      _dobError = dobError;
      _nationalIdError = nationalIdError;
      _frontIdError = frontIdError;
      _backIdError = backIdError;
    });

    return firstNameError == null &&
        secondNameError == null &&
        emailError == null &&
        passwordError == null &&
        confirmPasswordError == null &&
        genderError == null &&
        governorateError == null &&
        cityError == null &&
        addressError == null &&
        dobError == null &&
        nationalIdError == null &&
        frontIdError == null &&
        backIdError == null;
  }

  Uri _buildRegisterUri() {
    if (kIsWeb) {
      return Uri.parse('http://localhost$_registerApiPath');
    }

    if (Platform.isAndroid) {
      return Uri.parse('http://10.0.2.2$_registerApiPath');
    }

    return Uri.parse('http://localhost$_registerApiPath');
  }

  Future<Map<String, dynamic>> _submitRegistrationRequest() async {
    final uri = _buildRegisterUri();
    final request = http.MultipartRequest('POST', uri)
      ..fields['full_name'] =
          '${_firstNameController.text.trim()} ${_secondNameController.text.trim()}'
      ..fields['email'] = _emailController.text.trim()
      ..fields['password'] = _passwordController.text
      ..fields['gender'] = _selectedGender ?? ''
      ..fields['country'] = _countryController.text.trim()
      ..fields['government'] = _selectedGovernorate ?? ''
      ..fields['city'] = _selectedCity ?? ''
      ..fields['address'] = _addressController.text.trim()
      ..fields['birthdate'] = _selectedDob != null
          ? _formatDateForApi(_selectedDob!)
          : ''
      ..fields['national_id'] = _nationalIdController.text.trim();

    if (_frontIdImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'front_national_id_photo',
          _frontIdImage!.path,
        ),
      );
    }

    if (_backIdImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'back_national_id_photo',
          _backIdImage!.path,
        ),
      );
    }

    if (_profilePhotoImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'profile_photo',
          _profilePhotoImage!.path,
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    Map<String, dynamic> body = {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    }

    return {'statusCode': response.statusCode, 'body': body};
  }

  String _formatDateForApi(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _handleRegister() async {
    if (!_validateForm()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Register failed. Please fix highlighted fields.'.translate(),
          ),
        ),
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
      final result = await _submitRegistrationRequest();
      final statusCode = result['statusCode'] as int;
      final body = result['body'] as Map<String, dynamic>;

      final success =
          body['success'] == true && statusCode >= 200 && statusCode < 300;
      final message = body['message'] as String?;

      if (!mounted) {
        return;
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text((message ?? 'Register successfully').translate()),
          ),
        );

        Future.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) {
            return;
          }
          LoadingNavigator.pushReplacementNamed(context, AppRoutes.userHome);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (message ?? 'Register failed. Please try again.').translate(),
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not connect to server. Check API URL and network.'
                .translate(),
          ),
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
                      padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 22.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 22,
                            offset: Offset(0, 10.h),
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
          hintText: 'Select Governorate',
          value: _selectedGovernorate,
          items: _governoratesWithCities.keys.toList()..sort(),
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
          enabled: _selectedGovernorate != null,
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
          enabled: false,
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
          readOnly: true,
          enabled: false,
          errorText: _nationalIdError,
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
            'After capturing the front side, National ID and Birth Date are auto-filled.'
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

  Widget _buildProfilePhotoPicker() {
    return Column(
      children: [
        Text(
          'Profile Photo (Optional)'.translate(),
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.navyBlue,
          ),
        ),
        SizedBox(height: 10.h),
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
                    border: Border.all(
                      color: AppColors.legalGold,
                      width: 2.2.w,
                    ),
                    color: const Color(0xFFFAFAFA),
                  ),
                  child: ClipOval(
                    child: _profilePhotoImage == null
                        ? Icon(
                            Icons.person_outline,
                            size: 54.sp,
                            color: Colors.grey,
                          )
                        : Image.file(
                            File(_profilePhotoImage!.path),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                Positioned(
                  right: -2.w,
                  bottom: -2.h,
                  child: Container(
                    width: 34.w,
                    height: 34.h,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.navyBlue,
                    ),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: 18.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'Tap to add or change photo'.translate(),
          style: TextStyle(fontSize: 11.sp, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 56.h,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _handleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navyBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 22.w,
                height: 22.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                'register_button'.translate(),
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
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
    return Container(
      height: size.height * 0.31,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A2E63), AppColors.navyBlue, AppColors.legalGold],
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
                const Icon(Icons.person_rounded, color: Colors.white, size: 62),
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
  final String? errorText;

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
    final hasError = widget.errorText != null;
    final borderColor = hasError ? Colors.red : const Color(0xFFE0E0E0);
    final focusedBorderColor = hasError ? Colors.red : AppColors.legalGold;

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
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: widget.hintText.translate(),
            prefixIcon: Icon(
              widget.icon,
              color: hasError ? Colors.red : AppColors.legalGold,
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
                      ? const Color(0xFFFAFAFA)
                      : const Color(0xFFF1F1F1)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: borderColor, width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: borderColor, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: focusedBorderColor, width: 1.8),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: hasError ? Colors.red : const Color(0xFFD9D9D9),
                width: 1.2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Colors.red, width: 1.2),
            ),
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
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.navyBlue,
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          decoration: BoxDecoration(
            color: hasError ? const Color(0xFFFFEBEE) : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: hasError ? Colors.red : const Color(0xFFE0E0E0),
              width: 1.2,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
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
      borderRadius: BorderRadius.circular(10.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.navyBlue : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: selected ? AppColors.navyBlue : const Color(0xFFD8D8D8),
          ),
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
          initialValue: value,
          onChanged: enabled ? onChanged : null,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: hasError ? Colors.red : AppColors.navyBlue,
          ),
          style: const TextStyle(color: AppColors.navyBlue, fontSize: 14),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          decoration: InputDecoration(
            hintText: hintText.translate(),
            prefixIcon: Icon(
              icon,
              color: hasError ? Colors.red : AppColors.legalGold,
            ),
            filled: true,
            fillColor: hasError
                ? const Color(0xFFFFEBEE)
                : (enabled ? const Color(0xFFFAFAFA) : const Color(0xFFF1F1F1)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: hasError ? Colors.red : const Color(0xFFE0E0E0),
                width: 1.2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: hasError ? Colors.red : const Color(0xFFE0E0E0),
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: hasError ? Colors.red : AppColors.legalGold,
                width: 1.8,
              ),
            ),
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.navyBlue,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onCapturePressed,
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: errorText != null ? Colors.red : Colors.grey[200]!,
              ),
            ),
            child: imagePath == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isProcessing)
                        const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.3),
                        )
                      else
                        const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.grey,
                          size: 30,
                        ),
                      const SizedBox(height: 8),
                      Text(
                        isProcessing
                            ? 'Reading ID data...'.translate()
                            : 'Tap to capture'.translate(),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(15),
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
        Navigator.of(context).pop(image);
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
                            painter: _IdGridPainter(),
                            child: const SizedBox.expand(),
                          ),
                          Positioned(
                            left: 14,
                            right: 14,
                            bottom: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0x99FFD54F),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFFFC107),
                                  width: 1.4,
                                ),
                              ),
                              child: Text(
                                'Keep 14-digit number line here'.translate(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
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
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final bandPaint = Paint()
      ..color = const Color(0x33FFC107)
      ..style = PaintingStyle.fill;
    final bandBorderPaint = Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final x1 = size.width / 3;
    final x2 = (size.width / 3) * 2;
    final y1 = size.height / 3;
    final y2 = (size.height / 3) * 2;

    canvas.drawLine(Offset(x1, 0), Offset(x1, size.height), gridPaint);
    canvas.drawLine(Offset(x2, 0), Offset(x2, size.height), gridPaint);
    canvas.drawLine(Offset(0, y1), Offset(size.width, y1), gridPaint);
    canvas.drawLine(Offset(0, y2), Offset(size.width, y2), gridPaint);

    final bandRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        14,
        size.height * 0.73,
        size.width - 28,
        size.height * 0.14,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(bandRect, bandPaint);
    canvas.drawRRect(bandRect, bandBorderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
