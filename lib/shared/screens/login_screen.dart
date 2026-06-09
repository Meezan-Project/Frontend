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
import 'package:mezaan/shared/screens/otp_screen.dart';
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

  static final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

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
      case AppRole.secretary:
        LoadingNavigator.pushReplacementNamed(context, AppRoutes.secretaryHome);
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
      final normalizedPhone = _normalizePhoneToE164(_phoneController.text);
      if (normalizedPhone == null) {
        setState(() => _isPhoneValid = false);
        return;
      }

      final isRegisteredPhone = await _isPhoneRegistered(normalizedPhone);
      if (!isRegisteredPhone) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This phone number is not registered. Please create an account first.'
                  .translate(),
            ),
          ),
        );
        return;
      }

      setState(() {
        _isPhoneValid = true;
        _isSigningIn = true;
      });

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: normalizedPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final result = await FirebaseAuth.instance.signInWithCredential(
              credential,
            );
            final role = await _resolveRoleForCurrentUser(
              result.user,
              loginIdentifier: normalizedPhone,
            );
            authState.loginAs(role);
            await authState.cacheRoleHint(
              identifier: normalizedPhone,
              role: role,
            );

            if (!mounted) {
              return;
            }
            _navigateToHomeByRole();
          } catch (_) {
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Phone sign-in failed.'.translate())),
            );
          } finally {
            if (mounted) {
              setState(() {
                _isSigningIn = false;
              });
            }
          }
        },
        verificationFailed: (FirebaseAuthException error) {
          if (!mounted) {
            return;
          }

          final rawMessage = (error.message ?? '').toLowerCase();
          final message = switch (error.code) {
            'invalid-phone-number' =>
              'Please enter a valid phone number.'.translate(),
            'too-many-requests' =>
              'Too many requests. Try again later.'.translate(),
            'billing-not-enabled' =>
              'Phone OTP is blocked: enable billing in Firebase/Google Cloud for this project.'
                  .translate(),
            _ =>
              rawMessage.contains('billing_not_enabled') ||
                      rawMessage.contains('billing-not-enabled')
                  ? 'Phone OTP is blocked: enable billing in Firebase/Google Cloud for this project.'
                        .translate()
                  : (error.message ?? 'Could not send OTP.').translate(),
          };

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));

          setState(() {
            _isSigningIn = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) {
            return;
          }

          setState(() {
            _isSigningIn = false;
          });

          LoadingNavigator.pushNamed(
            context,
            AppRoutes.otp,
            arguments: OtpScreenArgs(
              verificationId: verificationId,
              phoneNumber: normalizedPhone,
              resendToken: resendToken,
            ),
          );
        },
        codeAutoRetrievalTimeout: (_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _isSigningIn = false;
          });
        },
      );
    } else {
      if (!_isValidEmail(_emailController.text)) {
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

        final role = await _resolveRoleForCurrentUser(
          credential.user,
          loginIdentifier: email,
        );
        authState.loginAs(role);
        await authState.cacheRoleHint(identifier: email, role: role);

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

  String? _normalizePhoneToE164(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return null;
    }

    if (digits.length == 11 && digits.startsWith('0')) {
      return '+2$digits';
    }

    if (digits.length == 12 && digits.startsWith('20')) {
      return '+$digits';
    }

    if (digits.length == 13 && digits.startsWith('201')) {
      return '+$digits';
    }

    return null;
  }

  bool _isValidEmail(String input) {
    return _emailRegex.hasMatch(input.trim().toLowerCase());
  }

  Future<AppRole> _resolveRoleForCurrentUser(
    User? user, {
    String? loginIdentifier,
  }) async {
    if (user == null) {
      return AppRole.user;
    }

    final firestore = FirebaseFirestore.instance;
    final normalizedEmail = user.email?.trim().toLowerCase();
    final normalizedPhone = user.phoneNumber;

    try {
      // 1) Fast path by UID in lawyers collection.
      final lawyerDoc = await _tryGetDoc(
        firestore.collection('lawyers').doc(user.uid),
      );
      if (lawyerDoc != null && lawyerDoc.exists) {
        final role = _roleFromDocData(lawyerDoc.data(), fallback: AppRole.lawyer);
        if (loginIdentifier != null) {
          await authState.cacheRoleHint(identifier: loginIdentifier, role: role);
        }
        return role;
      }

      // 3) Query lawyers by phone
      if (normalizedPhone != null && normalizedPhone.isNotEmpty) {
        final lawyerByPhone = await _tryQueryFirst(
          firestore
              .collection('lawyers')
              .where('phone', isEqualTo: normalizedPhone)
              .limit(1),
        );
        if (lawyerByPhone != null && lawyerByPhone.docs.isNotEmpty) {
          final role = _roleFromDocData(
            lawyerByPhone.docs.first.data(),
            fallback: AppRole.lawyer,
          );
          if (loginIdentifier != null) {
            await authState.cacheRoleHint(identifier: loginIdentifier, role: role);
          }
          return role;
        }
      }

      if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
        // 4) Query lawyers by emailLower first, then email.
        final lawyerByEmailLower = await _tryQueryFirst(
          firestore
              .collection('lawyers')
              .where('emailLower', isEqualTo: normalizedEmail)
              .limit(1),
        );
        if (lawyerByEmailLower != null && lawyerByEmailLower.docs.isNotEmpty) {
          final role = _roleFromDocData(
            lawyerByEmailLower.docs.first.data(),
            fallback: AppRole.lawyer,
          );
          if (loginIdentifier != null) {
            await authState.cacheRoleHint(identifier: loginIdentifier, role: role);
          }
          return role;
        }

        final lawyerByEmail = await _tryQueryFirst(
          firestore
              .collection('lawyers')
              .where('email', isEqualTo: user.email!.trim())
              .limit(1),
        );
        if (lawyerByEmail != null && lawyerByEmail.docs.isNotEmpty) {
          final role = _roleFromDocData(
            lawyerByEmail.docs.first.data(),
            fallback: AppRole.lawyer,
          );
          if (loginIdentifier != null) {
            await authState.cacheRoleHint(identifier: loginIdentifier, role: role);
          }
          return role;
        }
      }

      // 5) Fast path by UID in users collection.
      final userDoc = await _tryGetDoc(
        firestore.collection('users').doc(user.uid),
      );
      if (userDoc != null && userDoc.exists) {
        final role = _roleFromDocData(userDoc.data(), fallback: AppRole.user);
        if (loginIdentifier != null) {
          await authState.cacheRoleHint(identifier: loginIdentifier, role: role);
        }
        return role;
      }

      if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
        // 6) Query users by emailLower first, then email.
        final userByEmailLower = await _tryQueryFirst(
          firestore
              .collection('users')
              .where('emailLower', isEqualTo: normalizedEmail)
              .limit(1),
        );
        if (userByEmailLower != null && userByEmailLower.docs.isNotEmpty) {
          final role = _roleFromDocData(
            userByEmailLower.docs.first.data(),
            fallback: AppRole.user,
          );
          if (loginIdentifier != null) {
            await authState.cacheRoleHint(identifier: loginIdentifier, role: role);
          }
          return role;
        }

        final userByEmail = await _tryQueryFirst(
          firestore
              .collection('users')
              .where('email', isEqualTo: user.email!.trim())
              .limit(1),
        );
        if (userByEmail != null && userByEmail.docs.isNotEmpty) {
          final role = _roleFromDocData(
            userByEmail.docs.first.data(),
            fallback: AppRole.user,
          );
          if (loginIdentifier != null) {
            await authState.cacheRoleHint(identifier: loginIdentifier, role: role);
          }
          return role;
        }
      }

      // 6) Query users by phone
      if (normalizedPhone != null && normalizedPhone.isNotEmpty) {
        final userByPhone = await _tryQueryFirst(
          firestore
              .collection('users')
              .where('phone', isEqualTo: normalizedPhone)
              .limit(1),
        );
        if (userByPhone != null && userByPhone.docs.isNotEmpty) {
          final role = _roleFromDocData(
            userByPhone.docs.first.data(),
            fallback: AppRole.user,
          );
          if (loginIdentifier != null) {
            await authState.cacheRoleHint(identifier: loginIdentifier, role: role);
          }
          return role;
        }
      }
    } catch (e) {
      debugPrint('Error querying Firestore for role: $e');
    }

    if (loginIdentifier != null) {
      final cachedRole = await authState.resolveRoleHint(loginIdentifier);
      if (cachedRole != null) {
        return cachedRole;
      }
    }

    return AppRole.user;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _tryGetDoc(
    DocumentReference<Map<String, dynamic>> docRef,
  ) async {
    try {
      return await docRef.get();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return null;
      }
      rethrow;
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>?> _tryQueryFirst(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      return await query.get();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return null;
      }
      rethrow;
    }
  }

  AppRole _roleFromDocData(
    Map<String, dynamic>? data, {
    required AppRole fallback,
  }) {
    if (data == null || data.isEmpty) {
      return fallback;
    }

    final rawRoleValue =
        data['role'] ?? data['accountType'] ?? data['userType'];

    if (rawRoleValue == null) {
      return fallback;
    }

    final rawRole = rawRoleValue.toString().trim().toLowerCase();

    if (rawRole == 'admin') {
      return AppRole.admin;
    }
    if (rawRole == 'lawyer') {
      return AppRole.lawyer;
    }
    if (rawRole == 'secretary') {
      return AppRole.secretary;
    }
    if (rawRole == 'user') {
      return AppRole.user;
    }

    return fallback;
  }

  Future<bool> _isPhoneRegistered(String normalizedPhone) async {
    final userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: normalizedPhone)
        .limit(1)
        .get();
    if (userSnapshot.docs.isNotEmpty) return true;

    final lawyerSnapshot = await FirebaseFirestore.instance
        .collection('lawyers')
        .where('phone', isEqualTo: normalizedPhone)
        .limit(1)
        .get();
    return lawyerSnapshot.docs.isNotEmpty;
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
        loginIdentifier: FirebaseAuth.instance.currentUser?.email,
      );
      authState.loginAs(role);
      final currentEmail = FirebaseAuth.instance.currentUser?.email;
      if (currentEmail != null && currentEmail.trim().isNotEmpty) {
        await authState.cacheRoleHint(identifier: currentEmail, role: role);
      }
      final homeRoute = switch (role) {
        AppRole.admin => AppRoutes.adminHome,
        AppRole.lawyer => AppRoutes.lawyerHome,
        AppRole.secretary => AppRoutes.secretaryHome,
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
                                  () => _isEmailValid = _isValidEmail(val),
                                ),
                              ),
                              SizedBox(height: 16.h),
                              _PasswordField(controller: _passwordController),
                              SizedBox(height: 8.h),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => LoadingNavigator.pushNamed(
                                    context,
                                    AppRoutes.forgotPassword,
                                  ),
                                  style: TextButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4.w,
                                      vertical: 4.h,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Forgot password?'.translate(),
                                    style: TextStyle(
                                      color: AppColors.legalGold,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.sp,
                                    ),
                                  ),
                                ),
                              ),
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
