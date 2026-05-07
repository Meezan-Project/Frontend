import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';

class LawyerRealScheduleScreen extends StatefulWidget {
  const LawyerRealScheduleScreen({super.key});

  @override
  State<LawyerRealScheduleScreen> createState() => _LawyerRealScheduleScreenState();
}

class _LawyerRealScheduleScreenState extends State<LawyerRealScheduleScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text('My Appointments'.translate())),
        body: Center(child: Text('User not logged in'.translate())),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('My Appointments'.translate()),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('appointments')
              .where('lawyerId', isEqualTo: currentUser.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final appointments = snapshot.data?.docs ?? [];

            if (appointments.isEmpty) {
              return Center(
                child: Text(
                  'DATABASE CONNECTION ACTIVE - BUT NO BOOKINGS FOUND',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final cardColor = isDark ? const Color(0xFF162235) : Colors.white;

            return ListView(
              padding: EdgeInsets.all(16.r),
              children: [
                for (int i = 0; i < appointments.length; i++) ...[
                  Builder(
                    builder: (context) {
                      final doc = appointments[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final clientName = data['clientName'] as String? ?? 'Unknown Client';
                      final appointmentTime = data['appointmentTime'] as String? ?? 'Time not set';
                      final day = data['day'] as String? ?? 'Date not set';

                      return Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334766) : const Color(0xFFE5E7EB),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.04),
                              blurRadius: 8,
                              offset: Offset(0, 2.h),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: BoxDecoration(
                                color: AppColors.navyBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Icon(
                                Icons.schedule_rounded,
                                color: AppColors.navyBlue,
                                size: 18.sp,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    clientName,
                                    style: GoogleFonts.cairo(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : AppColors.navyBlue,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    '$day | $appointmentTime',
                                    style: GoogleFonts.cairo(
                                      fontSize: 11.sp,
                                      color: isDark ? Colors.white70 : Colors.grey[600]!,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
