import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/widgets/document_picker_widget.dart';

/// Example: How to use DocumentPickerWidget in your Case Details/Creation screen
class CaseDocumentUploadExample extends StatefulWidget {
  const CaseDocumentUploadExample({super.key});

  @override
  State<CaseDocumentUploadExample> createState() =>
      _CaseDocumentUploadExampleState();
}

class _CaseDocumentUploadExampleState extends State<CaseDocumentUploadExample> {
  // Document requirements for a case
  final List<String> documentRequirements = [
    'National ID',
    'Case Description',
    'Supporting Documents',
    'Contract/Agreement',
  ];

  // Store selected documents
  final Map<String, File?> selectedDocuments = {};

  @override
  void initState() {
    super.initState();
    // Initialize with null values
    for (var doc in documentRequirements) {
      selectedDocuments[doc] = null;
    }
  }

  void _handleDocumentSelected(String docName, File file) {
    setState(() {
      selectedDocuments[docName] = file;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$docName uploaded: ${file.path.split('/').last}')),
    );
  }

  void _handleRemoveDocument(String docName) {
    setState(() {
      selectedDocuments[docName] = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$docName removed')),
    );
  }

  bool _areAllDocumentsUploaded() {
    return selectedDocuments.values.every((file) => file != null);
  }

  void _submitCase() {
    if (!_areAllDocumentsUploaded()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload all required documents')),
      );
      return;
    }

    // Handle case submission
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Case submitted successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Upload Case Documents',
          style: GoogleFonts.cairo(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.navyBlue,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Case Information & Documents',
              style: GoogleFonts.cairo(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.navyBlue,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Please upload all required documents for your case',
              style: GoogleFonts.cairo(
                fontSize: 13.sp,
                color: AppColors.textDark.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: 20.h),

            // Document Selection Row
            DocumentSelectionRow(
              documentRequirements: documentRequirements,
              selectedDocuments: selectedDocuments,
              onDocumentSelected: _handleDocumentSelected,
              onRemoveDocument: _handleRemoveDocument,
            ),

            SizedBox(height: 24.h),

            // Upload Progress Indicator
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppColors.legalGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppColors.legalGold.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Upload Progress',
                        style: GoogleFonts.cairo(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navyBlue,
                        ),
                      ),
                      Text(
                        '${selectedDocuments.values.where((f) => f != null).length}/${documentRequirements.length}',
                        style: GoogleFonts.cairo(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.legalGold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: LinearProgressIndicator(
                      value: selectedDocuments.values.where((f) => f != null).length /
                          documentRequirements.length,
                      minHeight: 6.h,
                      backgroundColor: AppColors.legalGold.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.legalGold),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 28.h),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _areAllDocumentsUploaded() ? _submitCase : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyBlue,
                  disabledBackgroundColor: Colors.grey[400],
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Submit Case',
                  style: GoogleFonts.cairo(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            SizedBox(height: 12.h),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.legalGold, width: 1.5),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.cairo(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.legalGold,
                  ),
                ),
              ),
            ),

            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}
