import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/screens/lawyer_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  static Route createRoute() {
    return PageRouteBuilder(
      pageBuilder: (_, _, _) => const SearchScreen(),
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<DocumentSnapshot> _allResults = [];
  List<DocumentSnapshot> _filteredResults = [];
  List<String> _suggestions = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    final lawyersSnap = await FirebaseFirestore.instance
        .collection('lawyers')
        .limit(100)
        .get();

    if (mounted) {
      setState(() {
        _allResults = lawyersSnap.docs;
        _filteredResults = lawyersSnap.docs;
        _loading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredResults = _allResults;
        _suggestions = [];
        _loading = false;
      });
      return;
    }

    setState(() { _loading = true; });

    final List<DocumentSnapshot> filtered = _allResults.where((item) {
      final data = item.data() as Map<String, dynamic>? ?? {};
      bool matchList(dynamic field) {
        if (field is List) return field.join(' ').toLowerCase().contains(query);
        if (field is String) return field.toLowerCase().contains(query);
        return false;
      }
      final officeNameStr = data['employer_office_name'] ?? (data['office_details'] is Map ? data['office_details']['office_name'] : data['officeName']);
      // Use the robust `matchList` for all fields to prevent type errors.
      return matchList(data['name']) ||
             matchList(data['lawyerName']) ||
             matchList(data['first_name']) ||
             matchList(data['second_name']) ||
             matchList(officeNameStr) ||
             matchList(data['professional_bio']) ||
             matchList(data['specialization']) ||
             matchList(data['specializationText']) ||
             matchList(data['category']) ||
             matchList(data['city']) ||
             matchList(data['country']) ||
             matchList(data['govern']);
    }).toList();

    final Set<String> sugg = {};
    for (final doc in filtered) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      if (data['name'] != null && data['name'].toString().toLowerCase().contains(query)) sugg.add(data['name'].toString());
      if (data['first_name'] != null && data['first_name'].toString().toLowerCase().contains(query)) sugg.add(data['first_name'].toString());
      if (data['second_name'] != null && data['second_name'].toString().toLowerCase().contains(query)) sugg.add(data['second_name'].toString());
      if (data['specializationText'] != null && data['specializationText'].toString().toLowerCase().contains(query)) sugg.add(data['specializationText'].toString());
      if (data['city'] != null && data['city'].toString().toLowerCase().contains(query)) sugg.add(data['city'].toString());
      if (data['govern'] != null && data['govern'].toString().toLowerCase().contains(query)) sugg.add(data['govern'].toString());
      final officeNameStr = data['employer_office_name'] ?? (data['office_details'] is Map ? data['office_details']['office_name'] : data['officeName']);
      if (officeNameStr != null && officeNameStr.toString().toLowerCase().contains(query)) sugg.add(officeNameStr.toString());
    }

    setState(() {
      _filteredResults = filtered;
      _suggestions = sugg.take(5).toList();
      _loading = false;
    });
  }

  Widget _buildSearchBar() {
    return Hero(
      tag: 'searchBar',
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: 52.h,
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            style: GoogleFonts.cairo(
              color: AppColors.navyBlue,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Search lawyers, offices, or specialties...',
              hintStyle: GoogleFonts.cairo(
                color: Colors.grey.shade400,
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(Icons.search, color: AppColors.legalGold, size: 24.sp),
              contentPadding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 10.w),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey.shade400, size: 20.sp),
                      onPressed: () {
                        _controller.clear();
                        _onSearchChanged();
                      },
                    )
                  : null,
            ),
            cursorColor: AppColors.navyBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    if (_suggestions.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 2.h),
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _suggestions
            .map(
              (s) => InkWell(
                onTap: () {
                  _controller.text = s;
                  _controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: s.length),
                  );
                  _onSearchChanged();
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 10.h,
                    horizontal: 12.w,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.grey.shade400, size: 18.sp),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          s,
                          style: GoogleFonts.cairo(
                            fontSize: 15.sp,
                            color: AppColors.navyBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.only(top: 8.h, bottom: 8.h, right: 16.w),
              color: AppColors.navyBlue,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20.sp),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(child: _buildSearchBar()),
                ],
              ),
            ),
            _buildSuggestions(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.legalGold))
                  : _controller.text.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_rounded, color: Colors.grey.shade300, size: 64.sp),
                              SizedBox(height: 16.h),
                              Text(
                                'Start searching for lawyers, offices...',
                                style: GoogleFonts.cairo(color: Colors.grey.shade500, fontSize: 16.sp, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      : _filteredResults.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off_rounded, color: Colors.grey.shade300, size: 64.sp),
                                  SizedBox(height: 16.h),
                                  Text(
                                    'No matching results found.',
                                    style: GoogleFonts.cairo(color: Colors.grey.shade500, fontSize: 16.sp, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
                              itemCount: _filteredResults.length,
                              itemBuilder: (context, i) {
                                final item = _filteredResults[i];
                                return _buildResultCard(item);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(DocumentSnapshot doc) {
    final lawyer = LawyerModel.fromFirestore(doc);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LawyerProfileScreen(lawyer: lawyer),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 28.r,
                  backgroundColor: AppColors.legalGold.withOpacity(0.15),
                  backgroundImage: lawyer.imageUrl.isNotEmpty ? NetworkImage(lawyer.imageUrl) : null,
                  child: lawyer.imageUrl.isEmpty 
                      ? Icon(
                          Icons.person_rounded,
                          color: AppColors.legalGold,
                          size: 28.sp,
                        )
                      : null,
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          lawyer.name,
                        style: GoogleFonts.cairo(
                          color: AppColors.navyBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (lawyer.workStatus.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          lawyer.workStatus == 'Owns an Office' ? 'Office Owner' :
                          lawyer.workStatus == 'Works in an Office' ? 'Works at an Office' : 'Freelancer',
                          style: GoogleFonts.cairo(
                            color: Colors.grey.shade600,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (lawyer.officeName.isNotEmpty && lawyer.workStatus != 'Freelancer') ...[
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(Icons.business_center_rounded, size: 14.sp, color: AppColors.legalGold),
                            SizedBox(width: 4.w),
                            Expanded(
                              child: Text(
                                lawyer.officeName,
                                style: GoogleFonts.cairo(
                                  color: AppColors.navyBlue,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                        if (lawyer.specialization.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                            lawyer.specialization,
                          style: GoogleFonts.cairo(
                            color: AppColors.legalGold,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.sp,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                        if (lawyer.location.isNotEmpty && lawyer.location != 'Location not provided') ...[
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, color: Colors.grey.shade500, size: 14.sp),
                            SizedBox(width: 4.w),
                            Expanded(
                              child: Text(
                                  lawyer.location,
                                style: GoogleFonts.cairo(
                                  color: Colors.grey.shade600,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade300, size: 16.sp),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
