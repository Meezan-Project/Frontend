import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/screens/saved_cards_screen.dart'; // قم بتعديل المسار إذا كان مختلفاً

class BookingConfirmationScreen extends StatefulWidget {
  final String lawyerId;
  final String lawyerName;
  final String lawyerImage;
  final String lawyerSpecialization;
  final String dateLabel;
  final String timeRange;
  final String officeAddress;
  final String consultationType; // 'online' or 'office'
  final double fee;

  const BookingConfirmationScreen({
    super.key,
    required this.lawyerId,
    required this.lawyerName,
    required this.lawyerImage,
    required this.lawyerSpecialization,
    required this.dateLabel,
    required this.timeRange,
    required this.officeAddress,
    required this.consultationType,
    required this.fee,
  });

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  String _userName = 'Loading...';
  String _userPhone = '';
  String _userEmail = '';
  bool _isLoadingUser = true;
  bool _isConfirming = false;
  double _userBalance = 0.0;

  String? _selectedPaymentType; // null by default to enforce selection
  String? _selectedOnlineMethod; // 'wallet', 'fawry', 'card'
  String? _selectedCardId;

  final TextEditingController _walletPhoneController = TextEditingController();
  final TextEditingController _fawryPhoneController = TextEditingController();
  String? _walletError;
  String? _fawryError;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _walletPhoneController.dispose();
    _fawryPhoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          final data = doc.data()!;
          final firstName = data['firstName'] ?? data['first_name'] ?? '';
          final secondName = data['secondName'] ?? data['second_name'] ?? '';
          final fullName =
              data['name'] ?? data['fullName'] ?? data['full_name'] ?? '';

          String finalName = '$firstName $secondName'.trim();
          if (finalName.isEmpty) finalName = fullName.trim();

          final bal =
              data['balance'] ??
              data['walletBalance'] ??
              data['wallet_balance'] ??
              0;

          setState(() {
            _userName = finalName.isEmpty ? 'Mezaan User' : finalName;
            _userPhone =
                data['phone'] ??
                data['phoneNumber'] ??
                data['phone_number'] ??
                user.phoneNumber ??
                '';
            _userEmail = data['email'] ?? user.email ?? '';
            _userBalance = (bal is num)
                ? bal.toDouble()
                : double.tryParse(bal.toString()) ?? 0.0;
            _isLoadingUser = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _userName = 'Test User';
        _userPhone = '01000000000';
        _userEmail = 'user@example.com';
        _isLoadingUser = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSavedCards() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      // 1. هل الكروت محفوظة كمصفوفة (Array) داخل بيانات المستخدم؟
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
        if (data['saved_cards'] is List &&
            (data['saved_cards'] as List).isNotEmpty) {
          return (data['saved_cards'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        if (data['cards'] is List && (data['cards'] as List).isNotEmpty) {
          return (data['cards'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }

      // 2. هل الكروت محفوظة في Subcollection داخل بيانات المستخدم؟
      var snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('saved_cards')
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => d.data()..['id'] = d.id).toList();
      }

      snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cards')
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => d.data()..['id'] = d.id).toList();
      }

      // 3. هل الكروت محفوظة في Collection خارجي منفصل؟
      snap = await FirebaseFirestore.instance
          .collection('saved_cards')
          .where('userId', isEqualTo: user.uid)
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => d.data()..['id'] = d.id).toList();
      }

      snap = await FirebaseFirestore.instance
          .collection('payment_methods')
          .where('userId', isEqualTo: user.uid)
          .get();
      return snap.docs.map((d) => d.data()..['id'] = d.id).toList();
    } catch (e) {
      return [];
    }
  }

  bool _validateOnlinePayment() {
    setState(() {
      _walletError = null;
      _fawryError = null;
    });

    if (_selectedPaymentType == 'online') {
      if (_selectedOnlineMethod == null) {
        _showErrorSnackBar('Please select an online payment method.');
        return false;
      }

      if (_selectedOnlineMethod == 'wallet') {
        if (_walletPhoneController.text.length != 11) {
          setState(() => _walletError = 'Must be exactly 11 digits');
          return false;
        }
      } else if (_selectedOnlineMethod == 'fawry') {
        if (_fawryPhoneController.text.length != 11) {
          setState(() => _fawryError = 'Must be exactly 11 digits');
          return false;
        }
      } else if (_selectedOnlineMethod == 'card') {
        if (_selectedCardId == null) {
          _showErrorSnackBar('Please select a credit/debit card.');
          return false;
        }
      }
    }
    return true;
  }

  void _showErrorSnackBar(String message) {
    _showPopupMessage(
      'Error',
      message,
      Icons.error_outline,
      const Color(0xFFC63F3F),
    );
  }

  void _showPopupMessage(
    String title,
    String message,
    IconData icon,
    Color iconColor, {
    VoidCallback? onClose,
    bool showOkButton = true,
  }) {
    showDialog(
      context: context,
      barrierDismissible: showOkButton,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Column(
          children: [
            Icon(icon, color: iconColor, size: 48.sp),
            SizedBox(height: 12.h),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w800,
                color: AppColors.navyBlue,
                fontSize: 20.sp,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(fontSize: 15.sp),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: showOkButton
            ? [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    if (onClose != null) onClose();
                  },
                  child: Text(
                    'OK',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ]
            : null,
      ),
    );
  }

  Future<void> _confirmAndSaveAppointment() async {
    if (!_validateOnlinePayment()) return;

    if (_selectedPaymentType == 'balance' && _userBalance < widget.fee) {
      _showErrorSnackBar(
        'Insufficient balance. Please recharge or choose another payment method.',
      );
      return;
    }

    setState(() => _isConfirming = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final apptRef = firestore.collection('appointments').doc();

      String paymentMethod = _selectedPaymentType ?? 'cash';
      String? paymentPhone;

      if (_selectedPaymentType == 'online') {
        paymentMethod = _selectedOnlineMethod ?? 'online';
        if (paymentMethod == 'wallet') {
          paymentPhone = '+2${_walletPhoneController.text}';
        } else if (paymentMethod == 'fawry') {
          paymentPhone = '+2${_fawryPhoneController.text}';
        }
      }

      batch.set(apptRef, {
        'appointmentId': apptRef.id,
        'userId': user?.uid ?? 'guest_user',
        'userName': _userName,
        'userEmail': _userEmail,
        'lawyerId': widget.lawyerId,
        'lawyerName': widget.lawyerName,
        'lawyerImage': widget.lawyerImage,
        'day': widget.dateLabel,
        'time': widget.timeRange,
        'officeAddress': widget.officeAddress,
        'paymentMethod': paymentMethod,
        'paymentPhone': paymentPhone, // Saved if Wallet or Fawry is used
        'cardId': _selectedCardId, // Saved if Card is used
        'paymentStatus': 'pending',
        'bookingStatus': 'pending',
        'fees': widget.fee,
        'consultationType': widget.consultationType,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // خصم الرصيد وتسجيل المعاملة لو الدفع تم بالمحفظة
      if (_selectedPaymentType == 'balance' && user != null) {
        final userRef = firestore.collection('users').doc(user.uid);
        batch.update(userRef, {'balance': FieldValue.increment(-widget.fee)});

        // Add transaction to user's sub-collection
        final userTransRef = firestore
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .doc();
        batch.set(userTransRef, {
          'userId': user.uid,
          'lawyerId': widget.lawyerId,
          'amount': -widget.fee,
          'type': 'booking_payment',
          'description': 'Consultation Booking - ${widget.lawyerName}',
          'isWalletTransaction': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Add transaction to lawyer's sub-collection
        final lawyerTransRef = firestore
            .collection('lawyers')
            .doc(widget.lawyerId)
            .collection('transactions')
            .doc();
        batch.set(lawyerTransRef, {
          'userId': user.uid,
          'lawyerId': widget.lawyerId,
          'amount': widget.fee,
          'type': 'booking_payment',
          'description': 'Consultation Booking from $_userName',
          'isWalletTransaction': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update lawyer's balance
        final lawyerRef = firestore.collection('lawyers').doc(widget.lawyerId);
        batch.update(lawyerRef, {'balance': FieldValue.increment(widget.fee)});
      }

      await batch.commit();

      if (mounted) {
        _showPopupMessage(
          'Success',
          'Booking confirmed successfully!',
          Icons.check_circle_outline,
          Colors.green,
          showOkButton: false,
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop(); // إغلاق الـ Popup
            Navigator.of(
              context,
            ).popUntil((route) => route.isFirst); // العودة لصفحة الـ Dashboard
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('An error occurred: $e');
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Note: Removed Directionality to force LTR layout for English
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.navyBlue,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Booking Confirmation',
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
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLawyerInfoCard(),
                  SizedBox(height: 20.h),
                  _buildUserInfoCard(),
                  SizedBox(height: 20.h),
                  _buildAppointmentDetailsCard(),
                  SizedBox(height: 24.h),
                  _buildPaymentSection(),
                ],
              ),
            ),
          ),
          _buildStickyBottomBar(),
        ],
      ),
    );
  }

  Widget _buildLawyerInfoCard() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: EdgeInsets.only(top: 40.h),
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16.w, 54.h, 16.w, 20.h),
          decoration: BoxDecoration(
            color: Colors.white,
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
            children: [
              Text(
                widget.lawyerName,
                style: GoogleFonts.cairo(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navyBlue,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                widget.lawyerSpecialization,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          child: Container(
            padding: EdgeInsets.all(4.r),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: Offset(0, 4.h),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.network(
                widget.lawyerImage,
                width: 84.r,
                height: 84.r,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 84.r,
                  height: 84.r,
                  color: Colors.grey.shade200,
                  child: Icon(
                    Icons.person_rounded,
                    size: 42.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoCard() {
    return _buildSectionCard(
      title: 'User Details',
      child: _isLoadingUser
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildInfoRow(Icons.person_outline, _userName),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Divider(color: Colors.grey.shade200, height: 1),
                ),
                _buildInfoRow(
                  Icons.phone_outlined,
                  _userPhone.isNotEmpty ? _userPhone : 'Not provided',
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Divider(color: Colors.grey.shade200, height: 1),
                ),
                _buildInfoRow(
                  Icons.email_outlined,
                  _userEmail.isNotEmpty ? _userEmail : 'Not provided',
                ),
              ],
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            color: AppColors.navyBlue.withOpacity(0.06),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.navyBlue, size: 20.sp),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.navyBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentDetailsCard() {
    return _buildSectionCard(
      title: 'Appointment Details',
      child: Column(
        children: [
          _buildDetailRow(
            Icons.calendar_month_outlined,
            widget.dateLabel,
            widget.timeRange,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Divider(color: Colors.grey.shade200, height: 1),
          ),
          _buildDetailRow(
            widget.consultationType == 'online'
                ? Icons.video_camera_front_outlined
                : Icons.location_on_outlined,
            widget.consultationType == 'online'
                ? 'Online Consultation'
                : 'In Office',
            widget.consultationType == 'online'
                ? 'Meeting link will be provided shortly.'
                : widget.officeAddress,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            color: AppColors.legalGold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, color: AppColors.legalGold, size: 22.sp),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navyBlue,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                style: GoogleFonts.cairo(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Payment Method',
          style: GoogleFonts.cairo(
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.navyBlue,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
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
            children: [
              if (widget.consultationType != 'online') ...[
                RadioListTile<String>(
                  value: 'cash',
                  groupValue: _selectedPaymentType,
                  activeColor: AppColors.legalGold,
                  title: Text(
                    'Cash at the office',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.sp,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  onChanged: (val) =>
                      setState(() => _selectedPaymentType = val),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
              ],
              RadioListTile<String>(
                value: 'balance',
                groupValue: _selectedPaymentType,
                activeColor: AppColors.legalGold,
                title: Text(
                  'From your balance (${_userBalance.toStringAsFixed(2)} EGP)',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.sp,
                    color: AppColors.navyBlue,
                  ),
                ),
                onChanged: (val) => setState(() => _selectedPaymentType = val),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              RadioListTile<String>(
                value: 'online',
                groupValue: _selectedPaymentType,
                activeColor: AppColors.legalGold,
                title: Text(
                  'Online Payment',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.sp,
                    color: AppColors.navyBlue,
                  ),
                ),
                onChanged: (val) => setState(() => _selectedPaymentType = val),
              ),
              if (_selectedPaymentType == 'online') ...[
                Container(
                  color: const Color(0xFFF8FAFC),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 16.h,
                  ),
                  child: Column(
                    children: [
                      _buildOnlineMethodOption(
                        'wallet',
                        'Smart Wallet',
                        Icons.account_balance_wallet_outlined,
                      ),
                      if (_selectedOnlineMethod == 'wallet')
                        _buildPhoneInputField(
                          _walletPhoneController,
                          _walletError,
                        ),

                      SizedBox(height: 8.h),
                      _buildOnlineMethodOption(
                        'fawry',
                        'Fawry',
                        Icons.storefront_outlined,
                      ),
                      if (_selectedOnlineMethod == 'fawry')
                        _buildPhoneInputField(
                          _fawryPhoneController,
                          _fawryError,
                        ),

                      SizedBox(height: 8.h),
                      _buildOnlineMethodOption(
                        'card',
                        'Credit / Debit Card',
                        Icons.credit_card_outlined,
                      ),
                      if (_selectedOnlineMethod == 'card')
                        _buildSavedCardsList(),
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

  Widget _buildOnlineMethodOption(String value, String title, IconData icon) {
    final isSelected = _selectedOnlineMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedOnlineMethod = value),
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.legalGold : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.legalGold : Colors.grey.shade500,
              size: 22.sp,
            ),
            SizedBox(width: 12.w),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 14.sp,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.navyBlue : Colors.grey.shade700,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.legalGold, size: 22.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneInputField(
    TextEditingController controller,
    String? errorMsg,
  ) {
    return Padding(
      padding: EdgeInsets.only(top: 8.h, bottom: 8.h),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.phone,
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
          errorText: errorMsg,
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

  Widget _buildSavedCardsList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: 8.h),
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
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Text(
              'Error loading cards',
              style: TextStyle(color: Colors.red.shade400),
            );
          }

          final cards = snapshot.data ?? [];

          // تحديد الكارت الأساسي تلقائياً إذا لم يقم المستخدم باختيار كارت بعد
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
              Divider(color: Colors.grey.shade200),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SavedCardsScreen(),
                    ),
                  );
                  setState(() {}); // لتحديث القائمة بالبطاقة الجديدة عند العودة
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

  Widget _buildSectionCard({String? title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
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
          if (title != null) ...[
            Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.navyBlue,
              ),
            ),
            SizedBox(height: 16.h),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16.w,
        16.h,
        16.w,
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
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Amount',
                style: GoogleFonts.cairo(
                  fontSize: 13.sp,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${widget.fee.toInt()} EGP',
                style: GoogleFonts.cairo(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navyBlue,
                ),
              ),
            ],
          ),
          SizedBox(width: 24.w),
          Expanded(
            child: SizedBox(
              height: 54.h,
              child: ElevatedButton(
                onPressed: (_selectedPaymentType != null && !_isConfirming)
                    ? _confirmAndSaveAppointment
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFFC63F3F,
                  ), // Red action button as per design
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  elevation: 0,
                ),
                child: _isConfirming
                    ? SizedBox(
                        width: 24.w,
                        height: 24.h,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Confirm',
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
    );
  }
}
