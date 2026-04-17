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
        padding: EdgeInsets.fromLTRB(18.w, 42.h, 18.w, 24.h),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: size.height * 0.44,
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
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: SizedBox(
                        height: size.height * 0.44,
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
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 22.h),
              Center(
                child: SizedBox(
                  width: 220.w,
                  height: 46.h,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        LoadingNavigator.pushNamed(context, AppRoutes.login),
                    icon: Icon(Icons.login_rounded, size: 20.sp),
                    label: Text(
                      'Back to Login'.translate(),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF042A52),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.all(10.r),
        padding: EdgeInsets.all(22.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: accentColor.withOpacity(0.16), width: 1.2),
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
        child: Row(
          children: imageOnLeft
              ? [
                  _buildCharacter(context),
                  SizedBox(width: 14.w),
                  Expanded(child: _buildTextBlock(context)),
                ]
              : [
                  Expanded(child: _buildTextBlock(context)),
                  SizedBox(width: 8.w),
                  _buildCharacter(context),
                ],
        ),
      ),
    );
  }

  Widget _buildCharacter(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.26,
      child: Align(
        alignment: imageOnLeft ? Alignment.centerLeft : Alignment.centerRight,
        child: Image.asset(
          charAsset,
          height: MediaQuery.of(context).size.height * 0.40,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const SizedBox(),
        ),
      ),
    );
  }

  Widget _buildTextBlock(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: imageOnLeft
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: accentColor, size: 28.sp),
        ),
        SizedBox(height: 14.h),
        Text(
          title.translate(),
          textAlign: imageOnLeft ? TextAlign.left : TextAlign.right,
          style: TextStyle(
            color: Color(0xFF042A52),
            fontSize: 24.sp,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          subtitle.translate(),
          textAlign: imageOnLeft ? TextAlign.left : TextAlign.right,
          style: TextStyle(
            color: Colors.black.withOpacity(0.55),
            fontSize: 13.sp,
            height: 1.3,
          ),
        ),
        SizedBox(height: 14.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999.r),
          ),
          child: Text(
            'Select'.translate(),
            style: TextStyle(
              color: accentColor,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
