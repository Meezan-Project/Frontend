import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class DocumentSelectionRow extends StatelessWidget {
  final List<String> documentRequirements;
  final Map<String, File?> selectedDocuments;
  final void Function(String docName, File file) onDocumentSelected;
  final void Function(String docName) onRemoveDocument;

  const DocumentSelectionRow({
    super.key,
    required this.documentRequirements,
    required this.selectedDocuments,
    required this.onDocumentSelected,
    required this.onRemoveDocument,
  });

  Future<void> _pickDocument(BuildContext context, String docName) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final pickedFile = result.files.first;
    if (pickedFile.path == null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to access selected file. Please try again.')),
      );
      return;
    }

    onDocumentSelected(docName, File(pickedFile.path!));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: documentRequirements.map((docName) {
        final selectedFile = selectedDocuments[docName];
        return Padding(
          padding: EdgeInsets.only(bottom: 14.h),
          child: Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: AppColors.navyBlue.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AppColors.navyBlue.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        docName,
                        style: GoogleFonts.cairo(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navyBlue,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        selectedFile?.path.split('/').last ?? 'No file selected',
                        style: GoogleFonts.cairo(
                          fontSize: 12.sp,
                          color: AppColors.textDark.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 34.h,
                      child: ElevatedButton(
                        onPressed: () => _pickDocument(context, docName),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.legalGold,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 14.w),
                          elevation: 0,
                        ),
                        child: Text(
                          selectedFile == null ? 'Select' : 'Change',
                          style: GoogleFonts.cairo(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (selectedFile != null) ...[
                      SizedBox(height: 8.h),
                      SizedBox(
                        height: 34.h,
                        child: OutlinedButton(
                          onPressed: () => onRemoveDocument(docName),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.navyBlue.withValues(alpha: 0.35)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 14.w),
                          ),
                          child: Text(
                            'Remove',
                            style: GoogleFonts.cairo(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navyBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
