import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class LawyerTemplatesScreen extends StatelessWidget {
  const LawyerTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBg = isDark ? const Color(0xFF0F1419) : const Color(0xFFFCFDFF);
    final cardBg = isDark ? const Color(0xFF1A2940) : Colors.white;
    final borderColor = isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5);

    // Mock templates data
    final templates = [
      {'name': 'Contract of Employment'.translate(), 'type': 'Labor Law', 'date': '2024-01-15'},
      {'name': 'Power of Attorney'.translate(), 'type': 'General', 'date': '2024-02-20'},
      {'name': 'Rental Agreement'.translate(), 'type': 'Real Estate', 'date': '2024-03-10'},
      {'name': 'Company Incorporation'.translate(), 'type': 'Commercial', 'date': '2024-04-05'},
      {'name': 'Divorce Settlement'.translate(), 'type': 'Family Law', 'date': '2024-05-12'},
      {'name': 'NDA Agreement'.translate(), 'type': 'Corporate', 'date': '2024-06-18'},
      {'name': 'Loan Agreement'.translate(), 'type': 'Banking', 'date': '2024-07-22'},
      {'name': 'Intellectual Property'.translate(), 'type': 'IP Law', 'date': '2024-08-30'},
    ];

    return Scaffold(
      backgroundColor: appBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 20.sp, color: isDark ? Colors.white : AppColors.navyBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Quick Templates'.translate(),
          style: GoogleFonts.cairo(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.navyBlue,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: templates.length,
        itemBuilder: (context, index) {
          final template = templates[index];
          return Container(
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 48.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: AppColors.legalGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    Icons.description_rounded,
                    color: AppColors.legalGold,
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template['name']!,
                        style: GoogleFonts.cairo(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.navyBlue,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: AppColors.legalGold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              template['type']!,
                              style: GoogleFonts.cairo(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.legalGold,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            template['date']!,
                            style: GoogleFonts.cairo(
                              fontSize: 11.sp,
                              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_rounded, size: 20.sp, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Edit template: ${template['name']}'.translate())),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Create new template'.translate())),
          );
        },
        backgroundColor: AppColors.legalGold,
        child: Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}