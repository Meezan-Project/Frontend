import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class UserRegisterScreen extends StatefulWidget {
  const UserRegisterScreen({super.key});

  @override
  State<UserRegisterScreen> createState() => _UserRegisterScreenState();
}

class _UserRegisterScreenState extends State<UserRegisterScreen> {
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
  XFile? _frontIdImage;
  XFile? _backIdImage;
  bool _isUnder18 = false;
  bool _isExtractingIdData = false;

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

  Future<XFile?> _openIdCameraWithGrid({required bool isFront}) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No camera available on this device')),
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
          const SnackBar(content: Text('Unable to open camera right now')),
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

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final List<String> tempGeneratedPaths = [];
    bool sawAnyText = false;
    int maxDigitCount = 0;

    try {
      String? nationalId;

      final fullImage = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      final fullInspection = _inspectRecognizedText(fullImage, stage: 'full');
      sawAnyText = sawAnyText || fullInspection.hasText;
      maxDigitCount = math.max(maxDigitCount, fullInspection.digitCount);
      nationalId = fullInspection.candidate;
      if (nationalId == null) {
        final rawNationalId = _extractRawNationalIdDigits(fullImage);
        if (rawNationalId != null) {
          nationalId = rawNationalId;
        }
      }

      if (nationalId == null) {
        final enhancedFullPaths = await _createEnhancedVariants(
          imagePath,
          prefix: 'id_full_enh',
        );
        tempGeneratedPaths.addAll(enhancedFullPaths);
        for (final enhancedPath in enhancedFullPaths) {
          final enhancedImage = await recognizer.processImage(
            InputImage.fromFilePath(enhancedPath),
          );
          final enhancedInspection = _inspectRecognizedText(
            enhancedImage,
            stage: 'enhanced-full',
          );
          sawAnyText = sawAnyText || enhancedInspection.hasText;
          maxDigitCount = math.max(
            maxDigitCount,
            enhancedInspection.digitCount,
          );
          nationalId = enhancedInspection.candidate;
          if (nationalId == null) {
            final rawNationalId = _extractRawNationalIdDigits(enhancedImage);
            if (rawNationalId != null) {
              nationalId = rawNationalId;
            }
          }

          if (nationalId != null) {
            break;
          }
        }
      }

      if (nationalId == null) {
        final rotatedFullPaths = await _createRotatedVariants(
          imagePath,
          prefix: 'id_full_rot',
        );
        tempGeneratedPaths.addAll(rotatedFullPaths);
        for (final rotatedPath in rotatedFullPaths) {
          final rotatedImage = await recognizer.processImage(
            InputImage.fromFilePath(rotatedPath),
          );
          final rotatedInspection = _inspectRecognizedText(
            rotatedImage,
            stage: 'rotated-full',
          );
          sawAnyText = sawAnyText || rotatedInspection.hasText;
          maxDigitCount = math.max(maxDigitCount, rotatedInspection.digitCount);
          nationalId = rotatedInspection.candidate;
          if (nationalId == null) {
            final rawNationalId = _extractRawNationalIdDigits(rotatedImage);
            if (rawNationalId != null) {
              nationalId = rawNationalId;
            }
          }

          if (nationalId != null) {
            break;
          }
        }
      }

      if (nationalId == null) {
        final cropPaths = await _createIdNumberBandCrops(imagePath);
        tempGeneratedPaths.addAll(cropPaths);
        for (final cropPath in cropPaths) {
          final cropImage = await recognizer.processImage(
            InputImage.fromFilePath(cropPath),
          );
          final cropInspection = _inspectRecognizedText(
            cropImage,
            stage: 'crop',
          );
          sawAnyText = sawAnyText || cropInspection.hasText;
          maxDigitCount = math.max(maxDigitCount, cropInspection.digitCount);
          nationalId = cropInspection.candidate;
          if (nationalId == null) {
            final rawNationalId = _extractRawNationalIdDigits(cropImage);
            if (rawNationalId != null) {
              nationalId = rawNationalId;
            }
          }

          if (nationalId != null) {
            break;
          }

          final enhancedCropPaths = await _createEnhancedVariants(
            cropPath,
            prefix: 'id_crop_enh',
          );
          tempGeneratedPaths.addAll(enhancedCropPaths);
          for (final enhancedCropPath in enhancedCropPaths) {
            final enhancedCropImage = await recognizer.processImage(
              InputImage.fromFilePath(enhancedCropPath),
            );
            final enhancedCropInspection = _inspectRecognizedText(
              enhancedCropImage,
              stage: 'crop-enhanced',
            );
            sawAnyText = sawAnyText || enhancedCropInspection.hasText;
            maxDigitCount = math.max(
              maxDigitCount,
              enhancedCropInspection.digitCount,
            );
            nationalId = enhancedCropInspection.candidate;
            if (nationalId == null) {
              final rawNationalId = _extractRawNationalIdDigits(
                enhancedCropImage,
              );
              if (rawNationalId != null) {
                nationalId = rawNationalId;
              }
            }

            if (nationalId != null) {
              break;
            }
          }

          if (nationalId != null) {
            break;
          }

          final rotatedCropPaths = await _createRotatedVariants(
            cropPath,
            prefix: 'id_crop_rot',
          );
          tempGeneratedPaths.addAll(rotatedCropPaths);
          for (final rotatedCropPath in rotatedCropPaths) {
            final rotatedCropImage = await recognizer.processImage(
              InputImage.fromFilePath(rotatedCropPath),
            );
            final rotatedCropInspection = _inspectRecognizedText(
              rotatedCropImage,
              stage: 'crop-rotated',
            );
            sawAnyText = sawAnyText || rotatedCropInspection.hasText;
            maxDigitCount = math.max(
              maxDigitCount,
              rotatedCropInspection.digitCount,
            );
            nationalId = rotatedCropInspection.candidate;
            if (nationalId == null) {
              final rawNationalId = _extractRawNationalIdDigits(
                rotatedCropImage,
              );
              if (rawNationalId != null) {
                nationalId = rawNationalId;
              }
            }

            if (nationalId != null) {
              break;
            }
          }

          if (nationalId != null) {
            break;
          }
        }
      }

      if (nationalId == null) {
        final failureMessage = !sawAnyText
            ? 'No OCR text was detected. Keep the ID inside the frame and try again.'
            : maxDigitCount < 14
            ? 'OCR found text but fewer than 14 digits were detected. Keep the 14-digit number line inside the yellow band.'
            : 'OCR found text but could not isolate a valid National ID. Try a clearer photo.';
        setState(() {
          _nationalIdController.clear();
          _dobController.clear();
          _selectedDob = null;
          _isUnder18 = false;
          _frontIdError = failureMessage;
        });
        return;
      }

      _nationalIdController.text = nationalId;

      var dob = _extractBirthDateFromNationalId(nationalId);
      if (dob == null) {
        final repairedNationalId = _repairNationalIdCandidate(nationalId);
        if (repairedNationalId != null) {
          nationalId = repairedNationalId;
          _nationalIdController.text = nationalId;
          dob = _extractBirthDateFromNationalId(nationalId);
        }
      }

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
        _dobController.text = dob != null ? _formatDate(dob) : '';
        _isUnder18 = dob != null && _calculateAge(dob) < 18;
        _frontIdError = null;
        _nationalIdError = null;
        _dobError = _isUnder18 ? '+18 only' : null;
      });
    } catch (_) {
      setState(() {
        _frontIdError = 'Failed to read National ID. Please retake the photo';
      });
    } finally {
      for (final generatedPath in tempGeneratedPaths) {
        final file = File(generatedPath);
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

  String? _repairNationalIdCandidate(String candidate) {
    if (candidate.length != 14) {
      return null;
    }

    final suffix = candidate.substring(7);
    final now = DateTime.now();

    for (final centuryDigit in const [2, 3]) {
      final centuryBase = centuryDigit == 2 ? 1900 : 2000;

      for (var yearOffset = 0; yearOffset < 100; yearOffset++) {
        final year = centuryBase + yearOffset;

        for (var month = 1; month <= 12; month++) {
          final daysInMonth = DateTime(year, month + 1, 0).day;

          for (var day = 1; day <= daysInMonth; day++) {
            final repaired =
                '$centuryDigit${yearOffset.toString().padLeft(2, '0')}'
                '${month.toString().padLeft(2, '0')}'
                '${day.toString().padLeft(2, '0')}'
                '$suffix';
            final dob = _extractBirthDateFromNationalId(repaired);
            if (dob == null) {
              continue;
            }

            final age = _calculateAge(dob);
            if (age >= 0 && age <= 120 && !dob.isAfter(now)) {
              return repaired;
            }
          }
        }
      }
    }

    return null;
  }

  String _normalizeOcrDigits(String input) {
    const digitMap = {
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
      '０': '0',
      '１': '1',
      '２': '2',
      '３': '3',
      '４': '4',
      '５': '5',
      '６': '6',
      '７': '7',
      '８': '8',
      '９': '9',
    };

    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(digitMap[char] ?? char);
    }
    return buffer.toString();
  }

  String _normalizeOcrIdText(String input) {
    final normalizedDigits = _normalizeOcrDigits(input).toUpperCase();
    final replacements = <String, String>{
      'O': '0',
      'Q': '0',
      'D': '0',
      'I': '1',
      'L': '1',
      'T': '1',
      '|': '1',
      '!': '1',
      'Z': '2',
      'S': '5',
      'G': '6',
      'B': '8',
    };

    final buffer = StringBuffer();
    for (final rune in normalizedDigits.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(replacements[char] ?? char);
    }
    return buffer.toString();
  }

  ({String? candidate, bool hasText, int digitCount}) _inspectRecognizedText(
    RecognizedText recognized, {
    required String stage,
  }) {
    final rawText = recognized.text.trim();
    final normalizedText = _normalizeOcrIdText(recognized.text);
    final digitCount = normalizedText.replaceAll(RegExp(r'\D'), '').length;

    debugPrint('--- National ID OCR [$stage] ---');
    debugPrint('raw text: ${rawText.isEmpty ? '<empty>' : rawText}');
    debugPrint('digit count: $digitCount');

    for (
      var blockIndex = 0;
      blockIndex < recognized.blocks.length;
      blockIndex++
    ) {
      final block = recognized.blocks[blockIndex];
      debugPrint('block #$blockIndex: ${block.text}');
      for (var lineIndex = 0; lineIndex < block.lines.length; lineIndex++) {
        final line = block.lines[lineIndex];
        debugPrint('  line #$lineIndex: ${line.text}');
      }
    }

    final candidate = _findBestNationalIdCandidateFromText(
      recognized,
      normalizedText: normalizedText,
      stage: stage,
    );

    debugPrint('candidate: ${candidate ?? '<none>'}');
    debugPrint('--- End OCR [$stage] ---');

    return (
      candidate: candidate,
      hasText: rawText.isNotEmpty || digitCount > 0,
      digitCount: digitCount,
    );
  }

  String? _findBestNationalIdCandidateFromText(
    RecognizedText recognized, {
    required String normalizedText,
    required String stage,
  }) {
    final candidates = <String>[];
    final seen = <String>{};

    void addCandidate(String candidate) {
      if (candidate.length != 14) {
        return;
      }
      if (seen.add(candidate)) {
        candidates.add(candidate);
      }
    }

    void addCandidatesFromSource(String source) {
      final normalizedSource = _normalizeOcrIdText(source);

      for (final match in RegExp(r'[0-9]+').allMatches(normalizedSource)) {
        final digitsOnly = match.group(0) ?? '';
        for (final candidate in _expandLikelyNationalIds(digitsOnly)) {
          addCandidate(candidate);
        }
      }
    }

    debugPrint(
      '[National ID OCR][$stage] normalized global digits: '
      '${normalizedText.replaceAll(RegExp(r'\D'), '')}',
    );

    addCandidatesFromSource(recognized.text);

    if (candidates.isEmpty) {
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          addCandidatesFromSource(line.text);
        }
      }
    }

    if (candidates.isEmpty) {
      final joined = normalizedText.replaceAll(RegExp(r'\D'), '');
      for (final candidate in _expandLikelyNationalIds(joined)) {
        addCandidate(candidate);
      }
    }

    for (final candidate in candidates) {
      final dob = _extractBirthDateFromNationalId(candidate);
      if (dob != null) {
        return candidate;
      }
    }

    for (final candidate in candidates) {
      final repaired = _repairNationalIdCandidate(candidate);
      if (repaired != null) {
        return repaired;
      }
    }

    return candidates.isNotEmpty ? candidates.first : null;
  }

  List<String> _expandLikelyNationalIds(String digits) {
    final normalized = digits.replaceAll(RegExp(r'\D'), '');
    final candidates = <String>[];
    final seen = <String>{};

    void add(String candidate) {
      if (candidate.length != 14) {
        return;
      }
      if (seen.add(candidate)) {
        candidates.add(candidate);
      }
    }

    if (normalized.length == 14) {
      add(normalized);
      return candidates;
    }

    if (normalized.length > 14) {
      for (var i = 0; i <= normalized.length - 14; i++) {
        add(normalized.substring(i, i + 14));
      }
      return candidates;
    }

    if (normalized.length == 15) {
      for (var i = 0; i < normalized.length; i++) {
        add(normalized.substring(0, i) + normalized.substring(i + 1));
      }
      return candidates;
    }

    if (normalized.length == 13) {
      for (var i = 0; i <= normalized.length; i++) {
        for (var digit = 0; digit <= 9; digit++) {
          add(
            normalized.substring(0, i) +
                digit.toString() +
                normalized.substring(i),
          );
        }
      }
      return candidates;
    }

    if (normalized.length == 12) {
      for (var i = 0; i <= normalized.length; i++) {
        for (var firstDigit = 0; firstDigit <= 9; firstDigit++) {
          final withOneInsertion =
              normalized.substring(0, i) +
              firstDigit.toString() +
              normalized.substring(i);
          for (var j = 0; j <= withOneInsertion.length; j++) {
            for (var secondDigit = 0; secondDigit <= 9; secondDigit++) {
              add(
                withOneInsertion.substring(0, j) +
                    secondDigit.toString() +
                    withOneInsertion.substring(j),
              );
            }
          }
        }
      }
      return candidates;
    }

    if (normalized.length >= 10) {
      add(normalized);
    }

    return candidates;
  }

  String? _extractRawNationalIdDigits(RecognizedText recognized) {
    final normalized = _normalizeOcrIdText(recognized.text);
    final digits = normalized.replaceAll(RegExp(r'\D'), '');

    if (digits.length >= 14) {
      return digits.substring(0, 14);
    }

    if (digits.length >= 12) {
      return digits;
    }

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final lineDigits = _normalizeOcrIdText(
          line.text,
        ).replaceAll(RegExp(r'\D'), '');
        if (lineDigits.length >= 14) {
          return lineDigits.substring(0, 14);
        }
        if (lineDigits.length >= 12) {
          return lineDigits;
        }
      }
    }

    return null;
  }

  Future<List<String>> _createEnhancedVariants(
    String imagePath, {
    required String prefix,
  }) async {
    final bytes = await File(imagePath).readAsBytes();
    final source = img.decodeImage(bytes);
    if (source == null) {
      return const [];
    }

    final outputPaths = <String>[];
    final upscaled = img.copyResize(
      source,
      width: source.width * 2,
      height: source.height * 2,
    );
    final grayscale = img.grayscale(img.decodeImage(bytes)!);
    final grayscaleUpscaled = img.grayscale(
      img.copyResize(
        img.decodeImage(bytes)!,
        width: source.width * 2,
        height: source.height * 2,
      ),
    );

    final variants = <img.Image>[upscaled, grayscale, grayscaleUpscaled];

    for (var i = 0; i < variants.length; i++) {
      final path =
          '${Directory.systemTemp.path}${Platform.pathSeparator}${prefix}_${DateTime.now().microsecondsSinceEpoch}_$i.jpg';
      final file = File(path);
      await file.writeAsBytes(
        img.encodeJpg(variants[i], quality: 98),
        flush: true,
      );
      outputPaths.add(path);
    }

    return outputPaths;
  }

  Future<List<String>> _createIdNumberBandCrops(String imagePath) async {
    final inputBytes = await File(imagePath).readAsBytes();
    final source = img.decodeImage(inputBytes);
    if (source == null) {
      return const [];
    }

    final width = source.width;
    final height = source.height;

    final List<({double x, double y, double w, double h})> regions = [
      (x: 0.08, y: 0.66, w: 0.84, h: 0.18),
      (x: 0.05, y: 0.60, w: 0.90, h: 0.22),
      (x: 0.10, y: 0.58, w: 0.80, h: 0.16),
      (x: 0.06, y: 0.50, w: 0.88, h: 0.20),
      (x: 0.08, y: 0.44, w: 0.84, h: 0.20),
      (x: 0.04, y: 0.54, w: 0.92, h: 0.28),
      (x: 0.15, y: 0.62, w: 0.70, h: 0.16),
    ];

    final outputPaths = <String>[];
    for (var i = 0; i < regions.length; i++) {
      final region = regions[i];
      final cropX = math.max(0, (width * region.x).round());
      final cropY = math.max(0, (height * region.y).round());
      final cropWidth = math.min(width - cropX, (width * region.w).round());
      final cropHeight = math.min(height - cropY, (height * region.h).round());

      if (cropWidth < 40 || cropHeight < 20) {
        continue;
      }

      final cropped = img.copyCrop(
        source,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      final outputPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}id_crop_${DateTime.now().microsecondsSinceEpoch}_$i.jpg';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(
        img.encodeJpg(cropped, quality: 95),
        flush: true,
      );
      outputPaths.add(outputPath);
    }

    return outputPaths;
  }

  Future<List<String>> _createRotatedVariants(
    String imagePath, {
    required String prefix,
  }) async {
    final bytes = await File(imagePath).readAsBytes();
    final source = img.decodeImage(bytes);
    if (source == null) {
      return const [];
    }

    final angles = [90, 180, 270];
    final outputPaths = <String>[];
    for (var i = 0; i < angles.length; i++) {
      final rotated = img.copyRotate(source, angle: angles[i]);
      final path =
          '${Directory.systemTemp.path}${Platform.pathSeparator}${prefix}_${DateTime.now().microsecondsSinceEpoch}_$i.jpg';
      final file = File(path);
      await file.writeAsBytes(img.encodeJpg(rotated, quality: 95), flush: true);
      outputPaths.add(path);
    }
    return outputPaths;
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

  void _handleRegister() {
    if (!_validateForm()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Register failed. Please fix highlighted fields.'),
        ),
      );
      return;
    }

    try {
      final registrationPayload = {
        'firstName': _firstNameController.text.trim(),
        'secondName': _secondNameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'gender': _selectedGender,
        'country': _countryController.text,
        'governorate': _selectedGovernorate,
        'city': _selectedCity,
        'address': _addressController.text.trim(),
        'dateOfBirth': _dobController.text.trim(),
        'nationalId': _nationalIdController.text.trim(),
        'nationalIdFrontImagePath': _frontIdImage?.path,
        'nationalIdBackImagePath': _backIdImage?.path,
      };

      debugPrint('Ready to save user payload: $registrationPayload');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Register successfully')));

      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) {
          return;
        }
        LoadingNavigator.pushReplacementNamed(context, AppRoutes.userHome);
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Register failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.width > 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _ModernRegisterHeader(),
            Transform.translate(
              offset: const Offset(0, -42),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isTablet ? 620 : double.infinity,
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
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
                            const Expanded(
                              child: Text(
                                'User Registration',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.navyBlue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildFormFields(),
                        const SizedBox(height: 30),
                        _buildSubmitButton(),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Already have an account? ',
                              style: TextStyle(color: Colors.grey),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  LoadingNavigator.pushReplacementNamed(
                                    context,
                                    AppRoutes.login,
                                  ),
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  color: AppColors.legalGold,
                                  fontWeight: FontWeight.bold,
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
  }

  Widget _buildFormFields() {
    return Column(
      children: [
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
            const SizedBox(width: 12),
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
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
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
        const SizedBox(height: 10),
        _PasswordRuleItem(text: 'At least 8 characters', passed: _hasMinLength),
        _PasswordRuleItem(text: 'One uppercase letter', passed: _hasUpper),
        _PasswordRuleItem(text: 'One lowercase letter', passed: _hasLower),
        _PasswordRuleItem(text: 'One special character', passed: _hasSpecial),
        _PasswordRuleItem(text: 'One number', passed: _hasNumber),
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
        _CustomTextField(
          controller: _countryController,
          label: 'Country',
          hintText: 'Egypt',
          icon: Icons.public,
          readOnly: true,
          enabled: false,
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
        _CustomTextField(
          controller: _dobController,
          label: 'Birth Date (Auto from OCR)',
          hintText: 'DD/MM/YYYY',
          icon: Icons.calendar_today_outlined,
          readOnly: true,
          enabled: false,
          errorText: _dobError,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _PasswordRuleItem(
            text: 'Must be +18',
            passed: _selectedDob != null && !_isUnder18,
          ),
        ),
        const SizedBox(height: 16),
        _CustomTextField(
          controller: _nationalIdController,
          label: 'National ID Number (Auto from OCR)',
          hintText: 'e.g. 29801011234567',
          icon: Icons.badge_outlined,
          readOnly: true,
          enabled: false,
          errorText: _nationalIdError,
        ),
        const SizedBox(height: 16),
        _IdCaptureCard(
          title: 'National ID (Front)',
          imagePath: _frontIdImage?.path,
          errorText: _frontIdError,
          isProcessing: _isExtractingIdData,
          onCapturePressed: () => _captureNationalId(isFront: true),
        ),
        const SizedBox(height: 6),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'After capturing the front side, National ID and Birth Date are auto-filled.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 12),
        _IdCaptureCard(
          title: 'National ID (Back)',
          imagePath: _backIdImage?.path,
          errorText: _backIdError,
          onCapturePressed: () => _captureNationalId(isFront: false),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _handleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navyBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Create Account',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_rounded, color: Colors.white, size: 62),
            const SizedBox(height: 10),
            const Text(
              'Join as User',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            Text(
              'Access Legal Services with Ease',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 14,
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
          widget.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.navyBlue,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          obscureText: _obscureText,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
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
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor, width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: focusedBorderColor, width: 1.8),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? Colors.red : const Color(0xFFD9D9D9),
                width: 1.2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 14,
            ),
          ),
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              widget.errorText!,
              style: const TextStyle(
                fontSize: 12,
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
        const Text(
          'Gender',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.navyBlue,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: hasError ? const Color(0xFFFFEBEE) : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError ? Colors.red : const Color(0xFFE0E0E0),
              width: 1.2,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
              const SizedBox(width: 10),
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
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              errorText!,
              style: const TextStyle(
                fontSize: 12,
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
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.navyBlue : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.navyBlue : const Color(0xFFD8D8D8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : AppColors.navyBlue,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.navyBlue,
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
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.navyBlue,
          ),
        ),
        const SizedBox(height: 6),
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
            hintText: hintText,
            prefixIcon: Icon(
              icon,
              color: hasError ? Colors.red : AppColors.legalGold,
            ),
            filled: true,
            fillColor: hasError
                ? const Color(0xFFFFEBEE)
                : (enabled ? const Color(0xFFFAFAFA) : const Color(0xFFF1F1F1)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? Colors.red : const Color(0xFFE0E0E0),
                width: 1.2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? Colors.red : const Color(0xFFE0E0E0),
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? Colors.red : AppColors.legalGold,
                width: 1.8,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 14,
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              errorText!,
              style: const TextStyle(
                fontSize: 12,
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: passed ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
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
          title,
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
                        isProcessing ? 'Reading ID data...' : 'Tap to capture',
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
              errorText!,
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
          const SnackBar(content: Text('Capture failed. Please try again.')),
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
                              child: const Text(
                                'Keep 14-digit number line here',
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
                        'Align National ID ${widget.captureLabel} inside the grid',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Center the whole card, then align ID number with the yellow band',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 12),
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
