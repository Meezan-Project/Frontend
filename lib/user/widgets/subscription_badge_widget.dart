import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';

class SubscriptionBadgeWidget extends StatelessWidget {
  final String tier;
  final bool isProfile;

  const SubscriptionBadgeWidget({
    super.key,
    required this.tier,
    this.isProfile = false,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedTier = tier.trim().toLowerCase();
    if (normalizedTier != 'elite' && normalizedTier != 'partner') {
      return const SizedBox.shrink();
    }

    final isPartner = normalizedTier == 'partner';
    final gradient = isPartner
        ? const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFE0E0E0), Color(0xFF9E9E9E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final icon = isPartner ? Icons.workspace_premium_rounded : Icons.star_rounded;
    final label = isPartner ? 'Partner'.translate() : 'Elite'.translate();
    final textColor = isPartner ? const Color(0xFF6B4700) : const Color(0xFF333333);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isProfile ? 10.w : 6.w,
        vertical: isProfile ? 4.h : 2.h,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: isPartner
            ? [
                BoxShadow(
                  // Fixed: withValues to withOpacity
                  color: const Color(0xFFFFD700).withOpacity(0.3),
                  blurRadius: 6,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                )
              ]
            : [
                BoxShadow(
                  // Fixed: withValues to withOpacity
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                )
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: textColor,
            size: isProfile ? 14.sp : 11.sp,
          ),
          SizedBox(width: 4.w),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: textColor,
              fontSize: isProfile ? 11.sp : 9.sp,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
