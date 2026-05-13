import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/screens/user_balance_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserTopHeader extends StatefulWidget {
  final String balance;
  final String appName;
  final VoidCallback? onNotificationTap;

  const UserTopHeader({
    super.key,
    required this.balance,
    this.appName = 'Mezaan',
    this.onNotificationTap,
  });

  @override
  State<UserTopHeader> createState() => _UserTopHeaderState();
}

class _UserTopHeaderState extends State<UserTopHeader> {
  bool _isBalanceVisible = false;

  void _handleWalletTap() async {
    if (!_isBalanceVisible) {
      // إظهار نافذة إدخال / إنشاء رمز المرور
      final success = await WalletPasscodeDialog.show(context);

      if (success) {
        setState(() {
          _isBalanceVisible = true;
        });

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserBalanceScreen(currentBalance: widget.balance),
            ),
          );
        }
      }
    } else {
      // إذا كان الرصيد مكشوفاً بالفعل، انتقل لشاشة المحفظة مباشرة
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserBalanceScreen(currentBalance: widget.balance),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF162235) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF131313);
    final balanceTextColor = isDark ? Colors.white : AppColors.navyBlue;
    final balanceContainerColor = isDark
        ? const Color(0xFF1F2D45)
        : const Color(0xFFF7FAFC);
    final balanceBorderColor = isDark
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
                ),
              ),
              GestureDetector(
                onTap: _handleWalletTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: balanceContainerColor,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: balanceBorderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        color: balanceTextColor,
                        size: 18.sp,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        _isBalanceVisible ? widget.balance : '***',
                        style: GoogleFonts.cairo(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: balanceTextColor,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Icon(
                        _isBalanceVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: balanceTextColor,
                        size: 18.sp,
                      ),
                    ],
                  ),
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
                },
              ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
