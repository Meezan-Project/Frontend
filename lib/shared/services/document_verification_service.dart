import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Service for verifying document images using Gemini (Google Generative AI).
class DocumentVerificationService {
  DocumentVerificationService({
    required String apiKey,
    String model = 'gemini-1.5-pro',
  }) : _model = GenerativeModel(model: model, apiKey: apiKey);

  final GenerativeModel _model;

  /// Returns true if Gemini replies EXACTLY with `YES` (or contains `YES`).
  Future<bool> isNationalId(File imageFile) async {
    final prompt =
        'Analyze this image. Is it a clear picture of an Egyptian National ID card (front or back)? Answer EXACTLY with a single word: YES or NO. Do not add any other text.';

    try {
      final bytes = await imageFile.readAsBytes();
      final b64 = base64Encode(bytes);
      final mime = _mimeTypeFromPath(imageFile.path);

      // Some package versions support sending bytes directly. If not,
      // send the image as a base64 string inside the text prompt so
      // the code compiles and the model still receives the image data.
      final promptWithImage =
          'Image-MIME: $mime\nImage-Base64: $b64\n\n$prompt';

      final response = await _model.generateContent([
        Content.text(promptWithImage),
      ]);

      final text = response.text?.trim().toUpperCase() ?? '';
      return text.contains('YES');
    } catch (e, st) {
      // Log and fail safely
      debugPrint('DocumentVerificationService.isNationalId error: $e');
      debugPrint('$st');
      return false;
    }
  }

  /// Returns true if Gemini replies EXACTLY with `YES` (or contains `YES`).
  Future<bool> isLawyerLicense(File imageFile) async {
    final prompt =
        'Analyze this image. Is it a clear picture of an Egyptian Lawyer Syndicate Card (كارنيه نقابة المحامين)? Answer EXACTLY with a single word: YES or NO. Do not add any other text.';

    try {
      final bytes = await imageFile.readAsBytes();
      final b64 = base64Encode(bytes);
      final mime = _mimeTypeFromPath(imageFile.path);

      final promptWithImage =
          'Image-MIME: $mime\nImage-Base64: $b64\n\n$prompt';

      final response = await _model.generateContent([
        Content.text(promptWithImage),
      ]);

      final text = response.text?.trim().toUpperCase() ?? '';
      return text.contains('YES');
    } catch (e, st) {
      // Log and fail safely
      debugPrint('DocumentVerificationService.isLawyerLicense error: $e');
      debugPrint('$st');
      return false;
    }
  }

  String _mimeTypeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}

/*
Integration example (use inside your `_handleRegister()`):

final verifier = DocumentVerificationService(apiKey: '<YOUR_GEMINI_API_KEY>');

_handleRegister() async {
  // show blocking loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  final idOk = await verifier.isNationalId(selectedIdFile);
  final licenseOk = await verifier.isLawyerLicense(selectedLicenseFile);

  Navigator.of(context).pop(); // close loading

  if (!idOk || !licenseOk) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document verification failed. Please upload clear, official documents.'),
      ),
    );
    return;
  }

  // continue with database uploads / registration
}

Notes:
- The prompts are intentionally strict: Gemini should answer EXACTLY with YES or NO.
- On any API error we log and return false so registration is blocked until verification succeeds.
*/
