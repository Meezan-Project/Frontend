import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mezaan/shared/auth/auth_state.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';

class LaunchSplashScreen extends StatefulWidget {
  const LaunchSplashScreen({super.key});

  @override
  State<LaunchSplashScreen> createState() => _LaunchSplashScreenState();
}

class _LaunchSplashScreenState extends State<LaunchSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scale = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _timer = Timer(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      final route = await _resolveStartupRoute();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, route);
    });
  }

  Future<String> _resolveStartupRoute() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      authState.logout();
      return AppRoutes.onboarding;
    }

    final role = await _resolveRoleForCurrentUser(user);
    authState.loginAs(role);

    switch (role) {
      case AppRole.admin:
        return AppRoutes.adminHome;
      case AppRole.lawyer:
        return AppRoutes.lawyerHome;
      case AppRole.user:
        return AppRoutes.userHome;
    }
  }

  Future<AppRole> _resolveRoleForCurrentUser(User user) async {
    final firestore = FirebaseFirestore.instance;
    final normalizedEmail = user.email?.trim().toLowerCase();

    // 1) Fast path by UID in users collection.
    final userDoc = await firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      return _roleFromDocData(userDoc.data(), fallback: AppRole.user);
    }

    // 2) Fast path by UID in lawyers collection.
    final lawyerDoc = await firestore.collection('lawyers').doc(user.uid).get();
    if (lawyerDoc.exists) {
      return _roleFromDocData(lawyerDoc.data(), fallback: AppRole.lawyer);
    }

    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      // 3) Query users by emailLower first, then email.
      final userByEmailLower = await firestore
          .collection('users')
          .where('emailLower', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (userByEmailLower.docs.isNotEmpty) {
        return _roleFromDocData(
          userByEmailLower.docs.first.data(),
          fallback: AppRole.user,
        );
      }

      final userByEmail = await firestore
          .collection('users')
          .where('email', isEqualTo: user.email!.trim())
          .limit(1)
          .get();
      if (userByEmail.docs.isNotEmpty) {
        return _roleFromDocData(
          userByEmail.docs.first.data(),
          fallback: AppRole.user,
        );
      }

      // 4) Query lawyers by emailLower first, then email.
      final lawyerByEmailLower = await firestore
          .collection('lawyers')
          .where('emailLower', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (lawyerByEmailLower.docs.isNotEmpty) {
        return _roleFromDocData(
          lawyerByEmailLower.docs.first.data(),
          fallback: AppRole.lawyer,
        );
      }

      final lawyerByEmail = await firestore
          .collection('lawyers')
          .where('email', isEqualTo: user.email!.trim())
          .limit(1)
          .get();
      if (lawyerByEmail.docs.isNotEmpty) {
        return _roleFromDocData(
          lawyerByEmail.docs.first.data(),
          fallback: AppRole.lawyer,
        );
      }
    }

    return AppRole.user;
  }

  AppRole _roleFromDocData(
    Map<String, dynamic>? data, {
    required AppRole fallback,
  }) {
    if (data == null || data.isEmpty) {
      return fallback;
    }

    final normalized = (data['role'] ?? data['accountType'] ?? data['userType'])
        .toString()
        .trim()
        .toLowerCase();

    if (normalized == 'admin') {
      return AppRole.admin;
    }
    if (normalized == 'lawyer') {
      return AppRole.lawyer;
    }
    if (normalized == 'user') {
      return AppRole.user;
    }

    return fallback;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0F172A)],
          ),
        ),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: Image.asset(
              'assets/images/app_icon.png',
              width: 128,
              height: 128,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
