import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class LawyerLegalLibraryScreen extends StatefulWidget {
  const LawyerLegalLibraryScreen({super.key});

  @override
  State<LawyerLegalLibraryScreen> createState() => _LawyerLegalLibraryScreenState();
}

class _LawyerLegalLibraryScreenState extends State<LawyerLegalLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Mock documents data
  final List<Map<String, dynamic>> _documents = [
    {'name': 'Egyptian Civil Code 2024'.translate(), 'category': 'Laws', 'size': '2.4 MB', 'date': '2024-01-10'},
    {'name': 'Court Ruling - Contract Dispute 2023'.translate(), 'category': 'Rulings', 'size': '1.2 MB', 'date': '2024-02-15'},
    {'name': 'Labor Law Amendments'.translate(), 'category': 'Laws', 'size': '850 KB', 'date': '2024-03-20'},
    {'name': 'Commercial Register Guidelines'.translate(), 'category': 'Guidelines', 'size': '3.1 MB', 'date': '2024-04-05'},
    {'name': 'Family Law Handbook'.translate(), 'category': 'Handbook', 'size': '5.2 MB', 'date': '2024-05-12'},
    {'name': 'Criminal Procedure Code'.translate(), 'category': 'Laws', 'size': '1.8 MB', 'date': '2024-06-18'},
    {'name': 'Investment Law 2024'.translate(), 'category': 'Laws', 'size': '920 KB', 'date': '2024-07-22'},
    {'name': 'Tax Authority Regulations'.translate(), 'category': 'Regulations', 'size': '2.1 MB', 'date': '2024-08-30'},
  ];

  List<Map<String, dynamic>> get _filteredDocuments {
    if (_searchQuery.isEmpty) return _documents;
    return _documents.where((doc) => 
      doc['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
      doc['category'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _uploadFile() async {
    // Mock file upload function
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('File upload feature - integrate with file picker'.translate())),
    );
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
          'My Legal Library'.translate(),
          style: GoogleFonts.cairo(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.navyBlue,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.cloud_upload_rounded, size: 24.sp, color: AppColors.legalGold),
            onPressed: _uploadFile,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(16.w),
            color: cardBg,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: GoogleFonts.cairo(fontSize: 14.sp, color: isDark ? Colors.white : AppColors.navyBlue),
              decoration: InputDecoration(
                hintText: 'Search documents...'.translate(),
                hintStyle: GoogleFonts.cairo(fontSize: 14.sp, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFFCFDFF),
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
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              ),
            ),
          ),
          // Documents List
          Expanded(
            child: _filteredDocuments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open_rounded, size: 64.sp, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                        SizedBox(height: 16.h),
                        Text(
                          'No documents found'.translate(),
                          style: GoogleFonts.cairo(
                            fontSize: 16.sp,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16.w),
                    itemCount: _filteredDocuments.length,
                    itemBuilder: (context, index) {
                      final doc = _filteredDocuments[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48.w,
                              height: 48.h,
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Icon(
                                Icons.picture_as_pdf_rounded,
                                color: Colors.red.shade700,
                                size: 24.sp,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc['name']!,
                                    style: GoogleFonts.cairo(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : AppColors.navyBlue,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                        decoration: BoxDecoration(
                                          color: AppColors.legalGold.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4.r),
                                        ),
                                        child: Text(
                                          doc['category']!,
                                          style: GoogleFonts.cairo(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.legalGold,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        doc['size']!,
                                        style: GoogleFonts.cairo(
                                          fontSize: 11.sp,
                                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.visibility_rounded, size: 20.sp, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('View document: ${doc['name']}'.translate())),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadFile,
        backgroundColor: AppColors.legalGold,
        child: Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}