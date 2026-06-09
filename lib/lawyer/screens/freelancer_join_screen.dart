import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class FreelancerJoinScreen extends StatefulWidget {
  const FreelancerJoinScreen({super.key});

  @override
  State<FreelancerJoinScreen> createState() => _FreelancerJoinScreenState();
}

class _FreelancerJoinScreenState extends State<FreelancerJoinScreen> {
  final TextEditingController _searchController = TextEditingController();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String _searchQuery = '';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _sendJoinRequest(Map<String, dynamic> office) async {
    if (_currentUserId == null) return;

    final TextEditingController licenseController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isVerifying = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              title: Text(
                'Join Office'.translate(),
                style: GoogleFonts.cairo(
                  color: AppColors.navyBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'To join "${office['name']}", you must enter the Owner\'s License ID for security validation.'
                          .translate(),
                      style: GoogleFonts.cairo(
                        color: AppColors.textDark.withOpacity(0.7),
                        fontSize: 14.sp,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: licenseController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Owner License ID'.translate(),
                        labelStyle: GoogleFonts.cairo(color: Colors.grey),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.legalGold,
                            width: 1.5.w,
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'License ID is required'.translate();
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying
                      ? null
                      : () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel'.translate(),
                    style: GoogleFonts.cairo(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() {
                              isVerifying = true;
                            });

                            final inputId = licenseController.text.trim();
                            final correctId = office['ownerLicenseId']
                                .toString()
                                .trim();

                            if (inputId == correctId) {
                              Navigator.pop(context, true);
                            } else {
                              setDialogState(() {
                                isVerifying = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Incorrect Owner License ID. Please try again.'
                                        .translate(),
                                  ),
                                  backgroundColor: AppColors.sosRed,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: isVerifying
                      ? SizedBox(
                          width: 18.w,
                          height: 18.h,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Submit'.translate(),
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      setState(() => _isSubmitting = true);
      try {
        // Fetch freelancer details
        final freelancerDoc = await FirebaseFirestore.instance
            .collection('lawyers')
            .doc(_currentUserId)
            .get();

        final freelancerData = freelancerDoc.data() ?? {};
        final name = freelancerData['name'] ?? 'Freelancer Lawyer';
        final licenseId = freelancerData['license_ID'] ?? '';
        final specs = freelancerData['specialization'] ?? [];

        // Save request
        final requestId = '${_currentUserId}_${office['officeId']}';
        await FirebaseFirestore.instance
            .collection('office_requests')
            .doc(requestId)
            .set({
              'requestId': requestId,
              'freelancerId': _currentUserId,
              'freelancerName': name,
              'freelancerLicenseId': licenseId,
              'freelancerSpecialization': specs,
              'officeId': office['officeId'],
              'officeName': office['name'],
              'ownerId': office['ownerId'],
              'status': 'pending',
              'createdAt': FieldValue.serverTimestamp(),
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Join request submitted successfully.'.translate()),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to submit request. Please try again.'.translate(),
              ),
              backgroundColor: AppColors.sosRed,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  void _cancelRequest(String requestId) async {
    setState(() => _isSubmitting = true);
    try {
      await FirebaseFirestore.instance
          .collection('office_requests')
          .doc(requestId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request cancelled successfully.'.translate()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel request.'.translate()),
            backgroundColor: AppColors.sosRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lawyers')
          .doc(_currentUserId)
          .snapshots(),
      builder: (context, lawyerSnapshot) {
        if (lawyerSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final lawyerData = lawyerSnapshot.data?.data() as Map<String, dynamic>? ?? {};
        final workStatusRaw = (lawyerData['work_status'] ?? '').toString().trim().toLowerCase();
        final isAssociate = workStatusRaw.contains('work') || workStatusRaw.contains('employee');

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('office_requests')
              .where('freelancerId', isEqualTo: _currentUserId)
              .snapshots(),
          builder: (context, requestSnapshot) {
            if (requestSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final requests = requestSnapshot.data?.docs ?? [];
            final hasPendingRequest = requests.any(
              (doc) => doc['status'] == 'pending',
            );
            final pendingRequest = hasPendingRequest
                ? requests.firstWhere((doc) => doc['status'] == 'pending')
                : null;

            return Column(
              children: [
                // Header Intro Card
                Container(
                  margin: EdgeInsets.all(16.r),
                  padding: EdgeInsets.all(20.r),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.navyBlue, Color(0xFF0D253F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isAssociate
                            ? 'Associate Status'.translate()
                            : 'Freelancer Status'.translate(),
                        style: GoogleFonts.cairo(
                          color: AppColors.legalGold,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        isAssociate
                            ? 'You are registered as working in an office, but are not currently attached to any office. Search for your employer\'s office below to submit a join request.'
                                .translate()
                            : 'You are currently an independent Freelancer. Search for law offices to request joining their team, collaborate on cases, and receive commissions.'
                                .translate(),
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 13.5.sp,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                if (hasPendingRequest && pendingRequest != null) ...[
                  // Pending Request Banner
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16.w),
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: AppColors.legalGold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.legalGold, width: 1.w),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.hourglass_empty_rounded,
                          color: AppColors.legalGold,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pending Office Request'.translate(),
                                style: GoogleFonts.cairo(
                                  color: AppColors.navyBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.sp,
                                ),
                              ),
                              Text(
                                'Sent to: ${pendingRequest['officeName']}'
                                    .translate(),
                                style: GoogleFonts.cairo(
                                  color: AppColors.textDark,
                                  fontSize: 12.5.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => _cancelRequest(pendingRequest.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.sosRed,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 12.w),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          child: Text(
                            'Cancel'.translate(),
                            style: GoogleFonts.cairo(fontSize: 11.sp),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                ] else ...[
                  // Search Input
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.cairo(
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search office by name...'.translate(),
                        hintStyle: GoogleFonts.cairo(color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: isDark
                              ? BorderSide.none
                              : const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppColors.legalGold,
                            width: 1.5.w,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.trim();
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('offices')
                        .snapshots(),
                    builder: (context, officeSnapshot) {
                      if (officeSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      var docs = officeSnapshot.data?.docs ?? [];
                      if (_searchQuery.isNotEmpty) {
                        docs = docs.where((doc) {
                          final name = (doc['name'] ?? '').toString().toLowerCase();
                          final owner = (doc['ownerName'] ?? doc['owner_name'] ?? '').toString().toLowerCase();
                          final query = _searchQuery.toLowerCase();
                          return name.contains(query) || owner.contains(query);
                        }).toList();
                      }

                      if (docs.isEmpty) {
                        return Center(
                          child: Text(
                            'No offices found.'.translate(),
                            style: GoogleFonts.cairo(
                              color: Colors.grey,
                              fontSize: 14.sp,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        itemBuilder: (context, index) {
                          final officeDoc = docs[index];
                          final office = officeDoc.data() as Map<String, dynamic>;

                          return Card(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            elevation: 1,
                            margin: EdgeInsets.only(bottom: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 8.h,
                              ),
                              title: Text(
                                office['name'] ?? '',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.sp,
                                  color: isDark ? Colors.white : AppColors.navyBlue,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${'Owner'.translate()}: ${(office['ownerName'] ?? office['owner_name'] ?? 'Unknown Owner').toString().trim()}',
                                    style: GoogleFonts.cairo(
                                      fontSize: 13.sp,
                                      color: isDark
                                          ? Colors.white70
                                          : AppColors.textDark.withOpacity(0.7),
                                    ),
                                  ),
                                  if (office['address'] != null &&
                                      office['address'].toString().isNotEmpty)
                                    Text(
                                      office['address'],
                                      style: GoogleFonts.cairo(
                                        fontSize: 12.sp,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: (hasPendingRequest || _isSubmitting)
                                    ? null
                                    : () => _sendJoinRequest(office),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.legalGold,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                                child: Text(
                                  'Join'.translate(),
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
