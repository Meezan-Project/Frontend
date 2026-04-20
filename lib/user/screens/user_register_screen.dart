import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
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
  static const String _registerApiBaseUrl = String.fromEnvironment(
    'MEZAAN_API_BASE_URL',
    defaultValue: '',
  );
  static const Duration _registerRequestTimeout = Duration(seconds: 120);
  static const int _maxUploadImageBytes = 900 * 1024;
  static const int _uploadImageMaxDimension = 1280;
  static const int _uploadImageQuality = 72;
  static const String _ocrSpaceEndpoint = 'https://api.ocr.space/parse/image';
  static const String _ocrSpaceApiKey = 'K87899142388957';

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
  final OnDeviceTranslatorModelManager _translatorModelManager =
      OnDeviceTranslatorModelManager();
  late final OnDeviceTranslator _arabicToEnglishTranslator;
  Future<void>? _translationSetupFuture;
  Map<String, List<String>> _governoratesWithCities = <String, List<String>>{};
  bool _isLoadingGovernorates = false;

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
  String? _phoneError;
  String? _genderError;
  String? _governorateError;
  String? _cityError;
  String? _addressError;
  String? _dobError;
  String? _nationalIdError;
  String? _frontIdError;
  String? _backIdError;

  @override
  void initState() {
    super.initState();
    _arabicToEnglishTranslator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.arabic,
      targetLanguage: TranslateLanguage.english,
    );

    // Warm translation models in background to reduce first-scan latency.
    _translationSetupFuture = _ensureTranslationModelsReady();
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
    super.dispose();
  }

  Future<void> _ensureTranslationModelsReady() async {
    final languages = <TranslateLanguage>[
      TranslateLanguage.arabic,
      TranslateLanguage.english,
    ];

    for (final language in languages) {
      final modelCode = language.bcpCode;
      final downloaded = await _translatorModelManager.isModelDownloaded(
        modelCode,
      );
      if (!downloaded) {
        await _translatorModelManager.downloadModel(modelCode);
      }
    }
  }

  Future<void> _loadGovernoratesFromFirebase() async {
    if (_isLoadingGovernorates) {
      return;
    }

    setState(() {
      _isLoadingGovernorates = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('governorates')
          .get();

      final loaded = <String, List<String>>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawName = data['name']?.toString().trim() ?? '';
        final name = rawName.isNotEmpty ? rawName : doc.id.trim();
        if (name.isEmpty) {
          continue;
        }

        final citiesRaw = data['cities'];
        final cities = <String>[];
        if (citiesRaw is List) {
          for (final item in citiesRaw) {
            final city = item?.toString().trim() ?? '';
            if (city.isNotEmpty) {
              cities.add(city);
            }
          }
        }

        loaded[name] = cities;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _governoratesWithCities = loaded;
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

  Future<String> _translateArabicToEnglishSafely(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty ||
        !RegExp(r'[\u0600-\u06FF]').hasMatch(normalized)) {
      return normalized;
    }

    try {
      await (_translationSetupFuture ??= _ensureTranslationModelsReady());
      final translated = await _arabicToEnglishTranslator.translateText(
        normalized,
      );
      return translated.trim().isEmpty ? normalized : translated.trim();
    } catch (_) {
      return normalized;
    }
  }

  ({String? arabicName, String? arabicAddress})
  _extractArabicNameAndAddressFromText(RecognizedText recognizedText) {
    final lines = recognizedText.blocks
        .expand((block) => block.lines)
        .map((line) => line.text.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final labelNameRegex = RegExp(r'^(?:الاسم|اسم)\s*[:：]?\s*(.+)$');
    final labelAddressRegex = RegExp(r'^(?:العنوان|عنوان)\s*[:：]?\s*(.+)$');
    final addressKeywordRegex = RegExp(
      r'(?:عنوان|العنوان|محافظة|مدينة|حي|شارع|قسم|مركز|عمارة|منزل|بلوك|طريق)',
    );

    String? arabicName;
    String? arabicAddress;

    for (final line in lines) {
      if (arabicName == null) {
        final match = labelNameRegex.firstMatch(line);
        if (match != null) {
          final value = match.group(1)?.trim() ?? '';
          if (value.isNotEmpty) {
            arabicName = value;
          }
        }
      }

      if (arabicAddress == null) {
        final match = labelAddressRegex.firstMatch(line);
        if (match != null) {
          final value = match.group(1)?.trim() ?? '';
          if (value.isNotEmpty) {
            arabicAddress = value;
          }
        }
      }
    }

    if (arabicName == null) {
      for (final line in lines) {
        final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(line);
        final hasDigits = RegExp(r'\d').hasMatch(line);
        final wordsCount = line.split(RegExp(r'\s+')).length;
        final looksLikeAddress = addressKeywordRegex.hasMatch(line);

        if (isArabic && !hasDigits && wordsCount >= 2 && !looksLikeAddress) {
          arabicName = line;
          break;
        }
      }
    }

    if (arabicAddress == null) {
      final addressParts = lines
          .where((line) {
            return RegExp(r'[\u0600-\u06FF]').hasMatch(line) &&
                addressKeywordRegex.hasMatch(line);
          })
          .take(2)
          .toList();

      if (addressParts.isNotEmpty) {
        arabicAddress = addressParts.join(' ');
      }
    }

    return (arabicName: arabicName, arabicAddress: arabicAddress);
  }

  ({String? firstName, String? secondName}) _splitEnglishName(String fullName) {
    final cleaned = fullName.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) {
      return (firstName: null, secondName: null);
    }

    final parts = cleaned.split(' ');
    if (parts.length == 1) {
      return (firstName: parts.first, secondName: null);
    }

    return (firstName: parts.first, secondName: parts.sublist(1).join(' '));
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

  Future<void> _extractDataWithGemini(String imagePath) async {
    setState(() {
      _isExtractingIdData = true;
      _frontIdError = null;
      _nationalIdError = null;
      _dobError = null;
    });

    try {
      final apiKey = 'AIzaSyAizv9GUL5IPntXZLY3M15BB2Ghi0q0ReM';
      final imageBytes = await File(imagePath).readAsBytes();
      final imagePart = DataPart('image/jpeg', imageBytes);

      final prompt = TextPart(
        "Analyze this Egyptian National ID card. Extract the First Name, Last Name, and the 14-digit National ID number. Return ONLY a valid JSON object with the keys: 'firstName', 'lastName', and 'nationalId'. Do not include any markdown formatting or extra text.",
      );

      GenerateContentResponse? response;
      String? lastError;

      // Try multiple models in case the API key restricts access to some of them
      final modelsToTry = ['gemini-1.5-flash', 'gemini-1.5-flash-latest'];

      for (final modelName in modelsToTry) {
        try {
          final model = GenerativeModel(model: modelName, apiKey: apiKey);
          response = await model.generateContent([
            Content.multi([prompt, imagePart]),
          ]);
          break; // Success
        } catch (e) {
          lastError = e.toString();
          debugPrint('Failed with $modelName: $e');
        }
      }

      if (response == null) {
        throw Exception('All Gemini models failed. Last error: $lastError');
      }

      final jsonString = response.text?.trim() ?? '';
      if (jsonString.isEmpty) {
        throw Exception('Empty response from Gemini.');
      }

      var cleanJson = jsonString;
      if (cleanJson.startsWith('```')) {
        final lines = cleanJson.split('\n');
        cleanJson = lines.skip(1).take(lines.length - 2).join('\n').trim();
      }

      final data = jsonDecode(cleanJson);

      final String? firstName = data['firstName']?.toString();
      final String? lastName = data['lastName']?.toString();
      final String? nationalId = data['nationalId']?.toString();

      if (nationalId == null || nationalId.length != 14) {
        throw Exception('Could not detect a valid 14-digit National ID.');
      }

      final dob = _extractBirthDateFromNationalId(nationalId);

      if (!mounted) return;
      setState(() {
        if (firstName != null && firstName.isNotEmpty) {
          _firstNameController.text = firstName;
        }
        if (lastName != null && lastName.isNotEmpty) {
          _secondNameController.text = lastName;
        }

        _nationalIdController.text = nationalId;

        if (dob != null) {
          _selectedDob = dob;
          _dobController.text = _formatDate(dob);
          _isUnder18 = _calculateAge(dob) < 18;
          _dobError = _isUnder18 ? '+18 only' : null;
        } else {
          _dobController.clear();
          _selectedDob = null;
          _isUnder18 = false;
          _dobError = 'Birth date could not be confirmed from ID.';
        }
      });
    } catch (e) {
      debugPrint('Gemini OCR Error: $e');
      if (mounted) {
        setState(() {
          _frontIdError = 'Failed to read National ID: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExtractingIdData = false;
        });
      }
    }
  }

  Future<void> _extractDataWithOcrSpace(String imagePath) async {
    setState(() {
      _isExtractingIdData = true;
      _frontIdError = null;
      _nationalIdError = null;
      _dobError = null;
    });

    try {
      // 1. Try on-device ML Kit first (Free, fast, and excellent for Arabic numbers)
      final mlKitResult = await _extractDataWithMlKit(imagePath);
      String? nationalId = mlKitResult.nationalId;
      DateTime? dob = mlKitResult.birthDate;

      // 2. If ML Kit fails to detect a valid 14-digit ID, fallback to OCR.space API
      if (nationalId == null) {
        final apiResult = await _extractDataWithOcrSpaceApi(imagePath);
        nationalId = apiResult.nationalId;
        dob = apiResult.birthDate;
      }

      if (nationalId == null) {
        if (!mounted) return;
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

      if (dob == null) {
        if (!mounted) return;
        final String capturedId = nationalId;
        setState(() {
          _nationalIdController.text = capturedId;
          _dobController.clear();
          _selectedDob = null;
          _isUnder18 = false;
          _frontIdError = null;
          _nationalIdError = null;
          _dobError = 'Birth date could not be confirmed from ID.';
        });
        return;
      }

      if (!mounted) return;
      final String finalId = nationalId;
      final DateTime finalDob = dob;
      setState(() {
        _nationalIdController.text = finalId;
        _selectedDob = finalDob;
        _dobController.text = _formatDate(finalDob);
        _isUnder18 = _calculateAge(finalDob) < 18;
        _frontIdError = null;
        _nationalIdError = null;
        _dobError = _isUnder18 ? '+18 only' : null;
      });
    } catch (_) {
      setState(() {
        _frontIdError = 'Failed to read National ID. Please retake the photo';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isExtractingIdData = false;
        });
      }
    }
  }

  Future<({String rawText, String? nationalId, DateTime? birthDate})>
  _extractDataWithOcrSpaceApi(String imagePath) async {
    final request = http.MultipartRequest('POST', Uri.parse(_ocrSpaceEndpoint))
      ..headers['apikey'] = _ocrSpaceApiKey
      ..fields['language'] = 'ara'
      ..fields['isOverlayRequired'] = 'false'
      ..fields['scale'] = 'true'
      ..fields['detectOrientation'] = 'true'
      ..fields['OCREngine'] = '2'
      ..files.add(await http.MultipartFile.fromPath('file', imagePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'OCR.space request failed with status ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected OCR response format.');
    }

    final parsedResults = decoded['ParsedResults'];
    String rawText = '';

    if (parsedResults is List && parsedResults.isNotEmpty) {
      final firstResult = parsedResults.first;
      if (firstResult is Map<String, dynamic>) {
        rawText = (firstResult['ParsedText'] as String?)?.trim() ?? '';
      }
    }

    if (rawText.isEmpty) {
      final errorMessages = decoded['ErrorMessage'];
      if (errorMessages is List && errorMessages.isNotEmpty) {
        throw Exception(errorMessages.join(', '));
      }
      throw Exception('OCR did not return readable text.');
    }

    final normalizedText = _normalizeOcrDigits(rawText);
    final nationalId = _extractNationalIdFromText(normalizedText);
    final birthDate = nationalId != null
        ? _extractBirthDateFromNationalId(nationalId)
        : null;

    return (rawText: rawText, nationalId: nationalId, birthDate: birthDate);
  }

  Future<({String rawText, String? nationalId, DateTime? birthDate})>
  _extractDataWithMlKit(String imagePath) async {
    String pathToProcess = imagePath;
    try {
      final croppedPath = await _createBottomThirdCrop(imagePath);
      if (croppedPath != null) {
        pathToProcess = croppedPath;
      }
    } catch (_) {}
    final inputImage = InputImage.fromFilePath(pathToProcess);
    // On-device ML Kit primarily supports Latin-based scripts for text recognition.
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      final rawText = recognizedText.text;
      final normalizedText = _normalizeOcrDigits(rawText);
      final nationalId = _extractNationalIdFromText(normalizedText);
      final birthDate = nationalId != null
          ? _extractBirthDateFromNationalId(nationalId)
          : null;

      return (rawText: rawText, nationalId: nationalId, birthDate: birthDate);
    } catch (e) {
      debugPrint('ML Kit OCR Error: $e');
      return (rawText: '', nationalId: null, birthDate: null);
    } finally {
      textRecognizer.close();
      if (pathToProcess != imagePath) {
        try {
          File(pathToProcess).deleteSync();
        } catch (_) {}
      }
    }
  }

  String? _extractNationalIdFromText(String normalizedText) {
    final exact14Regex = RegExp(r'(?<!\d)\d{14}(?!\d)');
    final match = exact14Regex.firstMatch(normalizedText);
    if (match != null) {
      final candidate = match.group(0);
      if (candidate != null &&
          _extractBirthDateFromNationalId(candidate) != null) {
        return candidate;
      }
    }

    final digitsOnly = normalizedText.replaceAll(RegExp(r'[^0-9]'), '');
    for (var i = 0; i <= digitsOnly.length - 14; i++) {
      final candidate = digitsOnly.substring(i, i + 14);
      if (_extractBirthDateFromNationalId(candidate) != null) {
        return candidate;
      }
    }

    return null;
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
      'A': '8',
      'E': '3',
      'V': '7',
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
        backIdError == null;
  }

  Uri _buildRegisterUri() {
    final configuredBase = _registerApiBaseUrl.trim();
    if (configuredBase.isNotEmpty) {
      final parsed = Uri.tryParse(configuredBase);
      if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
        final configuredPath = parsed.path;
        if (configuredPath.endsWith('/register.php')) {
          return parsed;
        }

        final normalizedBasePath = configuredPath.endsWith('/')
            ? configuredPath.substring(0, configuredPath.length - 1)
            : configuredPath;
        return parsed.replace(path: '$normalizedBasePath$_registerApiPath');
      }
    }

    if (kIsWeb) {
      return Uri.parse('http://localhost$_registerApiPath');
    }

    if (Platform.isAndroid) {
      return Uri.parse('http://10.0.2.2$_registerApiPath');
    }

    return Uri.parse('http://localhost$_registerApiPath');
  }

  String _apiConnectionHint() {
    final configuredBase = _registerApiBaseUrl.trim();
    if (configuredBase.isNotEmpty) {
      return 'Using configured API base URL from MEZAAN_API_BASE_URL.';
    }

    if (kIsWeb) {
      return 'Web uses localhost by default. Ensure the backend is reachable from browser origin.';
    }

    if (Platform.isAndroid) {
      return 'Android default is 10.0.2.2 (emulator only). On a real phone, run with --dart-define=MEZAAN_API_BASE_URL=http://YOUR_PC_LAN_IP.';
    }

    return 'Desktop/iOS default is localhost. Ensure backend is running on this machine or configure MEZAAN_API_BASE_URL.';
  }

  Future<({String path, int bytes, bool isTemp})> _prepareImageForUpload(
    XFile file, {
    required String tempPrefix,
  }) async {
    final sourcePath = file.path;
    final sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      return (path: sourcePath, bytes: 0, isTemp: false);
    }

    final sourceBytesLength = await sourceFile.length();
    if (sourceBytesLength <= _maxUploadImageBytes) {
      return (path: sourcePath, bytes: sourceBytesLength, isTemp: false);
    }

    try {
      final rawBytes = await sourceFile.readAsBytes();
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) {
        return (path: sourcePath, bytes: sourceBytesLength, isTemp: false);
      }

      img.Image processed = decoded;
      if (decoded.width > _uploadImageMaxDimension ||
          decoded.height > _uploadImageMaxDimension) {
        if (decoded.width >= decoded.height) {
          processed = img.copyResize(decoded, width: _uploadImageMaxDimension);
        } else {
          processed = img.copyResize(decoded, height: _uploadImageMaxDimension);
        }
      }

      final encoded = img.encodeJpg(processed, quality: _uploadImageQuality);
      if (encoded.length >= sourceBytesLength) {
        return (path: sourcePath, bytes: sourceBytesLength, isTemp: false);
      }

      final tempPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}${tempPrefix}_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(encoded, flush: true);

      return (path: tempPath, bytes: encoded.length, isTemp: true);
    } catch (e) {
      debugPrint('Image upload optimization failed for $sourcePath: $e');
      return (path: sourcePath, bytes: sourceBytesLength, isTemp: false);
    }
  }

  Future<Map<String, dynamic>> _submitRegistrationRequest() async {
    final uri = _buildRegisterUri();
    debugPrint('Register API URI: $uri');
    final tempFilesToDelete = <String>[];

    try {
      final request = http.MultipartRequest('POST', uri)
        ..fields['full_name'] =
            '${_firstNameController.text.trim()} ${_secondNameController.text.trim()}'
        ..fields['email'] = _emailController.text.trim()
        ..fields['password'] = _passwordController.text
        ..fields['phone'] = _phoneController.text.trim()
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
        final prepared = await _prepareImageForUpload(
          _frontIdImage!,
          tempPrefix: 'front_id_upload',
        );
        if (prepared.isTemp) {
          tempFilesToDelete.add(prepared.path);
        }
        request.files.add(
          await http.MultipartFile.fromPath(
            'front_national_id_photo',
            prepared.path,
          ),
        );
        debugPrint('Front ID upload bytes: ${prepared.bytes}');
      }

      if (_backIdImage != null) {
        final prepared = await _prepareImageForUpload(
          _backIdImage!,
          tempPrefix: 'back_id_upload',
        );
        if (prepared.isTemp) {
          tempFilesToDelete.add(prepared.path);
        }
        request.files.add(
          await http.MultipartFile.fromPath(
            'back_national_id_photo',
            prepared.path,
          ),
        );
        debugPrint('Back ID upload bytes: ${prepared.bytes}');
      }

      if (_profilePhotoImage != null) {
        final prepared = await _prepareImageForUpload(
          _profilePhotoImage!,
          tempPrefix: 'profile_upload',
        );
        if (prepared.isTemp) {
          tempFilesToDelete.add(prepared.path);
        }
        request.files.add(
          await http.MultipartFile.fromPath('profile_photo', prepared.path),
        );
        debugPrint('Profile upload bytes: ${prepared.bytes}');
      }

      final streamedResponse = await request.send().timeout(
        _registerRequestTimeout,
      );
      final response = await http.Response.fromStream(streamedResponse);

      Map<String, dynamic> body = {};
      if (response.body.isNotEmpty) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            body = decoded;
          }
        } catch (_) {
          // Keep body empty for non-JSON responses; caller will use rawBody.
        }
      }

      return {
        'statusCode': response.statusCode,
        'body': body,
        'uri': uri.toString(),
        'rawBody': response.body,
      };
    } finally {
      for (final path in tempFilesToDelete) {
        try {
          final tempFile = File(path);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }
    }
  }

  String _formatDateForApi(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _syncRegistrationToFirebase() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    UserCredential credential;
    try {
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'email-already-in-use') {
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        rethrow;
      }
    }

    final firebaseUser = credential.user ?? FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      throw Exception('Firebase user not available after registration sync.');
    }

    await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).set({
      'uid': firebaseUser.uid,
      'email': email,
      'firstName': _firstNameController.text.trim(),
      'secondName': _secondNameController.text.trim(),
      'fullName':
          '${_firstNameController.text.trim()} ${_secondNameController.text.trim()}'
              .trim(),
      'phone': _phoneController.text.trim(),
      'gender': _selectedGender ?? '',
      'country': _countryController.text.trim(),
      'governorate': _selectedGovernorate ?? '',
      'city': _selectedCity ?? '',
      'address': _addressController.text.trim(),
      'birthDate': _selectedDob != null ? _formatDateForApi(_selectedDob!) : '',
      'nationalId': _nationalIdController.text.trim(),
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

    final fallbackRequestUri = _buildRegisterUri().toString();

    try {
      final result = await _submitRegistrationRequest();
      final statusCode = result['statusCode'] as int;
      final body = result['body'] as Map<String, dynamic>;
      final rawBody = (result['rawBody'] as String?) ?? '';
      final requestUri = (result['uri'] as String?) ?? '';

      final success =
          body['success'] == true && statusCode >= 200 && statusCode < 300;
      String? message = body['message'] as String?;

      if ((message == null || message.trim().isEmpty) && !success) {
        if (rawBody.trim().isNotEmpty) {
          final compact = rawBody.replaceAll(RegExp(r'\s+'), ' ').trim();
          message = compact.length > 220
              ? '${compact.substring(0, 220)}...'
              : compact;
        } else {
          message = 'Register failed (HTTP $statusCode).';
        }
      }

      if (!success) {
        debugPrint(
          'Register failed. uri=$requestUri status=$statusCode message=${message ?? ''}',
        );
      }

      if (!mounted) {
        return;
      }

      if (success) {
        try {
          await _syncRegistrationToFirebase();
        } on FirebaseAuthException catch (e) {
          if (!mounted) {
            return;
          }
          debugPrint('Firebase sync failed: ${e.code} ${e.message ?? ''}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_firebaseRegisterErrorMessage(e).translate()),
            ),
          );
          return;
        } catch (e) {
          if (!mounted) {
            return;
          }
          debugPrint('Firebase sync unexpected error: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Registration created on API, but Firebase sync failed.'
                    .translate(),
              ),
            ),
          );
          return;
        }

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
    } on SocketException catch (e) {
      if (!mounted) {
        return;
      }
      debugPrint('Register network error: $e');
      final apiHint = _apiConnectionHint();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not connect to server. URL: $fallbackRequestUri. $apiHint'
                .translate(),
          ),
        ),
      );
    } on TimeoutException catch (e) {
      if (!mounted) {
        return;
      }
      debugPrint('Register request timeout: $e');
      final apiHint = _apiConnectionHint();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Server timeout while uploading photos. URL: $fallbackRequestUri. $apiHint'
                .translate(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      debugPrint('Register unexpected error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Register failed unexpectedly. Please try again.'.translate(),
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

  Future<void> _testFirebaseConnection() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      UserCredential credential;
      const testEmail = 'test.seif@mezaan.com';
      const testPassword = 'password123';

      try {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );
      } on FirebaseAuthException catch (authError) {
        if (authError.code != 'email-already-in-use') {
          rethrow;
        }

        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );
      }

      final user = credential.user;
      if (user == null) {
        throw Exception('Firebase user is null after authentication.');
      }

      debugPrint('Firebase test auth OK. uid=${user.uid} email=${user.email}');

      final firestore = FirebaseFirestore.instance;
      final testDocRef = firestore.collection('users').doc(user.uid);
      final testData = {
        'firstName': _firstNameController.text.trim(),
        'secondName': _secondNameController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? testEmail
            : _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'birthDate': _dobController.text.trim(),
        'nationalId': _nationalIdController.text.trim(),
        'gender': _selectedGender ?? '',
        'governorate': _selectedGovernorate ?? '',
        'city': _selectedCity ?? '',
        'address': _addressController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'user_register_screen_test',
        'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
      };

      await testDocRef
          .set(testData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 15));

      final writtenSnapshot = await testDocRef.get().timeout(
        const Duration(seconds: 15),
      );

      debugPrint(
        'Firestore write OK. exists=${writtenSnapshot.exists} path=${testDocRef.path}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            'Firebase test succeeded. Data saved at users/${user.uid}.'
                .translate(),
          ),
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint(
        'Firebase test FirebaseException: plugin=${e.plugin} code=${e.code} message=${e.message}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Firebase test failed [${e.plugin}/${e.code}] ${e.message ?? ''}',
          ),
        ),
      );
    } on TimeoutException catch (e) {
      debugPrint('Firebase test timeout: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Firebase test timed out. Check internet or Firestore availability.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Firebase test generic error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Firebase test failed: ${e.toString()}'),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
