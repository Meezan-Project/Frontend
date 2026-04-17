import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _continueWithPhone() {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a phone number'.translate())),
      );
      return;
    }
    // TODO: Implement phone verification logic
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Phone: ${_phoneController.text}')));
  }

  void _continueWithSocial(String provider) {
    // TODO: Implement social login logic
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${'Login'.translate()} $provider')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isTablet = constraints.maxWidth >= 600;
            final bool isNarrow = constraints.maxWidth < 360;
            final bool isUltraSmall = constraints.maxWidth < 330;
            final double horizontalPadding = (constraints.maxWidth * 0.06)
                .clamp(16.0, 32.0)
                .toDouble();
            final double verticalPadding = (constraints.maxHeight * 0.03)
                .clamp(16.0, 28.0)
                .toDouble();
            final double contentMaxWidth = isTablet ? 560 : 430;
            final double actionsMaxWidth = isTablet ? 460 : double.infinity;
            final double socialButtonWidth = isTablet
                ? 120
                : isUltraSmall
                ? 84
                : 92;
            final double socialIconBoxSize = isTablet
                ? 64
                : isUltraSmall
                ? 52
                : 60;
            final double socialIconSize = isTablet
                ? 34
                : isUltraSmall
                ? 28
                : 32;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (verticalPadding * 2),
                    maxWidth: contentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: isTablet ? 20 : 12),
                      Text(
                        'Join Meezan'.translate(),
                        style: TextStyle(
                          fontSize: (isTablet ? 34 : 28).sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navyBlue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Your Legal Partner'.translate(),
                        style: TextStyle(
                          fontSize: (isTablet ? 18 : 16).sp,
                          color: AppColors.textDark.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: (isTablet ? 44 : 30).h),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '+1 (555) 123-4567',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      SizedBox(
                        height: (isTablet ? 56 : 52).h,
                        child: ElevatedButton(
                          onPressed: _continueWithPhone,
                          child: Text(
                            'Continue with Phone'.translate(),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: (isTablet ? 34 : 28).h),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              thickness: 1,
                              color: AppColors.textDark.withValues(alpha: 0.2),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.w),
                            child: Text(
                              'Or continue with'.translate(),
                              style: TextStyle(
                                color: AppColors.textDark.withValues(
                                  alpha: 0.6,
                                ),
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              thickness: 1,
                              color: AppColors.textDark.withValues(alpha: 0.2),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: (isTablet ? 28 : 20).h),
                      Wrap(
                        alignment: WrapAlignment.spaceEvenly,
                        spacing: (isTablet ? 20 : 12).w,
                        runSpacing: 14.h,
                        children: [
                          SizedBox(
                            width: socialButtonWidth,
                            child: _SocialLoginButton(
                              icon: Icons.facebook,
                              label: 'Facebook',
                              color: const Color(0xFF1877F2),
                              iconBoxSize: socialIconBoxSize,
                              iconSize: socialIconSize,
                              onPressed: () => _continueWithSocial('Facebook'),
                            ),
                          ),
                          SizedBox(
                            width: socialButtonWidth,
                            child: _SocialLoginButton(
                              icon: Icons.g_mobiledata,
                              label: 'Google',
                              color: const Color(0xFFEA4335),
                              iconBoxSize: socialIconBoxSize,
                              iconSize: socialIconSize,
                              onPressed: () => _continueWithSocial('Google'),
                            ),
                          ),
                          SizedBox(
                            width: socialButtonWidth,
                            child: _SocialLoginButton(
                              icon: Icons.apple,
                              label: 'Apple',
                              color: AppColors.textDark,
                              iconBoxSize: socialIconBoxSize,
                              iconSize: socialIconSize,
                              onPressed: () => _continueWithSocial('Apple'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: (isTablet ? 48 : 34).h),
                      Align(
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: actionsMaxWidth,
                          ),
                          child: isNarrow
                              ? Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: AppColors.navyBlue,
                                            width: 2,
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            vertical: 14.h,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8.r,
                                            ),
                                          ),
                                        ),
                                        onPressed: () {
                                          LoadingNavigator.pushReplacementNamed(
                                            context,
                                            AppRoutes.login,
                                          );
                                        },
                                        child: Text(
                                          'Login'.translate(),
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.navyBlue,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 10.h),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.legalGold,
                                          padding: EdgeInsets.symmetric(
                                            vertical: 14.h,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8.r,
                                            ),
                                          ),
                                        ),
                                        onPressed: () {
                                          LoadingNavigator.pushReplacementNamed(
                                            context,
                                            AppRoutes.register,
                                          );
                                        },
                                        child: Text(
                                          'Create New Account'.translate(),
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: AppColors.navyBlue,
                                            width: 2,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        onPressed: () {
                                          LoadingNavigator.pushReplacementNamed(
                                            context,
                                            AppRoutes.login,
                                          );
                                        },
                                        child: Text(
                                          'Login'.translate(),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.navyBlue,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.legalGold,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        onPressed: () {
                                          LoadingNavigator.pushReplacementNamed(
                                            context,
                                            AppRoutes.register,
                                          );
                                        },
                                        child: Text(
                                          'Create New Account'.translate(),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      SizedBox(height: isTablet ? 28 : 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double iconBoxSize;
  final double iconSize;
  final VoidCallback onPressed;

  const _SocialLoginButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconBoxSize,
    required this.iconSize,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: iconBoxSize,
          height: iconBoxSize,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: Icon(icon, color: color, size: iconSize),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textDark.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
