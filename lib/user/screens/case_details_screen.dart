import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mezaan/shared/services/supabase_storage_service.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/models/case_model.dart';
import 'package:mezaan/user/screens/deposit_screen.dart';
import 'package:mezaan/shared/services/notification_service.dart';

// Date formatting helper function
String formatDate(DateTime date, String format) {
  // Simple date formatter since intl is not available
  String result = format;
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

class CaseDetailsScreen extends StatefulWidget {
  final UserCase case_;

  const CaseDetailsScreen({super.key, required this.case_});

  @override
  State<CaseDetailsScreen> createState() => _CaseDetailsScreenState();
}

class _CaseDetailsScreenState extends State<CaseDetailsScreen> {
  late PageController _pageController;
  int _currentTabIndex = 0;
  late bool _isPaymentPending;

  double get _baseRequestedAmount => widget.case_.legalFees;

  double get _calculatedServiceFee => _baseRequestedAmount * 0.20;
  double get _totalAmountDue => _baseRequestedAmount + _calculatedServiceFee;

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final wholeNumber = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    return '$wholeNumber.${parts[1]}';
  }

  String get _paymentMessage => widget.case_.status == 'on_hold'
      ? 'Payment overdue. Please settle the remaining fees to resume the case'
      : 'Please complete the initial payment to unlock full case details';

  String get _initialFee => 'EGP ${_formatCurrency(_baseRequestedAmount)}';
  String get _serviceFee => 'EGP ${_formatCurrency(_calculatedServiceFee)}';
  String get _totalFee => 'EGP ${_formatCurrency(_totalAmountDue)}';

  final Map<String, PlatformFile?> _pickedDocumentFiles = {};
  final Set<String> _expandedDocuments = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _isPaymentPending = widget.case_.status != 'active';
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

    return DefaultTabController(
      length: 5, // Updated from 4 to 5
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20.sp,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Case Details'.translate(),
            style: GoogleFonts.cairo(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          centerTitle: false,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Header Card
              _buildHeaderCard(isDark),

              if (_isPaymentPending)
                _buildPaymentLockedView(isDark)
              else ...[
                // Tab Navigation
                _buildTabBar(isDark),

                // Content area with defined height for PageView
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
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
                      _buildFeesTab(isDark),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cases')
          .doc(widget.case_.id)
          .snapshots(),
      builder: (context, snapshot) {
        final caseData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
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
                  _buildStatusBadge(
                    caseData['status'] as String? ?? widget.case_.status,
                    isDark,
                  ),
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
                    value:
                        caseData['category'] as String? ??
                        widget.case_.category,
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
      },
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
      'Fees'.translate(), // New Fees tab
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

  Widget _buildPaymentLockedView(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A2940) : Colors.white;
    final borderColor = AppColors.legalGold;
    final textColor = isDark ? Colors.grey.shade200 : Colors.grey.shade800;
    final secondaryTextColor = isDark
        ? Colors.grey.shade400
        : Colors.grey.shade600;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 28.h),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: borderColor, width: 1.8),
            boxShadow: [
              BoxShadow(
                // Fixed: withValues to withOpacity
                color: Colors.black.withOpacity(0.08),
                blurRadius: 22,
                offset: Offset(0, 10.h),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 76.w,
                height: 76.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, // Fixed: withValues to withOpacity
                  color: borderColor.withOpacity(0.12),
                  border: Border.all(color: borderColor, width: 1.8),
                ),
                child: Icon(
                  Icons.lock_outline,
                  color: borderColor,
                  size: 40.sp,
                ),
              ),
              SizedBox(height: 22.h),
              Text(
                'Case Created On: ${formatDate(widget.case_.createdDate, 'MMM dd, yyyy')}'
                    .translate(),
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                _paymentMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1.45,
                ),
              ),
              SizedBox(height: 20.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F1826)
                      : const Color(
                          0xFFFDF6E8,
                        ), // Fixed: withValues to withOpacity
                  borderRadius: BorderRadius.circular(
                    16.r,
                  ), // Fixed: withValues to withOpacity
                  border: Border.all(color: borderColor.withOpacity(0.16)),
                ),
                child: Column(
                  children: [
                    _buildPriceRow(
                      'Initial payment',
                      _initialFee,
                      textColor,
                      secondaryTextColor,
                    ),
                    SizedBox(height: 10.h),
                    _buildPriceRow(
                      'Service fee',
                      _serviceFee,
                      textColor,
                      secondaryTextColor,
                    ),
                    SizedBox(height: 10.h),
                    _buildPriceRow(
                      'Total due',
                      _totalFee,
                      textColor,
                      textColor,
                      isTotal: true,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Unlock access to all case details including documents, sessions, updates, and lawyer notes.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        color: secondaryTextColor,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 22.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: borderColor,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  onPressed: () => _showPaymentDialog(context, isDark),
                  child: Text(
                    'Pay to Unlock'.translate(),
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
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

  Future<double> _resolveCurrentBalance() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0.0;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = snapshot.data();
    if (data == null) return 0.0;

    final balanceValue =
        data['balance'] ?? data['walletBalance'] ?? data['wallet_balance'] ?? 0;
    if (balanceValue is num) {
      return balanceValue.toDouble();
    }

    return double.tryParse(balanceValue.toString()) ?? 0.0;
  }

  Future<void> _showPaymentDialog(BuildContext context, bool isDark) async {
    final currentBalance = await _resolveCurrentBalance();
    final borderColor = AppColors.legalGold;
    final surfaceColor = isDark ? const Color(0xFF12203A) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final descriptionColor = isDark
        ? Colors.grey.shade400
        : Colors.grey.shade600;
    final walletBalanceText = 'EGP ${_formatCurrency(currentBalance)}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (BuildContext bottomSheetContext) {
        int selectedOption = 0;
        bool isProcessing = false;

        void showPaymentResultDialog({
          required bool success,
          required String message,
        }) {
          showDialog(
            context: context,
            builder: (dialogContext) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76.w,
                        height: 76.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: success
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFEBEE),
                        ),
                        child: Icon(
                          success
                              ? Icons.check_circle_rounded
                              : Icons.error_outline,
                          size: 42.sp,
                          color: success
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC62828),
                        ),
                      ),
                      SizedBox(height: 18.h),
                      Text(
                        success
                            ? 'Payment Complete'.translate()
                            : 'Insufficient Balance!'.translate(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: success
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC62828),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 14.sp,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 22.h),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: success
                                ? borderColor
                                : const Color(0xFFC62828),
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            if (!success) {
                              Navigator.of(bottomSheetContext).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const DepositScreen(),
                                ),
                              );
                            }
                          },
                          child: Text(
                            success
                                ? 'Continue'.translate()
                                : 'Top Up Now'.translate(),
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 16.h,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 64.w,
                        height: 6.h,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade500.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 18.h),
                    Text(
                      'Confirm Payment'.translate(),
                      style: GoogleFonts.cairo(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      'EGP ${_formatCurrency(_totalAmountDue)} total due'
                          .translate(),
                      style: GoogleFonts.cairo(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: descriptionColor,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0B182F)
                            : const Color(
                                0xFFFDF6E8,
                              ), // Fixed: withValues to withOpacity
                        borderRadius: BorderRadius.circular(
                          16.r,
                        ), // Fixed: withValues to withOpacity
                        border: Border.all(
                          color: borderColor.withOpacity(0.16),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildPriceRow(
                            'Initial payment',
                            _initialFee,
                            titleColor,
                            descriptionColor,
                          ),
                          SizedBox(height: 8.h),
                          _buildPriceRow(
                            'Service fee',
                            _serviceFee,
                            titleColor,
                            descriptionColor,
                          ),
                          SizedBox(height: 8.h),
                          _buildPriceRow(
                            'Total due',
                            _totalFee,
                            titleColor,
                            titleColor,
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      'Wallet balance: $walletBalanceText'.translate(),
                      style: GoogleFonts.cairo(
                        fontSize: 13.sp,
                        color: descriptionColor,
                      ),
                    ),
                    SizedBox(height: 22.h),
                    Text(
                      'Select a payment method'.translate(),
                      style: GoogleFonts.cairo(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Column(
                      children: List.generate(2, (index) {
                        final optionTitle = index == 0
                            ? 'Credit Card'.translate()
                            : 'PayPal'.translate();
                        final optionSubtitle = index == 0
                            ? 'Visa, MasterCard, Amex'.translate()
                            : 'Pay with your PayPal account'.translate();
                        final optionIcon = index == 0
                            ? Icons.credit_card_rounded
                            : Icons.account_balance_wallet;
                        final selected = selectedOption == index;

                        return Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                selectedOption = index;
                              });
                            },
                            borderRadius: BorderRadius.circular(16.r),
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    selected // Fixed: withValues to withOpacity
                                    ? borderColor.withOpacity(0.12)
                                    : (isDark
                                          ? const Color(0xFF0B182F)
                                          : const Color(0xFFF7F2E5)),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: selected
                                      ? borderColor
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 14.h,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40.w,
                                    height: 40.w,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? borderColor
                                          : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    child: Icon(
                                      optionIcon,
                                      size: 20.sp,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          optionTitle,
                                          style: GoogleFonts.cairo(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w700,
                                            color: titleColor,
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          optionSubtitle,
                                          style: GoogleFonts.cairo(
                                            fontSize: 12.sp,
                                            color: descriptionColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Radio<int>(
                                    value: index,
                                    groupValue: selectedOption,
                                    activeColor: borderColor,
                                    onChanged: (value) {
                                      setModalState(() {
                                        selectedOption = value ?? 0;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 8.h),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: borderColor,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        onPressed: isProcessing
                            ? null
                            : () async {
                                setModalState(() {
                                  isProcessing = true;
                                });
                                final bottomSheetNavigator = Navigator.of(
                                  bottomSheetContext,
                                );
                                await Future.delayed(
                                  const Duration(milliseconds: 1500),
                                );
                                if (!mounted) return;
                                setModalState(() {
                                  isProcessing = false;
                                });

                                final uid =
                                    FirebaseAuth.instance.currentUser?.uid;
                                if (uid == null) {
                                  showPaymentResultDialog(
                                    success: false,
                                    message:
                                        'Unable to resolve user account. Please sign in again.'
                                            .translate(),
                                  );
                                  return;
                                }

                                if (currentBalance < _totalAmountDue) {
                                  showPaymentResultDialog(
                                    success: false,
                                    message:
                                        'You only have $walletBalanceText. Please top up your wallet.'
                                            .translate(),
                                  );
                                  return;
                                }

                                final userDocRef = FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid);
                                final caseDocRef = FirebaseFirestore.instance
                                    .collection('cases')
                                    .doc(widget.case_.id);
                                try {
                                  await FirebaseFirestore.instance
                                      .runTransaction((transaction) async {
                                        final snapshot = await transaction.get(
                                          userDocRef,
                                        );
                                        final data = snapshot.data();
                                        final balanceValue = data == null
                                            ? 0
                                            : data['balance'] ??
                                                  data['walletBalance'] ??
                                                  data['wallet_balance'] ??
                                                  0;
                                        final currentStoredBalance =
                                            balanceValue is num
                                            ? balanceValue.toDouble()
                                            : double.tryParse(
                                                    balanceValue.toString(),
                                                  ) ??
                                                  0.0;

                                        if (currentStoredBalance <
                                            _totalAmountDue) {
                                          throw Exception(
                                            'insufficient_balance',
                                          );
                                        }

                                        transaction.update(userDocRef, {
                                          'balance':
                                              currentStoredBalance -
                                              _totalAmountDue,
                                        });
                                        transaction.update(caseDocRef, {
                                          'status': 'active',
                                        });
                                        final feeDocRef = caseDocRef
                                            .collection('fees')
                                            .doc();
                                        transaction.set(feeDocRef, {
                                          'type': 'deposit',
                                          'amount': _baseRequestedAmount,
                                          'title': 'Initial Payment',
                                          'createdAt':
                                              FieldValue.serverTimestamp(),
                                        });
                                      });
                                } catch (e) {
                                  if (e is Exception &&
                                      e.toString().contains(
                                        'insufficient_balance',
                                      )) {
                                    showPaymentResultDialog(
                                      success: false,
                                      message:
                                          'You only have $walletBalanceText. Please top up your wallet.'
                                              .translate(),
                                    );
                                  } else {
                                    showPaymentResultDialog(
                                      success: false,
                                      message:
                                          'Unable to process payment. Please try again later.'
                                              .translate(),
                                    );
                                  }
                                  return;
                                }

                                bottomSheetNavigator.pop();
                                setState(() {
                                  _isPaymentPending = false;
                                });

                                // Trigger notifications
                                final initialPayAmount = _baseRequestedAmount;
                                final caseData = widget.case_;

                                // Notify Client
                                if (caseData.clientId.isNotEmpty) {
                                  NotificationService().createAndSendNotification(
                                    targetUserId: caseData.clientId,
                                    title: 'Initial Payment Processed'.translate(),
                                    body: '${'You have successfully paid initial fees of'.translate()} $initialPayAmount ${'EGP for case'.translate()} ${caseData.caseNumber}.',
                                    type: 'transaction',
                                    referenceId: caseData.id,
                                  ).catchError((e) => debugPrint('Error sending initial payment client notification: $e'));
                                }

                                // Notify Lawyer
                                if (caseData.lawyerId.isNotEmpty) {
                                  NotificationService().createAndSendNotification(
                                    targetUserId: caseData.lawyerId,
                                    title: 'Case Initial Payment Paid'.translate(),
                                    body: '${'Client'.translate()} ${caseData.clientName} ${'has paid initial fees of'.translate()} $initialPayAmount ${'EGP for case'.translate()} ${caseData.caseNumber}.',
                                    type: 'transaction',
                                    referenceId: caseData.id,
                                  ).catchError((e) => debugPrint('Error sending initial payment lawyer notification: $e'));
                                }

                                // --- Create chat between user and lawyer after payment ---
                                final chatId = caseData
                                    .id; // Use case ID as chat ID for uniqueness
                                final userId = caseData.clientId;
                                final userName = caseData.clientName;
                                final userAvatar =
                                    caseData.clientNationalId ?? "";
                                final lawyerId = caseData.lawyerId;
                                final lawyerName = caseData.lawyerName;
                                final lawyerAvatar =
                                    caseData.lawyerAvatar ?? "";

                                final chatDoc = FirebaseFirestore.instance
                                    .collection('chats')
                                    .doc(chatId);
                                final userConvoDoc = FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userId)
                                    .collection('conversations')
                                    .doc(chatId);
                                final lawyerConvoDoc = FirebaseFirestore
                                    .instance
                                    .collection('lawyers')
                                    .doc(lawyerId)
                                    .collection('conversations')
                                    .doc(chatId);

                                // Check if chat already exists, if not, create it
                                chatDoc.get().then((doc) async {
                                  if (!doc.exists) {
                                    await chatDoc.set({
                                      'caseId': chatId,
                                      'userId': userId,
                                      'userName': userName,
                                      'userAvatar': userAvatar,
                                      'clientId': userId,
                                      'clientName': userName,
                                      'clientProfileImage': userAvatar,
                                      'lawyerId': lawyerId,
                                      'lawyerName': lawyerName,
                                      'lawyerAvatar': lawyerAvatar,
                                      'createdAt': FieldValue.serverTimestamp(),
                                      'lastMessage': '',
                                      'lastMessageTime':
                                          FieldValue.serverTimestamp(),
                                    });
                                  }
                                  // Add conversation reference for user
                                  await userConvoDoc.set({
                                    'chatId': chatId,
                                    'lawyerId': lawyerId,
                                    'lawyerName': lawyerName,
                                    'lawyerAvatar': lawyerAvatar,
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'lastMessage': '',
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));
                                  // Add conversation reference for lawyer
                                  await lawyerConvoDoc.set({
                                    'chatId': chatId,
                                    'userId': userId,
                                    'userName': userName,
                                    'userAvatar': userAvatar,
                                    'clientId': userId,
                                    'clientName': userName,
                                    'clientProfileImage': userAvatar,
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'lastMessage': '',
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));
                                });

                                showPaymentResultDialog(
                                  success: true,
                                  message:
                                      'Your payment was processed successfully, and case details are now unlocked.'
                                          .translate(),
                                );
                              },
                        child: isProcessing
                            ? SizedBox(
                                height: 20.h,
                                width: 20.h,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.2,
                                ),
                              )
                            : Text(
                                'Confirm Payment'.translate(),
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPriceRow(
    String label,
    String value,
    Color labelColor,
    Color valueColor, {
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: isTotal ? 13.sp : 12.sp,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: labelColor,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: isTotal ? 13.sp : 12.sp,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _showFeePaymentDialog(bool isDark) {
    final amountController = TextEditingController();
    bool isProcessing = false;
    bool isSuccess = false;
    double enteredAmount = 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          double serviceFee = enteredAmount * 0.20;
          double totalDue = enteredAmount + serviceFee;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            title: Text(
              'Pay Fees'.translate(),
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSuccess)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 70.sp,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Payment Successful!'.translate(),
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isProcessing)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(color: Color(0xFF002147)),
                  )
                else ...[
                  Text(
                    'Enter the amount you wish to pay'.translate(),
                    style: GoogleFonts.cairo(),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.cairo(),
                    onChanged: (val) {
                      setDialogState(() {
                        enteredAmount = double.tryParse(val) ?? 0.0;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: '0.00',
                      suffixText: 'EGP',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                  if (enteredAmount > 0) ...[
                    SizedBox(height: 16.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Base Amount:'.translate(),
                          style: GoogleFonts.cairo(fontSize: 13.sp),
                        ),
                        Text(
                          '${_formatCurrency(enteredAmount)} EGP',
                          style: GoogleFonts.cairo(fontSize: 13.sp),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Service Fee (20%):'.translate(),
                          style: GoogleFonts.cairo(fontSize: 13.sp),
                        ),
                        Text(
                          '${_formatCurrency(serviceFee)} EGP',
                          style: GoogleFonts.cairo(fontSize: 13.sp),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: const Divider(),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Due:'.translate(),
                          style: GoogleFonts.cairo(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_formatCurrency(totalDue)} EGP',
                          style: GoogleFonts.cairo(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navyBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
            actions: (isProcessing || isSuccess)
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel'.translate(),
                        style: GoogleFonts.cairo(color: Colors.grey),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: enteredAmount <= 0
                          ? null
                          : () async {
                              setDialogState(() => isProcessing = true);

                              final uid =
                                  FirebaseAuth.instance.currentUser?.uid;
                              if (uid == null) return;

                              try {
                                await FirebaseFirestore.instance.runTransaction(
                                  (transaction) async {
                                    final userRef = FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(uid);
                                    final userDoc = await transaction.get(
                                      userRef,
                                    );

                                    double currentBalance = 0.0;
                                    if (userDoc.exists) {
                                      final data = userDoc.data()!;
                                      final balanceValue =
                                          data['balance'] ??
                                          data['walletBalance'] ??
                                          data['wallet_balance'] ??
                                          0;
                                      currentBalance = balanceValue is num
                                          ? balanceValue.toDouble()
                                          : double.tryParse(
                                                  balanceValue.toString(),
                                                ) ??
                                                0.0;
                                    }

                                    if (currentBalance < totalDue) {
                                      throw Exception('insufficient_balance');
                                    }

                                    transaction.update(userRef, {
                                      'balance': currentBalance - totalDue,
                                    });

                                    final feeDocRef = FirebaseFirestore.instance
                                        .collection('cases')
                                        .doc(widget.case_.id)
                                        .collection('fees')
                                        .doc();
                                    transaction.set(feeDocRef, {
                                      'type': 'deposit',
                                      'amount': enteredAmount,
                                      'title': 'Account Funded',
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });
                                  },
                                );

                                if (!mounted) return;
                                setDialogState(() {
                                  isProcessing = false;
                                  isSuccess = true;
                                });

                                // Trigger notifications
                                final caseData = widget.case_;
                                
                                // Notify Client
                                if (caseData.clientId.isNotEmpty) {
                                  NotificationService().createAndSendNotification(
                                    targetUserId: caseData.clientId,
                                    title: 'Case Funded'.translate(),
                                    body: '${'You have successfully funded'.translate()} $enteredAmount ${'EGP to case'.translate()} ${caseData.caseNumber}.',
                                    type: 'transaction',
                                    referenceId: caseData.id,
                                  ).catchError((e) => debugPrint('Error sending additional funding client notification: $e'));
                                }
                                
                                // Notify Lawyer
                                if (caseData.lawyerId.isNotEmpty) {
                                  NotificationService().createAndSendNotification(
                                    targetUserId: caseData.lawyerId,
                                    title: 'Case Funded'.translate(),
                                    body: '${'Client'.translate()} ${caseData.clientName} ${'has funded'.translate()} $enteredAmount ${'EGP to case'.translate()} ${caseData.caseNumber}.',
                                    type: 'transaction',
                                    referenceId: caseData.id,
                                  ).catchError((e) => debugPrint('Error sending additional funding lawyer notification: $e'));
                                }

                                await Future.delayed(
                                  const Duration(milliseconds: 1500),
                                );
                                if (!mounted) return;
                                Navigator.pop(context);
                              } catch (e) {
                                setDialogState(() => isProcessing = false);
                                if (e.toString().contains(
                                  'insufficient_balance',
                                )) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Insufficient wallet balance'
                                            .translate(),
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'.translate()),
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF002147),
                      ),
                      child: Text(
                        'Confirm'.translate(),
                        style: GoogleFonts.cairo(color: Colors.white),
                      ),
                    ),
                  ],
          );
        },
      ),
    );
  }

  void _showPayRequestDialog(Map<String, dynamic> request, bool isDark) {
    bool isProcessing = false;
    bool isSuccess = false;
    double baseAmount = (request['amount'] as num?)?.toDouble() ?? 0.0;
    double serviceFee = baseAmount * 0.20;
    double totalDue = baseAmount + serviceFee;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            title: Text(
              'Pay Requested Funds'.translate(),
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSuccess)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 70.sp,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Payment Successful!'.translate(),
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isProcessing)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(color: Color(0xFF002147)),
                  )
                else ...[
                  Text(
                    request['title'] ?? 'Requested by Lawyer',
                    style: GoogleFonts.cairo(fontSize: 14.sp),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Requested Amount:'.translate(),
                        style: GoogleFonts.cairo(fontSize: 13.sp),
                      ),
                      Text(
                        '${_formatCurrency(baseAmount)} EGP',
                        style: GoogleFonts.cairo(fontSize: 13.sp),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Service Fee (20%):'.translate(),
                        style: GoogleFonts.cairo(fontSize: 13.sp),
                      ),
                      Text(
                        '${_formatCurrency(serviceFee)} EGP',
                        style: GoogleFonts.cairo(fontSize: 13.sp),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: const Divider(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Due:'.translate(),
                        style: GoogleFonts.cairo(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_formatCurrency(totalDue)} EGP',
                        style: GoogleFonts.cairo(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navyBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: (isProcessing || isSuccess)
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel'.translate(),
                        style: GoogleFonts.cairo(color: Colors.grey),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        setDialogState(() => isProcessing = true);

                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid == null) return;

                        try {
                          await FirebaseFirestore.instance.runTransaction((
                            transaction,
                          ) async {
                            final userRef = FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid);
                            final userDoc = await transaction.get(userRef);

                            double currentBalance = 0.0;
                            if (userDoc.exists) {
                              final data = userDoc.data()!;
                              final balanceValue =
                                  data['balance'] ??
                                  data['walletBalance'] ??
                                  data['wallet_balance'] ??
                                  0;
                              currentBalance = balanceValue is num
                                  ? balanceValue.toDouble()
                                  : double.tryParse(balanceValue.toString()) ??
                                        0.0;
                            }

                            if (currentBalance < totalDue) {
                              throw Exception('insufficient_balance');
                            }

                            transaction.update(userRef, {
                              'balance': currentBalance - totalDue,
                            });

                            final feeDocRef = FirebaseFirestore.instance
                                .collection('cases')
                                .doc(widget.case_.id)
                                .collection('fees')
                                .doc(request['id']);
                            transaction.update(feeDocRef, {
                              'status': 'paid',
                              'paidAt': FieldValue.serverTimestamp(),
                            });
                          });

                          if (!mounted) return;
                          setDialogState(() {
                            isProcessing = false;
                            isSuccess = true;
                          });
                          await Future.delayed(
                            const Duration(milliseconds: 1500),
                          );
                          if (!mounted) return;
                          Navigator.pop(context);
                        } catch (e) {
                          setDialogState(() => isProcessing = false);
                          if (e.toString().contains('insufficient_balance')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Insufficient wallet balance'.translate(),
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'.translate())),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF002147),
                      ),
                      child: Text(
                        'Pay Now'.translate(),
                        style: GoogleFonts.cairo(color: Colors.white),
                      ),
                    ),
                  ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A2940) : Colors.white;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cases')
          .doc(widget.case_.id)
          .snapshots(),
      builder: (context, caseSnapshot) {
        final caseData =
            caseSnapshot.data?.data() as Map<String, dynamic>? ?? {};
        final serviceType =
            caseData['serviceType'] as String? ?? 'non_litigation';
        final officialCaseNumber = caseData['caseNumber'] as String?;
        final caseYear = caseData['caseYear'] as String?;
        final lawyerId =
            caseData['lawyerId'] as String? ?? caseData['lawyer_id'] as String?;

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
                  color: isDark
                      ? const Color(0xFF304563)
                      : const Color(0xFFDCE6F5),
                ),
              ),
              child: lawyerId != null && lawyerId.isNotEmpty
                  ? FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('lawyers')
                          .doc(lawyerId)
                          .get(),
                      builder: (context, lawyerSnapshot) {
                        String? photoUrl;
                        double rating = 0.0;
                        if (lawyerSnapshot.hasData &&
                            lawyerSnapshot.data!.exists) {
                          final data =
                              lawyerSnapshot.data!.data()
                                  as Map<String, dynamic>?;
                          photoUrl =
                              data?['profile_photo'] ??
                              data?['profileImage'] ??
                              data?['profilePhotoUrl'] ??
                              data?['photoUrl'] ??
                              data?['avatar'] ??
                              data?['image'];
                          if (photoUrl != null && photoUrl.trim().isEmpty) {
                            photoUrl = null;
                          }

                          final ratingVal =
                              data?['rating'] ??
                              data?['averageRating'] ??
                              data?['rate'];
                          rating = ratingVal is num
                              ? ratingVal.toDouble()
                              : double.tryParse(ratingVal?.toString() ?? '0') ??
                                    0.0;
                        }
                        return _buildLawyerInfoRow(photoUrl, rating, isDark);
                      },
                    )
                  : _buildLawyerInfoRow(null, 0.0, isDark),
            ),
            SizedBox(height: 16.h),

            // Case Information
            Text(
              'Case Information'.translate(),
              style: GoogleFonts.cairo(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF304563)
                      : const Color(0xFFDCE6F5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    'Service Type'.translate(),
                    serviceType == 'litigation'
                        ? 'Litigation'.translate()
                        : 'Non-Litigation'.translate(),
                    isDark,
                  ),
                  if (officialCaseNumber != null &&
                      officialCaseNumber.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: const Divider(),
                    ),
                    _buildInfoRow(
                      'Official Case No'.translate(),
                      officialCaseNumber,
                      isDark,
                    ),
                  ],
                  if (caseYear != null && caseYear.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: const Divider(),
                    ),
                    _buildInfoRow('Case Year'.translate(), caseYear, isDark),
                  ],
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCardStream(
                    icon: Icons.description_outlined,
                    label: 'Documents'.translate(),
                    collectionPath: 'documentations',
                    isDark: isDark,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildStatCardStream(
                    icon: Icons.calendar_today_outlined,
                    label: 'Sessions'.translate(),
                    collectionPath: 'sessions',
                    isDark: isDark,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildStatCardStream(
                    icon: Icons.update_outlined,
                    label: 'Updates'.translate(),
                    collectionPath: 'updates',
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),

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
      },
    );
  }

  Widget _buildLawyerInfoRow(String? photoUrl, double rating, bool isDark) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24.r,
          backgroundColor: AppColors.legalGold.withOpacity(0.2),
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? Text(
                  widget.case_.lawyerName.isNotEmpty
                      ? widget.case_.lawyerName[0].toUpperCase()
                      : 'L',
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
                widget.case_.lawyerName,
                style: GoogleFonts.cairo(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.navyBlue,
                ),
              ),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Text(
                    'Lawyer'.translate(),
                    style: GoogleFonts.cairo(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade600,
                    ),
                  ),
                  if (rating > 0) ...[
                    SizedBox(width: 8.w),
                    Icon(Icons.star_rounded, color: Colors.amber, size: 14.sp),
                    SizedBox(width: 2.w),
                    Text(
                      rating.toStringAsFixed(1),
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 13.sp,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.navyBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCardStream({
    required IconData icon,
    required String label,
    required String collectionPath,
    required bool isDark,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cases')
          .doc(widget.case_.id)
          .collection(collectionPath)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        final value = snapshot.connectionState == ConnectionState.waiting
            ? '...'
            : count.toString();

        return _buildStatCard(
          icon: icon,
          label: label,
          value: value,
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildFeesTab(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A2940) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    String formatVal(double val) => '${_formatCurrency(val)} EGP';

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
        double totalFunded = 0.0;
        double spentByLawyer = 0.0;
        bool hasInitialPayment = false;
        final List<Map<String, dynamic>> pendingRequests = [];

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final type = data['type'] ?? 'deposit';
          final status = data['status'];
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          if (type == 'deposit' || (type == 'request' && status == 'paid')) {
            totalFunded += amount;
            if (data['title'] == 'Initial Payment') hasInitialPayment = true;
          } else if (type == 'withdrawal') {
            spentByLawyer += amount;
          } else if (type == 'request' && status == 'pending') {
            pendingRequests.add({'id': doc.id, ...data});
          }
        }

        if (!hasInitialPayment &&
            (widget.case_.status == 'active' ||
                widget.case_.status == 'closed')) {
          totalFunded += widget.case_.legalFees;
        }

        double balanceAvailable = totalFunded - spentByLawyer;

        return ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            Card(
              elevation: 2,
              color: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSummaryItem(
                      'Total Funded'.translate(),
                      formatVal(totalFunded),
                      const Color(0xFF002147),
                    ),
                    _buildSummaryItem(
                      'Spent by Lawyer'.translate(),
                      formatVal(spentByLawyer),
                      Colors.red,
                    ),
                    _buildSummaryItem(
                      'Balance Available'.translate(),
                      formatVal(balanceAvailable),
                      const Color(0xFFC6A243),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showFeePaymentDialog(isDark),
                icon: Icon(Icons.payment, color: Colors.white, size: 20.sp),
                label: Text(
                  'Pay Outstanding Fees'.translate(),
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002147),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            if (pendingRequests.isNotEmpty) ...[
              SizedBox(height: 24.h),
              Text(
                'Additional Fees Requested'.translate(),
                style: GoogleFonts.cairo(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              SizedBox(height: 12.h),
              ...pendingRequests.map((req) {
                final reqAmount = (req['amount'] as num?)?.toDouble() ?? 0.0;
                final reqTitle = req['title'] ?? 'Requested by Lawyer';
                return Card(
                  color: isDark
                      ? const Color(0xFF24344C)
                      : const Color(0xFFFFF8E1),
                  elevation: 0,
                  margin: EdgeInsets.only(bottom: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    side: BorderSide(
                      color: AppColors.legalGold.withOpacity(0.5),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reqTitle,
                                style: GoogleFonts.cairo(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                '${_formatCurrency(reqAmount)} EGP',
                                style: GoogleFonts.cairo(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.legalGold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _showPayRequestDialog(req, isDark),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.legalGold,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          child: Text(
                            'Pay'.translate(),
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            SizedBox(height: 24.h),
            Text(
              'Financial Activity'.translate(),
              style: GoogleFonts.cairo(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: 12.h),
            if (docs.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.h),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 80.sp,
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade300,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        "No financial activity yet",
                        style: GoogleFonts.cairo(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey.shade500 : Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        "Start funding your case to see details here.",
                        style: GoogleFonts.cairo(
                          fontSize: 12.sp,
                          color: isDark
                              ? Colors.grey.shade600
                              : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...docs.map((docSnap) {
                final data = docSnap.data() as Map<String, dynamic>;
                final isWithdrawal = data['type'] == 'withdrawal';
                final isRequest = data['type'] == 'request';
                final status = data['status'];
                final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                final dateStr = data['createdAt'] != null
                    ? formatDate(
                        (data['createdAt'] as Timestamp).toDate(),
                        'dd MMM yyyy',
                      )
                    : 'Pending';

                String title = data['title'] ?? 'Transaction';
                String amountStr =
                    '${isWithdrawal ? '-' : '+'} ${_formatCurrency(amount)} EGP';
                Color amtColor = isWithdrawal ? Colors.red : Colors.green;
                IconData listIcon = isWithdrawal
                    ? Icons.remove_circle_outline
                    : Icons.add_circle_outline;

                if (isRequest) {
                  if (status == 'pending') {
                    title = 'Requested: $title';
                    amountStr = '${_formatCurrency(amount)} EGP';
                    amtColor = Colors.orange;
                    listIcon = Icons.hourglass_empty;
                  } else {
                    title = 'Paid Request: $title';
                    listIcon = Icons.check_circle_outline;
                  }
                }

                return _buildActivityItem(
                  dateStr,
                  title,
                  amountStr,
                  amtColor,
                  isDark,
                  icon: listIcon,
                  evidenceUrl: data['evidenceUrl'],
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.grey),
        ),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(
    String date,
    String title,
    String amount,
    Color amountColor,
    bool isDark, {
    IconData? icon,
    String? evidenceUrl,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12.w,
              height: 12.h,
              decoration: BoxDecoration(
                color: icon != null
                    ? AppColors.legalGold
                    : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(6.r),
              ),
            ),
            Container(
              width: 2.w,
              height: 35.h,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
          ],
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 14.sp, color: AppColors.navyBlue),
                        SizedBox(width: 6.w),
                      ],
                      Text(
                        title.translate(),
                        style: GoogleFonts.cairo(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    amount,
                    style: GoogleFonts.cairo(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w900,
                      color: amountColor,
                    ),
                  ),
                ],
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
              if (evidenceUrl != null) ...[
                SizedBox(height: 6.h),
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(child: Image.network(evidenceUrl)),
                    );
                  },
                  child: Row(
                    children: [
                      Icon(
                        Icons.attachment,
                        size: 14.sp,
                        color: AppColors.legalGold,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'View Evidence'.translate(),
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

  Future<void> _uploadOrChangeDocument(String docId, String docName) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.path != null) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Uploading "$docName"...'),
              duration: const Duration(seconds: 1),
            ),
          );

          final storageService = const SupabaseStorageService();
          final fileUrl = await storageService.uploadMedia(
            file: File(file.path!),
            folderPath: 'legal_documents/${widget.case_.id}',
            fileName: '${DateTime.now().millisecondsSinceEpoch}_${file.name}',
          );

          await FirebaseFirestore.instance
              .collection('cases')
              .doc(widget.case_.id)
              .collection('documentations')
              .doc(docId)
              .update({
                'isSubmitted': true,
                'submittedDate': FieldValue.serverTimestamp(),
                'fileUrl': fileUrl,
              });

          setState(() {
            _expandedDocuments.remove(docId);
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Document "$docName" uploaded successfully!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error uploading document: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
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
              color: isDark ? Colors.white : AppColors.navyBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsTab(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
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
          return Center(child: Text('Error loading documents'.translate()));
        }

        final docs = snapshot.data?.docs ?? [];
        final completedCount = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isSubmitted'] == true;
        }).length;
        final completionPercentage = docs.isEmpty
            ? 0
            : ((completedCount / docs.length) * 100).round();

        return ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            if (docs.isEmpty) ...[
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.h),
                  child: Column(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 48.sp,
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade300,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'No documents required'.translate(),
                        style: GoogleFonts.cairo(
                          fontSize: 14.sp,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
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
                    '$completionPercentage%',
                    style: GoogleFonts.cairo(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.legalGold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              ...docs.map((docSnap) {
                final data = docSnap.data() as Map<String, dynamic>;
                final docId = docSnap.id;
                final name = data['name'] ?? 'Untitled';
                final description = data['description'] ?? '';
                final isSubmitted = data['isSubmitted'] == true;
                final fileUrl = data['fileUrl'];
                final submittedDate = data['submittedDate'] != null
                    ? (data['submittedDate'] as Timestamp).toDate()
                    : null;
                final createdAt = data['createdAt'] != null
                    ? (data['createdAt'] as Timestamp).toDate()
                    : null;

                return Container(
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A2940) : Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isSubmitted ? Colors.green : Colors.grey.shade300,
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
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
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
                                createdAt != null
                                    ? formatDate(
                                        createdAt,
                                        'MMM dd, yyyy - hh:mm a',
                                      )
                                    : 'N/A',
                                isDark,
                              ),
                              SizedBox(height: 8.h),
                              _buildDocumentDetailRow(
                                'Uploaded:',
                                submittedDate != null
                                    ? formatDate(
                                        submittedDate,
                                        'MMM dd, yyyy - hh:mm a',
                                      )
                                    : 'Pending',
                                isDark,
                              ),
                              SizedBox(height: 16.h),
                              if (isSubmitted) ...[
                                Row(
                                  children: [
                                    if (fileUrl != null) ...[
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _previewDocument(fileUrl),
                                          icon: const Icon(Icons.visibility),
                                          label: Text('Preview'.translate()),
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                    ],
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _uploadOrChangeDocument(
                                              docId,
                                              name,
                                            ),
                                        icon: const Icon(
                                          Icons.upload_file,
                                          color: Colors.white,
                                        ),
                                        label: Text(
                                          'Change'.translate(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.navyBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _uploadOrChangeDocument(docId, name),
                                    icon: const Icon(
                                      Icons.upload_file,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      'Upload Document'.translate(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.navyBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }),
              SizedBox(height: 16.h),
            ],
          ],
        );
      },
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
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade600,
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
                    color: isDark
                        ? const Color(0xFF304563)
                        : const Color(0xFFDCE6F5),
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
                    if (session.location != null &&
                        session.location!.isNotEmpty) ...[
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
                          color: isDark
                              ? Colors.grey.shade900
                              : Colors.grey.shade100,
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
                          // Fixed: withValues to withOpacity
                          color: Colors.green.withOpacity(
                            0.1,
                          ), // Fixed: withValues to withOpacity
                          borderRadius: BorderRadius.circular(
                            8.r,
                          ), // Fixed: withValues to withOpacity
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
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
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade600,
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
                    color: isDark
                        ? const Color(0xFF304563)
                        : const Color(0xFFDCE6F5),
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
                                .withOpacity(
                                  0.15,
                                ), // Fixed: withValues to withOpacity
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
                                formatDate(
                                  update.date,
                                  'MMM dd, yyyy - hh:mm a',
                                ),
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
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
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
      'pending_payment': {
        'bg': 0xFFFF9800,
        'label': 'Pending Payment'.translate(),
      },
    };

    int bgColor = 0xFF757575;
    String label = status.replaceAll('_', ' ');

    if (statusColors.containsKey(status)) {
      final info = statusColors[status]!;
      bgColor = (info['bg'] as int?) ?? 0xFF757575;
      label = (info['label'] as String?) ?? label;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Color(
          bgColor,
        ).withOpacity(0.15), // Fixed: withValues to withOpacity
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

    int bgColor = 0xFF757575;
    String label = status;

    if (statusMap.containsKey(status)) {
      final info = statusMap[status]!;
      bgColor = (info['bg'] as int?) ?? 0xFF757575;
      label = (info['label'] as String?) ?? status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Color(
          bgColor,
        ).withOpacity(0.15), // Fixed: withValues to withOpacity
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
        return {
          'color': 0xFF2196F3,
          'icon': Icons.assignment_turned_in_outlined,
        };
      case 'process':
        return {'color': 0xFFFF9800, 'icon': Icons.trending_up_outlined};
      case 'result':
        return {'color': 0xFF4CAF50, 'icon': Icons.check_circle_outline};
      default:
        return {'color': 0xFF9C27B0, 'icon': Icons.info_outline};
    }
  }
}
