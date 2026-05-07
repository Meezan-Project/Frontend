import 'dart:ui';
import 'dart:async';
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
      onlineFee: parseFee([
        'online_consultation_fee',
        'online_fee',
        'onlineFee',
      ], baseFee),
      inOfficeFee: parseFee([
        'in_office_consultation_fee',
        'in_office_fee',
        'inOfficeFee',
      ], baseFee),
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
  String _selectedConsultationType = 'online'; // 'online' or 'office'
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  List<DateTime> _availableDates = [];
  LawyerModel? _fetchedLawyer;
  bool _isLoading = false;
  Map<String, List<String>> _bookedSlots = {};
  StreamSubscription<QuerySnapshot>? _appointmentsSub;

  LawyerModel? get _currentLawyer => _fetchedLawyer ?? widget.lawyer;

  @override
  void initState() {
    super.initState();
    if (widget.lawyer != null) {
      _generateAvailableDates();
      _listenToBookedSlots();
    } else if (widget.lawyerId != null) {
      _fetchLawyerData();
    }
  }

  @override
  void dispose() {
    _appointmentsSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchLawyerData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('lawyers')
          .doc(widget.lawyerId)
          .get();
      if (doc.exists && mounted) {
        setState(() => _fetchedLawyer = LawyerModel.fromFirestore(doc));
        _generateAvailableDates();
        _listenToBookedSlots();
      }
    } catch (e) {
      debugPrint('Error fetching lawyer: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listenToBookedSlots() {
    if (_currentLawyer == null) return;
    _appointmentsSub?.cancel();

    _appointmentsSub = FirebaseFirestore.instance
        .collection('appointments')
        .where('lawyerId', isEqualTo: _currentLawyer!.id)
        .snapshots()
        .listen((snap) {
          final Map<String, List<String>> booked = {};

          for (var doc in snap.docs) {
            final data = doc.data();
            final status = data['status'] ?? data['bookingStatus'] ?? 'pending';
            if (status == 'cancelled') continue; // Allow booking if cancelled

            final day = data['day'] as String?;
            final time = data['time'] as String?;
            if (day != null && time != null) {
              booked.putIfAbsent(day, () => []).add(time);
            }
          }

          if (mounted) {
            setState(() {
              _bookedSlots = booked;
              // Deselect the slot if it was just booked by someone else
              if (_selectedDate != null && _selectedTimeSlot != null) {
                final dayLabel = DateFormat(
                  'EEEE, d MMM yyyy',
                ).format(_selectedDate!);
                if (booked[dayLabel]?.contains(_selectedTimeSlot) == true) {
                  _selectedTimeSlot = null;
                }
              }
            });
          }
        }, onError: (e) => debugPrint('Error listening to booked slots: $e'));
  }

  Map<String, String>? _getStartEndTimeForDate(DateTime date) {
    final safeSchedule = _currentLawyer?.schedule ?? {};
    if (safeSchedule.isEmpty) return null;

    final dayNameTitle = DateFormat('EEEE').format(date);
    final dayNameLower = dayNameTitle.toLowerCase();

    final String? matchedKey = safeSchedule.containsKey(dayNameTitle)
        ? dayNameTitle
        : (safeSchedule.containsKey(dayNameLower) ? dayNameLower : null);

    if (matchedKey != null) {
      final val = safeSchedule[matchedKey];
      if (val is Map) {
        final f = val['from']?.toString() ?? val['start']?.toString() ?? '';
        final t = val['to']?.toString() ?? val['end']?.toString() ?? '';
        return {'start': f, 'end': t};
      } else {
        final str = val.toString();
        if (str.contains('-')) {
          final parts = str.split('-');
          return {'start': parts[0].trim(), 'end': parts[1].trim()};
        }
      }
    }
    return null;
  }

  void _generateAvailableDates() {
    final List<DateTime> dates = [];
    final now = DateTime.now();
    for (int i = 0; i < 14; i++) {
      final date = now.add(Duration(days: i));
      if (_getStartEndTimeForDate(date) != null) {
        dates.add(date);
      }
    }
    if (mounted) {
      setState(() {
        _availableDates = dates;
      });
    }
  }

  int _parseTimeToMinutes(String timeStr) {
    timeStr = timeStr.trim().toLowerCase();
    bool isPm = timeStr.contains('pm');
    bool isAm = timeStr.contains('am');
    timeStr = timeStr.replaceAll('am', '').replaceAll('pm', '').trim();

    final parts = timeStr.split(':');
    if (parts.isEmpty) return 0;

    int h = int.tryParse(parts[0]) ?? 0;
    int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    if (isPm && h < 12) h += 12;
    if (isAm && h == 12) h = 0;

    return h * 60 + m;
  }

  String _formatMinsTo12h(int mins) {
    int h = mins ~/ 60;
    int m = mins % 60;
    String amPm = h >= 12 ? 'PM' : 'AM';
    int h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $amPm';
  }

  List<String> _generateTimeSlots(String start, String end, DateTime date) {
    int startMins = _parseTimeToMinutes(start);
    int endMins = _parseTimeToMinutes(end);
    if (startMins == 0 && endMins == 0) return [];

    final dayLabel = DateFormat('EEEE, d MMM yyyy').format(date);
    final bookedForDay = _bookedSlots[dayLabel] ?? [];

    List<String> slots = [];
    while (startMins + 45 <= endMins) {
      int eMins = startMins + 45;
      String slotStr =
          '${_formatMinsTo12h(startMins)} - ${_formatMinsTo12h(eMins)}';
      if (!bookedForDay.contains(slotStr)) {
        slots.add(slotStr);
      }
      startMins += 55; // 45 min session + 10 min break
    }
    return slots;
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
                child: ClipOval(
                  child: Image.network(
                    _currentLawyer!.imageUrl,
                    width: 108.r,
                    height: 108.r,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 108.r,
                      height: 108.r,
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.person_rounded,
                        size: 54.sp,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentLawyer!.name,
                      style: GoogleFonts.cairo(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.navyBlue,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _currentLawyer!.specialization,
                      style: GoogleFonts.cairo(
                        fontSize: 15.sp,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // ...existing code for rating, etc.
            ],
          ),
          // ...existing code for office, location, etc.

          // Working Days & Times Section
          if (_currentLawyer?.schedule != null && _currentLawyer!.schedule!.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Text(
              'Working Days & Times',
              style: GoogleFonts.cairo(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.navyBlue,
              ),
            ),
            SizedBox(height: 8.h),
            ..._currentLawyer!.schedule!.entries.map((entry) {
              final day = entry.key;
              final val = entry.value;
              String timeStr = '';
              if (val is Map) {
                final from = val['from']?.toString() ?? val['start']?.toString() ?? '';
                final to = val['to']?.toString() ?? val['end']?.toString() ?? '';
                if (from.isNotEmpty && to.isNotEmpty) {
                  timeStr = '$from - $to';
                }
              } else if (val is String && val.contains('-')) {
                timeStr = val;
              }
              return timeStr.isNotEmpty
                  ? Padding(
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      child: Row(
                        children: [
                          Text(
                            day,
                            style: GoogleFonts.cairo(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.navyBlue,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            timeStr,
                            style: GoogleFonts.cairo(
                              fontSize: 14.sp,
                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink();
            }),
          ],
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
              '${_currentLawyer!.experience} Years',
              Icons.work_outline_rounded,
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
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2A40) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3550) : const Color(0xFFE6ECF5),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.legalGold, size: 24.sp),
            SizedBox(height: 6.h),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.navyBlue,
              ),
            ),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 12.sp,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
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
        children: [
          // 1. Consultation Type
          Text(
            '1. Select Consultation Type',
            style: GoogleFonts.cairo(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.navyBlue,
            ),
          ),
          SizedBox(height: 12.h),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
          ),
          SizedBox(height: 24.h),

          // 2. Select Day
          Text(
            '2. Select Day',
            style: GoogleFonts.cairo(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.navyBlue,
            ),
          ),
          SizedBox(height: 12.h),
          if (_availableDates.isEmpty)
            Text(
              'No available appointments in the next 14 days.',
              style: GoogleFonts.cairo(
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            )
          else
            SizedBox(
              height: 85.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _availableDates.length,
                itemBuilder: (context, index) {
                  final date = _availableDates[index];
                  final isSelected = _selectedDate == date;
                  final dayName = DateFormat('EEE').format(date);
                  final dayNum = DateFormat('d').format(date);
                  final monthName = DateFormat('MMM').format(date);

                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedDate = date;
                      _selectedTimeSlot = null; // Reset time when day changes
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 75.w,
                      margin: EdgeInsets.only(right: 12.w),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.navyBlue
                            : (isDark ? const Color(0xFF1C2A40) : Colors.white),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.navyBlue
                              : (isDark
                                    ? const Color(0xFF334866)
                                    : Colors.grey.shade300),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.navyBlue.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayName,
                            style: GoogleFonts.cairo(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white70
                                  : (isDark
                                        ? Colors.white70
                                        : Colors.grey.shade600),
                            ),
                          ),
                          Text(
                            dayNum,
                            style: GoogleFonts.cairo(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                        ? Colors.white
                                        : AppColors.navyBlue),
                            ),
                          ),
                          Text(
                            monthName,
                            style: GoogleFonts.cairo(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white70
                                  : (isDark
                                        ? Colors.white70
                                        : Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // 3. Dynamic Time Section Based on Type
          if (_selectedDate != null) ...[
            SizedBox(height: 24.h),
            Text(
              _selectedConsultationType == 'online'
                  ? '3. Select Time Slot'
                  : '3. Working Hours',
              style: GoogleFonts.cairo(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.navyBlue,
              ),
            ),
            SizedBox(height: 12.h),

            Builder(
              builder: (context) {
                final hours = _getStartEndTimeForDate(_selectedDate!);
                if (hours == null) return const SizedBox.shrink();

                if (_selectedConsultationType == 'online') {
                  final slots = _generateTimeSlots(
                    hours['start']!,
                    hours['end']!,
                    _selectedDate!,
                  );
                  if (slots.isEmpty) {
                    return Text(
                      'No slots available.',
                      style: GoogleFonts.cairo(color: Colors.grey),
                    );
                  }
                  return Wrap(
                    spacing: 12.w,
                    runSpacing: 12.h,
                    children: slots.map((slot) {
                      final isSelected = _selectedTimeSlot == slot;
                      return GestureDetector(
                        onTap: () => setState(
                          () => _selectedTimeSlot = isSelected ? null : slot,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 10.h,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.navyBlue
                                : (isDark
                                      ? const Color(0xFF1C2A40)
                                      : Colors.white),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.navyBlue
                                  : (isDark
                                        ? const Color(0xFF334866)
                                        : Colors.grey.shade300),
                              width: isSelected ? 1.5 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.navyBlue.withOpacity(
                                        0.2,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Text(
                            slot,
                            style: GoogleFonts.cairo(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                        ? Colors.white70
                                        : AppColors.navyBlue),
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 13.sp,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                } else {
                  return Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: AppColors.legalGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.legalGold.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.access_time_filled_rounded,
                          color: AppColors.legalGold,
                          size: 28.sp,
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Available for Office Visits',
                          style: GoogleFonts.cairo(
                            fontSize: 14.sp,
                            color: isDark ? Colors.white : AppColors.navyBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_formatMinsTo12h(_parseTimeToMinutes(hours['start']!))} to ${_formatMinsTo12h(_parseTimeToMinutes(hours['end']!))}',
                          style: GoogleFonts.cairo(
                            fontSize: 16.sp,
                            color: isDark ? Colors.white : AppColors.navyBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ],
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
            ? () => setState(() {
                _selectedConsultationType = type;
                _selectedTimeSlot =
                    null; // Reset time slot when switching modes
              })
            : null,
        child: Opacity(
          opacity: isAvailable ? 1.0 : 0.5,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
            alignment: Alignment.center,
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
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.legalGold, size: 24.sp),
                  SizedBox(height: 8.h),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.navyBlue,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    feeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
        _selectedDate != null &&
        (_selectedConsultationType == 'office' ||
            (_selectedConsultationType == 'online' &&
                _selectedTimeSlot != null));

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
                            String timeRangeToPass = '';
                            if (_selectedConsultationType == 'online') {
                              timeRangeToPass = _selectedTimeSlot!;
                            } else {
                              final hours = _getStartEndTimeForDate(
                                _selectedDate!,
                              );
                              timeRangeToPass =
                                  '${_formatMinsTo12h(_parseTimeToMinutes(hours!['start']!))} to ${_formatMinsTo12h(_parseTimeToMinutes(hours['end']!))}';
                            }
                            final dayLabel = DateFormat(
                              'EEEE, d MMM yyyy',
                            ).format(_selectedDate!);

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BookingConfirmationScreen(
                                  lawyerId: _currentLawyer!.id,
                                  lawyerName: _currentLawyer!.name,
                                  lawyerImage: _currentLawyer!.imageUrl,
                                  lawyerSpecialization:
                                      _currentLawyer!.specialization,
                                  dateLabel: dayLabel,
                                  timeRange: timeRangeToPass,
                                  officeAddress:
                                      _currentLawyer!.fullAddress ??
                                      _currentLawyer!.location,
                                  consultationType: _selectedConsultationType,
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
