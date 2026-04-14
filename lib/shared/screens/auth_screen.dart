import 'package:flutter/material.dart';
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
        const SnackBar(content: Text('Please enter a phone number')),
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
    ).showSnackBar(SnackBar(content: Text('Login with $provider')));
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
                        'Join Meezan',
                        style: TextStyle(
                          fontSize: isTablet ? 34 : 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navyBlue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your Legal Partner',
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 16,
                          color: AppColors.textDark.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isTablet ? 44 : 30),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '+1 (555) 123-4567',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: isTablet ? 56 : 52,
                        child: ElevatedButton(
                          onPressed: _continueWithPhone,
                          child: const Text(
                            'Continue with Phone',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isTablet ? 34 : 28),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              thickness: 1,
                              color: AppColors.textDark.withValues(alpha: 0.2),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Or continue with',
                              style: TextStyle(
                                color: AppColors.textDark.withValues(
                                  alpha: 0.6,
                                ),
                                fontSize: 14,
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
                      SizedBox(height: isTablet ? 28 : 20),
                      Wrap(
                        alignment: WrapAlignment.spaceEvenly,
                        spacing: isTablet ? 20 : 12,
                        runSpacing: 14,
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
                      SizedBox(height: isTablet ? 48 : 34),
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
                                        child: const Text(
                                          'Login',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.navyBlue,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
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
                                        child: const Text(
                                          'Create New Account',
                                          style: TextStyle(
                                            fontSize: 16,
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
                                        child: const Text(
                                          'Login',
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
                                        child: const Text(
                                          'Create New Account',
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
