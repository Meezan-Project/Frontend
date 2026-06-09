import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/models/case_model.dart';
import 'package:mezaan/lawyer/screens/lawyer_case_management_screen.dart';

class LawyerCasesTrackerScreen extends StatelessWidget {
  final String lawyerId;
  final String lawyerName;

  const LawyerCasesTrackerScreen({
    super.key,
    required this.lawyerId,
    required this.lawyerName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        title: Text(
          '$lawyerName - ${'Cases'.translate()}',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.navyBlue,
            fontSize: 16.sp,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('cases')
            .where('lawyerId', isEqualTo: lawyerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final casesDocs = snapshot.data?.docs ?? [];
          if (casesDocs.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24.r),
                child: Text(
                  'No cases assigned to this lawyer yet.'.translate(),
                  style: GoogleFonts.cairo(color: Colors.grey, fontSize: 14.sp),
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: casesDocs.length,
            padding: EdgeInsets.all(16.r),
            itemBuilder: (context, index) {
              final caseDoc = casesDocs[index];
              final userCase = UserCase.fromFirestore(caseDoc);

              return Card(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                margin: EdgeInsets.only(bottom: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12.r),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LawyerCaseDetailsScreen(
                          case_: userCase,
                          isLawyer: true,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.all(16.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              userCase.caseNumber.isNotEmpty
                                  ? userCase.caseNumber
                                  : 'Case #${userCase.id.substring(0, 5)}',
                              style: GoogleFonts.cairo(
                                color: AppColors.legalGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.sp,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                userCase.status.toUpperCase().translate(),
                                style: GoogleFonts.cairo(
                                  color: Colors.green,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          userCase.title,
                          style: GoogleFonts.cairo(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.navyBlue,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          userCase.description,
                          style: GoogleFonts.cairo(
                            fontSize: 13.sp,
                            color: isDark
                                ? Colors.white70
                                : AppColors.textDark.withOpacity(0.7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Tap to view details'.translate(),
                              style: GoogleFonts.cairo(
                                fontSize: 12.sp,
                                color: AppColors.legalGold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12.sp,
                              color: AppColors.legalGold,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
