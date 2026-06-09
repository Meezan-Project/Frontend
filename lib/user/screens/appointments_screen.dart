import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/theme/app_typography.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mezaan/user/screens/video_call_screen.dart';
import 'package:mezaan/shared/services/notification_service.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  Future<void> _launchMaps(BuildContext context, String query) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open maps'.translate())),
      );
    }
  }



  Future<void> _cancelAppointment(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final double originalFee = (data['fees'] as num?)?.toDouble() ?? 0.0;
    final String paymentMethod = data['paymentMethod']?.toString() ?? 'cash';
    final bool isPaid = originalFee > 0 && paymentMethod != 'cash';
    final double refundAmount = originalFee > 200 ? originalFee - 200 : 0.0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel Appointment'.translate()),
        content: Text(
          isPaid
              ? '${'Are you sure you want to cancel this appointment?'.translate()}\n\n${'A cancellation fee of 200 EGP will be deducted, and'.translate()} ${refundAmount.toStringAsFixed(2)} ${'EGP will be refunded to your wallet.'.translate()}'
              : 'Are you sure you want to cancel this appointment?'.translate(),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'No'.translate(),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Yes, Cancel'.translate(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final firestore = FirebaseFirestore.instance;
        final batch = firestore.batch();

        final apptRef = firestore.collection('appointments').doc(docId);

        final String type =
            data['consultationType']?.toString() ??
            data['type']?.toString() ??
            'online';
        final Map<String, dynamic> updates = {
          'status': 'cancelled',
          'bookingStatus': 'cancelled',
        };

        if (isPaid) {
          updates['paymentStatus'] = 'refunded';
          updates['refundedAmount'] = refundAmount;
        }

        if (type == 'online') {
          updates['meetingLink'] = FieldValue.delete();
        } else if (type == 'office') {
          updates['officeAddress'] = FieldValue.delete();
          updates['address'] = FieldValue.delete();
          updates['location'] = FieldValue.delete();
        }

        batch.update(apptRef, updates);

        if (isPaid && refundAmount > 0) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            final userRef = firestore.collection('users').doc(currentUser.uid);
            batch.update(userRef, {
              'balance': FieldValue.increment(refundAmount),
            });

            final userTransRef = firestore
                .collection('users')
                .doc(currentUser.uid)
                .collection('transactions')
                .doc();
            batch.set(userTransRef, {
              'userId': currentUser.uid,
              'amount': refundAmount,
              'type': 'refund',
              'description':
                  'Refund to Wallet (${paymentMethod.toUpperCase()} payment cancellation) - 200 EGP Fee',
              'isWalletTransaction': true,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }

        await batch.commit();

        // Trigger notifications
        // Notify Client
        NotificationService().createAndSendNotification(
          targetUserId: data['userId'] ?? '',
          title: 'Appointment Cancelled'.translate(),
          body: '${'Your appointment with'.translate()} ${data['lawyerName']} ${'has been cancelled.'.translate()}',
          type: 'appointment',
          referenceId: docId,
        ).catchError((e) => debugPrint('Error sending client cancel notification: $e'));

        // Notify Lawyer
        NotificationService().createAndSendNotification(
          targetUserId: data['lawyerId'] ?? '',
          title: 'Appointment Cancelled'.translate(),
          body: '${'Client'.translate()} ${data['userName']} ${'has cancelled their appointment.'.translate()}',
          type: 'lawyer_request',
          referenceId: docId,
        ).catchError((e) => debugPrint('Error sending lawyer cancel notification: $e'));

        // If refund processed, notify client about refund
        if (isPaid && refundAmount > 0) {
          NotificationService().createAndSendNotification(
            targetUserId: data['userId'] ?? '',
            title: 'Refund Processed'.translate(),
            body: '$refundAmount ${'EGP has been refunded to your wallet.'.translate()}',
            type: 'transaction',
            referenceId: docId,
          ).catchError((e) => debugPrint('Error sending client refund notification: $e'));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel appointment'.translate())),
          );
        }
      }
    }
  }

  DateTime? _parseAppointmentDateTime(String day, String time) {
    try {
      final dayParts = day.split(',');
      if (dayParts.length < 2) return null;
      final datePart = dayParts[1].trim(); // "16 May 2026"
      final date = DateTime.parse(_convertToIsoDate(datePart));
      final timeRange = time.split('-');
      final startTime = timeRange[0].trim(); // "06:25 PM"
      final timeOfDay = _parseTimeOfDay(startTime);
      if (timeOfDay == null) return null;
      return DateTime(
        date.year,
        date.month,
        date.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );
    } catch (_) {
      return null;
    }
  }

  String _convertToIsoDate(String datePart) {
    final parts = datePart.split(' ');
    if (parts.length != 3) return '';
    final day = parts[0].padLeft(2, '0');
    final month = _monthToNumber(parts[1]);
    final year = parts[2];
    return "$year-$month-$day";
  }

  String _monthToNumber(String month) {
    switch (month.toLowerCase()) {
      case 'jan':
      case 'january':
        return '01';
      case 'feb':
      case 'february':
        return '02';
      case 'mar':
      case 'march':
        return '03';
      case 'apr':
      case 'april':
        return '04';
      case 'may':
        return '05';
      case 'jun':
      case 'june':
        return '06';
      case 'jul':
      case 'july':
        return '07';
      case 'aug':
      case 'august':
        return '08';
      case 'sep':
      case 'september':
        return '09';
      case 'oct':
      case 'october':
        return '10';
      case 'nov':
      case 'november':
        return '11';
      case 'dec':
      case 'december':
        return '12';
      default:
        return '01';
    }
  }

  TimeOfDay? _parseTimeOfDay(String time) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*([AP]M)').firstMatch(time);
    if (match == null) return null;
    int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2)!);
    final String period = match.group(3)!;
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1A2235)
          : const Color(0xFFF4F7FB),
      // الحل السحري: خليت الشاشة كلها تعمل سكرول مش الليستة بس
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ==========================================
            // LAYER 1: The Curved Navy Header
            // ==========================================
            Container(
              height: 220.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.navyBlue,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(35.r),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 16.h,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(12.r),
                        child: Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20.sp,
                          ),
                        ),
                      ),
                      // Title
                      Padding(
                        padding: EdgeInsets.only(top: 8.h),
                        child: Text(
                          'My Appointments'.translate(),
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20.sp,
                          ),
                        ),
                      ),
                      // Dummy box for perfect centering
                      SizedBox(width: 36.w),
                    ],
                  ),
                ),
              ),
            ),

            // ==========================================
            // LAYER 2: The Overlapping Content
            // ==========================================
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(
                top: 140.h,
              ), // هنا بنعمل التداخل مع الهيدر
              child: currentUser == null
                  ? _buildUnauthenticatedView(isDark)
                  : _buildStreamBuilder(currentUser.uid, isDark),
            ),
          ],
        ),
      ),
    );
  }

  // View shown when user is not logged in
  Widget _buildUnauthenticatedView(bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w),
      padding: EdgeInsets.all(32.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24344C) : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20.r,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Text(
        'Please log in to view your appointments.'.translate(),
        textAlign: TextAlign.center,
        style: GoogleFonts.cairo(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.navyBlue,
        ),
      ),
    );
  }

  // The main appointments list StreamBuilder
  Widget _buildStreamBuilder(String uid, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 300.h,
            alignment: Alignment.center,
            child: Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF24344C) : Colors.white,
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(color: AppColors.navyBlue),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            height: 300.h,
            alignment: Alignment.center,
            child: Text(
              'Error loading appointments:\n${snapshot.error}'.translate(),
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(
                context,
              ).copyWith(color: Colors.red),
            ),
          );
        }

        final docs = snapshot.data?.docs.toList() ?? [];

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty) {
          return _buildEmptyState(context, isDark);
        }

        return ListView.separated(
          shrinkWrap: true, // مهم جداً عشان تشتغل جوه الـ SingleChildScrollView
          physics:
              const NeverScrollableScrollPhysics(), // بنقفل السكرول الداخلي عشان الشاشة كلها تسكرول
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 40.h),
          itemCount: docs.length,
          separatorBuilder: (context, index) => SizedBox(height: 16.h),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final lawyerName =
                data['lawyerName'] ?? data['lawyer'] ?? 'Unknown Lawyer';
            final type = data['consultationType'] ?? data['type'] ?? 'online';
            final status = data['status'] ?? 'pending';
            final isCancelled = status == 'cancelled';

            final address =
                data['officeAddress'] ??
                data['address'] ??
                data['location'] ??
                (isCancelled
                    ? 'Not available'.translate()
                    : 'Location not specified'.translate());
            final lawyerImage = data['lawyerImage']?.toString().trim() ?? '';
            final agoraChannelId = doc.id;
            final meetingStatusText = isCancelled ? 'Not available'.translate() : 'Available'.translate();

            final dayStr = data['day']?.toString() ?? '';
            final dateStr = data['dateLabel'] ?? data['date'] ?? 'Pending Date';
            final dateDisplay =
                dayStr.isNotEmpty && !dateStr.toString().contains(dayStr)
                ? '$dayStr, $dateStr'
                : dateStr.toString();
            final timeStr = data['timeRange'] ?? data['time'] ?? 'Pending Time';
            final paymentMethod = data['paymentMethod'] ?? 'Cash/Wallet';

            final apptDateTime = _parseAppointmentDateTime(dayStr, timeStr);
            final isEnded = status == 'done' || status == 'completed' || (apptDateTime != null && DateTime.now().isAfter(apptDateTime));

            final hasImage =
                lawyerImage.isNotEmpty &&
                Uri.tryParse(lawyerImage)?.hasAbsolutePath == true;

            return Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF24344C) : Colors.white,
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2A3550)
                      : const Color(0xFFE6ECF5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navyBlue.withOpacity(0.06),
                    blurRadius: 20.r,
                    offset: Offset(0, 8.h),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30.r,
                        backgroundColor: AppColors.navyBlue.withOpacity(0.08),
                        backgroundImage: hasImage
                            ? NetworkImage(lawyerImage)
                            : null,
                        child: !hasImage
                            ? Icon(
                                Icons.gavel_rounded,
                                color: AppColors.navyBlue,
                                size: 28.sp,
                              )
                            : null,
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lawyerName,
                              style: GoogleFonts.cairo(
                                color: isDark
                                    ? Colors.white
                                    : AppColors.navyBlue,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              type == 'office'
                                  ? 'In-Office Consultation'.translate()
                                  : 'Online Meeting'.translate(),
                              style: GoogleFonts.cairo(
                                color: isDark
                                    ? Colors.white.withOpacity(0.7)
                                    : Colors.grey.shade600,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      _buildStatusBadge(context, status, isEnded),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    child: Divider(
                      color: isDark
                          ? const Color(0xFF334866)
                          : Colors.grey.shade200,
                      height: 1,
                      thickness: 1,
                    ),
                  ),
                  _buildInfoRow(
                    context,
                    Icons.calendar_month_rounded,
                    'Date & Time'.translate(),
                    '$dateDisplay • $timeStr',
                    isDark: isDark,
                  ),
                  SizedBox(height: 16.h),
                  _buildInfoRow(
                    context,
                    Icons.payment_rounded,
                    'Payment Method'.translate(),
                    paymentMethod.toString().toUpperCase(),
                    isDark: isDark,
                  ),
                  if (type == 'office') ...[
                    SizedBox(height: 16.h),
                    _buildInfoRow(
                      context,
                      Icons.location_on_rounded,
                      'Location'.translate(),
                      address,
                      isActionable:
                          !isEnded &&
                          address.isNotEmpty &&
                          address != 'Location not specified'.translate() &&
                          address != 'Not available'.translate(),
                      actionText: 'Open in Map'.translate(),
                      onActionTap: () => _launchMaps(context, address),
                      isDark: isDark,
                    ),
                  ],
                  if (type == 'online') ...[
                    SizedBox(height: 16.h),
                    _buildInfoRow(
                      context,
                      Icons.video_camera_front_rounded,
                      'Meeting Link'.translate(),
                      meetingStatusText,
                      isActionable: !isCancelled && !isEnded,
                      actionText: 'Join Meeting'.translate(),
                      onActionTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoCallScreen(meetingId: agoraChannelId),
                          ),
                        );
                      },
                      isDark: isDark,
                    ),
                  ],
                  if (!isCancelled && status != 'done' && status != 'completed' && !isEnded) ...[
                    SizedBox(height: 24.h),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _cancelAppointment(context, doc.id, data),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFFC63F3F),
                            width: 1.2,
                          ),
                          foregroundColor: const Color(0xFFC63F3F),
                          backgroundColor: isDark
                              ? const Color(0xFF3A2830)
                              : const Color(0xFFFFF5F5),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        icon: const Icon(Icons.cancel_outlined),
                        label: Text(
                          'Cancel Appointment'.translate(),
                          style: GoogleFonts.cairo(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w),
      padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24344C) : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20.r,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2235) : const Color(0xFFF4F7FB),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_busy_rounded,
              size: 48.w,
              color: AppColors.navyBlue.withOpacity(0.5),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'No appointments yet'.translate(),
            style: GoogleFonts.cairo(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
            ).copyWith(color: isDark ? Colors.white : AppColors.navyBlue),
          ),
          SizedBox(height: 8.h),
          Text(
            'Book a consultation to see it here.'.translate(),
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(
              context,
            ).copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool isActionable = false,
    String? actionText,
    VoidCallback? onActionTap,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(10.r),
          decoration: BoxDecoration(
            color: AppColors.navyBlue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(icon, size: 20.sp, color: AppColors.navyBlue),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: (isDark ? Colors.white : AppColors.navyBlue)
                      .withOpacity(0.6),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                value,
                style: GoogleFonts.cairo(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                  height: 1.3,
                ),
              ),
              if (isActionable && actionText != null) ...[
                SizedBox(height: 6.h),
                InkWell(
                  onTap: onActionTap,
                  borderRadius: BorderRadius.circular(6.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          actionText,
                          style: GoogleFonts.cairo(
                            color: AppColors.legalGold,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.sp,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12.sp,
                          color: AppColors.legalGold,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status, bool isEnded) {
    Color bgColor;
    Color textColor;
    String text = status;

    if (isEnded) {
      bgColor = Colors.grey.withOpacity(0.15);
      textColor = Colors.grey.shade700;
      text = 'Ended'.translate();
    } else if (status == 'done' || status == 'completed') {
      bgColor = Colors.green.withOpacity(0.1);
      textColor = Colors.green.shade700;
      text = 'Completed'.translate();
    } else if (status == 'cancelled') {
      bgColor = Colors.red.withOpacity(0.1);
      textColor = Colors.red.shade700;
      text = 'Cancelled'.translate();
    } else {
      bgColor = AppColors.legalGold.withOpacity(0.15);
      textColor = const Color(0xFFB8860B);
      text = 'Pending'.translate();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.cairo(
          color: textColor,
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
