import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/screens/deposit_screen.dart';

class UserBalanceScreen extends StatelessWidget {
  final String currentBalance;

  const UserBalanceScreen({super.key, this.currentBalance = '0.00'});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        body: Column(
          children: [
            // Header with Overlapping Card
            Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  children: [
                    // Navy Blue Header Background
                    Container(
                      width: double.infinity,
                      height: 220.h,
                      decoration: BoxDecoration(
                        color: AppColors.navyBlue,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(30.r),
                          bottomRight: Radius.circular(30.r),
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 10.h,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_ios,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 8.h),
                                  child: Text(
                                    'Wallet',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.cairo(
                                      color: Colors.white,
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 48.w), // Balance alignment
                            ],
                          ),
                        ),
                      ),
                    ),
                    // وضع المساحة دي جوة الـ Stack بيسمح للزرار إنه يتضغط لأنه بقى جوة الحدود
                    SizedBox(height: 110.h),
                  ],
                ),
                // Overlapping Balance Card
                Positioned(
                  top: 120.h,
                  left: 24.w,
                  right: 24.w,
                  child: Container(
                    padding: EdgeInsets.all(24.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 15,
                          offset: Offset(0, 8.h),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Current Balance',
                          style: GoogleFonts.cairo(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser?.uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            String displayBalance = currentBalance;
                            if (snapshot.hasData &&
                                snapshot.data != null &&
                                snapshot.data!.exists) {
                              final data =
                                  snapshot.data!.data()
                                      as Map<String, dynamic>?;
                              if (data != null) {
                                final bal =
                                    data['balance'] ??
                                    data['walletBalance'] ??
                                    data['wallet_balance'] ??
                                    0;
                                displayBalance = (bal is num)
                                    ? bal.toStringAsFixed(2)
                                    : (double.tryParse(
                                            bal.toString(),
                                          )?.toStringAsFixed(2) ??
                                          '0.00');
                              }
                            }
                            return Text(
                              '$displayBalance EGP',
                              style: GoogleFonts.cairo(
                                fontSize: 32.sp,
                                fontWeight: FontWeight.w900,
                                color: AppColors.navyBlue,
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 20.h),
                        SizedBox(
                          width: double.infinity,
                          height: 50.h,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const DepositScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.legalGold,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Recharge Balance',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Recent Transactions
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Transactions',
                      style: GoogleFonts.cairo(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navyBlue,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser?.uid)
                            .collection('transactions')
                            .where('isWalletTransaction', isEqualTo: true)
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.legalGold,
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            debugPrint('Transactions Error: ${snapshot.error}');
                            return Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.w),
                                child: Text(
                                  'Firebase Index Required!\nCheck your Terminal/Console for the blue link to create it.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cairo(
                                    fontSize: 14.sp,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            );
                          }

                          final docs = snapshot.data?.docs.toList() ?? [];

                          // ترتيب المعاملات برمجياً محلياً لتخطي مشكلة الـ Index في فايربيز
                          docs.sort((a, b) {
                            final aData = a.data() as Map<String, dynamic>;
                            final bData = b.data() as Map<String, dynamic>;
                            final aTime = aData['createdAt'] as Timestamp?;
                            final bTime = bData['createdAt'] as Timestamp?;
                            if (aTime == null && bTime == null) return 0;
                            if (aTime == null) return 1;
                            if (bTime == null) return -1;
                            return bTime.compareTo(aTime); // الأحدث أولاً
                          });

                          if (docs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 64.sp,
                                    color: Colors.grey.shade400,
                                  ),
                                  SizedBox(height: 16.h),
                                  Text(
                                    'No recent transactions',
                                    style: GoogleFonts.cairo(
                                      fontSize: 16.sp,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: docs.length,
                            separatorBuilder: (context, index) => Divider(
                              color: Colors.grey.shade200,
                              height: 24.h,
                            ),
                            itemBuilder: (context, index) {
                              final data =
                                  docs[index].data() as Map<String, dynamic>;
                              final amount =
                                  (data['amount'] as num?)?.toDouble() ?? 0.0;
                              final type = data['type'] as String? ?? '';
                              final description =
                                  data['description'] as String? ??
                                  'Transaction';
                              final createdAt = data['createdAt'] as Timestamp?;

                              final isDeposit = amount > 0 || type == 'deposit';

                              String dateString = '';
                              if (createdAt != null) {
                                dateString = DateFormat(
                                  'dd MMMM yyyy, hh:mm a',
                                  'en',
                                ).format(createdAt.toDate());
                              }

                              return Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12.r),
                                    decoration: BoxDecoration(
                                      color: isDeposit
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.red.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isDeposit
                                          ? Icons.arrow_downward_rounded
                                          : Icons.arrow_upward_rounded,
                                      color: isDeposit
                                          ? Colors.green
                                          : Colors.red,
                                      size: 20.sp,
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          description,
                                          style: GoogleFonts.cairo(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.navyBlue,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          dateString,
                                          style: GoogleFonts.cairo(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${isDeposit ? '+' : '-'} ${amount.abs().toStringAsFixed(2)} EGP',
                                    style: GoogleFonts.cairo(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.bold,
                                      color: isDeposit
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// --- Wallet Passcode Bottom Sheet Logic ---

enum PasscodeState { loading, create, confirm, enter, saving }

class WalletPasscodeDialog extends StatefulWidget {
  const WalletPasscodeDialog({super.key});

  /// Returns [true] if passcode was verified or successfully created.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const WalletPasscodeDialog(),
    );
    return result ?? false;
  }

  @override
  State<WalletPasscodeDialog> createState() => _WalletPasscodeDialogState();
}

class _WalletPasscodeDialogState extends State<WalletPasscodeDialog> {
  PasscodeState _state = PasscodeState.loading;
  String? _firestorePasscode;
  String _firstAttempt = '';
  String _errorMsg = '';

  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _checkExistingPasscode();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _checkExistingPasscode() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Navigator.pop(context, false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()!.containsKey('walletPasscode')) {
        _firestorePasscode = doc.data()!['walletPasscode'];
        setState(() => _state = PasscodeState.enter);
      } else {
        setState(() => _state = PasscodeState.create);
      }

      // Request focus after state is determined
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _focusNode.requestFocus();
      });
    } catch (e) {
      if (mounted) Navigator.pop(context, false);
    }
  }

  void _onPinChanged(String value) async {
    setState(() => _errorMsg = '');

    if (value.length == 6) {
      if (_state == PasscodeState.create) {
        _firstAttempt = value;
        _pinController.clear();
        setState(() => _state = PasscodeState.confirm);
        _focusNode.requestFocus();
      } else if (_state == PasscodeState.confirm) {
        if (value == _firstAttempt) {
          setState(() => _state = PasscodeState.saving);
          await _savePasscode(value);
        } else {
          _pinController.clear();
          _firstAttempt = '';
          setState(() {
            _state = PasscodeState.create;
            _errorMsg = 'Passcode does not match. Try again.';
          });
          _focusNode.requestFocus();
        }
      } else if (_state == PasscodeState.enter) {
        if (value == _firestorePasscode) {
          Navigator.pop(context, true);
        } else {
          _pinController.clear();
          setState(() {
            _errorMsg = 'Incorrect passcode.';
          });
          _focusNode.requestFocus();
        }
      }
    }
  }

  Future<void> _savePasscode(String pin) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'walletPasscode': pin,
        }, SetOptions(merge: true));
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _errorMsg = 'Error saving passcode.');
      _pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child:
            (_state == PasscodeState.loading || _state == PasscodeState.saving)
            ? const SizedBox(
                height: 150,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.navyBlue),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _state == PasscodeState.create
                        ? 'Create Passcode (6 Digits)'
                        : _state == PasscodeState.confirm
                        ? 'Confirm Passcode'
                        : 'Enter Passcode',
                    style: GoogleFonts.cairo(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'To secure your wallet and balance',
                    style: GoogleFonts.cairo(
                      fontSize: 14.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 32.h),

                  // Custom PIN Dots
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 0,
                        child: TextField(
                          controller: _pinController,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 6,
                          onChanged: _onPinChanged,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _focusNode.requestFocus(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6, (index) {
                            bool isFilled = _pinController.text.length > index;
                            return Container(
                              margin: EdgeInsets.symmetric(horizontal: 8.w),
                              width: 22.w,
                              height: 22.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isFilled
                                    ? AppColors.legalGold
                                    : Colors.grey.shade300,
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  if (_errorMsg.isNotEmpty)
                    Text(
                      _errorMsg,
                      style: GoogleFonts.cairo(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  SizedBox(height: 16.h),
                ],
              ),
      ),
    );
  }
}
