import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/models/case_model.dart';

// Date formatting helper function
String formatDate(DateTime date, String format) {
  // Simple date formatter since intl is not available
  String result = format;
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final days = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday',
    'Thursday', 'Friday', 'Saturday'
  ];
  
  result = result.replaceAll('EEEE', days[date.weekday % 7]);
  result = result.replaceAll('MMM', months[date.month - 1]);
  result = result.replaceAll('dd', date.day.toString().padLeft(2, '0'));
  result = result.replaceAll('yyyy', date.year.toString());
  result = result.replaceAll('hh', (date.hour % 12 == 0 ? 12 : date.hour % 12).toString().padLeft(2, '0'));
  result = result.replaceAll('mm', date.minute.toString().padLeft(2, '0'));
  result = result.replaceAll('a', date.hour >= 12 ? 'PM' : 'AM');
  
  return result;
}

class CaseDetailsScreen extends StatefulWidget {
  final UserCase case_;

  const CaseDetailsScreen({super.key, required this.case_});

  @override
  State<CaseDetailsScreen> createState() => _CaseDetailsScreenState();
}

class _CaseDetailsScreenState extends State<CaseDetailsScreen> {
  late PageController _pageController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F1419) : const Color(0xFFFCFDFF);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Case Details'.translate(),
          style: GoogleFonts.cairo(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Header Card
          _buildHeaderCard(isDark),

          // Tab Navigation
          _buildTabBar(isDark),

          // Content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentTabIndex = index);
              },
              children: [
                _buildOverviewTab(isDark),
                _buildDocumentsTab(isDark),
                _buildSessionsTab(isDark),
                _buildUpdatesTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A2940) : Colors.white;

    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.case_.caseNumber,
                      style: GoogleFonts.cairo(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.legalGold,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      widget.case_.title,
                      style: GoogleFonts.cairo(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              _buildStatusBadge(widget.case_.status, isDark),
            ],
          ),
          SizedBox(height: 14.h),
          Text(
            widget.case_.description,
            style: GoogleFonts.cairo(
              fontSize: 13.sp,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderInfo(
                label: 'Category'.translate(),
                value: widget.case_.category,
                isDark: isDark,
              ),
              _buildHeaderInfo(
                label: 'Created'.translate(),
                value: formatDate(widget.case_.createdDate, 'MMM dd, yyyy'),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo({
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(bool isDark) {
    final tabs = [
      'Overview'.translate(),
      'Documents'.translate(),
      'Sessions'.translate(),
      'Updates'.translate(),
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isActive = _currentTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Text(
                      tabs[index],
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                        color: isActive
                            ? AppColors.legalGold
                            : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (isActive)
                    Container(
                      height: 3.h,
                      decoration: BoxDecoration(
                        color: AppColors.legalGold,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A2940) : Colors.white;

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        // Lawyer Info
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24.r,
                backgroundColor: AppColors.legalGold.withValues(alpha: 0.2),
                child: Text(
                  widget.case_.lawyerName.isNotEmpty
                      ? widget.case_.lawyerName[0].toUpperCase()
                      : 'L',
                  style: GoogleFonts.cairo(
                    fontSize: 18.sp,
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
                      'Assigned Lawyer'.translate(),
                      style: GoogleFonts.cairo(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      widget.case_.lawyerName,
                      style: GoogleFonts.cairo(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // Quick Stats
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.description_outlined,
                label: 'Documents'.translate(),
                value: '${widget.case_.requiredDocuments.length}',
                isDark: isDark,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildStatCard(
                icon: Icons.calendar_today_outlined,
                label: 'Sessions'.translate(),
                value: '${widget.case_.sessions.length}',
                isDark: isDark,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildStatCard(
                icon: Icons.update_outlined,
                label: 'Updates'.translate(),
                value: '${widget.case_.updates.length}',
                isDark: isDark,
              ),
            ),
          ],
        ),
        SizedBox(height: 20.h),

        // Case Notes
        if (widget.case_.notes != null && widget.case_.notes!.isNotEmpty) ...[
          Text(
            'Notes'.translate(),
            style: GoogleFonts.cairo(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5),
              ),
            ),
            child: Text(
              widget.case_.notes!,
              style: GoogleFonts.cairo(
                fontSize: 13.sp,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: 20.h),
        ],

        // Case Timeline
        Text(
          'Case Timeline'.translate(),
          style: GoogleFonts.cairo(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 12.h),
        _buildTimelineItem(
          date: formatDate(widget.case_.createdDate, 'MMM dd, yyyy'),
          title: 'Case Created'.translate(),
          isDark: isDark,
        ),
        if (widget.case_.closedDate != null)
          _buildTimelineItem(
            date: formatDate(widget.case_.closedDate!, 'MMM dd, yyyy'),
            title: 'Case Closed'.translate(),
            isDark: isDark,
          ),
        SizedBox(height: 16.h),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF1A2940) : Colors.white;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.legalGold, size: 24.sp),
          SizedBox(height: 8.h),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.legalGold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String date,
    required String title,
    required bool isDark,
  }) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 12.w,
              height: 12.h,
              decoration: BoxDecoration(
                color: AppColors.legalGold,
                borderRadius: BorderRadius.circular(6.r),
              ),
            ),
            Container(
              width: 2.w,
              height: 20.h,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
          ],
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                date,
                style: GoogleFonts.cairo(
                  fontSize: 12.sp,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsTab(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A2940) : Colors.white;

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        if (widget.case_.requiredDocuments.isEmpty) ...[
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.h),
              child: Column(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 48.sp,
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'No documents required'.translate(),
                    style: GoogleFonts.cairo(
                      fontSize: 14.sp,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Required Documents'.translate(),
                style: GoogleFonts.cairo(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${widget.case_.getCompletionPercentage()}%',
                style: GoogleFonts.cairo(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.legalGold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...widget.case_.requiredDocuments.map((doc) {
            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          doc.isSubmitted
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: doc.isSubmitted
                              ? Colors.green
                              : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                          size: 22.sp,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc.name,
                                style: GoogleFonts.cairo(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                doc.description,
                                style: GoogleFonts.cairo(
                                  fontSize: 12.sp,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (doc.submittedDate != null) ...[
                      SizedBox(height: 8.h),
                      Text(
                        'Submitted: ${formatDate(doc.submittedDate!, 'MMM dd, yyyy')}',
                        style: GoogleFonts.cairo(
                          fontSize: 11.sp,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: 16.h),
        ],
      ],
    );
  }

  Widget _buildSessionsTab(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A2940) : Colors.white;

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        if (widget.case_.sessions.isEmpty) ...[
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.h),
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 48.sp,
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'No sessions scheduled'.translate(),
                    style: GoogleFonts.cairo(
                      fontSize: 14.sp,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Text(
            'Scheduled Sessions'.translate(),
            style: GoogleFonts.cairo(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12.h),
          ...widget.case_.sessions.map((session) {
            final isCompleted = session.status == 'completed';

            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatDate(session.scheduledDate, 'EEEE, MMM dd'),
                          style: GoogleFonts.cairo(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        _buildSessionStatusBadge(session.status, isDark),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14.sp,
                          color: AppColors.legalGold,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          formatDate(session.scheduledDate, 'hh:mm a'),
                          style: GoogleFonts.cairo(
                            fontSize: 12.sp,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    if (session.location != null && session.location!.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14.sp,
                            color: AppColors.legalGold,
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              session.location!,
                              style: GoogleFonts.cairo(
                                fontSize: 12.sp,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (session.notes != null && session.notes!.isNotEmpty) ...[
                      SizedBox(height: 10.h),
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notes'.translate(),
                              style: GoogleFonts.cairo(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              session.notes!,
                              style: GoogleFonts.cairo(
                                fontSize: 12.sp,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (isCompleted &&
                        session.result != null &&
                        session.result!.isNotEmpty) ...[
                      SizedBox(height: 10.h),
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 14.sp,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  'Result'.translate(),
                                  style: GoogleFonts.cairo(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              session.result!,
                              style: GoogleFonts.cairo(
                                fontSize: 12.sp,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: 16.h),
        ],
      ],
    );
  }

  Widget _buildUpdatesTab(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A2940) : Colors.white;

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        if (widget.case_.updates.isEmpty) ...[
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.h),
              child: Column(
                children: [
                  Icon(
                    Icons.update_outlined,
                    size: 48.sp,
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'No updates yet'.translate(),
                    style: GoogleFonts.cairo(
                      fontSize: 14.sp,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Text(
            'Case Updates'.translate(),
            style: GoogleFonts.cairo(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12.h),
          ...widget.case_.updates.map((update) {
            final updateColor = _getUpdateTypeColor(update.type);

            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: Color(updateColor['color'] as int)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(
                            updateColor['icon'] as IconData,
                            size: 14.sp,
                            color: Color(updateColor['color'] as int),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                update.title,
                                style: GoogleFonts.cairo(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                formatDate(update.date, 'MMM dd, yyyy - hh:mm a'),
                                style: GoogleFonts.cairo(
                                  fontSize: 11.sp,
                                  color: isDark
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      update.description,
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: 16.h),
        ],
      ],
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    final statusColors = {
      'active': {'bg': 0xFF4CAF50, 'label': 'Active'.translate()},
      'closed': {'bg': 0xFF1976D2, 'label': 'Closed'.translate()},
      'pending': {'bg': 0xFFFF9800, 'label': 'Pending'.translate()},
      'on_hold': {'bg': 0xFFF44336, 'label': 'On Hold'.translate()},
    };

    final statusInfo = statusColors[status] ??
        {'bg': 0xFF757575, 'label': status.replaceAll('_', ' ')};
    final bgColor = statusInfo['bg'] as int;
    final label = statusInfo['label'] as String;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Color(bgColor).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: Color(bgColor),
        ),
      ),
    );
  }

  Widget _buildSessionStatusBadge(String status, bool isDark) {
    final statusMap = {
      'scheduled': {'bg': 0xFF2196F3, 'label': 'Scheduled'.translate()},
      'completed': {'bg': 0xFF4CAF50, 'label': 'Completed'.translate()},
      'cancelled': {'bg': 0xFFF44336, 'label': 'Cancelled'.translate()},
    };

    final statusInfo = statusMap[status] ?? {'bg': 0xFF757575, 'label': status};
    final bgColor = statusInfo['bg'] as int;
    final label = statusInfo['label'] as String;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Color(bgColor).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: Color(bgColor),
        ),
      ),
    );
  }

  Map<String, dynamic> _getUpdateTypeColor(String type) {
    switch (type) {
      case 'action':
        return {'color': 0xFF2196F3, 'icon': Icons.assignment_turned_in_outlined};
      case 'process':
        return {'color': 0xFFFF9800, 'icon': Icons.trending_up_outlined};
      case 'result':
        return {'color': 0xFF4CAF50, 'icon': Icons.check_circle_outline};
      default:
        return {'color': 0xFF9C27B0, 'icon': Icons.info_outline};
    }
  }
}
