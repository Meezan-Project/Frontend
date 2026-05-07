import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class LawyerConflictCheckerScreen extends StatefulWidget {
  const LawyerConflictCheckerScreen({super.key});

  @override
  State<LawyerConflictCheckerScreen> createState() => _LawyerConflictCheckerScreenState();
}

class _LawyerConflictCheckerScreenState extends State<LawyerConflictCheckerScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String? _searchResult;
  
  // Mock existing clients/cases for conflict detection
  final List<Map<String, dynamic>> _existingClients = [
    {'name': 'Ahmed Mohamed', 'case': 'Contract Dispute', 'status': 'active'},
    {'name': 'Sarah Ahmed', 'case': 'Divorce Case', 'status': 'active'},
    {'name': 'Omar Hassan', 'case': 'Property Dispute', 'status': 'closed'},
    {'name': 'Fatima Ali', 'case': 'Labor Case', 'status': 'active'},
    {'name': 'Mostafa Ibrahim', 'case': 'Commercial', 'status': 'pending'},
    {'name': 'Youssef Khaled', 'case': 'Criminal Defense', 'status': 'active'},
    {'name': 'Layla Mahmoud', 'case': 'Family Law', 'status': 'closed'},
    {'name': 'Tarek Samir', 'case': 'Real Estate', 'status': 'active'},
  ];

  void _checkForConflict() {
    if (_searchController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a name to check'.translate())),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResult = null;
    });

    // Simulate search delay
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      
      final query = _searchController.text.toLowerCase().trim();
      final foundClient = _existingClients.where((client) => 
        client['name'].toString().toLowerCase().contains(query)
      ).toList();

      setState(() {
        _isSearching = false;
        if (foundClient.isNotEmpty) {
          _searchResult = 'conflict';
        } else {
          _searchResult = 'clear';
        }
      });
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchResult = null;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBg = isDark ? const Color(0xFF0F1419) : const Color(0xFFFCFDFF);
    final cardBg = isDark ? const Color(0xFF1A2940) : Colors.white;
    final borderColor = isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5);

    return Scaffold(
      backgroundColor: appBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 20.sp, color: isDark ? Colors.white : AppColors.navyBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Conflict Checker'.translate(),
          style: GoogleFonts.cairo(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.navyBlue,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.legalGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.legalGold.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.legalGold, size: 24.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Check potential conflicts of interest before accepting new cases'.translate(),
                      style: GoogleFonts.cairo(
                        fontSize: 13.sp,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // Search Input
            Text(
              'Search Client or Case'.translate(),
              style: GoogleFonts.cairo(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.navyBlue,
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.cairo(fontSize: 14.sp, color: isDark ? Colors.white : AppColors.navyBlue),
                    decoration: InputDecoration(
                      hintText: 'Enter client name or case details...'.translate(),
                      hintStyle: GoogleFonts.cairo(fontSize: 14.sp, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                      prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                      filled: true,
                      fillColor: cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: AppColors.legalGold, width: 2),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    ),
                    onSubmitted: (_) => _checkForConflict(),
                  ),
                ),
                SizedBox(width: 12.w),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.legalGold,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: IconButton(
                    icon: _isSearching 
                        ? SizedBox(
                            width: 20.sp,
                            height: 20.sp,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(Icons.check_rounded, color: Colors.white),
                    onPressed: _isSearching ? null : _checkForConflict,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // Result Display
            if (_searchResult != null) ...[
              _buildResultCard(isDark, cardBg, borderColor),
              SizedBox(height: 24.h),
            ],

            // Recent Searches / Info
            Text(
              'How it works'.translate(),
              style: GoogleFonts.cairo(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.navyBlue,
              ),
            ),
            SizedBox(height: 12.h),
            _buildHowItWorksItem(
              icon: Icons.person_search_rounded,
              title: 'Enter Client Name'.translate(),
              description: 'Type the name of the potential client or case details'.translate(),
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
            ),
            SizedBox(height: 8.h),
            _buildHowItWorksItem(
              icon: Icons.analytics_rounded,
              title: 'Check Database'.translate(),
              description: 'System searches your existing clients and cases'.translate(),
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
            ),
            SizedBox(height: 8.h),
            _buildHowItWorksItem(
              icon: Icons.warning_amber_rounded,
              title: 'Get Result'.translate(),
              description: 'See if there\'s a conflict or if the case is clear'.translate(),
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(bool isDark, Color cardBg, Color borderColor) {
    final isConflict = _searchResult == 'conflict';
    
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isConflict 
            ? Colors.red.shade50
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isConflict 
              ? Colors.red.shade200
              : Colors.green.shade200,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            isConflict 
                ? Icons.warning_amber_rounded 
                : Icons.check_circle_rounded,
            color: isConflict 
                ? Colors.red.shade700 
                : Colors.green.shade700,
            size: 48.sp,
          ),
          SizedBox(height: 12.h),
          Text(
            isConflict 
                ? 'Conflict Detected!'.translate()
                : 'No Conflict Found'.translate(),
            style: GoogleFonts.cairo(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: isConflict 
                  ? Colors.red.shade700 
                  : Colors.green.shade700,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            isConflict 
                ? 'This client has an existing active case. Please review before proceeding.'.translate()
                : 'No matching records found in your database. You may proceed with this case.'.translate(),
            style: GoogleFonts.cairo(
              fontSize: 13.sp,
              color: isConflict 
                  ? Colors.red.shade600 
                  : Colors.green.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          TextButton(
            onPressed: _clearSearch,
            child: Text(
              'Clear Search'.translate(),
              style: GoogleFonts.cairo(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: AppColors.legalGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: AppColors.legalGold, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.navyBlue,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  description,
                  style: GoogleFonts.cairo(
                    fontSize: 11.sp,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}