import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/models/case_model.dart';
import 'package:mezaan/user/screens/deposit_screen.dart';

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
  late bool _isPaymentPending;

  double get _totalAmountDue => widget.case_.status == 'on_hold' ? 500.0 : 300.0;

  String get _paymentMessage => widget.case_.status == 'on_hold'
      ? 'Payment overdue. Please settle the remaining fees to resume the case'
      : 'Please complete the initial payment to unlock full case details';

  String get _initialFee => widget.case_.status == 'on_hold' ? 'SAR 450.00' : 'SAR 250.00';
  String get _serviceFee => 'SAR 50.00';
  String get _totalFee => 'SAR ${_totalAmountDue.toStringAsFixed(2)}';

  late final List<RequiredDocument> _documents;
  final Map<String, PlatformFile?> _pickedDocumentFiles = {};
  final Set<String> _expandedDocuments = {};
  late TextEditingController _notesController;
  final List<String> _notesList = [];
  double _totalFees = 0.0;
  final double _withdrawnAmount = 0.0;
  double _remainingAmount = 0.0;
  final List<Map<String, dynamic>> _feeTransactions = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _notesController = TextEditingController();
    _isPaymentPending = widget.case_.status != 'active';
    _documents = widget.case_.requiredDocuments
        .map((doc) => RequiredDocument(
              id: doc.id,
              name: doc.name,
              description: doc.description,
              isSubmitted: doc.isSubmitted,
              submittedDate: doc.submittedDate,
            ))
        .toList();
    for (final document in _documents) {
      _pickedDocumentFiles[document.id] = null;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _notesController.dispose();
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

  Widget _buildPaymentLockedView(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A2940) : Colors.white;
    final borderColor = AppColors.legalGold;
    final textColor = isDark ? Colors.grey.shade200 : Colors.grey.shade800;
    final secondaryTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

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
              BoxShadow( // Fixed: withValues to withOpacity
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
                  color: isDark ? const Color(0xFF0F1826) : const Color(0xFFFDF6E8), // Fixed: withValues to withOpacity
                  borderRadius: BorderRadius.circular(16.r), // Fixed: withValues to withOpacity
                  border: Border.all(color: borderColor.withOpacity(0.16)),
                ),
                child: Column(
                  children: [
                    _buildPriceRow('Initial payment', _initialFee, textColor, secondaryTextColor),
                    SizedBox(height: 10.h),
                    _buildPriceRow('Service fee', _serviceFee, textColor, secondaryTextColor),
                    SizedBox(height: 10.h),
                    _buildPriceRow('Total due', _totalFee, textColor, textColor, isTotal: true),
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

    final snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snapshot.data();
    if (data == null) return 0.0;

    final balanceValue = data['balance'] ?? data['walletBalance'] ?? data['wallet_balance'] ?? 0;
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
    final descriptionColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final walletBalanceText = 'SAR ${currentBalance.toStringAsFixed(2)}';

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

        void showPaymentResultDialog({required bool success, required String message}) {
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
                          color: success ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                        ),
                        child: Icon(
                          success ? Icons.check_circle_rounded : Icons.error_outline,
                          size: 42.sp,
                          color: success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                        ),
                      ),
                      SizedBox(height: 18.h),
                      Text(
                        success ? 'Payment Complete'.translate() : 'Insufficient Balance!'.translate(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
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
                            backgroundColor: success ? borderColor : const Color(0xFFC62828),
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
                            success ? 'Continue'.translate() : 'Top Up Now'.translate(),
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
                      'SAR ${_totalAmountDue.toStringAsFixed(2)} total due'.translate(),
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
                        color: isDark ? const Color(0xFF0B182F) : const Color(0xFFFDF6E8), // Fixed: withValues to withOpacity
                        borderRadius: BorderRadius.circular(16.r), // Fixed: withValues to withOpacity
                        border: Border.all(color: borderColor.withOpacity(0.16)),
                      ),
                      child: Column(
                        children: [
                          _buildPriceRow('Initial payment', _initialFee, titleColor, descriptionColor),
                          SizedBox(height: 8.h),
                          _buildPriceRow('Service fee', _serviceFee, titleColor, descriptionColor),
                          SizedBox(height: 8.h),
                          _buildPriceRow('Total due', _totalFee, titleColor, titleColor, isTotal: true),
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
                      children: List.generate(
                        2,
                        (index) {
                          final optionTitle = index == 0 ? 'Credit Card'.translate() : 'PayPal'.translate();
                          final optionSubtitle = index == 0 ? 'Visa, MasterCard, Amex'.translate() : 'Pay with your PayPal account'.translate();
                          final optionIcon = index == 0 ? Icons.credit_card_rounded : Icons.account_balance_wallet;
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
                                  color: selected // Fixed: withValues to withOpacity
                                      ? borderColor.withOpacity(0.12)
                                      : (isDark ? const Color(0xFF0B182F) : const Color(0xFFF7F2E5)),
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: selected ? borderColor : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40.w,
                                      height: 40.w,
                                      decoration: BoxDecoration(
                                        color: selected ? borderColor : Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(12.r),
                                      ),
                                      child: Icon(optionIcon, size: 20.sp, color: Colors.white),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
                        },
                      ),
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
                                final bottomSheetNavigator = Navigator.of(bottomSheetContext);
                                await Future.delayed(const Duration(milliseconds: 1500));
                                if (!mounted) return;
                                setModalState(() {
                                  isProcessing = false;
                                });

                                final uid = FirebaseAuth.instance.currentUser?.uid;
                                if (uid == null) {
                                  showPaymentResultDialog(
                                    success: false,
                                    message: 'Unable to resolve user account. Please sign in again.'.translate(),
                                  );
                                  return;
                                }

                                if (currentBalance < _totalAmountDue) {
                                  showPaymentResultDialog(
                                    success: false,
                                    message:
                                        'You only have $walletBalanceText. Please top up your wallet.'.translate(),
                                  );
                                  return;
                                }

                                final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
                                try {
                                  await FirebaseFirestore.instance.runTransaction((transaction) async {
                                    final snapshot = await transaction.get(userDocRef);
                                    final data = snapshot.data();
                                    final balanceValue = data == null
                                        ? 0
                                        : data['balance'] ?? data['walletBalance'] ?? data['wallet_balance'] ?? 0;
                                    final currentStoredBalance = balanceValue is num
                                        ? balanceValue.toDouble()
                                        : double.tryParse(balanceValue.toString()) ?? 0.0;

                                    if (currentStoredBalance < _totalAmountDue) {
                                      throw Exception('insufficient_balance');
                                    }

                                    transaction.update(userDocRef, {
                                      'balance': currentStoredBalance - _totalAmountDue,
                                    });
                                  });
                                } catch (e) {
                                  if (e is Exception && e.toString().contains('insufficient_balance')) {
                                    showPaymentResultDialog(
                                      success: false,
                                      message:
                                          'You only have $walletBalanceText. Please top up your wallet.'.translate(),
                                    );
                                  } else {
                                    showPaymentResultDialog(
                                      success: false,
                                      message: 'Unable to process payment. Please try again later.'.translate(),
                                    );
                                  }
                                  return;
                                }

                                bottomSheetNavigator.pop();
                                setState(() {
                                  _isPaymentPending = false;
                                });
                                showPaymentResultDialog(
                                  success: true,
                                  message:
                                      'Your payment was processed successfully, and case details are now unlocked.'.translate(),
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

  Widget _buildPriceRow(String label, String value, Color labelColor, Color valueColor, {bool isTotal = false}) {
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
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
                      Icon(Icons.check_circle_rounded, color: Colors.green, size: 70.sp),
                      SizedBox(height: 16.h),
                      Text('Payment Successful!'.translate(), 
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16.sp)),
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
                  decoration: InputDecoration(
                    hintText: '0.00',
                    suffixText: 'EGP',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
              ]
            ],
          ),
          actions: (isProcessing || isSuccess) ? [] : [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'.translate(), style: GoogleFonts.cairo(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final amountValue = double.tryParse(amountController.text);
                if (amountValue == null || amountValue <= 0) return;

                setDialogState(() => isProcessing = true);
                
                // Simulate processing delay
                await Future.delayed(const Duration(seconds: 2));
                
                if (!mounted) return;
                setDialogState(() {
                  isProcessing = false;
                  isSuccess = true;
                });

                // Wait a moment to show the success icon
                await Future.delayed(const Duration(milliseconds: 1500));

                if (!mounted) return;

                setState(() {
                  _totalFees += amountValue;
                  _remainingAmount = _totalFees - _withdrawnAmount;
                  _feeTransactions.insert(0, {
                    'date': formatDate(DateTime.now(), 'dd MMM yyyy'),
                    'title': 'Account Funded',
                    'amount': '+ ${amountValue.toStringAsFixed(0)} EGP',
                    'color': Colors.green,
                    'icon': Icons.add_circle_outline,
                  });
                });

                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF002147)),
              child: Text('Confirm'.translate(), style: GoogleFonts.cairo(color: Colors.white)),
            ),
          ],
        ),
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
                backgroundColor: AppColors.legalGold.withOpacity(0.2),
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
        Text(
          'Notes'.translate(),
          style: GoogleFonts.cairo(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: _notesController,
          maxLines: 3,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: 'Add a note...'.translate(),
            hintStyle: GoogleFonts.cairo(
              fontSize: 13.sp,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            filled: true,
            fillColor: cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: AppColors.legalGold,
                width: 1.5,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            suffixIcon: Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: IconButton(
                icon: Icon(
                  Icons.send,
                  color: AppColors.legalGold,
                  size: 20.sp,
                ),
                onPressed: () {
                  final note = _notesController.text.trim();
                  if (note.isNotEmpty) {
                    _notesList.add(note);
                    print('Note added: $note');
                    _notesController.clear();
                  }
                },
              ),
            ),
          ),
          style: GoogleFonts.cairo(
            fontSize: 13.sp,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        if (_notesList.isNotEmpty) ...[
          SizedBox(height: 12.h),
          Container(
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
              children: _notesList.asMap().entries.map((entry) {
                final index = entry.key;
                final note = entry.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: index < _notesList.length - 1 ? 8.h : 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16.sp,
                        color: AppColors.legalGold,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          note,
                          style: GoogleFonts.cairo(
                            fontSize: 12.sp,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
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
  }

  Widget _buildFeesTab(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A2940) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    
    String formatVal(double val) => 
        '${val.toStringAsFixed(0).replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (match) => ",")} EGP';

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        Card(
          elevation: 2,
          color: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSummaryItem('Total Funded'.translate(), formatVal(_totalFees), const Color(0xFF002147)),
                _buildSummaryItem('Spent by Lawyer'.translate(), formatVal(_withdrawnAmount), Colors.green),
                _buildSummaryItem('Balance Available'.translate(), formatVal(_remainingAmount), const Color(0xFFC6A243)),
              ],
            ),
          ),
        ),
        if (_feeTransactions.isNotEmpty) ...[
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                elevation: 0,
              ),
            ),
          ),
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
        if (_feeTransactions.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 80.sp,
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
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
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  ElevatedButton(
                    onPressed: () => _showFeePaymentDialog(isDark),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF002147),
                      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    child: Text(
                      "Start Funding",
                      style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._feeTransactions.map((tx) => _buildActivityItem(
                tx['date'],
                tx['title'],
                tx['amount'],
                tx['color'],
                isDark,
                icon: tx['icon'],
              )),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.grey)),
        Text(value, style: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildActivityItem(String date, String title, String amount, Color amountColor, bool isDark, {IconData? icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12.w,
              height: 12.h,
              decoration: BoxDecoration(
                color: icon != null ? AppColors.legalGold : Colors.grey.shade400,
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

  Widget _buildDocumentsTab(bool isDark) {
    final completedCount = _documents.where((doc) => doc.isSubmitted).length;
    final completionPercentage = _documents.isEmpty
        ? 0
        : ((completedCount / _documents.length) * 100).round();

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        if (_documents.isEmpty) ...[
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
          ..._documents.map((doc) {
            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: DocumentCard(
                document: doc,
                isDark: isDark,
                selectedFile: _pickedDocumentFiles[doc.id],
                isExpanded: _expandedDocuments.contains(doc.id),
                onTap: () {
                  setState(() {
                    if (_expandedDocuments.contains(doc.id)) {
                      _expandedDocuments.remove(doc.id);
                    } else {
                      _expandedDocuments.add(doc.id);
                    }
                  });
                },
                onCancel: doc.isSubmitted
                    ? null
                    : () {
                        setState(() {
                          _expandedDocuments.remove(doc.id);
                          _pickedDocumentFiles[doc.id] = null;
                        });
                      },
                onDelete: doc.isSubmitted
                    ? () {
                        setState(() {
                          _pickedDocumentFiles[doc.id] = null;
                          final index = _documents.indexWhere((item) => item.id == doc.id);
                          if (index != -1) {
                            _documents[index] = RequiredDocument(
                              id: doc.id,
                              name: doc.name,
                              description: doc.description,
                              isSubmitted: false,
                              submittedDate: null,
                            );
                          }
                        });
                      }
                    : null,
                onFileSelected: (file) {
                  setState(() {
                    _pickedDocumentFiles[doc.id] = file;
                    final index = _documents.indexWhere((item) => item.id == doc.id);
                    if (index != -1) {
                      _documents[index] = RequiredDocument(
                        id: doc.id,
                        name: doc.name,
                        description: doc.description,
                        isSubmitted: true,
                        submittedDate: DateTime.now(),
                      );
                    }
                    _expandedDocuments.remove(doc.id);
                  });

                  // Show success message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Document "${doc.name}" uploaded successfully!'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
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
                        decoration: BoxDecoration( // Fixed: withValues to withOpacity
                          color: Colors.green.withOpacity(0.1), // Fixed: withValues to withOpacity
                          borderRadius: BorderRadius.circular(8.r), // Fixed: withValues to withOpacity
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
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
                            color: Color(updateColor['color'] as int).withOpacity(0.15), // Fixed: withValues to withOpacity
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
        color: Color(bgColor).withOpacity(0.15), // Fixed: withValues to withOpacity
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
        color: Color(bgColor).withOpacity(0.15), // Fixed: withValues to withOpacity
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

class DocumentCard extends StatelessWidget {
  final RequiredDocument document;
  final bool isDark;
  final bool isExpanded;
  final PlatformFile? selectedFile;
  final VoidCallback onTap;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final ValueChanged<PlatformFile> onFileSelected;

  const DocumentCard({
    super.key,
    required this.document,
    required this.isDark,
    required this.isExpanded,
    required this.selectedFile,
    required this.onTap,
    required this.onCancel,
    required this.onDelete,
    required this.onFileSelected,
  });

  Widget _buildStatusDot(bool isSubmitted) {
    final circleColor = isSubmitted ? Colors.green : (isDark ? Colors.grey.shade500 : Colors.grey.shade400);
    return Container(
      width: 34.w,
      height: 34.h,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSubmitted ? Colors.green.withOpacity(0.12) : Colors.transparent,
        border: Border.all(color: circleColor, width: 1.5),
      ),
      child: Icon(
        isSubmitted ? Icons.check : Icons.radio_button_unchecked,
        size: 18.sp,
        color: circleColor,
      ),
    );
  }

  void _showDocumentPreview(BuildContext context) {
    final hasFile = selectedFile != null;
    final isImage = hasFile && (selectedFile!.extension?.toLowerCase() == 'jpg' ||
                               selectedFile!.extension?.toLowerCase() == 'jpeg' ||
                               selectedFile!.extension?.toLowerCase() == 'png');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Container(
            padding: EdgeInsets.all(20.w),
            constraints: BoxConstraints(
              maxWidth: 400.w,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.green, size: 24.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Document Preview'.translate(),
                        style: GoogleFonts.cairo(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, size: 20.sp),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                if (isImage && selectedFile!.bytes != null) ...[
                  // Show image preview
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: 300.h,
                      maxWidth: double.infinity,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: Image.memory(
                        selectedFile!.bytes!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ] else ...[
                  // Show file info for non-images or when bytes are not available
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          hasFile ? Icons.insert_drive_file : Icons.check_circle,
                          size: 48.sp,
                          color: Colors.green,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          hasFile ? selectedFile!.name : 'Document Submitted',
                          style: GoogleFonts.cairo(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (hasFile) ...[
                          SizedBox(height: 8.h),
                          Text(
                            'Size: ${(selectedFile!.size / 1024).round()} KB',
                            style: GoogleFonts.cairo(
                              fontSize: 12.sp,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 20.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green, size: 20.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'Successfully Submitted'.translate(),
                        style: GoogleFonts.cairo(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
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

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          title: Text(
            'Delete Document?'.translate(),
            style: GoogleFonts.cairo(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to remove this file?'.translate(),
            style: GoogleFonts.cairo(
              fontSize: 14.sp,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'No'.translate(),
                style: GoogleFonts.cairo(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (onDelete != null) {
                  onDelete!();
                }
              },
              child: Text(
                'Yes'.translate(),
                style: GoogleFonts.cairo(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1A2940) : Colors.white;
    final borderColor = document.isSubmitted ? Colors.green : AppColors.legalGold;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              child: Row(
                children: [
                  _buildStatusDot(document.isSubmitted),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.name,
                          style: GoogleFonts.cairo(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          document.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 12.sp,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (document.isSubmitted && onDelete != null)
                    IconButton(
                      onPressed: () => _showDeleteConfirmation(context),
                      icon: Icon(Icons.delete_outline, size: 20.sp, color: Colors.redAccent),
                    ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade500,
                    size: 22.sp,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.description,
                    style: GoogleFonts.cairo(
                      fontSize: 13.sp,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  if (selectedFile != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedFile!.name,
                            style: GoogleFonts.cairo(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        TextButton(
                          onPressed: () => _showDocumentPreview(context),
                          child: Text(
                            'Preview'.translate(),
                            style: GoogleFonts.cairo(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (!document.isSubmitted) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.legalGold,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            allowMultiple: false,
                            type: FileType.any,
                            withData: true,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            onFileSelected(result.files.first);
                          }
                        },
                        child: Text(
                          'Upload Document'.translate(),
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (onCancel != null && !document.isSubmitted) ...[
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                        onPressed: onCancel,
                        child: Text(
                          'Cancel'.translate(),
                          style: GoogleFonts.cairo(
                            color: borderColor,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
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
  }
}
