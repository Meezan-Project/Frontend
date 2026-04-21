import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mezaan/shared/auth/auth_state.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class OtpScreenArgs {
  final String verificationId;
  final String phoneNumber;
  final int? resendToken;

  const OtpScreenArgs({
    required this.verificationId,
    required this.phoneNumber,
    this.resendToken,
  });
}

class OtpScreen extends StatefulWidget {
  final OtpScreenArgs args;

  const OtpScreen({super.key, required this.args});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  late final TextEditingController _codeController;
  late String _verificationId;
  bool _isSubmitting = false;
  bool _isResending = false;
  int? _resendToken;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _verificationId = widget.args.verificationId;
    _resendToken = widget.args.resendToken;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter the 6-digit OTP code.'.translate())),
      );
      return;
    }

    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: code,
      );

      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final verifiedPhone = result.user?.phoneNumber;
      if (verifiedPhone == null || !(await _isRegisteredPhone(verifiedPhone))) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This phone number is not linked to any existing account.'
                  .translate(),
            ),
          ),
        );
        return;
      }

      final role = await _resolveRoleForCurrentUser(result.user);
      authState.loginAs(role);

      if (!mounted) {
        return;
      }

      final targetRoute = switch (role) {
        AppRole.admin => AppRoutes.adminHome,
        AppRole.lawyer => AppRoutes.lawyerHome,
        AppRole.user => AppRoutes.userHome,
      };

      LoadingNavigator.pushNamedAndRemoveUntil(
        context,
        targetRoute,
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      final message = switch (error.code) {
        'invalid-verification-code' =>
          'The OTP code is invalid. Please try again.'.translate(),
        'session-expired' =>
          'OTP expired. Please request a new code.'.translate(),
        _ => (error.message ?? 'Could not verify OTP.').translate(),
      };

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    if (_isResending) {
      return;
    }

    setState(() {
      _isResending = true;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.args.phoneNumber,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final result = await FirebaseAuth.instance.signInWithCredential(
            credential,
          );
          final verifiedPhone = result.user?.phoneNumber;
          if (verifiedPhone == null ||
              !(await _isRegisteredPhone(verifiedPhone))) {
            await FirebaseAuth.instance.signOut();
            return;
          }

          final role = await _resolveRoleForCurrentUser(result.user);
          authState.loginAs(role);

          if (!mounted) {
            return;
          }
          final targetRoute = switch (role) {
            AppRole.admin => AppRoutes.adminHome,
            AppRole.lawyer => AppRoutes.lawyerHome,
            AppRole.user => AppRoutes.userHome,
          };
          LoadingNavigator.pushNamedAndRemoveUntil(
            context,
            targetRoute,
            (route) => false,
          );
        } catch (_) {}
      },
      verificationFailed: (FirebaseAuthException error) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (error.message ?? 'Could not resend OTP.').translate(),
            ),
          ),
        );

        setState(() {
          _isResending = false;
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) {
          return;
        }

        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isResending = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('OTP sent again.'.translate())));
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!mounted) {
          return;
        }

        setState(() {
          _verificationId = verificationId;
          _isResending = false;
        });
      },
    );
  }

  Future<AppRole> _resolveRoleForCurrentUser(User? user) async {
    if (user == null) {
      return AppRole.user;
    }

    final firestore = FirebaseFirestore.instance;
    final userDoc = await firestore.collection('users').doc(user.uid).get();

    Map<String, dynamic>? data = userDoc.data();

    if ((data == null || data.isEmpty) && user.phoneNumber != null) {
      final byPhone = await firestore
          .collection('users')
          .where('phone', isEqualTo: user.phoneNumber)
          .limit(1)
          .get();
      if (byPhone.docs.isNotEmpty) {
        data = byPhone.docs.first.data();
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

  Future<bool> _isRegisteredPhone(String phoneNumber) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: phoneNumber)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: size.height * 0.28,
              decoration: BoxDecoration(
                color: AppColors.navyBlue,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(40.r),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 26.h, 24.w, 20.h),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 52.sp,
                        color: AppColors.legalGold,
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        'OTP Verification'.translate(),
                        style: TextStyle(
                          fontSize: 30.sp,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Mezaan Security'.translate(),
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.86),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 20.h),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 460.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.args.phoneNumber,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navyBlue,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Enter the 6-digit code sent by Firebase to your phone.'
                          .translate(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: AppColors.textDark.withValues(alpha: 0.62),
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30.sp,
                        letterSpacing: 16.w,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyBlue,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: InputDecoration(
                        hintText: '------',
                        hintStyle: TextStyle(
                          fontSize: 24.sp,
                          letterSpacing: 16.w,
                          color: AppColors.textDark.withValues(alpha: 0.3),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 22.h,
                          horizontal: 18.w,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: const BorderSide(
                            color: AppColors.legalGold,
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    SizedBox(
                      height: 58.h,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _verifyOtp,
                        style:
                            ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navyBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              shadowColor: Colors.transparent,
                            ).copyWith(
                              shadowColor: WidgetStateProperty.all(
                                Colors.black.withValues(alpha: 0.12),
                              ),
                              elevation: WidgetStateProperty.all(6),
                            ),
                        child: _isSubmitting
                            ? SizedBox(
                                width: 22.w,
                                height: 22.h,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Verify OTP'.translate(),
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Didn't receive the code? ".translate(),
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textDark.withValues(alpha: 0.62),
                          ),
                        ),
                        TextButton(
                          onPressed: _isResending ? null : _resendCode,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.legalGold,
                            padding: EdgeInsets.symmetric(horizontal: 2.w),
                            minimumSize: Size(0, 30.h),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: _isResending
                              ? SizedBox(
                                  width: 16.w,
                                  height: 16.h,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.legalGold,
                                  ),
                                )
                              : Text(
                                  'Resend'.translate(),
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.legalGold,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.legalGold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
