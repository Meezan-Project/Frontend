import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/screens/saved_cards_screen.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();

  final TextEditingController _walletPhoneController = TextEditingController();
  final TextEditingController _fawryPhoneController = TextEditingController();

  String? _selectedPaymentMethod;
  String? _selectedCardId;
  bool _isUpdating = false;
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    _balanceController.dispose();
    _walletPhoneController.dispose();
    _fawryPhoneController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    if (_isUpdating) return;
    _isUpdating = true;
    double? amount = double.tryParse(val);
    if (amount != null) {
      _balanceController.text = (amount / 1.14).toStringAsFixed(2);
    } else {
      _balanceController.clear();
    }
    _isUpdating = false;
    setState(() {}); // Update the bottom bar state
  }

  void _onBalanceChanged(String val) {
    if (_isUpdating) return;
    _isUpdating = true;
    double? balance = double.tryParse(val);
    if (balance != null) {
      _amountController.text = (balance * 1.14).toStringAsFixed(2);
    } else {
      _amountController.clear();
    }
    _isUpdating = false;
    setState(() {}); // Update the bottom bar state
  }

  Future<void> _processMockPayment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final double netBalance = double.tryParse(_balanceController.text) ?? 0.0;
    if (netBalance <= 0) return;

    setState(() => _isProcessing = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // 1. Update user balance
      final userRef = firestore.collection('users').doc(user.uid);
      batch.update(userRef, {'balance': FieldValue.increment(netBalance)});

      // 2. Add transaction record
      final transRef = firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .doc();
      String methodDesc = 'Credit/Debit Card';
      if (_selectedPaymentMethod == 'wallet') {
        methodDesc = 'Smart Wallet (${_walletPhoneController.text})';
      } else if (_selectedPaymentMethod == 'fawry') {
        methodDesc = 'Fawry (${_fawryPhoneController.text})';
      }

      batch.set(transRef, {
        'userId': user.uid,
        'amount': netBalance,
        'type': 'deposit',
        'description': 'Wallet Deposit via $methodDesc',
        'isWalletTransaction': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully added $netBalance EGP to your wallet!',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Return to Wallet screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.navyBlue,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Balance Recharge',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18.sp,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCalculatorCard(),
                  SizedBox(height: 24.h),
                  Text(
                    'Choose your payment method',
                    style: GoogleFonts.cairo(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _buildPaymentCard(
                    id: 'wallet',
                    title: 'Smart Wallet',
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                  if (_selectedPaymentMethod == 'wallet')
                    _buildPhoneInputField(_walletPhoneController),
                  _buildPaymentCard(
                    id: 'fawry',
                    title: 'Fawry',
                    icon: Icons.storefront_rounded,
                  ),
                  if (_selectedPaymentMethod == 'fawry')
                    _buildPhoneInputField(_fawryPhoneController),
                  _buildPaymentCard(
                    id: 'card',
                    title: 'Credit / Debit Card',
                    icon: Icons.credit_card_rounded,
                  ),
                  if (_selectedPaymentMethod == 'card') _buildSavedCardsList(),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildCalculatorCard() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _buildInputField(
              label: 'Amount to recharge',
              controller: _amountController,
              onChanged: _onAmountChanged,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Icon(
              Icons.compare_arrows_rounded,
              color: AppColors.legalGold,
              size: 28.sp,
            ),
          ),
          Expanded(
            child: _buildInputField(
              label: 'Balance',
              controller: _balanceController,
              onChanged: _onBalanceChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12.sp,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
          style: GoogleFonts.cairo(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.navyBlue,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 12.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(
                color: AppColors.legalGold,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchSavedCards() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      // Check savedCards array inside user doc
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        if (data['savedCards'] is List &&
            (data['savedCards'] as List).isNotEmpty) {
          return (data['savedCards'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
      // Check subcollection fallback
      var snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('saved_cards')
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => d.data()..['id'] = d.id).toList();
      }
    } catch (e) {
      return [];
    }
    return [];
  }

  Widget _buildSavedCardsList() {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchSavedCards(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final cards = snapshot.data ?? [];

          // Auto-select the default card initially
          if (cards.isNotEmpty && _selectedCardId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectedCardId == null) {
                final defaultCard = cards.firstWhere(
                  (c) => c['isDefault'] == true || c['is_default'] == true,
                  orElse: () => cards.first,
                );
                final defaultId =
                    defaultCard['id']?.toString() ??
                    defaultCard['cardNumber']?.toString() ??
                    defaultCard.hashCode.toString();
                setState(() => _selectedCardId = defaultId);
              }
            });
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cards.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Text(
                    'No saved cards found.',
                    style: GoogleFonts.cairo(
                      fontSize: 13.sp,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ...cards.map((cardData) {
                final brand =
                    cardData['brand'] ??
                    cardData['network'] ??
                    cardData['cardType'] ??
                    'Card';
                final fullNumber =
                    cardData['cardNumber'] ??
                    cardData['card_number'] ??
                    cardData['number'] ??
                    cardData['last4'] ??
                    '****';
                final last4 = fullNumber.toString().length >= 4
                    ? fullNumber.toString().substring(
                        fullNumber.toString().length - 4,
                      )
                    : fullNumber.toString();
                final cardId =
                    cardData['id']?.toString() ??
                    cardData['cardNumber']?.toString() ??
                    cardData.hashCode.toString();

                return RadioListTile(
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  activeColor: AppColors.navyBlue,
                  value: cardId,
                  groupValue: _selectedCardId,
                  title: Text(
                    '$brand ****$last4',
                    style: GoogleFonts.cairo(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  onChanged: (val) =>
                      setState(() => _selectedCardId = val.toString()),
                );
              }),
              if (cards.isNotEmpty) Divider(color: Colors.grey.shade200),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SavedCardsScreen(),
                    ),
                  );
                  setState(() {}); // Refresh list after adding a new card
                },
                icon: Icon(Icons.add, color: AppColors.legalGold, size: 20.sp),
                label: Text(
                  'Use another card',
                  style: GoogleFonts.cairo(
                    color: AppColors.legalGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaymentCard({
    required String id,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _selectedPaymentMethod == id;

    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = id),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? AppColors.legalGold : Colors.transparent,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.legalGold.withOpacity(0.1)
                    : const Color(0xFFF4F7FB),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.legalGold : Colors.grey.shade500,
                size: 22.sp,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 15.sp,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  color: isSelected ? AppColors.navyBlue : Colors.grey.shade700,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.legalGold,
                size: 24.sp,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneInputField(TextEditingController controller) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.phone,
        onChanged: (val) => setState(() {}),
        inputFormatters: [
          LengthLimitingTextInputFormatter(11),
          FilteringTextInputFormatter.digitsOnly,
        ],
        style: GoogleFonts.cairo(
          fontWeight: FontWeight.w700,
          color: AppColors.navyBlue,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: 'Enter 11 digit number',
          hintStyle: GoogleFonts.cairo(
            color: Colors.grey.shade400,
            fontSize: 13.sp,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🇪🇬', style: TextStyle(fontSize: 16.sp)),
                SizedBox(width: 6.w),
                Text(
                  '+2',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navyBlue,
                    fontSize: 15.sp,
                  ),
                ),
                SizedBox(width: 8.w),
                Container(width: 1, height: 20.h, color: Colors.grey.shade300),
              ],
            ),
          ),
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
            borderSide: const BorderSide(
              color: AppColors.legalGold,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    bool isPaymentValid = false;
    if (_selectedPaymentMethod == 'wallet') {
      isPaymentValid = _walletPhoneController.text.length == 11;
    } else if (_selectedPaymentMethod == 'fawry') {
      isPaymentValid = _fawryPhoneController.text.length == 11;
    } else if (_selectedPaymentMethod == 'card') {
      isPaymentValid = _selectedCardId != null;
    }

    final bool canProceed =
        _selectedPaymentMethod != null &&
        _amountController.text.isNotEmpty &&
        isPaymentValid;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20.w,
        16.h,
        20.w,
        MediaQuery.of(context).padding.bottom + 16.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, -5.h),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54.h,
        child: ElevatedButton(
          onPressed: (canProceed && !_isProcessing)
              ? _processMockPayment
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.legalGold,
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
            elevation: 0,
          ),
          child: _isProcessing
              ? SizedBox(
                  height: 24.h,
                  width: 24.w,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  'Continue to Payment',
                  style: GoogleFonts.cairo(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: canProceed ? Colors.white : Colors.grey.shade500,
                  ),
                ),
        ),
      ),
    );
  }
}
