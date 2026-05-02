import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/screens/booking_confirmation_screen.dart';
import 'package:url_launcher/url_launcher.dart';

// --- Lawyer Model ---
class LawyerModel {
  final String id;
  final String name;
  final String specialization;
  final String workStatus;
  final String officeName;
  final double rating;
  final int reviewsCount;
  final String location;
  final String? fullAddress;
  final List<String> governorates;
  final List<String> cities;
  final double fee;
  final String availability;
  final String imageUrl;
  final String about;
  final int experience;
  final Map<String, dynamic>? schedule;
  final double? onlineFee;
  final double? inOfficeFee;

  const LawyerModel({
    required this.id,
    required this.name,
    required this.specialization,
    required this.workStatus,
    required this.officeName,
    required this.rating,
    required this.reviewsCount,
    required this.location,
    this.fullAddress,
    required this.governorates,
    required this.cities,
    required this.fee,
    required this.availability,
    required this.imageUrl,
    this.about = '',
    this.experience = 0,
    this.schedule = const {},
    this.onlineFee,
    this.inOfficeFee,
  });

  factory LawyerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    double parseFee(List<String> keys, double fallback) {
      for (final key in keys) {
        final val = data[key];
        if (val is num) return val.toDouble();
        if (val is String) {
          final parsed = double.tryParse(val.trim());
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    final baseFee = parseFee(['consultation_fees', 'fee', 'price'], 0.0);

    return LawyerModel(
      id: doc.id,
      name: data['name'] ?? data['firstName'] ?? 'Unknown Name',
      specialization: data['specialization'] ?? 'Lawyer',
      workStatus: data['workStatus'] ?? 'Available',
      officeName: data['officeName'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviewsCount: data['reviewsCount'] ?? 0,
      location: data['location'] ?? data['address'] ?? 'Location not provided',
      fullAddress: data['fullAddress'],
      governorates: List<String>.from(data['governorates'] ?? []),
      cities: List<String>.from(data['cities'] ?? []),
      fee: baseFee,
      availability: data['availability'] ?? 'Available now',
      imageUrl:
          data['imageUrl'] ??
          data['profilePhoto'] ??
          'https://i.pravatar.cc/300',
      about: data['professional_bio'] ?? data['about'] ?? data['bio'] ?? '',
      experience: data['years_of_experience'] ?? data['experience'] ?? 0,
      schedule: data['schedule'] is Map
          ? Map<String, dynamic>.from(data['schedule'])
          : null,
      onlineFee: parseFee(['online_consultation_fee', 'online_fee', 'onlineFee'], baseFee),
      inOfficeFee: parseFee(['in_office_consultation_fee', 'in_office_fee', 'inOfficeFee'], baseFee),
    );
  }
}

class LawyerProfileScreen extends StatefulWidget {
  final String? lawyerId;
  final LawyerModel? lawyer;

  const LawyerProfileScreen({super.key, this.lawyerId, this.lawyer});

  @override
  State<LawyerProfileScreen> createState() => _LawyerProfileScreenState();
}

class _LawyerProfileScreenState extends State<LawyerProfileScreen> {
  int? _selectedDaySlotIndex;
  String? _selectedConsultationType; // 'online' or 'office'
  List<_ScheduleSlot> _availableSlots = [];
  LawyerModel? _fetchedLawyer;
  bool _isLoading = false;

  LawyerModel? get _currentLawyer => _fetchedLawyer ?? widget.lawyer;

  @override
  void initState() {
    super.initState();
    if (widget.lawyer != null) {
      _generateAvailableSlots();
    } else if (widget.lawyerId != null) {
      _fetchLawyerData();
    }
  }

  Future<void> _fetchLawyerData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.lawyerId)
          .get();
      if (doc.exists && mounted) {
        setState(() => _fetchedLawyer = LawyerModel.fromFirestore(doc));
        _generateAvailableSlots();
      }
    } catch (e) {
      debugPrint('Error fetching lawyer: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _generateAvailableSlots() {
    final List<_ScheduleSlot> slots = [];
    final now = DateTime.now();
    final safeSchedule = _currentLawyer?.schedule ?? {};

    if (safeSchedule.isEmpty) return;

    for (int i = 0; i < 14; i++) {
      final date = now.add(Duration(days: i));
      final dayNameTitle = DateFormat('EEEE').format(date);
      final dayNameLower = dayNameTitle.toLowerCase();

      final String? matchedKey = safeSchedule.containsKey(dayNameTitle)
          ? dayNameTitle
          : (safeSchedule.containsKey(dayNameLower) ? dayNameLower : null);

      if (matchedKey != null) {
        final rawValue = safeSchedule[matchedKey];
        final timeRange = _formatTimeRange(rawValue);
        if (timeRange.isNotEmpty) {
          slots.add(_ScheduleSlot.fromDateTime(date, timeRange));
        }
      }
    }
    if (mounted) {
      setState(() {
        _availableSlots = slots;
      });
    }
  }

  String _to12HourFormat(String timeStr) {
    final t = timeStr.trim();
    if (t.toLowerCase().contains('am') || t.toLowerCase().contains('pm')) {
      return t;
    }
    try {
      final parts = t.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        final dt = DateTime(2022, 1, 1, hour, minute);
        return DateFormat('h:mm a').format(dt);
      }
    } catch (_) {}
    return t;
  }

  String _formatTimeRange(dynamic value) {
    if (value == null) return '';
    if (value is Map) {
      final fromStr =
          value['from']?.toString() ?? value['start']?.toString() ?? '';
      final toStr = value['to']?.toString() ?? value['end']?.toString() ?? '';
      final fFrom = _to12HourFormat(fromStr);
      final fTo = _to12HourFormat(toStr);
      if (fFrom.isNotEmpty && fTo.isNotEmpty) return '$fFrom - $fTo';
      if (fFrom.isNotEmpty) return fFrom;
      if (fTo.isNotEmpty) return fTo;
    } else {
      final str = value.toString();
      if (str.contains('-')) {
        final parts = str.split('-');
        final fFrom = _to12HourFormat(parts[0]);
        final fTo = _to12HourFormat(parts[1]);
        return '$fFrom - $fTo';
      }
      return _to12HourFormat(str);
    }
    return value.toString();
  }

  String _formatFee(double fee) {
    return fee.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Future<void> _launchMaps(String query) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Column(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48.sp),
              SizedBox(height: 12.h),
              Text(
                'Error',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navyBlue,
                  fontSize: 20.sp,
                ),
              ),
            ],
          ),
          content: Text(
            'Could not open maps',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 15.sp),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navyBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F1726)
            : const Color(0xFFF8FAFC),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentLawyer == null) {
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F1726)
            : const Color(0xFFF8FAFC),
        body: const Center(child: Text('Lawyer not found')),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F1726)
          : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(isDark),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildMainInfo(isDark),
                SizedBox(height: 16.h),
                _buildQuickStats(isDark),
                SizedBox(height: 16.h),
                _buildAboutSection(isDark),
                SizedBox(height: 16.h),
                _buildLocationAndFees(isDark),
                SizedBox(height: 16.h),
                _buildBookingSection(isDark),
                SizedBox(height: 16.h),
                _buildReviewsSection(isDark),
                SizedBox(height: 100.h), // Space for Sticky Bottom Bar
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildStickyBottomBar(isDark),
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 220.h,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.navyBlue,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.favorite_border_rounded, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF042A52), Color(0xFF0B5E55)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              bottom: 20.h,
              child: Container(
                padding: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F1726) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 15,
                      offset: Offset(0, 5.h),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 54.r,
                  backgroundImage: NetworkImage(_currentLawyer!.imageUrl),
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainInfo(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          SizedBox(height: 10.h),
          Text(
            _currentLawyer!.name,
            style: GoogleFonts.cairo(
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.navyBlue,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            _currentLawyer!.workStatus +
                (_currentLawyer!.officeName.isNotEmpty
                    ? ' - ${_currentLawyer!.officeName}'
                    : ''),
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.legalGold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            _currentLawyer!.specialization,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              'Experience',
              '+${_currentLawyer!.experience} Years',
              Icons.workspace_premium_outlined,
              isDark,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _statCard(
              'Rating',
              '${_currentLawyer!.rating.toStringAsFixed(1)} ⭐',
              Icons.star_outline_rounded,
              isDark,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _statCard(
              'Reviews',
              '${_currentLawyer!.reviewsCount}',
              Icons.people_outline_rounded,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2A40) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3550) : const Color(0xFFE6ECF5),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.legalGold, size: 24.sp),
          SizedBox(height: 6.h),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.navyBlue,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 12.sp,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
    required bool isDark,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24344C) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D2345).withOpacity(0.04),
            blurRadius: 15,
            offset: Offset(0, 5.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.navyBlue,
            ),
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }

  Widget _buildAboutSection(bool isDark) {
    return _buildSectionCard(
      title: 'About the Lawyer',
      isDark: isDark,
      child: SizedBox(
        width: double.infinity,
        child: Text(
          _currentLawyer!.about.isNotEmpty
              ? _currentLawyer!.about
              : 'No information provided.',
          textAlign: TextAlign.start,
          style: GoogleFonts.cairo(
            fontSize: 14.sp,
            height: 1.6,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildLocationAndFees(bool isDark) {
    final displayLocation = _currentLawyer!.fullAddress?.isNotEmpty == true
        ? _currentLawyer!.fullAddress!
        : _currentLawyer!.location;

    return _buildSectionCard(
      title: 'Office Information',
      isDark: isDark,
      child: Column(
        children: [
          InkWell(
            onTap: () => _launchMaps(displayLocation),
            borderRadius: BorderRadius.circular(8.r),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: AppColors.navyBlue,
                    size: 22.sp,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayLocation,
                          style: GoogleFonts.cairo(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Tap to open in Maps',
                          style: GoogleFonts.cairo(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.legalGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: isDark ? Colors.white54 : Colors.grey.shade400,
                    size: 16.sp,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Divider(
              color: isDark ? const Color(0xFF334866) : Colors.grey.shade200,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.navyBlue,
                size: 22.sp,
              ),
              SizedBox(width: 10.w),
              Text(
                'Consultation Fee:',
                style: GoogleFonts.cairo(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Text(
                '${_formatFee(_currentLawyer!.fee)} EGP',
                style: GoogleFonts.cairo(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.legalGold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingSection(bool isDark) {
    return _buildSectionCard(
      title: 'Book an Appointment',
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _availableSlots.isEmpty
            ? [
                Text(
                  'No available appointments in the next 14 days.',
                  style: GoogleFonts.cairo(
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ]
            : [
                // Schedule Slots
                SizedBox(
                  height: 120.h,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableSlots.length,
                    itemBuilder: (context, index) {
                      final slot = _availableSlots[index];
                      final isSelected = _selectedDaySlotIndex == index;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedDaySlotIndex = index;
                        }),
                        child: Container(
                          width: 140.w,
                          margin: EdgeInsets.only(right: 12.w),
                          padding: EdgeInsets.all(12.r),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.navyBlue
                                : (isDark
                                      ? const Color(0xFF1C2A40)
                                      : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.navyBlue
                                  : (isDark
                                        ? const Color(0xFF334866)
                                        : Colors.grey.shade200),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                slot.dayLabel,
                                style: GoogleFonts.cairo(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                            ? Colors.white
                                            : AppColors.navyBlue),
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                slot.timeRange,
                                style: GoogleFonts.cairo(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white70
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 20.h),
                // Consultation Type
                Text(
                  'Select Consultation Type',
                  style: GoogleFonts.cairo(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? Colors.white.withOpacity(0.9)
                        : Colors.black87,
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    _buildConsultationTypeCard(
                      type: 'online',
                      title: 'Online Meeting',
                      icon: Icons.video_call_outlined,
                      fee: _currentLawyer!.onlineFee,
                      isDark: isDark,
                    ),
                    SizedBox(width: 12.w),
                    _buildConsultationTypeCard(
                      type: 'office',
                      title: 'In-Office Visit',
                      icon: Icons.work_outline,
                      fee: _currentLawyer!.inOfficeFee,
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
      ),
    );
  }

  Widget _buildConsultationTypeCard({
    required String type,
    required String title,
    required IconData icon,
    required double? fee,
    required bool isDark,
  }) {
    final isSelected = _selectedConsultationType == type;
    final bool isAvailable = fee != null && fee > 0;
    final feeText = isAvailable ? '${_formatFee(fee)} EGP' : 'Not Available';

    return Expanded(
      child: GestureDetector(
        onTap: isAvailable
            ? () => setState(() => _selectedConsultationType = type)
            : null,
        child: Opacity(
          opacity: isAvailable ? 1.0 : 0.5,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.legalGold.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isSelected
                    ? AppColors.legalGold
                    : (isDark ? const Color(0xFF334866) : Colors.grey.shade300),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: AppColors.legalGold, size: 24.sp),
                SizedBox(height: 8.h),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.navyBlue,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  feeText,
                  style: GoogleFonts.cairo(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white70 : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsSection(bool isDark) {
    return _buildSectionCard(
      title: 'Client Reviews',
      isDark: isDark,
      child: Column(
        children: [
          _reviewItem(
            'Ahmed Mahmoud',
            '10 October 2025',
            5,
            'Very respectful lawyer with a great conscience. Listened to my case details with care and reassured me. Highly recommended.',
            isDark,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Divider(
              color: isDark ? const Color(0xFF334866) : Colors.grey.shade200,
            ),
          ),
          _reviewItem(
            'Sarah Medhat',
            '25 September 2025',
            4,
            'Respectable office and appointments are exactly on time, but the consultation fee was a bit high.',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _reviewItem(
    String name,
    String date,
    int rating,
    String comment,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: GoogleFonts.cairo(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.navyBlue,
              ),
            ),
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: AppColors.legalGold,
                  size: 16.sp,
                );
              }),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          date,
          style: GoogleFonts.cairo(
            fontSize: 12.sp,
            color: Colors.grey.shade500,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          comment,
          style: GoogleFonts.cairo(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildStickyBottomBar(bool isDark) {
    final bool canBook =
        _selectedDaySlotIndex != null && _selectedConsultationType != null;

    String feeDisplay = '--- EGP';
    double currentFee = _currentLawyer!.fee;
    if (_selectedConsultationType == 'online') {
      currentFee = _currentLawyer!.onlineFee ?? _currentLawyer!.fee;
    } else if (_selectedConsultationType == 'office') {
      currentFee = _currentLawyer!.inOfficeFee ?? _currentLawyer!.fee;
    }

    if (_selectedConsultationType == 'online') {
      final val = _currentLawyer!.onlineFee ?? _currentLawyer!.fee;
      feeDisplay = '${_formatFee(val)} EGP';
    } else if (_selectedConsultationType == 'office') {
      final val = _currentLawyer!.inOfficeFee ?? _currentLawyer!.fee;
      feeDisplay = '${_formatFee(val)} EGP';
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xDD0F1726)
                : Colors.white.withOpacity(0.85),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? const Color(0xFF2A3850)
                    : const Color(0xFFE6ECF5),
              ),
            ),
          ),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Booking Fee',
                    style: GoogleFonts.cairo(
                      fontSize: 12.sp,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    feeDisplay,
                    style: GoogleFonts.cairo(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.navyBlue,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 24.w),
              Expanded(
                child: SizedBox(
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: canBook
                        ? () {
                            final slot =
                                _availableSlots[_selectedDaySlotIndex!];
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BookingConfirmationScreen(
                                  lawyerId: _currentLawyer!.id,
                                  lawyerName: _currentLawyer!.name,
                                  lawyerImage: _currentLawyer!.imageUrl,
                                  lawyerSpecialization:
                                      _currentLawyer!.specialization,
                                  dateLabel: slot.dayLabel,
                                  timeRange: slot.timeRange,
                                  officeAddress:
                                      _currentLawyer!.fullAddress ??
                                      _currentLawyer!.location,
                                  consultationType: _selectedConsultationType!,
                                  fee: currentFee,
                                ),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.legalGold,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Book Now',
                      style: GoogleFonts.cairo(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleSlot {
  final DateTime date;
  final String dayLabel;
  final String timeRange;

  _ScheduleSlot({
    required this.date,
    required this.dayLabel,
    required this.timeRange,
  });

  factory _ScheduleSlot.fromDateTime(DateTime date, String timeRange) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final slotDate = DateTime(date.year, date.month, date.day);

    String dayName;
    if (slotDate == today) {
      dayName = 'Today';
    } else if (slotDate == tomorrow) {
      dayName = 'Tomorrow';
    } else {
      dayName = DateFormat('E').format(date); // e.g., 'Thu'
    }

    final formattedDate = DateFormat('d/M').format(date);
    return _ScheduleSlot(
      date: date,
      dayLabel: '$dayName, $formattedDate',
      timeRange: timeRange,
    );
  }
}
