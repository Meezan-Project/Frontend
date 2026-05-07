// MINIMAL INTEGRATION SNIPPET
// Copy this into your Case Details or Case Creation screen

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/widgets/document_picker_widget.dart';

class YourCaseScreen extends StatefulWidget {
  const YourCaseScreen({super.key});

  @override
  State<YourCaseScreen> createState() => _YourCaseScreenState();
}

class _YourCaseScreenState extends State<YourCaseScreen> {
  // ==================== SETUP ====================
  
  final List<String> requiredDocs = [
    'National ID',
    'Case Description', 
    'Supporting Documents',
  ];

  final Map<String, File?> documents = {};

  @override
  void initState() {
    super.initState();
    for (var doc in requiredDocs) {
      documents[doc] = null;
    }
  }

  // ==================== HANDLERS ====================

  void _onDocumentPicked(String docName, File file) {
    setState(() {
      documents[docName] = file;
    });
  }

  void _onDocumentRemoved(String docName) {
    setState(() {
      documents[docName] = null;
    });
  }

  bool _allDocsUploaded() {
    return documents.values.every((f) => f != null);
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Case Details')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === YOUR EXISTING FORM FIELDS ===
            // (case title, description, etc.)

            SizedBox(height: 24.h),

            // === DOCUMENT UPLOAD SECTION ===
            DocumentSelectionRow(
              documentRequirements: requiredDocs,
              selectedDocuments: documents,
              onDocumentSelected: _onDocumentPicked,
              onRemoveDocument: _onDocumentRemoved,
            ),

            SizedBox(height: 24.h),

            // === SUBMIT BUTTON ===
            ElevatedButton(
              onPressed: _allDocsUploaded()
                  ? () {
                      // Handle submission with documents
                      _submitCase();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navyBlue,
                disabledBackgroundColor: Colors.grey[400],
                minimumSize: Size(double.infinity, 48.h),
              ),
              child: Text('Submit Case',
                  style: GoogleFonts.cairo(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitCase() async {
    try {
      // TODO: Upload files to Firebase Storage
      for (final entry in documents.entries) {
        if (entry.value != null) {
          // Upload file
          // final url = await _uploadToFirebase(entry.value!);
          // Save reference in Firestore
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Case submitted successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

// ==================== FIREBASE UPLOAD HELPER (OPTIONAL) ====================

/*
Future<String> _uploadToFirebase(File file, String docName) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'User not authenticated';

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$docName';
    final ref = FirebaseStorage.instance
        .ref()
        .child('cases')
        .child(user.uid)
        .child(fileName);

    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();
    
    return downloadUrl;
  } catch (e) {
    throw 'Failed to upload: $e';
  }
}
*/
