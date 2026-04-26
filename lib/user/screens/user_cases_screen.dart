import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/models/case_model.dart';
import 'package:mezaan/user/models/mock_case_data.dart';
import 'case_details_screen.dart';

class UserCasesScreen extends StatefulWidget {
  final bool embedded;

  const UserCasesScreen({super.key, this.embedded = false});

  @override
  State<UserCasesScreen> createState() => _UserCasesScreenState();
}

class _UserCasesScreenState extends State<UserCasesScreen>
    with AutomaticKeepAliveClientMixin {
  String _filterStatus = 'all'; // all, active, closed, pending, on_hold

  @override
  bool get wantKeepAlive => true;

  Stream<List<UserCase>> _getUserCases() {
    // Using mock data for UI design preview
    // To use real Firestore data, uncomment the code below and comment out the mock data
    return Stream.value(MockCaseData.getMockCases());

    // Real Firestore implementation:
    /*
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cases')
        .orderBy('createdDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserCase.fromFirestore(doc))
              .toList();
        });
    */
  }

  List<UserCase> _filterCases(List<UserCase> cases) {
    if (_filterStatus == 'all') {
      return cases;
    }
    return cases.where((c) => c.status == _filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<UserCase>>(
      stream: _getUserCases(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: AppColors.legalGold,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48.sp,
                  color: Colors.red,
                ),
                SizedBox(height: 16.h),
                Text(
                  'Error loading cases'.translate(),
                  style: GoogleFonts.cairo(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        final allCases = snapshot.data ?? [];
        final filteredCases = _filterCases(allCases);

        if (allCases.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_shared_outlined,
                  size: 64.sp,
                  color: isDark
                      ? Colors.grey.shade600
                      : Colors.grey.shade400,
                ),
                SizedBox(height: 16.h),
                Text(
                  'No cases yet'.translate(),
                  style: GoogleFonts.cairo(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Your cases will appear here'.translate(),
                  style: GoogleFonts.cairo(
                    fontSize: 14.sp,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
          children: [
            // Header
            Text(
              'My Cases'.translate(),
              style: GoogleFonts.cairo(
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 12.h),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All'.translate(), allCases.length, isDark),
                  SizedBox(width: 8.w),
                  _buildFilterChip('active', 'Active'.translate(),
                      allCases.where((c) => c.status == 'active').length, isDark),
                  SizedBox(width: 8.w),
                  _buildFilterChip('closed', 'Closed'.translate(),
                      allCases.where((c) => c.status == 'closed').length, isDark),
                  SizedBox(width: 8.w),
                  _buildFilterChip('pending', 'Pending'.translate(),
                      allCases.where((c) => c.status == 'pending').length, isDark),
                  SizedBox(width: 8.w),
                  _buildFilterChip('on_hold', 'On Hold'.translate(),
                      allCases.where((c) => c.status == 'on_hold').length, isDark),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Cases List
            if (filteredCases.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.h),
                  child: Text(
                    'No cases in this category'.translate(),
                    style: GoogleFonts.cairo(
                      fontSize: 14.sp,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ),
              )
            else
              ...filteredCases.map((case_) => Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: _CaseCard(
                      case_: case_,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) =>
                                CaseDetailsScreen(case_: case_),
                          ),
                        );
                      },
                    ),
                  )),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(
    String value,
    String label,
    int count,
    bool isDark,
  ) {
    final isActive = _filterStatus == value;
    return FilterChip(
      label: Text(
        '$label ($count)',
        style: GoogleFonts.cairo(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: isActive ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
        ),
      ),
      backgroundColor: isActive
          ? AppColors.legalGold
          : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  final UserCase case_;
  final VoidCallback onTap;

  const _CaseCard({
    required this.case_,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1A2940) : Colors.white;
    final completionPercent = case_.getCompletionPercentage();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 12,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        case_.caseNumber,
                        style: GoogleFonts.cairo(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.legalGold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        case_.title,
                        style: GoogleFonts.cairo(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                _buildStatusBadge(case_.status, isDark),
              ],
            ),
            SizedBox(height: 12.h),

            // Lawyer info
            Row(
              children: [
                CircleAvatar(
                  radius: 18.r,
                  backgroundColor: AppColors.legalGold.withValues(alpha: 0.2),
                  child: Text(
                    case_.lawyerName.isNotEmpty
                        ? case_.lawyerName[0].toUpperCase()
                        : 'L',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w700,
                      color: AppColors.legalGold,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lawyer'.translate(),
                        style: GoogleFonts.cairo(
                          fontSize: 11.sp,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        case_.lawyerName,
                        style: GoogleFonts.cairo(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),

            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Documents'.translate(),
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$completionPercent%',
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.legalGold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    value: completionPercent / 100,
                    minHeight: 6.h,
                    backgroundColor:
                        isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.legalGold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Footer info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoChip(
                  icon: Icons.calendar_today_outlined,
                  label:
                      '${case_.sessions.length} ${'sessions'.translate()}',
                  isDark: isDark,
                ),
                _buildInfoChip(
                  icon: Icons.description_outlined,
                  label:
                      '${case_.requiredDocuments.length} ${'tasks'.translate()}',
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    final statusColors = {
      'active': {'bg': 0xFF4CAF50, 'label': 'Active'.translate()},
      'closed': {'bg': 0xFF1976D2, 'label': 'Closed'.translate()},
      'pending': {'bg': 0xFFFF9800, 'label': 'Pending'.translate()},
      'on_hold': {'bg': 0xFFF44336, 'label': 'On Hold'.translate()},
    };

    final config = statusColors[status] ??
        {'bg': 0xFF757575, 'label': status.replaceAll('_', ' ')};

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Color(config['bg'] as int).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        config['label'] as String,
        style: GoogleFonts.cairo(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: Color(config['bg'] as int),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14.sp,
          color: AppColors.legalGold,
        ),
        SizedBox(width: 4.w),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
