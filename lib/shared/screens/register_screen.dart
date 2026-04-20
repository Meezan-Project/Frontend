import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:mezaan/lawyer/screens/lawyer_register_screen.dart';
import 'package:mezaan/shared/localization/localization_controller.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/widgets/language_toggle_button.dart';
import 'package:mezaan/user/screens/user_register_screen.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final localizationController = LocalizationController.instance;

    return Obx(() {
      localizationController.currentLanguage.value;

      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Column(
          children: [
            _ModernRegisterHeader(),
            Expanded(child: _buildRoleSelection(context, size)),
          ],
        ),
      );
    });
  }

  Widget _buildRoleSelection(BuildContext context, Size size) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(10.w, 30.h, 10.w, 20.h),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 760;
              final double cardHeight = (size.height * 0.48).clamp(
                330.0,
                520.0,
              );

              final userCard = SizedBox(
                height: cardHeight,
                child: _RoleSelectionCard(
                  title: 'Join As User',
                  subtitle: 'Tap to start user registration',
                  icon: Icons.person_add_alt_1_rounded,
                  accentColor: const Color(0xFF042A52),
                  charAsset: 'assets/images/user_char.png',
                  imageOnLeft: true,
                  onTap: () {
                    LoadingNavigator.pushPage(
                      context,
                      const UserRegisterScreen(),
                    );
                  },
                ),
              );

              final lawyerCard = SizedBox(
                height: cardHeight,
                child: _RoleSelectionCard(
                  title: 'Join As Lawyer',
                  subtitle: 'Tap to start lawyer registration',
                  icon: Icons.gavel_rounded,
                  accentColor: const Color(0xFF0B5E55),
                  charAsset: 'assets/images/lawyer_char.png',
                  imageOnLeft: false,
                  onTap: () {
                    LoadingNavigator.pushPage(
                      context,
                      const LawyerRegisterScreen(),
                    );
                  },
                ),
              );

              return Column(
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      children: [
                        Expanded(child: userCard),
                        SizedBox(width: 8.w),
                        Expanded(child: lawyerCard),
                      ],
                    ),
                  ),
                  SizedBox(height: 22.h),
                  Center(
                    child: SizedBox(
                      width: isNarrow ? double.infinity : 280.w,
                      height: 46.h,
                      child: ElevatedButton(
                        onPressed: () => LoadingNavigator.pushNamed(
                          context,
                          AppRoutes.login,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF042A52),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.login_rounded, size: 20.sp),
                            SizedBox(width: 8.w),
                            Flexible(
                              child: Text(
                                'Back to Login'.translate(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RoleSelectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String charAsset;
  final IconData icon;
  final Color accentColor;
  final bool imageOnLeft;
  final VoidCallback onTap;

  const _RoleSelectionCard({
    required this.title,
    required this.subtitle,
    required this.charAsset,
    required this.icon,
    required this.accentColor,
    required this.imageOnLeft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 430;
        final bool veryCompact = constraints.maxWidth < 220;
        final double characterPaneWidth = compact
            ? constraints.maxWidth
            : (constraints.maxWidth * 0.44).clamp(110.0, 220.0);
        final double characterHeight =
            (constraints.maxHeight * (compact ? 0.56 : 0.86)).clamp(
              150.0,
              340.0,
            );

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: EdgeInsets.all(4.r),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12.w : 20.w,
              vertical: compact ? 12.h : 20.h,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(
                color: accentColor.withOpacity(0.16),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 18,
                  offset: Offset(0, 8.h),
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, accentColor.withOpacity(0.04)],
              ),
            ),
            child: compact
                ? Column(
                    children: [
                      _buildCharacter(
                        paneWidth: characterPaneWidth,
                        imageHeight: characterHeight,
                        alignment: Alignment.center,
                      ),
                      SizedBox(height: 8.h),
                      Expanded(
                        child: _buildTextBlock(
                          context,
                          compact: compact,
                          veryCompact: veryCompact,
                          centered: true,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: imageOnLeft
                        ? [
                            _buildCharacter(
                              paneWidth: characterPaneWidth,
                              imageHeight: characterHeight,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _buildTextBlock(
                                context,
                                compact: compact,
                                veryCompact: veryCompact,
                                centered: false,
                              ),
                            ),
                          ]
                        : [
                            Expanded(
                              child: _buildTextBlock(
                                context,
                                compact: compact,
                                veryCompact: veryCompact,
                                centered: false,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            _buildCharacter(
                              paneWidth: characterPaneWidth,
                              imageHeight: characterHeight,
                            ),
                          ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildCharacter({
    required double paneWidth,
    required double imageHeight,
    Alignment? alignment,
  }) {
    return SizedBox(
      width: paneWidth,
      child: Align(
        alignment:
            alignment ??
            (imageOnLeft ? Alignment.centerLeft : Alignment.centerRight),
        child: Image.asset(
          charAsset,
          height: imageHeight,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const SizedBox(),
        ),
      ),
    );
  }

  Widget _buildTextBlock(
    BuildContext context, {
    required bool compact,
    required bool veryCompact,
    required bool centered,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool shortCard = constraints.maxHeight < 300;

        final double iconSize = compact
            ? (veryCompact ? 26.sp : (shortCard ? 26.sp : 28.sp))
            : (shortCard ? 26.sp : 32.sp);
        final double titleSize = compact
            ? (veryCompact ? 26.sp : (shortCard ? 24.sp : 26.sp))
            : (shortCard ? 26.sp : 30.sp);
        final double subtitleSize = compact
            ? (shortCard ? 12.sp : 13.sp)
            : (shortCard ? 13.sp : 15.sp);
        final double chipSize = compact
            ? (veryCompact ? 13.sp : (shortCard ? 11.sp : 12.sp))
            : (shortCard ? 12.sp : 14.sp);

        final content = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: centered
              ? CrossAxisAlignment.center
              : (imageOnLeft
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end),
          children: [
            Container(
              padding: EdgeInsets.all(compact ? 9.r : 12.r),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: iconSize),
            ),
            SizedBox(height: shortCard ? 8.h : 14.h),
            Text(
              title.translate(),
              textAlign: centered
                  ? TextAlign.center
                  : (imageOnLeft ? TextAlign.left : TextAlign.right),
              style: TextStyle(
                color: const Color(0xFF042A52),
                fontSize: titleSize,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
              maxLines: veryCompact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (!veryCompact) ...[
              SizedBox(height: shortCard ? 6.h : 8.h),
              Text(
                subtitle.translate(),
                textAlign: centered
                    ? TextAlign.center
                    : (imageOnLeft ? TextAlign.left : TextAlign.right),
                style: TextStyle(
                  color: Colors.black.withOpacity(0.55),
                  fontSize: subtitleSize,
                  height: 1.3,
                ),
                maxLines: shortCard ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: shortCard ? 8.h : 14.h),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? (veryCompact ? 12.w : 10.w) : 14.w,
                vertical: compact ? 4.h : 6.h,
              ),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(999.r),
              ),
              child: Text(
                'Select'.translate(),
                style: TextStyle(
                  color: accentColor,
                  fontSize: chipSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );

        if (centered && !veryCompact) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: content,
            ),
          );
        }

        return content;
      },
    );
  }
}

class _ModernRegisterHeader extends StatelessWidget {
  const _ModernRegisterHeader();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      height: size.height * 0.35,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navyBlue, Color(0xFF003366), AppColors.legalGold],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(50)),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: LanguageToggleButton(
                  backgroundColor: Colors.white24,
                  iconColor: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            top: -20,
            left: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.balance_rounded,
                  color: AppColors.legalGold,
                  size: 70,
                ),
                SizedBox(height: 12.h),
                Text(
                  'MEZAAN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Justice at Your Fingertips'.translate(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
