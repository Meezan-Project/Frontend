import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/user/screens/video_call_screen.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 19.sp,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          subtitle,
          style: TextStyle(
            color: textTheme.bodyMedium?.color?.withOpacity(0.7),
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class UpcomingAppointmentsWidget extends StatelessWidget {
  // Helper to parse appointment day and time to DateTime
  static DateTime? _parseAppointmentDateTime(String day, String time) {
    try {
      // Example day: "Saturday, 16 May 2026"
      // Example time: "06:25 PM - 07:10 PM"
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

  // Convert "16 May 2026" to "2026-05-16"
  static String _convertToIsoDate(String datePart) {
    final parts = datePart.split(' ');
    if (parts.length != 3) return '';
    final day = parts[0].padLeft(2, '0');
    final month = _monthToNumber(parts[1]);
    final year = parts[2];
    return "$year-$month-$day";
  }

  static String _monthToNumber(String month) {
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

  // Parse "06:25 PM" to TimeOfDay
  static TimeOfDay? _parseTimeOfDay(String time) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*([AP]M)').firstMatch(time);
    if (match == null) return null;
    int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2)!);
    final String period = match.group(3)!;
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  const UpcomingAppointmentsWidget({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _appointmentsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    final ref = FirebaseFirestore.instance
        .collection('appointments')
        .where('userId', isEqualTo: user.uid)
        .where('bookingStatus', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .limit(10);
    return ref.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _appointmentsStream(),
      builder: (context, snapshot) {
        Widget sectionHeader = _SectionHeader(
          title: 'Next Appointments',
          subtitle: 'Your upcoming meetings and visits',
        );
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionHeader,
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionHeader,
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    "No upcoming appointments",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        final appointments = snapshot.data!.docs;
        // Check and update status for past appointments
        Future.microtask(() async {
          for (final doc in appointments) {
            final data = doc.data();
            final appointmentDay = data['day'] ?? '';
            final appointmentTime = data['time'] ?? '';
            if (appointmentDay.isNotEmpty && appointmentTime.isNotEmpty) {
              try {
                // Parse the day and time to DateTime
                final dateTime = _parseAppointmentDateTime(
                  appointmentDay,
                  appointmentTime,
                );
                if (dateTime != null &&
                    DateTime.now().isAfter(
                      dateTime.add(Duration(seconds: 1)),
                    )) {
                  // Update Firestore if not already completed
                  if (data['bookingStatus'] == 'pending') {
                    await doc.reference.update({'bookingStatus': 'completed'});
                  }
                }
              } catch (_) {}
            }
          }
        });

        final now = DateTime.now();
        final activeAppointments = appointments.where((doc) {
          final data = doc.data();
          final appointmentDay = data['day'] ?? '';
          final appointmentTime = data['time'] ?? '';
          if (appointmentDay.isEmpty || appointmentTime.isEmpty) return false;
          final dateTime = _parseAppointmentDateTime(appointmentDay, appointmentTime);
          if (dateTime == null) return false;
          return dateTime.isAfter(now);
        }).toList();

        if (activeAppointments.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionHeader,
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    "No upcoming appointments".translate(),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // Sort appointments by nearest date/time ascending
        final sortedAppointments =
            List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
              activeAppointments,
            );
        sortedAppointments.sort((a, b) {
          final aData = a.data();
          final bData = b.data();
          final aDate =
              _parseAppointmentDateTime(
                aData['day'] ?? '',
                aData['time'] ?? '',
              ) ??
              DateTime(2100);
          final bDate =
              _parseAppointmentDateTime(
                bData['day'] ?? '',
                bData['time'] ?? '',
              ) ??
              DateTime(2100);
          return aDate.compareTo(bDate);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionHeader,
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: sortedAppointments.length,
              separatorBuilder: (_, _) => SizedBox(height: 8.h),
              itemBuilder: (context, index) {
                final data = sortedAppointments[index].data();
                final lawyerName = data['lawyerName'] ?? 'Lawyer';
                final lawyerAvatar =
                    data['lawyerAvatar'] ?? data['lawyerImage'];
                final appointmentDay = data['day'] ?? '';
                final appointmentTime = data['time'] ?? '';
                final meetingType =
                    data['type'] ?? data['consultationType'] ?? 'in_office';
                final docId = sortedAppointments[index].id;
                final meetingLink = docId;
                final locationUrl =
                    data['locationUrl'] ?? data['officeAddress'];
                final isOnline = meetingType == 'online';

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  color: Colors.white,
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Color(0xFF0A2342),
                          backgroundImage: lawyerAvatar != null
                              ? NetworkImage(lawyerAvatar)
                              : null,
                          child: lawyerAvatar == null
                              ? Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 28,
                                )
                              : null,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lawyerName,
                                style: TextStyle(
                                  color: Color(0xFF0A2342),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              if (appointmentDay.isNotEmpty ||
                                  appointmentTime.isNotEmpty)
                                Text(
                                  appointmentDay.isNotEmpty &&
                                          appointmentTime.isNotEmpty
                                      ? "$appointmentDay at $appointmentTime"
                                      : appointmentDay.isNotEmpty
                                      ? appointmentDay
                                      : appointmentTime,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                ),
                              if (appointmentDay.isEmpty &&
                                  appointmentTime.isEmpty)
                                Text(
                                  "Unknown appointment time",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                              SizedBox(height: 6),
                              _buildBadge(meetingType),
                            ],
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isOnline
                                ? Color(0xFF0A2342) // Navy Blue
                                : Color(0xFFFFD700), // Gold
                            foregroundColor: isOnline
                                ? Colors.white
                                : Color(0xFF0A2342),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () async {
                            final scaffoldMessenger = ScaffoldMessenger.of(
                              context,
                            );
                            if (isOnline) {
                              // Open video call link (meetingLink)
                              if (meetingLink.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        VideoCallScreen(meetingId: meetingLink),
                                  ),
                                );
                              } else {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'No valid meeting link provided.',
                                    ),
                                  ),
                                );
                              }
                            } else {
                              // Open Google Maps with locationUrl (should be address or lat,lng)
                              if (locationUrl != null &&
                                  locationUrl is String &&
                                  locationUrl.isNotEmpty) {
                                String googleMapsUrl;
                                if (locationUrl.contains(',')) {
                                  // Assume lat,lng
                                  googleMapsUrl =
                                      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(locationUrl)}';
                                } else {
                                  // Assume address
                                  googleMapsUrl =
                                      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(locationUrl)}';
                                }
                                final uri = Uri.tryParse(googleMapsUrl);
                                if (uri != null && await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                } else {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Could not open Google Maps for this location.',
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'No valid location provided.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: Text(
                            isOnline ? "Join Meeting" : "Get Location",
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  static Widget _buildBadge(String meetingType) {
    final isOnline = meetingType == 'online';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOnline ? Color(0xFF0A2342) : Color(0xFFFFD700),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isOnline ? "Online Meeting" : "In-Office",
        style: TextStyle(
          color: isOnline ? Colors.white : Color(0xFF0A2342),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

}
