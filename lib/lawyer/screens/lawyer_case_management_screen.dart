import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mezaan/shared/services/supabase_storage_service.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/models/case_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mezaan/shared/services/notification_service.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

// Reusing the date formatting helper for consistency with User side
String formatDate(DateTime date, String format) {
  final months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  return format.replaceAllMapped(RegExp(r'EEEE|MMM|dd|yyyy|hh|mm|\ba\b'), (
    match,
  ) {
    switch (match.group(0)) {
      case 'EEEE':
        return days[date.weekday % 7];
      case 'MMM':
        return months[date.month - 1];
      case 'dd':
        return date.day.toString().padLeft(2, '0');
      case 'yyyy':
        return date.year.toString();
      case 'hh':
        return (date.hour % 12 == 0 ? 12 : date.hour % 12).toString().padLeft(
          2,
          '0',
        );
      case 'mm':
        return date.minute.toString().padLeft(2, '0');
      case 'a':
        return date.hour >= 12 ? 'PM' : 'AM';
      default:
        return match.group(0)!;
    }
  });
}

class LawyerCaseDetailsScreen extends StatefulWidget {
  final UserCase case_;
  final bool isLawyer; // Global Role Logic toggle

  const LawyerCaseDetailsScreen({
    super.key,
    required this.case_,
    this.isLawyer = true,
  });

  @override
  State<LawyerCaseDetailsScreen> createState() =>
      _LawyerCaseDetailsScreenState();
}

class _LawyerCaseDetailsScreenState extends State<LawyerCaseDetailsScreen> {
  late PageController _pageController;
  int _currentTabIndex = 0;
  bool _isSaving = false;

  // Local state to simulate database updates without Firestore delay
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  String? _selectedCategory;
  String? _selectedStatus;
  late List<CaseSession> _sessions;
  late List<CaseUpdate> _updates;

  StreamSubscription<DocumentSnapshot>? _caseSubscription;

  // Controller for manual updates
  final TextEditingController _manualUpdateController = TextEditingController();

  // Controllers for Fees Tab
  final TextEditingController _withdrawAmountController =
      TextEditingController();
  final TextEditingController _withdrawDescController = TextEditingController();
  final TextEditingController _requestAmountController =
      TextEditingController();
  final TextEditingController _requestDescController = TextEditingController();
  PlatformFile? _evidenceFile;
  bool _isWithdrawing = false;
  bool _isRequesting = false;
  bool _isRequestFormVisible = false;
  final Set<String> _expandedDocuments = {};

  String? _selectedUpdateSessionId;
  bool _isRecording = false;
  String? _recordedAudioPath;
  bool _isPostingUpdate = false;

  Timer? _recordTimer;
  int _recordDuration = 0;

  final AudioRecorder _audioRecorder = AudioRecorder();

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final wholeNumber = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    return '$wholeNumber.${parts[1]}';
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _titleController = TextEditingController(text: widget.case_.title);
    _descriptionController = TextEditingController(
      text: widget.case_.description,
    );
    _selectedCategory = widget.case_.category;
    _selectedStatus = widget.case_.status;
    _sessions = List.from(widget.case_.sessions);
    _updates = List.from(widget.case_.updates);

    _caseSubscription = FirebaseFirestore.instance
        .collection('cases')
        .doc(widget.case_.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        final dbStatus = data['status'] as String?;
        final dbCategory = data['category'] as String?;
        final dbTitle = data['title'] as String?;
        final dbDescription = data['description'] as String?;

        if (mounted) {
          setState(() {
            if (dbStatus != null) _selectedStatus = dbStatus;
            if (dbCategory != null) _selectedCategory = dbCategory;
            if (dbTitle != null) _titleController.text = dbTitle;
            if (dbDescription != null) _descriptionController.text = dbDescription;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _caseSubscription?.cancel();
    _pageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _manualUpdateController.dispose();
    _withdrawAmountController.dispose();
    _withdrawDescController.dispose();
    _requestAmountController.dispose();
    _requestDescController.dispose();
    _audioRecorder.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  Future<void> _addCaseUpdate({
    required String type,
    required String title,
    required String description,
  }) async {
    if (!mounted) return;

    final docRef = FirebaseFirestore.instance
        .collection('cases')
        .doc(widget.case_.id)
        .collection('updates')
        .doc();

    final updateData = {
      'id': docRef.id,
      'type': type,
      'title': title,
      'description': description,
      'date': FieldValue.serverTimestamp(),
    };

    try {
      await docRef.set(updateData);
    } catch (_) {}

    setState(() {
      _updates.insert(
        0,
        CaseUpdate(
          id: docRef.id,
          type: type,
          title: title,
          description: description,
          date: DateTime.now(),
        ),
      );
    });
  }

  // Theme Constants based on requirements
  static const Color primaryBlue = Color(0xFF001F3F); // Dark Blue

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F1419) : const Color(0xFFFCFDFF);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cases')
          .doc(widget.case_.id)
          .snapshots(),
      builder: (context, caseSnapshot) {
        final caseData =
            caseSnapshot.data?.data() as Map<String, dynamic>? ?? {};

        final String status = caseData['status'] ?? widget.case_.status;
        final bool isPendingPayment = status == 'pending_payment';

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20.sp,
                color: isDark ? Colors.white : primaryBlue,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              widget.isLawyer
                  ? 'Manage Case'.translate()
                  : 'Case Details'.translate(),
              style: GoogleFonts.cairo(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : primaryBlue,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (widget.isLawyer && !isPendingPayment)
                _isSaving
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : TextButton(
                        onPressed: _saveOverviewChanges,
                        child: Text(
                          'Save'.translate(),
                          style: GoogleFonts.cairo(
                            color: AppColors.legalGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
            ],
          ),
          body: isPendingPayment
              ? Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24.r),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(24.r),
                          decoration: BoxDecoration(
                            color: AppColors.legalGold.withOpacity(0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.legalGold.withOpacity(0.3),
                              width: 2.w,
                            ),
                          ),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            size: 80.sp,
                            color: AppColors.legalGold,
                          ),
                        ),
                        SizedBox(height: 24.h),
                        Text(
                          'Payment Pending'.translate(),
                          style: GoogleFonts.cairo(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.navyBlue,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'Access to case details is locked because the client hasn\'t paid yet. The case details will be unlocked automatically once payment is completed.'
                              .translate(),
                          style: GoogleFonts.cairo(
                            fontSize: 14.sp,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 32.h),
                        Container(
                          padding: EdgeInsets.all(16.r),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                              ),
                            ],
                            border: Border.all(
                              color: isDark ? const Color(0xFF334766) : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildDetailRow(
                                'Case Number'.translate(),
                                widget.case_.caseNumber.isNotEmpty ? widget.case_.caseNumber : 'N/A',
                                isDark,
                              ),
                              const Divider(),
                              _buildDetailRow(
                                'Client Name'.translate(),
                                widget.case_.clientName.isNotEmpty ? widget.case_.clientName : widget.case_.lawyerName,
                                isDark,
                              ),
                              const Divider(),
                              _buildDetailRow(
                                'Category'.translate(),
                                widget.case_.category.translate(),
                                isDark,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeaderCard(isDark, caseData),
                      _buildTabBar(isDark),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) =>
                              setState(() => _currentTabIndex = index),
                          children: [
                            _buildOverviewTab(isDark, caseData),
                            _buildDocumentsTab(isDark),
                            _buildSessionsTab(isDark, caseData),
                            _buildUpdatesTab(isDark, caseData),
                            _buildFeesTab(isDark, caseData),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildTabBar(bool isDark) {
    final tabs = [
      'Overview'.translate(),
      'Documents'.translate(),
      'Sessions'.translate(),
      'Updates'.translate(),
      'Fees'.translate(),
    ];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isActive = _currentTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Text(
                      tabs[index],
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isActive
                            ? AppColors.legalGold
                            : (isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600),
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

  Widget _buildHeaderCard(bool isDark, Map<String, dynamic> caseData) {
    final cardBg = isDark ? const Color(0xFF1A2940) : Colors.white;
    final officialCaseNumber = caseData['caseNumber'] as String?;
    final caseYear = caseData['caseYear'] as String?;
    final hasOfficialCaseNumber =
        officialCaseNumber != null &&
        officialCaseNumber.isNotEmpty &&
        caseYear != null &&
        caseYear.isNotEmpty;

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
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
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
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 4.h,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          caseData['caseId'] as String? ??
                              widget.case_.caseNumber,
                          style: GoogleFonts.cairo(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.legalGold,
                          ),
                        ),
                        if (hasOfficialCaseNumber)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.legalGold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              'Official: $officialCaseNumber / $caseYear',
                              style: GoogleFonts.cairo(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.legalGold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      _titleController.text.isNotEmpty
                          ? _titleController.text
                          : widget.case_.title,
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
              _statusBadge(_selectedStatus ?? widget.case_.status),
            ],
          ),
          SizedBox(height: 14.h),
          Text(
            _descriptionController.text.isNotEmpty
                ? _descriptionController.text
                : widget.case_.description,
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
                value: _selectedCategory ?? widget.case_.category,
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

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 13.sp,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.navyBlue,
            ),
          ),
        ],
      ),
    );
  }

  // --- OVERVIEW TAB ---
  Widget _buildOverviewTab(bool isDark, Map<String, dynamic> caseData) {
    String currentServiceType =
        caseData['serviceType'] as String? ?? 'non_litigation';

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        // Person Info
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2940) : Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5),
            ),
          ),
          child: Builder(
            builder: (context) {
              final targetId = widget.isLawyer
                  ? caseData['clientId']
                  : caseData['lawyerId'];
              final collection = widget.isLawyer ? 'users' : 'lawyers';
              final fallbackName = widget.case_.lawyerName.isNotEmpty
                  ? widget.case_.lawyerName.replaceAll('Client: ', '').trim()
                  : 'Unknown';
              final roleLabel = widget.isLawyer
                  ? 'Client'.translate()
                  : 'Lawyer'.translate();

              Widget buildContent(String name, String? photoUrl) {
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 24.r,
                      backgroundColor: AppColors.legalGold.withOpacity(0.2),
                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl)
                          : null,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? Text(
                              name.isNotEmpty
                                  ? name[0].toUpperCase()
                                  : (widget.isLawyer ? 'C' : 'L'),
                              style: GoogleFonts.cairo(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.legalGold,
                              ),
                            )
                          : null,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.cairo(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : primaryBlue,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            roleLabel,
                            style: GoogleFonts.cairo(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              if (targetId != null && targetId.toString().isNotEmpty) {
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection(collection)
                      .doc(targetId)
                      .get(),
                  builder: (context, snapshot) {
                    String displayName = fallbackName;
                    String? photoUrl;

                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null) {
                        if (data.containsKey('name') &&
                            data['name'].toString().isNotEmpty) {
                          displayName = data['name'];
                        } else if (data.containsKey('first_name') &&
                            data.containsKey('second_name')) {
                          displayName =
                              '${data['first_name']} ${data['second_name']}';
                        }

                        photoUrl =
                            data['profile_photo'] ??
                            data['profileImage'] ??
                            data['profilePhotoUrl'] ??
                            data['photoUrl'];
                      }
                    }

                    return buildContent(displayName, photoUrl);
                  },
                );
              }

              return buildContent(fallbackName, null);
            },
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          'Manage Case Details'.translate(),
          style: GoogleFonts.cairo(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : primaryBlue,
          ),
        ),
        SizedBox(height: 12.h),
        if (widget.isLawyer) ...[
          _buildLabel('Case Title'.translate()),
          TextField(
            controller: _titleController,
            onChanged: (v) => setState(() {}),
            decoration: _inputDecoration(isDark),
            style: GoogleFonts.cairo(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),
        ] else ...[
          Text(
            _titleController.text,
            style: GoogleFonts.cairo(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : primaryBlue,
            ),
          ),
          SizedBox(height: 12.h),
        ],
        _buildLabel('Case Status'.translate()),
        widget.isLawyer
            ? Builder(
                builder: (context) {
                  final items = ['active', 'closed', 'on_hold', 'pending'];
                  if (_selectedStatus != null && !items.contains(_selectedStatus)) {
                    items.add(_selectedStatus!);
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedStatus,
                    items: items
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.toUpperCase().translate()),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedStatus = val),
                    decoration: _inputDecoration(isDark),
                  );
                },
              )
            : _readOnlyField(isDark, _selectedStatus?.toUpperCase() ?? 'N/A'),
        SizedBox(height: 16.h),
        _buildLabel('Category'.translate()),
        widget.isLawyer
            ? StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('lawyer_specialization')
                    .snapshots(),
                builder: (context, snapshot) {
                  List<String> categories = [
                    'Criminal',
                    'Civil',
                    'Family',
                    'Corporate',
                  ];
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    categories = snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return (data['name'] ?? doc.id).toString();
                    }).toList();
                  }

                  if (_selectedCategory != null &&
                      !categories.contains(_selectedCategory)) {
                    categories.add(_selectedCategory!);
                  }

                  return DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.translate()),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val),
                    decoration: _inputDecoration(isDark),
                  );
                },
              )
            : _readOnlyField(isDark, _selectedCategory ?? 'N/A'),
        SizedBox(height: 16.h),
        _buildLabel('Service Type'.translate()),
        _readOnlyField(
          isDark,
          currentServiceType == 'litigation' ? 'Litigation' : 'Non-Litigation',
        ),
        SizedBox(height: 16.h),
        _buildLabel('Case Description'.translate()),
        widget.isLawyer
            ? TextField(
                controller: _descriptionController,
                maxLines: 5,
                onChanged: (v) => setState(() {}),
                decoration: _inputDecoration(isDark),
                style: GoogleFonts.cairo(fontSize: 14.sp),
              )
            : _readOnlyField(isDark, _descriptionController.text, maxLines: 5),
        SizedBox(height: 24.h),
        if (widget.isLawyer)
          ElevatedButton.icon(
            onPressed: _showAddTimelineDialog,
            icon: const Icon(Icons.add_chart_rounded, color: Colors.white),
            label: Text(
              'Add Timeline Event'.translate(),
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              padding: EdgeInsets.symmetric(vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _saveOverviewChanges() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('cases')
          .doc(widget.case_.id)
          .update({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'status': _selectedStatus,
        'category': _selectedCategory,
      });

      await _addCaseUpdate(
        type: 'process',
        title: 'Details Updated',
        description: 'Case metadata was modified by the lawyer.',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Changes saved successfully'.translate())),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save changes: $e'.translate())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showAddTimelineDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'New Timeline Event'.translate(),
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            hintText: 'e.g., Initial Investigation',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'.translate()),
          ),
          TextButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                Navigator.pop(dialogContext); // Close immediately before async
                await _addCaseUpdate(
                  type: 'process',
                  title: 'Timeline Updated',
                  description: titleController.text,
                );
              }
            },
            child: Text('Add'.translate()),
          ),
        ],
      ),
    );
  }

  // --- DOCUMENTS TAB ---
  Widget _buildDocumentsTab(bool isDark) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('cases')
                .doc(widget.case_.id)
                .collection('documentations')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading documents'.translate()),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    'No documents requested.'.translate(),
                    style: GoogleFonts.cairo(color: Colors.grey),
                  ),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final docId = docs[index].id;
                  final name = data['name'] ?? 'Untitled';
                  final description = data['description'] ?? '';
                  final isSubmitted = data['isSubmitted'] == true;
                  final fileUrl = data['fileUrl'];

                  return Container(
                    margin: EdgeInsets.only(bottom: 12.h),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A2940) : Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isSubmitted
                            ? Colors.green
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          onTap: () {
                            setState(() {
                              if (_expandedDocuments.contains(docId)) {
                                _expandedDocuments.remove(docId);
                              } else {
                                _expandedDocuments.add(docId);
                              }
                            });
                          },
                          title: Text(
                            name,
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            description,
                            style: GoogleFonts.cairo(fontSize: 12.sp),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSubmitted)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                              if (!isSubmitted)
                                const Icon(
                                  Icons.pending_actions,
                                  color: AppColors.legalGold,
                                ),
                              Icon(
                                _expandedDocuments.contains(docId)
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: Colors.grey.shade500,
                              ),
                            ],
                          ),
                        ),
                        if (_expandedDocuments.contains(docId))
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                            ).copyWith(bottom: 16.h),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(),
                                SizedBox(height: 8.h),
                                _buildDocumentDetailRow(
                                  'Requested:',
                                  data['createdAt'] != null
                                      ? formatDate(
                                          (data['createdAt'] as Timestamp)
                                              .toDate(),
                                          'MMM dd, yyyy - hh:mm a',
                                        )
                                      : 'N/A',
                                  isDark,
                                ),
                                SizedBox(height: 8.h),
                                _buildDocumentDetailRow(
                                  'Uploaded:',
                                  data['submittedDate'] != null
                                      ? formatDate(
                                          (data['submittedDate'] as Timestamp)
                                              .toDate(),
                                          'MMM dd, yyyy - hh:mm a',
                                        )
                                      : 'Pending',
                                  isDark,
                                ),
                                if (isSubmitted && fileUrl != null) ...[
                                  SizedBox(height: 16.h),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _previewDocument(fileUrl),
                                          icon: const Icon(Icons.visibility),
                                          label: Text('Preview'.translate()),
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _downloadFile(fileUrl),
                                          icon: const Icon(
                                            Icons.download,
                                            color: Colors.white,
                                          ),
                                          label: Text(
                                            'Download'.translate(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (widget.isLawyer)
          Padding(
            padding: EdgeInsets.all(16.w),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showRequestDocumentModal,
                icon: const Icon(Icons.note_add_rounded, color: Colors.white),
                label: Text(
                  'Request Document'.translate(),
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showRequestDocumentModal() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (modalContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(modalContext).viewInsets.bottom,
          left: 20.w,
          right: 20.w,
          top: 20.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Request New Document'.translate(),
              style: GoogleFonts.cairo(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: nameController,
              decoration: _inputDecoration(
                false,
              ).copyWith(hintText: 'Document Title (e.g. ID Copy)'),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: descController,
              decoration: _inputDecoration(
                false,
              ).copyWith(hintText: 'Why is this needed?'),
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty) return;

                  Navigator.pop(modalContext); // Close immediately before async
                  final docRef = FirebaseFirestore.instance
                      .collection('cases')
                      .doc(widget.case_.id)
                      .collection('documentations')
                      .doc();

                  await docRef.set({
                    'id': docRef.id,
                    'name': nameController.text,
                    'description': descController.text,
                    'isSubmitted': false,
                    'submittedDate': null,
                    'fileUrl': null,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (!mounted) return;
                  await _addCaseUpdate(
                    type: 'action',
                    title: 'Document Requested',
                    description: 'Lawyer requested: ${nameController.text}',
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
                child: Text(
                  'Send Request'.translate(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  // --- SESSIONS TAB ---
  Widget _buildSessionsTab(bool isDark, Map<String, dynamic> caseData) {
    final serviceType = caseData['serviceType'] as String?;
    final isLitigation = serviceType == 'litigation';

    final officialCaseNumber = caseData['caseNumber'] as String?;
    final caseYear = caseData['caseYear'] as String?;
    final isLitigationUnlocked =
        officialCaseNumber != null &&
        officialCaseNumber.isNotEmpty &&
        caseYear != null &&
        caseYear.isNotEmpty;

    final isLocked = isLitigation && !isLitigationUnlocked;

    return Column(
      children: [
        if (isLocked && widget.isLawyer) _buildLitigationLockWarning(isDark),

        Expanded(
          child: isLocked
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, size: 48.sp, color: Colors.grey),
                      Icon(
                        Icons.sync_disabled,
                        size: 48.sp,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'Sessions are locked'.translate(),
                        style: TextStyle(color: Colors.grey, fontSize: 16.sp),
                      ),
                      Text(
                        'Awaiting Case Number'.translate(),
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32.w),
                        child: Text(
                          'Please add the official case number and year. The system will automatically fetch and sync the sessions for this case.'
                              .translate(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                        ),
                      ),
                    ],
                  ),
                )
              : (_sessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_available,
                              size: 48.sp,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'No sessions found yet'.translate(),
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16.sp,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            if (officialCaseNumber != null && caseYear != null)
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 32.w),
                                child: Text(
                                  'Sessions will be auto-synced from the court system using Case No: $officialCaseNumber / $caseYear'
                                      .translate(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16.w),
                        itemCount: _sessions.length,
                        itemBuilder: (context, index) {
                          final session = _sessions[index];
                          DateTime date = session.scheduledDate;

                          return Container(
                            margin: EdgeInsets.only(bottom: 12.h),
                            padding: EdgeInsets.all(14.w),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1A2940)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formatDate(date, 'EEEE, MMM dd'),
                                      style: GoogleFonts.cairo(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    _statusBadge(session.status),
                                  ],
                                ),
                                SizedBox(height: 8.h),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      session.location ?? 'TBD',
                                      style: GoogleFonts.cairo(
                                        fontSize: 12.sp,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    if (!widget.isLawyer &&
                                        session.status == 'scheduled')
                                      ElevatedButton(
                                        onPressed: () =>
                                            _showComingSoon('Meeting Link'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.legalGold,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12.w,
                                          ),
                                        ),
                                        child: Text(
                                          'Join Meeting'.translate(),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      )),
        ),
        if (widget.isLawyer && !isLitigation)
          Padding(
            padding: EdgeInsets.all(16.w),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showScheduleSessionModal,
                icon: const Icon(Icons.calendar_month, color: Colors.white),
                label: Text(
                  'Schedule Session'.translate(),
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showScheduleSessionModal() {
    final titleController = TextEditingController();
    final locController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (modalContext) => StatefulBuilder(
        builder: (statefulContext, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(statefulContext).viewInsets.bottom,
            left: 20.w,
            right: 20.w,
            top: 20.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Schedule Session'.translate(),
                style: GoogleFonts.cairo(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: titleController,
                decoration: _inputDecoration(
                  false,
                ).copyWith(hintText: 'Session Title'),
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: statefulContext,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (d != null) setModalState(() => selectedDate = d);
                      },
                      icon: const Icon(Icons.date_range),
                      label: Text(formatDate(selectedDate, 'MMM dd, yyyy')),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: statefulContext,
                          initialTime: selectedTime,
                        );
                        if (t != null) setModalState(() => selectedTime = t);
                      },
                      icon: const Icon(Icons.access_time),
                      label: Text(selectedTime.format(context)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: locController,
                decoration: _inputDecoration(
                  false,
                ).copyWith(hintText: 'Location (or Zoom Link)'),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: notesController,
                decoration: _inputDecoration(
                  false,
                ).copyWith(hintText: 'Additional Notes'),
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(
                      statefulContext,
                    ); // Close immediately before async
                    final fullDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );
                    final newSession = CaseSession(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      scheduledDate: fullDateTime,
                      status: 'scheduled',
                      location: locController.text.trim().isEmpty
                          ? 'Court Room'.translate()
                          : locController.text.trim(),
                      notes: notesController.text.trim(),
                    );
                    setState(() {
                      _sessions.add(newSession);
                    });
                    
                    // Persist to subcollection
                    await FirebaseFirestore.instance
                        .collection('cases')
                        .doc(widget.case_.id)
                        .collection('sessions')
                        .doc(newSession.id)
                        .set(newSession.toMap())
                        .catchError((e) => debugPrint('Error saving session subcollection: $e'));

                    // Append to case array field 'sessions'
                    await FirebaseFirestore.instance
                        .collection('cases')
                        .doc(widget.case_.id)
                        .update({
                      'sessions': FieldValue.arrayUnion([newSession.toMap()]),
                    }).catchError((e) => debugPrint('Error updating case sessions array: $e'));

                    // Trigger reminders schedule refresh
                    NotificationService().scheduleAllUpcomingReminders();

                    if (!mounted) return;
                    await _addCaseUpdate(
                      type: 'process',
                      title: 'New Session Scheduled',
                      description:
                          '${titleController.text} on ${formatDate(fullDateTime, 'MMM dd at hh:mm a')}',
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
                  child: Text(
                    'Save Session'.translate(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  // --- UPDATES TAB ---
  Widget _buildUpdatesTab(bool isDark, Map<String, dynamic> caseData) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('cases')
                .doc(widget.case_.id)
                .collection('updates')
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error loading updates'.translate()));
              }

              final docs = snapshot.data?.docs ?? [];
              final List<Map<String, dynamic>> updatesToDisplay = docs
                  .map((doc) => doc.data() as Map<String, dynamic>)
                  .toList();

              // Fallback to local updates if not yet found in the Firestore doc
              if (updatesToDisplay.isEmpty && _updates.isNotEmpty) {
                for (var u in _updates.reversed) {
                  updatesToDisplay.add({
                    'id': u.id,
                    'type': u.type,
                    'title': u.title,
                    'description': u.description,
                    'date': u.date.toIso8601String(),
                  });
                }
              }

              if (updatesToDisplay.isEmpty) {
                return Center(
                  child: Text(
                    'No updates yet'.translate(),
                    style: GoogleFonts.cairo(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: updatesToDisplay.length,
                itemBuilder: (context, index) {
                  final update = updatesToDisplay[index];
                  final dateVal = update['date'];
                  final date = dateVal is Timestamp
                      ? dateVal.toDate()
                      : (dateVal is String
                            ? DateTime.tryParse(dateVal) ?? DateTime.now()
                            : DateTime.now());
                  return _buildUpdateItem(update, date, isDark);
                },
              );
            },
          ),
        ),
        if (widget.isLawyer)
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2940) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Update Type:'.translate(),
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _selectedUpdateSessionId,
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('General Update'.translate()),
                          ),
                          ..._sessions.map(
                            (s) => DropdownMenuItem<String?>(
                              value: s.id,
                              child: Text(
                                'Session: ${formatDate(s.scheduledDate, 'MMM dd')} - ${s.location ?? 'TBD'}'
                                    .translate(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedUpdateSessionId = val),
                        decoration: _inputDecoration(isDark).copyWith(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.h,
                          ),
                        ),
                        style: GoogleFonts.cairo(
                          fontSize: 12.sp,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: _isRecording
                          ? Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 8.h,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2C1E16)
                                    : const Color(0xFFFFF4E5),
                                borderRadius: BorderRadius.circular(24.r),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.mic, color: Colors.red),
                                  SizedBox(width: 8.w),
                                  Text(
                                    '${(_recordDuration ~/ 60).toString().padLeft(2, '0')}:${(_recordDuration % 60).toString().padLeft(2, '0')}',
                                    style: GoogleFonts.cairo(
                                      fontSize: 14.sp,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: _cancelRecording,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            )
                          : TextField(
                              controller: _manualUpdateController,
                              decoration: _inputDecoration(isDark).copyWith(
                                hintText: 'Post case progress update...'
                                    .translate(),
                              ),
                              style: GoogleFonts.cairo(fontSize: 13.sp),
                              onChanged: (v) => setState(() {}),
                            ),
                    ),
                    SizedBox(width: 8.w),
                    if (_isRecording)
                      IconButton(
                        onPressed: _stopRecording,
                        icon: const Icon(Icons.stop_circle, color: Colors.red),
                      )
                    else if (_manualUpdateController.text.isEmpty &&
                        _recordedAudioPath == null)
                      IconButton(
                        onPressed: _startRecording,
                        icon: Icon(Icons.mic, color: AppColors.legalGold),
                      )
                    else
                      _isPostingUpdate
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              onPressed: _postManualUpdate,
                              icon: Icon(
                                Icons.send_rounded,
                                color: AppColors.legalGold,
                              ),
                            ),
                  ],
                ),
                if (_recordedAudioPath != null && !_isRecording)
                  Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: Row(
                      children: [
                        Expanded(
                          child: AudioPlayerWidget(
                            source: _recordedAudioPath!,
                            isRemote: false,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _recordedAudioPath = null),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        String filePath = '';
        if (!kIsWeb) {
          final dir = await getApplicationDocumentsDirectory();
          filePath =
              '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: filePath,
        );
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => _recordDuration++);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Microphone permission denied'.translate())),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e'.translate())),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _recordTimer?.cancel();
      setState(() {
        _isRecording = false;
        _recordedAudioPath = path;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: $e'.translate())),
        );
      }
    }
  }

  void _cancelRecording() async {
    await _audioRecorder.stop();
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _recordedAudioPath = null;
      _recordDuration = 0;
    });
  }

  Future<void> _postManualUpdate() async {
    if (_manualUpdateController.text.isEmpty && _recordedAudioPath == null) {
      return;
    }

    setState(() => _isPostingUpdate = true);

    try {
      String? voiceNoteUrl;
      if (_recordedAudioPath != null) {
        if (kIsWeb) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Voice notes uploading is currently only supported on mobile devices'
                      .translate(),
                ),
              ),
            );
          }
          setState(() => _isPostingUpdate = false);
          return;
        } else {
          final file = File(_recordedAudioPath!);
          if (await file.exists()) {
            voiceNoteUrl = await const SupabaseStorageService().uploadMedia(
              file: file,
              folderPath: 'voice_notes/${widget.case_.id}',
              fileName: 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
            );
          }
        }
      }

      String title = 'Lawyer Update'.translate();
      if (_selectedUpdateSessionId != null) {
        final session = _sessions.firstWhere(
          (s) => s.id == _selectedUpdateSessionId,
        );
        title =
            'Update for Session: ${formatDate(session.scheduledDate, "MMM dd")}'
                .translate();
      }

      final updateRef = FirebaseFirestore.instance
          .collection('cases')
          .doc(widget.case_.id)
          .collection('updates')
          .doc();

      final updateData = {
        'id': updateRef.id,
        'type': 'info',
        'title': title,
        'description': _manualUpdateController.text,
        if (_selectedUpdateSessionId != null)
          'sessionId': _selectedUpdateSessionId,
        'voiceNoteUrl': ?voiceNoteUrl,
        'date': FieldValue.serverTimestamp(),
      };

      await updateRef.set(updateData);

      if (mounted) {
        setState(() {
          _manualUpdateController.clear();
          _recordedAudioPath = null;
          _selectedUpdateSessionId = null;
        });
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update posted successfully'.translate())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting update: $e'.translate())),
        );
      }
    } finally {
      if (mounted) setState(() => _isPostingUpdate = false);
    }
  }

  Widget _buildUpdateItem(
    Map<String, dynamic> update,
    DateTime date,
    bool isDark,
  ) {
    final type = update['type'] as String? ?? 'info';
    final title = update['title'] as String? ?? '';
    final description = update['description'] as String? ?? '';
    final voiceNoteUrl = update['voiceNoteUrl'] as String?;

    IconData icon = Icons.info_outline;
    Color iconColor = AppColors.navyBlue;

    if (type == 'process') {
      icon = Icons.timeline;
      iconColor = Colors.blue;
    } else if (type == 'action') {
      icon = Icons.assignment_turned_in;
      iconColor = Colors.green;
    } else {
      icon = Icons.info_outline;
      iconColor = AppColors.legalGold;
    }

    final cardBg = isDark ? const Color(0xFF1A2940) : Colors.white;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.cairo(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : primaryBlue,
                        ),
                      ),
                    ),
                    Text(
                      formatDate(date, 'MMM dd, hh:mm a'),
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  description,
                  style: GoogleFonts.cairo(
                    fontSize: 12.sp,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                if (voiceNoteUrl != null) ...[
                  SizedBox(height: 12.h),
                  AudioPlayerWidget(source: voiceNoteUrl, isRemote: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeesTab(bool isDark, Map<String, dynamic> caseData) {
    final serviceType = caseData['serviceType'] as String?;
    final isLitigation = serviceType == 'litigation';
    final officialCaseNumber = caseData['caseNumber'] as String?;
    final caseYear = caseData['caseYear'] as String?;
    final isLitigationUnlocked =
        officialCaseNumber != null &&
        officialCaseNumber.isNotEmpty &&
        caseYear != null &&
        caseYear.isNotEmpty;
    final isLocked = isLitigation && !isLitigationUnlocked;
    final isLegalServiceLocked =
        (serviceType != 'litigation' && caseData['hasFinalDocument'] != true);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cases')
          .doc(widget.case_.id)
          .collection('fees')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];

        double total =
            (caseData['legalFees'] as num?)?.toDouble() ??
            (caseData['totalFees'] as num?)?.toDouble() ??
            0.0;
        double withdrawn = 0.0;
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['type'] == 'withdrawal') {
            withdrawn += (data['amount'] as num?)?.toDouble() ?? 0.0;
          } else if (data['type'] == 'request' && data['status'] == 'paid') {
            total += (data['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }
        double remaining = total - withdrawn;

        return ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            // --- SUMMARY STATS SECTION ---
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2940) : Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF304563)
                      : const Color(0xFFDCE6F5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildFeeStatColumn('Total Paid'.translate(), total, isDark),
                  _buildFeeStatColumn(
                    'Withdrawn'.translate(),
                    withdrawn,
                    isDark,
                    color: Colors.orange,
                  ),
                  _buildFeeStatColumn(
                    'Remaining'.translate(),
                    remaining,
                    isDark,
                    color: Colors.green,
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            if (widget.isLawyer) ...[
              if (isLocked) _buildLitigationLockWarning(isDark),
              if (isLegalServiceLocked) _buildLegalServiceLockWarning(isDark),

              if (!_isRequestFormVisible)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (isLocked || isLegalServiceLocked)
                        ? null
                        : () => setState(() => _isRequestFormVisible = true),
                    icon: Icon(
                      (isLocked || isLegalServiceLocked)
                          ? Icons.lock
                          : Icons.request_quote_rounded,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Request Additional Funds'.translate(),
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (isLocked || isLegalServiceLocked)
                          ? Colors.grey
                          : primaryBlue,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                  ),
                )
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildLabel('Request Additional Funds'.translate()),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () =>
                          setState(() => _isRequestFormVisible = false),
                    ),
                  ],
                ),
                _buildFundRequestForm(isDark),
              ],
              SizedBox(height: 24.h),
              _buildLabel('Take Funds'.translate()),
              _buildFeeManagementForm(
                isDark,
                remaining,
                isLocked: isLocked || isLegalServiceLocked,
              ),
              SizedBox(height: 24.h),
            ],
            Text(
              'Financial Activity'.translate(),
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
                color: isDark ? Colors.white : primaryBlue,
              ),
            ),
            SizedBox(height: 12.h),
            if (docs.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: Text(
                    'No financial activity yet.'.translate(),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ...docs.map((docSnap) {
              final data = docSnap.data() as Map<String, dynamic>;
              final isWithdrawal = data['type'] == 'withdrawal';
              final isRequest = data['type'] == 'request';
              final status = data['status'];
              final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
              final dateStr = data['createdAt'] != null
                  ? formatDate(
                      (data['createdAt'] as Timestamp).toDate(),
                      'MMM dd, yyyy',
                    )
                  : 'Pending';

              String title = data['title'] ?? 'Transaction';
              String amountStr =
                  '${isWithdrawal ? '-' : '+'} ${_formatCurrency(amount)} EGP';
              Color amtColor = isWithdrawal ? Colors.red : Colors.green;

              if (isRequest) {
                if (status == 'pending') {
                  title = 'Requested: $title';
                  amountStr = '${_formatCurrency(amount)} EGP';
                  amtColor = Colors.orange;
                } else {
                  title = 'Paid Request: $title';
                }
              }

              return _buildActivityItem(
                dateStr,
                title,
                amountStr,
                amtColor,
                isDark,
                evidenceUrl: data['evidenceUrl'],
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildFeeStatColumn(
    String label,
    dynamic value,
    bool isDark, {
    Color? color,
  }) {
    final valStr = value is double ? _formatCurrency(value) : value.toString();
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 10.sp,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          '$valStr EGP',
          style: GoogleFonts.cairo(
            fontSize: 14.sp,
            fontWeight: FontWeight.w900,
            color: color ?? (isDark ? Colors.white : primaryBlue),
          ),
        ),
      ],
    );
  }

  Widget _buildLitigationLockWarning(bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C1E16) : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.orange, size: 24.sp),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Please insert the official Case Number and Year to unlock fees management and allow the system to auto-update and notify you of the case schedule.',
                  style: GoogleFonts.cairo(
                    color: isDark
                        ? Colors.orange.shade200
                        : Colors.orange.shade900,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ElevatedButton.icon(
            onPressed: _showAddCaseNumberDialog,
            icon: const Icon(Icons.edit_document),
            label: Text(
              'Add Case Number',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalServiceLockWarning(bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2638) : const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.blue.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.blue, size: 24.sp),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Payments are locked until the final document is uploaded.',
                  style: GoogleFonts.cairo(
                    color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ElevatedButton.icon(
            onPressed: () async {
              // Mock final document upload
              await FirebaseFirestore.instance
                  .collection('cases')
                  .doc(widget.case_.id)
                  .update({'hasFinalDocument': true});
            },
            icon: const Icon(Icons.upload_file),
            label: Text(
              'Upload Final Document to Unlock Payment',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCaseNumberDialog() {
    final caseNumController = TextEditingController();
    String selectedYear = DateTime.now().year.toString();
    final List<String> years = List.generate(
      30,
      (index) => (DateTime.now().year - index).toString(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (statefulContext, setDialogState) => AlertDialog(
          title: Text(
            'Add Official Case Info',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: caseNumController,
                decoration: const InputDecoration(
                  labelText: 'Official Case Number',
                  hintText: 'e.g., 12345',
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16.h),
              DropdownButtonFormField<String>(
                initialValue: selectedYear,
                decoration: const InputDecoration(labelText: 'Case Year'),
                items: years
                    .map(
                      (year) =>
                          DropdownMenuItem(value: year, child: Text(year)),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedYear = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(statefulContext),
              child: Text('Cancel', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (caseNumController.text.isNotEmpty) {
                  Navigator.pop(
                    statefulContext,
                  ); // Close immediately before async
                  await _updateCaseNumber(caseNumController.text, selectedYear);
                }
              },
              child: Text('Save', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateCaseNumber(String caseNumber, String year) async {
    try {
      await FirebaseFirestore.instance
          .collection('cases')
          .doc(widget.case_.id)
          .update({'caseNumber': caseNumber, 'caseYear': year});
      if (!mounted) return;
      await _addCaseUpdate(
        type: 'process',
        title: 'Case Info Updated',
        description: 'Official case number $caseNumber/$year was added.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Case info updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating case info: $e')));
      }
    }
  }

  Widget _buildFundRequestForm(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _requestAmountController,
                decoration: _inputDecoration(
                  isDark,
                ).copyWith(hintText: 'Amount to request (EGP)'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        TextField(
          controller: _requestDescController,
          decoration: _inputDecoration(
            isDark,
          ).copyWith(hintText: 'Reason for request...'),
          maxLines: 2,
        ),
        SizedBox(height: 12.h),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isRequesting ? null : _submitFundRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: _isRequesting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Request Funds'.translate(),
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitFundRequest() async {
    final amount = double.tryParse(_requestAmountController.text) ?? 0.0;
    final desc = _requestDescController.text.trim();

    if (amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid amount'.translate())));
      return;
    }
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Description required'.translate())),
      );
      return;
    }

    setState(() => _isRequesting = true);
    try {
      final feeRef = FirebaseFirestore.instance
          .collection('cases')
          .doc(widget.case_.id)
          .collection('fees')
          .doc();
      await feeRef.set({
        'type': 'request',
        'status': 'pending',
        'amount': amount,
        'title': desc,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _requestAmountController.clear();
        _requestDescController.clear();
        _isRequestFormVisible = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request sent successfully'.translate())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e'.translate())));
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  Widget _buildFeeManagementForm(
    bool isDark,
    double remaining, {
    bool isLocked = false,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _withdrawAmountController,
                decoration: _inputDecoration(
                  isDark,
                ).copyWith(hintText: 'Amount (EGP)'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        TextField(
          controller: _withdrawDescController,
          decoration: _inputDecoration(
            isDark,
          ).copyWith(hintText: 'Describe the work done...'),
          maxLines: 2,
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.any,
                  );
                  if (result != null) {
                    setState(() => _evidenceFile = result.files.first);
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _evidenceFile != null
                      ? _evidenceFile!.name
                      : 'Upload Evidence (Optional)'.translate(),
                ),
              ),
            ),
            if (_evidenceFile != null)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => setState(() => _evidenceFile = null),
              ),
          ],
        ),
        SizedBox(height: 12.h),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_isWithdrawing || isLocked)
                ? null
                : () => _submitWithdrawal(remaining),
            style: ElevatedButton.styleFrom(
              backgroundColor: isLocked ? Colors.grey : AppColors.legalGold,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: _isWithdrawing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLocked) ...[
                        const Icon(Icons.lock, color: Colors.white, size: 18),
                        SizedBox(width: 8.w),
                      ],
                      Text(
                        'Take Funds'.translate(),
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitWithdrawal(double remaining) async {
    final amount = double.tryParse(_withdrawAmountController.text) ?? 0.0;
    final desc = _withdrawDescController.text.trim();

    if (amount <= 0 || amount > remaining) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid amount'.translate())));
      return;
    }
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Description required'.translate())),
      );
      return;
    }

    setState(() => _isWithdrawing = true);
    try {
      String? evidenceUrl;
      if (_evidenceFile != null) {
        if (kIsWeb) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Evidence upload is currently only supported on mobile'
                      .translate(),
                ),
              ),
            );
          }
          setState(() => _isWithdrawing = false);
          return;
        } else if (_evidenceFile!.path != null) {
          evidenceUrl = await const SupabaseStorageService().uploadMedia(
            file: File(_evidenceFile!.path!),
            folderPath: 'fees_evidence/${widget.case_.id}',
            fileName:
                '${DateTime.now().millisecondsSinceEpoch}_${_evidenceFile!.name}',
          );
        }
      }

      final lawyerId = FirebaseAuth.instance.currentUser?.uid;
      if (lawyerId != null) {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final lawyerRef = FirebaseFirestore.instance
              .collection('lawyers')
              .doc(lawyerId);
          transaction.set(lawyerRef, {
            'balance': FieldValue.increment(amount),
          }, SetOptions(merge: true));

          final txRef = lawyerRef.collection('transactions').doc();
          transaction.set(txRef, {
            'amount': amount,
            'type': 'deposit',
            'description':
                'Funds withdrawn from case ${widget.case_.caseNumber}',
            'isWalletTransaction': true,
            'referenceId': widget.case_.id,
            'createdAt': FieldValue.serverTimestamp(),
          });

          final feeRef = FirebaseFirestore.instance
              .collection('cases')
              .doc(widget.case_.id)
              .collection('fees')
              .doc();
          transaction.set(feeRef, {
            'type': 'withdrawal',
            'amount': amount,
            'title': desc,
            'evidenceUrl': evidenceUrl,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });

        // Trigger notifications to client and lawyer
        // Fetch lawyer name
        String lawyerName = 'Lawyer'.translate();
        try {
          final lawyerDoc = await FirebaseFirestore.instance
              .collection('lawyers')
              .doc(lawyerId)
              .get();
          if (lawyerDoc.exists) {
            lawyerName = lawyerDoc.data()?['name'] ?? lawyerDoc.data()?['fullName'] ?? 'Lawyer'.translate();
          }
        } catch (_) {}

        // Notify Client
        if (widget.case_.clientId.isNotEmpty) {
          NotificationService().createAndSendNotification(
            targetUserId: widget.case_.clientId,
            title: 'Case Funds Withdrawn'.translate(),
            body: '${'Lawyer'.translate()} $lawyerName ${'withdrew'.translate()} $amount ${'EGP from case'.translate()} ${widget.case_.caseNumber}.',
            type: 'transaction',
            referenceId: widget.case_.id,
          ).catchError((e) => debugPrint('Error sending client withdrawal notification: $e'));
        }

        // Notify Lawyer
        NotificationService().createAndSendNotification(
          targetUserId: lawyerId,
          title: 'Withdrawal Successful'.translate(),
          body: '${'You have successfully withdrawn'.translate()} $amount ${'EGP from case'.translate()} ${widget.case_.caseNumber} ${'to your wallet.'.translate()}',
          type: 'transaction',
          referenceId: widget.case_.id,
        ).catchError((e) => debugPrint('Error sending lawyer withdrawal notification: $e'));
      }

      if (!mounted) return;
      setState(() {
        _withdrawAmountController.clear();
        _withdrawDescController.clear();
        _evidenceFile = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Withdrawal successful'.translate())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e'.translate())));
      }
    } finally {
      if (mounted) setState(() => _isWithdrawing = false);
    }
  }

  Widget _buildActivityItem(
    String date,
    String title,
    String amount,
    Color amountColor,
    bool isDark, {
    String? evidenceUrl,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2940) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                    color: isDark ? Colors.white : primaryBlue,
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                ),
                if (evidenceUrl != null) ...[
                  SizedBox(height: 6.h),
                  InkWell(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => Dialog(child: Image.network(evidenceUrl)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.attachment,
                          size: 14.sp,
                          color: AppColors.legalGold,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'View Evidence',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppColors.legalGold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w900,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentDetailRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90.w,
          child: Text(
            label.translate(),
            style: GoogleFonts.cairo(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : primaryBlue,
            ),
          ),
        ),
      ],
    );
  }

  void _previewDocument(String fileUrl) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 16.w),
                  child: Text(
                    'Document Preview'.translate(),
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Image.network(
                    fileUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.insert_drive_file,
                          size: 64.sp,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Preview not available for this file type.\nDocument is successfully uploaded.'
                              .translate(),
                          style: GoogleFonts.cairo(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16.h),
                      ],
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

  Future<void> _downloadFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch download link'.translate())),
        );
      }
    }
  }

  // --- COMMON UI COMPONENTS ---

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h, top: 4.h),
      child: Text(
        text,
        style: GoogleFonts.cairo(
          fontSize: 13.sp,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : primaryBlue,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark) {
    return InputDecoration(
      filled: true,
      fillColor: isDark ? const Color(0xFF1A2940) : const Color(0xFFF8FAFE),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: AppColors.legalGold, width: 1.5),
      ),
    );
  }

  Widget _readOnlyField(bool isDark, String value, {int maxLines = 1}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2940) : const Color(0xFFF3F5F9),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        value,
        style: GoogleFonts.cairo(
          fontSize: 14.sp,
          color: isDark ? Colors.grey.shade300 : Colors.black87,
        ),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _statusBadge(String status) {
    final statusColors = {
      'active': {'bg': 0xFF4CAF50, 'label': 'Active'.translate()},
      'closed': {'bg': 0xFF1976D2, 'label': 'Closed'.translate()},
      'pending': {'bg': 0xFFFF9800, 'label': 'Pending'.translate()},
      'on_hold': {'bg': 0xFFF44336, 'label': 'On Hold'.translate()},
      'pending_payment': {
        'bg': 0xFFFF9800,
        'label': 'Pending Payment'.translate(),
      },
    };

    int bgColor = 0xFF757575;
    String label = status.replaceAll('_', ' ').toUpperCase();

    if (statusColors.containsKey(status.toLowerCase())) {
      final info = statusColors[status.toLowerCase()]!;
      bgColor = (info['bg'] as int?) ?? 0xFF757575;
      label = (info['label'] as String?) ?? label;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Color(bgColor).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
          color: Color(bgColor),
        ),
      ),
    );
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label coming soon...')));
  }
}

class AudioPlayerWidget extends StatefulWidget {
  final String source;
  final bool isRemote;

  const AudioPlayerWidget({
    super.key,
    required this.source,
    this.isRemote = false,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
  }

  Future<void> _setupAudioPlayer() async {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _isPlaying = false;
        });
      }
    });

    if (widget.isRemote) {
      await _audioPlayer.setSourceUrl(widget.source);
    } else {
      await _audioPlayer.setSourceDeviceFile(widget.source);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A364B)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () async {
              if (_isPlaying) {
                await _audioPlayer.pause();
              } else {
                if (widget.isRemote) {
                  await _audioPlayer.play(UrlSource(widget.source));
                } else {
                  await _audioPlayer.play(DeviceFileSource(widget.source));
                }
              }
            },
            child: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: AppColors.legalGold,
              size: 36.sp,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.r),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 12.r),
                trackHeight: 4.h,
              ),
              child: Slider(
                min: 0,
                max: _duration.inMilliseconds.toDouble() > 0
                    ? _duration.inMilliseconds.toDouble()
                    : 1.0,
                value: _position.inMilliseconds.toDouble().clamp(
                  0,
                  _duration.inMilliseconds.toDouble() > 0
                      ? _duration.inMilliseconds.toDouble()
                      : 1.0,
                ),
                activeColor: AppColors.legalGold,
                inactiveColor: Colors.grey.shade400,
                onChanged: (value) async {
                  await _audioPlayer.seek(
                    Duration(milliseconds: value.toInt()),
                  );
                },
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            _formatDuration(
              _position.inMilliseconds > 0 ? _position : _duration,
            ),
            style: GoogleFonts.cairo(
              fontSize: 12.sp,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
