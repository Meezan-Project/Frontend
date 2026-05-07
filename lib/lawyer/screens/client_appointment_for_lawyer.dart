import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class LawyerRealScheduleScreen extends StatelessWidget {
  const LawyerRealScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Appointments')),
        body: const Center(child: Text('User not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
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
          final validAppointments = appointments.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final clientName = (data['clientName'] as String?)?.trim() ?? '';
            return clientName.isNotEmpty;
          }).toList();

          if (validAppointments.isEmpty) {
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

          return ListView.separated(
            padding: EdgeInsets.all(16.r),
            itemCount: validAppointments.length,
            separatorBuilder: (context, index) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final doc = validAppointments[index];
              final data = doc.data() as Map<String, dynamic>;
              final clientName = (data['clientName'] as String?)?.trim() ?? 'No Name';
              final appointmentTime = data['appointmentTime'] as String? ?? 'Time not set';
              final day = data['day'] as String? ?? 'Date not set';

              return _buildAppointmentCard(
                clientName: clientName,
                appointmentTime: appointmentTime,
                day: day,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAppointmentCard({
    required String clientName,
    required String appointmentTime,
    required String day,
  }) {
    return Container(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            clientName,
            style: GoogleFonts.cairo(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.navyBlue,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16.sp, color: Colors.grey[600]),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  day,
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Icon(Icons.access_time, size: 16.sp, color: Colors.grey[600]),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  appointmentTime,
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}