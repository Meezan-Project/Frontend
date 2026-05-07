import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class BalancePasscodeDialog extends StatefulWidget {
  const BalancePasscodeDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const BalancePasscodeDialog(),
    );
    return result ?? false;
  }

  @override
  State<BalancePasscodeDialog> createState() => _BalancePasscodeDialogState();
}

enum PasscodeState { loading, createStep1, createStep2, enterPasscode }

class _BalancePasscodeDialogState extends State<BalancePasscodeDialog> {
  PasscodeState _currentState = PasscodeState.loading;
  String? _savedPasscode;
  String _firstAttempt = '';
  String? _errorMessage;

  final TextEditingController _passcodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkExistingPasscode();
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingPasscode() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) Navigator.pop(context, false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data()!.containsKey('walletPasscode')) {
        _savedPasscode = doc.data()!['walletPasscode'];
        setState(() => _currentState = PasscodeState.enterPasscode);
      } else {
        setState(() => _currentState = PasscodeState.createStep1);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context, false);
    }
  }

  Future<void> _onConfirm() async {
    final input = _passcodeController.text;
    if (input.length != 6) {
      setState(() => _errorMessage = 'Passcode must be exactly 6 digits');
      return;
    }

    setState(() => _errorMessage = null);

    if (_currentState == PasscodeState.createStep1) {
      _firstAttempt = input;
      _passcodeController.clear();
      setState(() => _currentState = PasscodeState.createStep2);
    } else if (_currentState == PasscodeState.createStep2) {
      if (input == _firstAttempt) {
        // Save to Firestore
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({'walletPasscode': input}, SetOptions(merge: true));
            if (mounted) Navigator.pop(context, true);
          }
        } catch (e) {
          setState(() => _errorMessage = 'Failed to save. Try again.');
        }
      } else {
        setState(() {
          _errorMessage = 'Passcodes do not match. Try again.';
          _firstAttempt = '';
          _currentState = PasscodeState.createStep1;
          _passcodeController.clear();
        });
      }
    } else if (_currentState == PasscodeState.enterPasscode) {
      if (input == _savedPasscode) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _errorMessage = 'Incorrect passcode';
          _passcodeController.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentState == PasscodeState.loading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    String title;
    String subtitle;

    switch (_currentState) {
      case PasscodeState.createStep1:
        title = 'Create Passcode';
        subtitle = 'Enter a 6-digit passcode to secure your balance';
        break;
      case PasscodeState.createStep2:
        title = 'Confirm Passcode';
        subtitle = 'Re-enter the 6-digit passcode to confirm';
        break;
      case PasscodeState.enterPasscode:
        title = 'Enter Passcode';
        subtitle = 'Enter your 6-digit passcode to view balance';
        break;
      default:
        title = '';
        subtitle = '';
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Text(
        title,
        style: GoogleFonts.cairo(
          fontWeight: FontWeight.w800,
          color: AppColors.navyBlue,
          fontSize: 18.sp,
        ),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            subtitle,
            style: GoogleFonts.cairo(
              fontSize: 14.sp,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20.h),
          TextField(
            controller: _passcodeController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            autofocus: true,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 12,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              errorText: _errorMessage,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(
                  color: AppColors.legalGold,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: GoogleFonts.cairo(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navyBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          onPressed: _onConfirm,
          child: Text(
            'Confirm',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
