import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mezaan/shared/auth/auth_state.dart';
import 'package:mezaan/shared/localization/localization_controller.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/widgets/language_toggle_button.dart';

enum LoginMethod { phone, email }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _googleWebClientId =
      '689791635864-976ekuhdir04je41sf4kgb8rppejcmga.apps.googleusercontent.com';

  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  LoginMethod _selectedMethod = LoginMethod.phone;
  bool _isPhoneValid = true;
  bool _isEmailValid = true;
  bool _isGoogleSigningIn = false;
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _navigateToHomeByRole() {
    final role = authState.role;
    switch (role) {
      case AppRole.lawyer:
        LoadingNavigator.pushReplacementNamed(context, AppRoutes.lawyerHome);
        break;
      case AppRole.admin:
        LoadingNavigator.pushReplacementNamed(context, AppRoutes.adminHome);
        break;
      case AppRole.user:
      default:
        LoadingNavigator.pushReplacementNamed(context, AppRoutes.userHome);
        break;
    }
  }

  Future<void> _handleSignIn() async {
    if (_isSigningIn) {
      return;
    }

    if (_selectedMethod == LoginMethod.phone) {
      if (_phoneController.text.length < 11) {
        setState(() => _isPhoneValid = false);
        return;
      }
      LoadingNavigator.pushNamed(context, AppRoutes.otp);
    } else {
      if (!_emailController.text.toLowerCase().endsWith('@gmail.com')) {
        setState(() => _isEmailValid = false);
        return;
      }
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password is required'.translate())),
        );
        return;
      }

      setState(() {
        _isSigningIn = true;
      });

      try {
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);

        final role = await _resolveRoleForCurrentUser(credential.user);
        authState.loginAs(role);

        if (!mounted) {
          return;
        }

        _navigateToHomeByRole();
      } on FirebaseAuthException catch (error) {
        if (!mounted) {
          return;
        }

        final message = switch (error.code) {
          'invalid-credential' =>
            'Invalid email or password. Please try again.'.translate(),
          'user-not-found' => 'No account found for this email.'.translate(),
          'wrong-password' =>
            'Invalid email or password. Please try again.'.translate(),
          'too-many-requests' =>
            'Too many attempts. Please try again later.'.translate(),
          _ => (error.message ?? 'Login failed. Please try again.').translate(),
        };

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      } catch (_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed. Please try again.'.translate()),
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSigningIn = false;
          });
        }
      }
    }
  }

  Future<AppRole> _resolveRoleForCurrentUser(User? user) async {
    if (user == null) {
      return AppRole.user;
    }

    final firestore = FirebaseFirestore.instance;
    final userDoc = await firestore.collection('users').doc(user.uid).get();

    Map<String, dynamic>? data = userDoc.data();

    if ((data == null || data.isEmpty) && user.email != null) {
      final byEmail = await firestore
          .collection('users')
          .where('email', isEqualTo: user.email!.trim())
          .limit(1)
          .get();
      if (byEmail.docs.isNotEmpty) {
        data = byEmail.docs.first.data();
      }
    }

    final rawRole = (data?['role'] ?? data?['accountType'] ?? 'user')
        .toString()
        .trim()
        .toLowerCase();

    if (rawRole == 'admin') {
      return AppRole.admin;
    }
    if (rawRole == 'lawyer') {
      return AppRole.lawyer;
    }
    return AppRole.user;
  }

  void _handleGuestSignIn() {
    authState.loginAs(AppRole.user);
    LoadingNavigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.userHome,
      (route) => false,
    );
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isGoogleSigningIn) return;

    setState(() {
      _isGoogleSigningIn = true;
    });

    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: _googleWebClientId,
        scopes: ['email', 'profile'],
      );

      final account = await googleSignIn.signIn();
      if (account == null) {
        return;
      }

      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;
      final role = await _resolveRoleForCurrentUser(
        FirebaseAuth.instance.currentUser,
      );
      authState.loginAs(role);
      final homeRoute = switch (role) {
        AppRole.admin => AppRoutes.adminHome,
        AppRole.lawyer => AppRoutes.lawyerHome,
        AppRole.user => AppRoutes.userHome,
      };
      LoadingNavigator.pushNamedAndRemoveUntil(
        context,
        homeRoute,
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-in failed. Please try again.'.translate()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleSigningIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.width > 600;
    final localizationController = LocalizationController.instance;

    return Obx(() {
      localizationController.currentLanguage.value;

      return Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(
            children: [
              // 1. المودرن هيدر الأصلي مع الـ Slogan
              const _ModernLoginHeader(),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isTablet ? 500 : double.infinity,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 16.h),
                      Text(
                        'Welcome Back'.translate(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32.sp,
                          fontWeight: FontWeight.w900,
                          color: AppColors.navyBlue,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Sign in to access your legal dashboard'.translate(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: AppColors.textDark.withOpacity(0.5),
                        ),
                      ),
                      SizedBox(height: 32.h),

                      // 2. الـ Login Form
                      Container(
                        padding: EdgeInsets.all(24.r),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundGrey,
                          borderRadius: BorderRadius.circular(28.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 20,
                              offset: Offset(0, 10.h),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _AuthMethodTabs(
                              selectedMethod: _selectedMethod,
                              onMethodChanged: (method) =>
                                  setState(() => _selectedMethod = method),
                            ),
                            SizedBox(height: 28.h),
                            if (_selectedMethod == LoginMethod.phone)
                              _PhoneField(
                                controller: _phoneController,
                                isValid: _isPhoneValid,
                                onChanged: (val) => setState(
                                  () => _isPhoneValid = val.length == 11,
                                ),
                              ),
                            if (_selectedMethod == LoginMethod.email) ...[
                              _EmailField(
                                controller: _emailController,
                                isValid: _isEmailValid,
                                onChanged: (val) => setState(
                                  () => _isEmailValid = val
                                      .toLowerCase()
                                      .endsWith('@gmail.com'),
                                ),
                              ),
                              SizedBox(height: 16.h),
                              _PasswordField(controller: _passwordController),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 32.h),

                      // 3. زرار الـ Sign In
                      SizedBox(
                        height: 58.h,
                        child: ElevatedButton(
                          onPressed: _isSigningIn ? null : _handleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navyBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            elevation: 0,
                          ),
                          child: _isSigningIn
                              ? SizedBox(
                                  width: 22.w,
                                  height: 22.h,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Sign In'.translate(),
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      SizedBox(height: 12.h),
                      SizedBox(
                        height: 52.h,
                        child: OutlinedButton.icon(
                          onPressed: _isGoogleSigningIn
                              ? null
                              : _handleGoogleSignIn,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFFDADCE0),
                              width: 1.2,
                            ),
                            foregroundColor: AppColors.navyBlue,
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                          icon: _isGoogleSigningIn
                              ? SizedBox(
                                  width: 18.w,
                                  height: 18.h,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.g_mobiledata_rounded,
                                  size: 26,
                                ),
                          label: Text(
                            _isGoogleSigningIn
                                ? 'Signing in with Google...'.translate()
                                : 'Continue with Google'.translate(),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 12.h),
                      SizedBox(
                        height: 52.h,
                        child: OutlinedButton(
                          onPressed: _handleGuestSignIn,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.navyBlue,
                              width: 1.6,
                            ),
                            foregroundColor: AppColors.navyBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                          child: Text(
                            'Sign in as Guest'.translate(),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 24.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ".translate(),
                            style: TextStyle(
                              color: AppColors.textDark.withOpacity(0.6),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => LoadingNavigator.pushNamed(
                              context,
                              AppRoutes.register,
                            ),
                            child: Text(
                              'Create'.translate(),
                              style: TextStyle(
                                color: AppColors.legalGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 16.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 40.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// --- الهيدر المودرن مع الـ Slogan ---

class _ModernLoginHeader extends StatelessWidget {
  const _ModernLoginHeader();

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
          // شكل جمالي دائري خلفي
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

          // الكروت المايلة (الرجوع للتصميم الأول)
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

          // النص في المنتصف (Logo + Slogan)
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
                // الـ Slogan اللي طلبته
                Text(
                  'Justice at Your Fingertips'.translate(),
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
        width: 85,
        height: 110,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.gavel_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthMethodTabs extends StatelessWidget {
  final LoginMethod selectedMethod;
  final ValueChanged<LoginMethod> onMethodChanged;
  const _AuthMethodTabs({
    required this.selectedMethod,
    required this.onMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTab('Phone', LoginMethod.phone)),
          Expanded(child: _buildTab('Email', LoginMethod.email)),
        ],
      ),
    );
  }

  Widget _buildTab(String label, LoginMethod method) {
    final bool isSelected = selectedMethod == method;
    return GestureDetector(
      onTap: () => onMethodChanged(method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navyBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label.translate(),
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final bool isValid;
  final Function(String) onChanged;
  const _PhoneField({
    required this.controller,
    required this.isValid,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11),
      ],
      decoration: InputDecoration(
        prefixIcon: const Icon(
          Icons.phone_android_rounded,
          color: AppColors.navyBlue,
        ),
        hintText: '11-digit mobile number'.translate(),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isValid ? Colors.transparent : Colors.red,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isValid ? AppColors.legalGold : Colors.red,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  final TextEditingController controller;
  final bool isValid;
  final Function(String) onChanged;
  const _EmailField({
    required this.controller,
    required this.isValid,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.navyBlue),
        hintText: 'example@gmail.com'.translate(),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isValid ? Colors.transparent : Colors.red,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isValid ? AppColors.legalGold : Colors.red,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  const _PasswordField({required this.controller});
  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _isObscured = true;
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _isObscured,
      decoration: InputDecoration(
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: AppColors.navyBlue,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _isObscured ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: () => setState(() => _isObscured = !_isObscured),
        ),
        hintText: 'Password'.translate(),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
