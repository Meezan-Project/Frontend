import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/lawyer/screens/office_chat_screen.dart';

class EmployeeOfficeView extends StatefulWidget {
  final String officeId;
  const EmployeeOfficeView({super.key, required this.officeId});

  @override
  State<EmployeeOfficeView> createState() => _EmployeeOfficeViewState();
}

class _EmployeeOfficeViewState extends State<EmployeeOfficeView> {
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _isLeaving = false;

  void _leaveOffice() async {
    if (_currentUserId == null) return;

    final TextEditingController licenseController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLeavingProcess = false;

    // Fetch lawyer data to verify license ID
    final lawyerDoc = await FirebaseFirestore.instance
        .collection('lawyers')
        .doc(_currentUserId)
        .get();

    final correctLicenseId = lawyerDoc.data()?['license_ID']?.toString().trim() ?? '';

    final confirm = await showDialog<bool>(
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
                'Leave Office'.translate(),
                style: GoogleFonts.cairo(
                  color: AppColors.sosRed,
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
                      'Are you sure you want to leave this office? You will lose access to the office database and group chats. Enter your License ID to confirm.'
                          .translate(),
                      style: GoogleFonts.cairo(
                        color: AppColors.textDark.withOpacity(0.7),
                        fontSize: 14.sp,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: licenseController,
                      decoration: InputDecoration(
                        labelText: 'Your License ID'.translate(),
                        labelStyle: GoogleFonts.cairo(color: Colors.grey),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.sosRed, width: 1.5.w),
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
                        if (value.trim() != correctLicenseId) {
                          return 'License ID does not match'.translate();
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLeavingProcess ? null : () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel'.translate(),
                    style: GoogleFonts.cairo(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLeavingProcess
                      ? null
                      : () {
                          if (formKey.currentState!.validate()) {
                            Navigator.pop(context, true);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sosRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Confirm Leave'.translate(),
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      setState(() => _isLeaving = true);
      try {
        final firestore = FirebaseFirestore.instance;
        final batch = firestore.batch();

        // 1. Update lawyer state to freelancer
        batch.update(firestore.collection('lawyers').doc(_currentUserId), {
          'officeId': null,
          'officeRole': 'freelancer',
          'work_status': 'Freelancer',
        });

        // 2. Remove member from offices/{officeId}/members/{userId}
        batch.delete(firestore
            .collection('offices')
            .doc(widget.officeId)
            .collection('members')
            .doc(_currentUserId));

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You have successfully left the office.'.translate()),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to leave office. Please try again.'.translate()),
              backgroundColor: AppColors.sosRed,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLeaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('offices').doc(widget.officeId).get(),
      builder: (context, officeSnapshot) {
        if (officeSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!officeSnapshot.hasData || !officeSnapshot.data!.exists) {
          return Center(
            child: Text(
              'Office details not found.'.translate(),
              style: GoogleFonts.cairo(color: Colors.grey),
            ),
          );
        }

        final office = officeSnapshot.data!.data() as Map<String, dynamic>;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('offices')
              .doc(widget.officeId)
              .collection('members')
              .doc(_currentUserId)
              .get(),
          builder: (context, memberSnapshot) {
            double commissionRate = 15.0;
            if (memberSnapshot.hasData && memberSnapshot.data!.exists) {
              final memberData = memberSnapshot.data!.data() as Map<String, dynamic>;
              commissionRate = (memberData['commissionRate'] as num?)?.toDouble() ?? 15.0;
            }

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: CustomScrollView(
                slivers: [
                  // Office Header details card
                  SliverToBoxAdapter(
                    child: Container(
                      margin: EdgeInsets.only(top: 16.h, bottom: 20.h),
                      padding: EdgeInsets.all(20.r),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.navyBlue, Color(0xFF0F2035)],
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                office['name'] ?? '',
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: AppColors.legalGold.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20.r),
                                  border: Border.all(color: AppColors.legalGold),
                                ),
                                child: Text(
                                  'Employee Lawyer'.translate(),
                                  style: GoogleFonts.cairo(
                                    color: AppColors.legalGold,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SliverDivider(color: Colors.white24),
                          Text(
                            '${'Owner'.translate()}: ${office['ownerName'] ?? ''}',
                            style: GoogleFonts.cairo(
                              color: Colors.white70,
                              fontSize: 14.sp,
                            ),
                          ),
                          if (office['address'] != null && office['address'].toString().isNotEmpty) ...[
                            SizedBox(height: 4.h),
                            Text(
                              '${'Address'.translate()}: ${office['address']}',
                              style: GoogleFonts.cairo(
                                color: Colors.white70,
                                fontSize: 13.sp,
                              ),
                            ),
                          ],
                          SliverDivider(color: Colors.white24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'My Commission Rate'.translate(),
                                style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13.sp),
                              ),
                              Text(
                                '$commissionRate%',
                                style: GoogleFonts.cairo(
                                  color: AppColors.legalGold,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Office Conversations'.translate(),
                                style: GoogleFonts.cairo(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.navyBlue,
                                ),
                              ),
                              const Icon(Icons.chat_rounded, color: AppColors.legalGold),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildChatCard(
                                title: 'Global Chat'.translate(),
                                subtitle: 'All Members'.translate(),
                                icon: Icons.groups_rounded,
                                isDark: isDark,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => OfficeChatScreen(
                                        officeId: widget.officeId,
                                        chatTitle: 'Global Office Chat'.translate(),
                                        isGroupChat: true,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _buildChatCard(
                                title: 'Owner Chat'.translate(),
                                subtitle: (office['ownerName'] ?? 'Owner').toString(),
                                icon: Icons.support_agent_rounded,
                                isDark: isDark,
                                onTap: () {
                                  final ownerId = office['ownerId'] ?? widget.officeId;
                                  final sortedIds = [_currentUserId!, ownerId]..sort();
                                  final chatId = 'office_1on1_${sortedIds[0]}_${sortedIds[1]}';

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => OfficeChatScreen(
                                        officeId: widget.officeId,
                                        chatId: chatId,
                                        chatTitle: office['ownerName'] ?? 'Owner'.translate(),
                                        isGroupChat: false,
                                        targetUserId: ownerId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),

                  // Case list title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Assigned Cases'.translate(),
                            style: GoogleFonts.cairo(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.navyBlue,
                            ),
                          ),
                          const Icon(Icons.assignment_turned_in_rounded, color: AppColors.legalGold),
                        ],
                      ),
                    ),
                  ),

                  // Query cases assigned to this lawyer
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('cases')
                        .where('lawyerId', isEqualTo: _currentUserId)
                        .snapshots(),
                    builder: (context, casesSnapshot) {
                      if (casesSnapshot.connectionState == ConnectionState.waiting) {
                        return const SliverToBoxAdapter(
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final allDocs = casesSnapshot.data?.docs ?? [];
                      final cases = allDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['isOfficeAssigned'] == true;
                      }).toList();
                      if (cases.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Container(
                            padding: EdgeInsets.all(24.r),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Center(
                              child: Text(
                                'No cases assigned to you yet.'.translate(),
                                style: GoogleFonts.cairo(color: Colors.grey, fontSize: 14.sp),
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final caseDoc = cases[index];
                            final caseData = caseDoc.data() as Map<String, dynamic>;
                            final double totalFee = (caseData['legalFees'] as num?)?.toDouble() ?? 0.0;
                            final double commission = (totalFee * commissionRate) / 100.0;

                            return Card(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              margin: EdgeInsets.only(bottom: 12.h),
                              elevation: 1,
                              child: Padding(
                                padding: EdgeInsets.all(16.r),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          caseData['caseNumber'] ?? 'N/A',
                                          style: GoogleFonts.cairo(
                                            color: AppColors.legalGold,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.sp,
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: (caseData['status'] == 'active')
                                                ? Colors.green.withOpacity(0.12)
                                                : Colors.orange.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(8.r),
                                          ),
                                          child: Text(
                                            (caseData['status'] ?? 'Active').toString().toUpperCase().translate(),
                                            style: GoogleFonts.cairo(
                                              color: (caseData['status'] == 'active') ? Colors.green : Colors.orange,
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      caseData['title'] ?? '',
                                      style: GoogleFonts.cairo(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : AppColors.navyBlue,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      caseData['description'] ?? '',
                                      style: GoogleFonts.cairo(
                                        fontSize: 13.sp,
                                        color: isDark ? Colors.white70 : AppColors.textDark.withOpacity(0.7),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Divider(),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'My Commission'.translate(),
                                          style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.grey),
                                        ),
                                        Text(
                                          '$commission EGP',
                                          style: GoogleFonts.cairo(
                                            color: isDark ? Colors.white : AppColors.navyBlue,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: cases.length,
                        ),
                      );
                    },
                  ),

                  // Leave Office Action
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.h),
                      child: SizedBox(
                        height: 52.h,
                        child: OutlinedButton.icon(
                          onPressed: _isLeaving ? null : _leaveOffice,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.sosRed, width: 1.2.w),
                            foregroundColor: AppColors.sosRed,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          icon: _isLeaving
                              ? SizedBox(
                                  width: 18.w,
                                  height: 18.h,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.sosRed,
                                  ),
                                )
                              : const Icon(Icons.exit_to_app_rounded),
                          label: Text(
                            'Leave Office'.translate(),
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 15.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChatCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.w,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: AppColors.legalGold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.legalGold,
                size: 24.sp,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navyBlue,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2.h),
            Text(
              subtitle,
              style: GoogleFonts.cairo(
                fontSize: 12.sp,
                color: isDark ? Colors.white70 : AppColors.textDark.withOpacity(0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class SliverDivider extends StatelessWidget {
  final Color color;
  const SliverDivider({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Divider(color: color, height: 1.h),
    );
  }
}
