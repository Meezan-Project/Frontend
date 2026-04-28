import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/screens/lawyers_list_screen.dart'; // To get LawyerMockModel

class LawyerProfileScreen extends StatefulWidget {
  final LawyerMockModel lawyer;

  const LawyerProfileScreen({super.key, required this.lawyer});

  @override
  State<LawyerProfileScreen> createState() => _LawyerProfileScreenState();
}

class _LawyerProfileScreenState extends State<LawyerProfileScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        title: Text(
          'Lawyer Profile',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w800,
            fontSize: 20.sp,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Column(
          children: [
            _buildTopSection(),
            SizedBox(height: 16.h),
            _buildMiddleSection(),
            SizedBox(height: 16.h),
            _buildAppointmentSection(),
            SizedBox(height: 16.h),
            _buildExpandableSections(),
            SizedBox(height: 16.h),
            _buildReviewsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTopSection() {
    return _buildCard(
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: Image.network(
                    widget.lawyer.imageUrl,
                    width: 80.w,
                    height: 80.w,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.lawyer.name,
                        style: GoogleFonts.cairo(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navyBlue,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < widget.lawyer.rating.floor()
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: AppColors.legalGold,
                              size: 20.sp,
                            );
                          }),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Overall Rating From ${widget.lawyer.reviewsCount} Visitors',
                        style: GoogleFonts.cairo(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Text(
              widget.lawyer.specialization,
              style: GoogleFonts.cairo(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              "- Bachelor's degree in Law\n- Fellowship in Legal Aesthetics\n- Diploma in Corporate Law\n- Diploma in Advanced Litigation",
              style: GoogleFonts.cairo(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            SizedBox(height: 16.h),
            _buildOutlinedButton(Icons.play_circle_outline, 'Video'),
          ],
        ),
      ),
    );
  }

  Widget _buildOutlinedButton(IconData icon, String text) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 18.sp, color: AppColors.navyBlue),
      label: Text(
        text,
        style: GoogleFonts.cairo(
          color: AppColors.navyBlue,
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.navyBlue.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      ),
    );
  }

  Widget _buildMiddleSection() {
    final cityTabTitle = widget.lawyer.location.split(',').first.trim();
    
    return _buildCard(
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildTab(
                    title: cityTabTitle.isNotEmpty ? cityTabTitle : 'Location',
                    isSelected: _selectedTabIndex == 0,
                    onTap: () => setState(() => _selectedTabIndex = 0),
                  ),
                ),
                Expanded(
                  child: _buildTab(
                    title: 'Services',
                    isSelected: _selectedTabIndex == 1,
                    onTap: () => setState(() => _selectedTabIndex = 1),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, color: AppColors.navyBlue, size: 24.sp),
                SizedBox(width: 12.w),
                Text(
                  'Fees: ',
                  style: GoogleFonts.cairo(
                    fontSize: 15.sp,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  '${widget.lawyer.fee % 1 == 0 ? widget.lawyer.fee.toInt() : widget.lawyer.fee} EGP',
                  style: GoogleFonts.cairo(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Icon(Icons.access_time_outlined, color: Colors.transparent, size: 24.sp),
                SizedBox(width: 12.w),
                Text(
                  'Waiting Time: 10 min',
                  style: GoogleFonts.cairo(
                    fontSize: 15.sp,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, color: AppColors.navyBlue, size: 24.sp),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    '${widget.lawyer.location}\nBook and you will receive the address details',
                    style: GoogleFonts.cairo(
                      fontSize: 15.sp,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({required String title, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.navyBlue : Colors.grey.shade300,
              width: 2.w,
            ),
          ),
        ),
        child: Center(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 14.sp,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? AppColors.navyBlue : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentSection() {
    return _buildCard(
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          children: [
            Text(
              'Choose your appointment',
              style: GoogleFonts.cairo(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Icon(Icons.chevron_left, color: Colors.grey.shade400),
                SizedBox(width: 8.w),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildAppointmentCard('Today', true)),
                      SizedBox(width: 8.w),
                      Expanded(child: _buildAppointmentCard('Tomorrow', false)),
                      SizedBox(width: 8.w),
                      Expanded(child: _buildAppointmentCard('Thursday 30/4', false)),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(String title, bool isSelected) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.navyBlue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8.r)),
            ),
            child: Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Column(
              children: [
                Text(
                  '3:00 PM',
                  style: GoogleFonts.cairo(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
                ),
                Text(
                  'To',
                  style: GoogleFonts.cairo(fontSize: 11.sp, color: Colors.grey),
                ),
                Text(
                  '11:00 PM',
                  style: GoogleFonts.cairo(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 36.h,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50000), // Red button from design
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(8.r))),
                padding: EdgeInsets.zero,
                elevation: 0,
              ),
              child: Text(
                'Book',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSections() {
    return _buildCard(
      child: Column(
        children: [
          _buildExpansionTile(
            'Education and experience', 
            "- Masters in Criminal Justice\n- 10+ years of active practice"
          ),
          _buildExpansionTile(
            'Sub-Specialties', 
            "- Criminal Law\n- Family Law\n- Property Dispute"
          ),
          _buildExpansionTile(
            'Lawyer\'s Questions and Answers', 
            "No active Q&A at the moment."
          ),
        ],
      ),
    );
  }

  Widget _buildExpansionTile(String title, String content) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        iconColor: AppColors.navyBlue,
        collapsedIconColor: AppColors.navyBlue,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                content,
                style: GoogleFonts.cairo(
                  fontSize: 14.sp,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return _buildCard(
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Clients\' Reviews',
                  style: GoogleFonts.cairo(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Default Order',
                        style: GoogleFonts.cairo(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(Icons.keyboard_arrow_down, color: Colors.blue.shade700, size: 16.sp),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Center(
              child: Text(
                'Overall Rating from ${widget.lawyer.reviewsCount} Visitors',
                style: GoogleFonts.cairo(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: _buildRatingBox('Lawyer Rating', widget.lawyer.rating),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildRatingBox('Overall Rating', widget.lawyer.rating),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            _buildReviewItem('Visitor 3', 'Excellent lawyer and very professional.', 5.0, '17 April 2026'),
            SizedBox(height: 16.h),
            _buildReviewItem('Visitor 2', 'Very good experience, highly recommended.', 4.5, '10 April 2026'),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBox(String title, double rating) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return Icon(
                index < rating.floor()
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: AppColors.legalGold,
                size: 20.sp,
              );
            }),
          ),
          SizedBox(height: 8.h),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String author, String comment, double rating, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ...List.generate(5, (index) {
              return Icon(
                index < rating.floor()
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: AppColors.legalGold,
                size: 16.sp,
              );
            }),
            SizedBox(width: 8.w),
            Text(
              'Overall Rating',
              style: GoogleFonts.cairo(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          '"$comment"',
          style: GoogleFonts.cairo(
            fontSize: 14.sp,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Text(
              author,
              style: GoogleFonts.cairo(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              date,
              style: GoogleFonts.cairo(
                fontSize: 12.sp,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
