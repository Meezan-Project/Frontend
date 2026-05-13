import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/user/screens/video_call_screen.dart';

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

            var appointments = snapshot.data?.docs.toList() ?? [];

            if (appointments.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_busy_rounded,
                      size: 64.sp,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'No appointments scheduled yet.'.translate(),
                      style: GoogleFonts.cairo(
                        color: Colors.grey.shade500,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Sort locally by createdAt descending
            appointments.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['createdAt'] as Timestamp?;
              final bTime = bData['createdAt'] as Timestamp?;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final cardColor = isDark ? const Color(0xFF162235) : Colors.white;

            return ListView.builder(
              padding: EdgeInsets.all(16.r),
              itemCount: appointments.length,
              itemBuilder: (context, index) {
                final doc = appointments[index];
                final data = doc.data() as Map<String, dynamic>;
                
                final clientName = data['userName'] as String? ?? data['clientName'] as String? ?? 'Unknown Client';
                final appointmentTime = data['time'] as String? ?? data['appointmentTime'] as String? ?? 'Time not set';
                final day = data['day'] as String? ?? 'Date not set';
                final type = data['consultationType'] as String? ?? 'office';
                final fees = data['fees']?.toString() ?? '0';
                
                final isOnline = type.toLowerCase() == 'online';
                final badgeColor = isOnline ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD);
                final badgeTextColor = isOnline ? const Color(0xFF2E7D32) : const Color(0xFF1565C0);

                return Container(
                  margin: EdgeInsets.only(bottom: 16.h),
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334766) : const Color(0xFFE5E7EB),
                      width: 1.w,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
                        blurRadius: 10,
                        offset: Offset(0, 4.h),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12.r),
                            decoration: BoxDecoration(
                              color: isOnline 
                                  ? Colors.green.withOpacity(0.1) 
                                  : AppColors.navyBlue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isOnline ? Icons.video_call_rounded : Icons.business_rounded,
                              color: isOnline ? Colors.green : AppColors.navyBlue,
                              size: 24.sp,
                            ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  clientName,
                                  style: GoogleFonts.cairo(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : AppColors.navyBlue,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4.h),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 12.sp,
                                      color: isDark ? Colors.white70 : Colors.grey[600],
                                    ),
                                    SizedBox(width: 4.w),
                                    Expanded(
                                      child: Text(
                                        '$day | $appointmentTime',
                                        style: GoogleFonts.cairo(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white70 : Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: isDark ? badgeColor.withOpacity(0.15) : badgeColor,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              isOnline ? 'Online' : 'In Office',
                              style: GoogleFonts.cairo(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: badgeTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        child: Divider(
                          color: isDark ? const Color(0xFF334766) : const Color(0xFFE5E7EB),
                          height: 1.h,
                        ),
                      ),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Amount Paid'.translate(),
                                style: GoogleFonts.cairo(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              Text(
                                '$fees EGP',
                                style: GoogleFonts.cairo(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.legalGold,
                                ),
                              ),
                            ],
                          ),
                          if (isOnline)
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VideoCallScreen(meetingId: doc.id),
                                  ),
                                );
                              },
                              icon: Icon(Icons.video_camera_front_rounded, size: 18.sp, color: Colors.white),
                              label: Text(
                                'Join Meeting'.translate(),
                                style: GoogleFonts.cairo(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
