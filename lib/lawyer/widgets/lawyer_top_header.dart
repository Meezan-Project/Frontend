import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mezaan/lawyer/screens/lawyer_balance_screen.dart';

class LawyerTopHeader extends StatefulWidget {
  final String rating;
  final int pendingCases;
  final String appName;
  final VoidCallback? onNotificationTap;

  const LawyerTopHeader({
    super.key,
    required this.rating,
    required this.pendingCases,
    this.appName = 'Mezaan',
    this.onNotificationTap,
  });

  @override
  State<LawyerTopHeader> createState() => _LawyerTopHeaderState();
}

class _LawyerTopHeaderState extends State<LawyerTopHeader> {
  bool _isBalanceVisible = false;
  String _currentBalance = '0.00';

  void _handleWalletTap() async {
    if (!_isBalanceVisible) {
      final success = await LawyerWalletPasscodeDialog.show(context);

      if (success) {
        setState(() {
          _isBalanceVisible = true;
        });

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LawyerBalanceScreen(currentBalance: _currentBalance),
            ),
          );
        }
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LawyerBalanceScreen(currentBalance: _currentBalance),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF162235) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF131313);
    final ratingTextColor = isDark ? Colors.white : AppColors.navyBlue;
    final ratingContainerColor = isDark
        ? const Color(0xFF1F2D45)
        : const Color(0xFFF7FAFC);
    final ratingBorderColor = isDark
        ? const Color(0xFF334766)
        : const Color(0xFFE5E7EB);
    final bellContainerColor = isDark
        ? const Color(0xFF24324A)
        : const Color(0xFFF3F4F6);

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
            blurRadius: 14,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  width: 32.w,
                  height: 32.h,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 32.w,
                      height: 32.h,
                      color: AppColors.navyBlue.withValues(alpha: 0.08),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 18.sp,
                        color: AppColors.navyBlue,
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  widget.appName,
                  style: GoogleFonts.cairo(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: ratingContainerColor,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: ratingBorderColor),
                ),
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseAuth.instance.currentUser != null
                      ? FirebaseFirestore.instance
                          .collection('lawyers')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .snapshots()
                      : null,
                  builder: (context, snapshot) {
                    String displayRating = widget.rating; // fallback
                    if (snapshot.hasData && snapshot.data!.data() != null) {
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      
                      // Process balance
                      final bal = data['balance'] ?? data['walletBalance'] ?? data['wallet_balance'] ?? 0;
                      if (bal is num) {
                        _currentBalance = bal.toStringAsFixed(2);
                      } else {
                        _currentBalance = double.tryParse(bal.toString())?.toStringAsFixed(2) ?? '0.00';
                      }

                      // Process rating
                      final r = data['rating'];
                      if (r != null) {
                        displayRating = (r is num)
                            ? (r % 1 == 0 ? r.toInt().toString() : r.toStringAsFixed(1))
                            : r.toString();
                      }
                    }
                    
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Wallet Section
                        GestureDetector(
                          onTap: _handleWalletTap,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2A3A54) : Colors.white,
                              borderRadius: BorderRadius.circular(10.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: AppColors.legalGold,
                                  size: 16.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  _isBalanceVisible ? _currentBalance : '***',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    color: ratingTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        // Rating Section
                        Icon(
                          Icons.star_rounded,
                          color: const Color(0xFFFFC107),
                          size: 18.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          displayRating,
                          style: GoogleFonts.cairo(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: ratingTextColor,
                          ),
                        ),
                      ],
                    );
                  }
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                height: 40.h,
                width: 40.w,
                decoration: BoxDecoration(
                  color: bellContainerColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseAuth.instance.currentUser != null
                      ? FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .collection('notifications')
                          .where('isRead', isEqualTo: false)
                          .snapshots()
                      : null,
                  builder: (context, snapshot) {
                    int unreadCount = snapshot.data?.docs.length ?? 0;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          onPressed: widget.onNotificationTap,
                          icon: Icon(
                            Icons.notifications_none_rounded,
                            color: const Color(0xFFEF6A6A),
                            size: 22.sp,
                          ),
                          splashRadius: 20.r,
                          tooltip: 'Notifications'.translate(),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: 4.h,
                            right: 4.w,
                            child: Container(
                              padding: EdgeInsets.all(4.r),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unreadCount > 9 ? '9+' : unreadCount.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  }
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
