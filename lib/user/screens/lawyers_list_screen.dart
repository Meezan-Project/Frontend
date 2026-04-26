import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class LawyersListScreen extends StatefulWidget {
  final String categoryName;

  const LawyersListScreen({super.key, this.categoryName = 'محامين جنائيين'});

  @override
  State<LawyersListScreen> createState() => _LawyersListScreenState();
}

class _LawyersListScreenState extends State<LawyersListScreen> {
  int _selectedSortIndex = 0;
  String _selectedGov = 'بورسعيد';
  String _selectedCity = 'حي الشرق';

  final List<String> _sortOptions = [
    'الأعلى تقييماً',
    'الأقل سعراً',
    'الأعلى سعراً',
    'أقل مدة إنتظار',
  ];

  final List<LawyerMockModel> _dummyLawyers = [
    LawyerMockModel(
      name: 'أ. د. محمود عبد الرحمن',
      specialization: 'استشاري قضايا جنائية ونقض',
      rating: 4.9,
      reviewsCount: 156,
      location: 'بورسعيد : حي الشرق',
      fee: 800,
      waitTime: 15,
      availability: 'متاح اليوم من 4:00 م',
      imageUrl: 'https://i.pravatar.cc/150?img=11',
    ),
    LawyerMockModel(
      name: 'أ. سارة الجندي',
      specialization: 'محامي متخصص في الجنايات والجنح',
      rating: 4.7,
      reviewsCount: 89,
      location: 'بورسعيد : بورفؤاد',
      fee: 500,
      waitTime: 30,
      availability: 'متاح غداً من 10:00 ص',
      imageUrl: 'https://i.pravatar.cc/150?img=5',
    ),
    LawyerMockModel(
      name: 'أ. أحمد الشناوي',
      specialization: 'خبير قضايا الأموال العامة',
      rating: 4.5,
      reviewsCount: 210,
      location: 'القاهرة : التجمع الخامس',
      fee: 1200,
      waitTime: 45,
      availability: 'متاح اليوم من 6:00 م',
      imageUrl: 'https://i.pravatar.cc/150?img=13',
    ),
    LawyerMockModel(
      name: 'أ. مصطفى كمال',
      specialization: 'محامي استئناف عالي ومجلس دولة',
      rating: 4.8,
      reviewsCount: 342,
      location: 'بورسعيد : حي الزهور',
      fee: 600,
      waitTime: 20,
      availability: 'متاح اليوم من 2:00 م',
      imageUrl: 'https://i.pravatar.cc/150?img=8',
    ),
  ];

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.all(20.r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ترتيب حسب',
                      style: GoogleFonts.cairo(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navyBlue,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    ...List.generate(_sortOptions.length, (index) {
                      return RadioListTile<int>(
                        activeColor: AppColors.navyBlue,
                        title: Text(
                          _sortOptions[index],
                          style: GoogleFonts.cairo(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: index,
                        groupValue: _selectedSortIndex,
                        onChanged: (val) {
                          setModalState(() => _selectedSortIndex = val!);
                          setState(() => _selectedSortIndex = val!);
                          Navigator.pop(context);
                        },
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.all(20.r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التصفية',
                      style: GoogleFonts.cairo(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navyBlue,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    DropdownButtonFormField<String>(
                      value: _selectedGov,
                      decoration: InputDecoration(
                        labelText: 'المحافظة',
                        labelStyle: GoogleFonts.cairo(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      items: ['بورسعيد', 'القاهرة', 'الإسكندرية']
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e, style: GoogleFonts.cairo()),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setModalState(() => _selectedGov = val!),
                    ),
                    SizedBox(height: 16.h),
                    DropdownButtonFormField<String>(
                      value: _selectedCity,
                      decoration: InputDecoration(
                        labelText: 'المنطقة',
                        labelStyle: GoogleFonts.cairo(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      items: ['حي الشرق', 'بورفؤاد', 'حي الزهور']
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e, style: GoogleFonts.cairo()),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setModalState(() => _selectedCity = val!),
                    ),
                    SizedBox(height: 24.h),
                    SizedBox(
                      width: double.infinity,
                      height: 50.h,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navyBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'تطبيق التصفية',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16.sp,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildActionButton(String title, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18.sp, color: AppColors.navyBlue),
      label: Text(
        title,
        style: GoogleFonts.cairo(
          color: AppColors.navyBlue,
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.navyBlue.withOpacity(0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
        padding: EdgeInsets.symmetric(vertical: 8.h),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: AppColors.navyBlue),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.navyBlue,
          title: Text(
            widget.categoryName,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w800,
              fontSize: 20.sp,
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم، التخصص...',
                  hintStyle: GoogleFonts.cairo(color: Colors.grey),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.navyBlue,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 12.h,
                    horizontal: 16.w,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: AppColors.navyBlue),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'الترتيب',
                      Icons.sort,
                      _showSortBottomSheet,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _buildActionButton(
                      'التصفية',
                      Icons.filter_alt_outlined,
                      _showFilterBottomSheet,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _buildActionButton(
                      'الخريطة',
                      Icons.map_outlined,
                      () {},
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                itemCount: _dummyLawyers.length,
                itemBuilder: (context, index) {
                  final lawyer = _dummyLawyers[index];
                  return Container(
                    margin: EdgeInsets.only(bottom: 16.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: AppColors.navyBlue,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16.r),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(16.r),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lawyer.name,
                                          style: GoogleFonts.cairo(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.navyBlue,
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          lawyer.specialization,
                                          style: GoogleFonts.cairo(
                                            fontSize: 13.sp,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 6.h),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.star_rounded,
                                              color: Colors.amber,
                                              size: 18,
                                            ),
                                            SizedBox(width: 4.w),
                                            Text(
                                              '${lawyer.rating} (${lawyer.reviewsCount} زائر)',
                                              style: GoogleFonts.cairo(
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  CircleAvatar(
                                    radius: 30.r,
                                    backgroundColor: Colors.grey.shade200,
                                    backgroundImage: NetworkImage(
                                      lawyer.imageUrl,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
                              _buildInfoRow(
                                Icons.location_on_outlined,
                                lawyer.location,
                              ),
                              _buildInfoRow(
                                Icons.account_balance_wallet_outlined,
                                'سعر الكشف: ${lawyer.fee} جنيه',
                              ),
                              _buildInfoRow(
                                Icons.access_time_outlined,
                                'مدة الانتظار: ${lawyer.waitTime} دقيقة',
                              ),
                              SizedBox(height: 16.h),
                              Row(
                                children: [
                                  SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width * 0.4,
                                    height: 44.h,
                                    child: ElevatedButton(
                                      onPressed: () {},
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.legalGold,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10.r,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'احجز',
                                        style: GoogleFonts.cairo(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15.sp,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(
                                          10.r,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        lawyer.availability,
                                        style: GoogleFonts.cairo(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LawyerMockModel {
  final String name;
  final String specialization;
  final double rating;
  final int reviewsCount;
  final String location;
  final int fee;
  final int waitTime;
  final String availability;
  final String imageUrl;

  LawyerMockModel({
    required this.name,
    required this.specialization,
    required this.rating,
    required this.reviewsCount,
    required this.location,
    required this.fee,
    required this.waitTime,
    required this.availability,
    required this.imageUrl,
  });
}
