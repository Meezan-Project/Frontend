import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/theme/app_typography.dart';
import 'package:mezaan/user/screens/sos_video_player_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class SosRequestsScreen extends StatelessWidget {
  const SosRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        body: Center(
          child: Text(
            'User not logged in.',
            style: AppTypography.bodyMedium(context),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sos_alerts')
              .where('userId', isEqualTo: currentUser.uid)
              // .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            final totalFiles = docs.length;
            
            // Local sort to avoid index issues if order is needed
            docs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['timestamp'] as Timestamp?;
              final bTime = bData['timestamp'] as Timestamp?;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });

            return Column(
              children: [
                // Header with Overlapping Card
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      children: [
                        // Navy Blue Header Background
                        Container(
                          width: double.infinity,
                          height: 220.h,
                          decoration: BoxDecoration(
                            color: AppColors.navyBlue,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(30.r),
                              bottomRight: Radius.circular(30.r),
                            ),
                          ),
                          child: SafeArea(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 10.h,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back_ios,
                                      color: Colors.white,
                                    ),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(top: 8.h),
                                      child: Text(
                                        'SOS Evidence',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.cairo(
                                          color: Colors.white,
                                          fontSize: 20.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 48.w), // Balance alignment
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 110.h),
                      ],
                    ),
                    
                    // Overlapping Status Card
                    Positioned(
                      top: 120.h,
                      left: 24.w,
                      right: 24.w,
                      child: Container(
                        padding: EdgeInsets.all(24.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 15,
                              offset: Offset(0, 8.h),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shield_rounded, color: Colors.green, size: 20.sp),
                                SizedBox(width: 8.w),
                                Text(
                                  'Security Status',
                                  style: GoogleFonts.cairo(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              '$totalFiles Secured Files',
                              style: GoogleFonts.cairo(
                                fontSize: 28.sp,
                                fontWeight: FontWeight.w900,
                                color: AppColors.navyBlue,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'End-to-End Encrypted',
                              style: GoogleFonts.cairo(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.legalGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Recent Evidence List
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Recordings',
                          style: GoogleFonts.cairo(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navyBlue,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        
                        Expanded(
                          child: snapshot.connectionState == ConnectionState.waiting
                              ? const Center(
                                  child: CircularProgressIndicator(color: AppColors.legalGold),
                                )
                              : docs.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.videocam_off_outlined,
                                            size: 64.sp,
                                            color: Colors.grey.shade400,
                                          ),
                                          SizedBox(height: 16.h),
                                          Text(
                                            'No evidence secured yet',
                                            style: GoogleFonts.cairo(
                                              fontSize: 16.sp,
                                              color: Colors.grey.shade500,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: EdgeInsets.zero,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: docs.length,
                                      separatorBuilder: (context, index) => SizedBox(height: 16.h),
                                      itemBuilder: (context, index) {
                                        final data = docs[index].data() as Map<String, dynamic>;

                                        final timestamp = data['timestamp'] as Timestamp?;
                                        final dateLabel = timestamp != null
                                            ? DateFormat('MMM d, yyyy  •  hh:mm a').format(timestamp.toDate())
                                            : 'Unknown Date & Time';

                                        final duration = data['duration'] ?? 0;
                                        final String durationLabel = duration > 60
                                            ? '${(duration / 60).toStringAsFixed(1)} mins'
                                            : '$duration secs';

                                        final videoUrl = data['videoUrl'] as String?;
                                        final status = data['status'] ?? 'Unknown';
                                        final isSaved = status.toLowerCase() == 'saved';

                                        return Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16.r),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.04),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(16.r),
                                            child: Row(
                                              children: [
                                                // Left Accent Border (Red for SOS)
                                                Container(
                                                  width: 6.w,
                                                  height: 120.h,
                                                  color: const Color(0xFFB91C1C),
                                                ),
                                                Expanded(
                                                  child: Padding(
                                                    padding: EdgeInsets.all(16.r),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Emergency Video',
                                                              style: GoogleFonts.cairo(
                                                                fontSize: 14.sp,
                                                                fontWeight: FontWeight.w700,
                                                                color: AppColors.navyBlue,
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                            Container(
                                                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
                                                              decoration: BoxDecoration(
                                                                color: isSaved ? Colors.green.withOpacity(0.1) : AppColors.legalGold.withOpacity(0.1),
                                                                borderRadius: BorderRadius.circular(20.r),
                                                              ),
                                                              child: Text(
                                                                status.toUpperCase(),
                                                                style: GoogleFonts.cairo(
                                                                  fontSize: 10.sp,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: isSaved ? Colors.green[700] : AppColors.legalGold,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(height: 4.h),
                                                        Text(
                                                          dateLabel,
                                                          style: GoogleFonts.cairo(
                                                            fontSize: 12.sp,
                                                            fontWeight: FontWeight.w600,
                                                            color: Colors.grey.shade500,
                                                          ),
                                                        ),
                                                        SizedBox(height: 12.h),
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            Text(
                                                              durationLabel,
                                                              style: GoogleFonts.cairo(
                                                                fontSize: 13.sp,
                                                                fontWeight: FontWeight.bold,
                                                                color: const Color(0xFFB91C1C),
                                                              ),
                                                            ),
                                                            if (videoUrl != null && videoUrl.isNotEmpty)
                                                              Row(
                                                                children: [
                                                                  GestureDetector(
                                                                    onTap: () async {
                                                                      final url = Uri.parse(videoUrl.contains('?') ? '$videoUrl&download=' : '$videoUrl?download=');
                                                                      if (await canLaunchUrl(url)) {
                                                                        await launchUrl(url, mode: LaunchMode.externalApplication);
                                                                      }
                                                                    },
                                                                    child: Icon(Icons.download_rounded, color: Colors.grey.shade600, size: 24.sp),
                                                                  ),
                                                                  SizedBox(width: 16.w),
                                                                  GestureDetector(
                                                                    onTap: () {
                                                                      Navigator.push(
                                                                        context,
                                                                        MaterialPageRoute(
                                                                          builder: (_) => SosVideoPlayerScreen(videoUrl: videoUrl),
                                                                        ),
                                                                      );
                                                                    },
                                                                    child: Icon(Icons.play_circle_fill_rounded, color: AppColors.navyBlue, size: 32.sp),
                                                                  ),
                                                                ],
                                                              )
                                                            else
                                                              Row(
                                                                children: [
                                                                  SizedBox(
                                                                    width: 14.r,
                                                                    height: 14.r,
                                                                    child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.legalGold),
                                                                  ),
                                                                  SizedBox(width: 6.w),
                                                                  Text(
                                                                    'Uploading...',
                                                                    style: GoogleFonts.cairo(
                                                                      fontSize: 12.sp,
                                                                      color: AppColors.legalGold,
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                ],
                                                              )
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
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