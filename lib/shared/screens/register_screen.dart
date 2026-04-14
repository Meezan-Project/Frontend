import 'package:flutter/material.dart';
import 'package:mezaan/lawyer/screens/lawyer_register_screen.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/screens/user_register_screen.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          const _ModernRegisterHeader(),
          Expanded(child: _buildRoleSelection(context, size)),
        ],
      ),
    );
  }

  Widget _buildRoleSelection(BuildContext context, Size size) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 42, 18, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            children: [
              Row(
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
                  const SizedBox(width: 14),
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
              const SizedBox(height: 22),
              Center(
                child: SizedBox(
                  width: 220,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        LoadingNavigator.pushNamed(context, AppRoutes.login),
                    icon: const Icon(Icons.login_rounded, size: 20),
                    label: const Text(
                      'Back to Login',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF042A52),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accentColor.withOpacity(0.16), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
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
                  const SizedBox(width: 14),
                  Expanded(child: _buildTextBlock(context)),
                ]
              : [
                  Expanded(child: _buildTextBlock(context)),
                  const SizedBox(width: 8),
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: accentColor, size: 28),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: imageOnLeft ? TextAlign.left : TextAlign.right,
          style: const TextStyle(
            color: Color(0xFF042A52),
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: imageOnLeft ? TextAlign.left : TextAlign.right,
          style: TextStyle(
            color: Colors.black.withOpacity(0.55),
            fontSize: 13,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Select',
            style: TextStyle(
              color: accentColor,
              fontSize: 12,
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
          const Positioned(
            bottom: 40,
            right: 40,
            child: _TiltHeaderCard(angle: 0.12, title: 'Secure'),
          ),
          const Positioned(
            top: 50,
            left: 30,
            child: _TiltHeaderCard(angle: -0.15, title: 'Trusted'),
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
                const SizedBox(height: 12),
                const Text(
                  'MEZAAN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Justice at Your Fingertips',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
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

class _TiltHeaderCard extends StatelessWidget {
  final double angle;
  final String title;

  const _TiltHeaderCard({required this.angle, required this.title});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
