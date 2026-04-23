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
    DocumentSnapshot<Map<String, dynamic>> userDoc;

    try {
      userDoc = await firestore.collection('users').doc(user.uid).get();
      final data = userDoc.data();
      if (data != null && data.isNotEmpty) {
        return _mapRole(data['role'] ?? data['accountType']);
      }

      if (user.email != null && user.email!.trim().isNotEmpty) {
        final byEmail = await firestore
            .collection('users')
            .where('email', isEqualTo: user.email!.trim())
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          final fallback = byEmail.docs.first.data();
          return _mapRole(fallback['role'] ?? fallback['accountType']);
        }
      }

      if (user.phoneNumber != null && user.phoneNumber!.trim().isNotEmpty) {
        final byPhone = await firestore
            .collection('users')
            .where('phone', isEqualTo: user.phoneNumber!.trim())
            .limit(1)
            .get();
        if (byPhone.docs.isNotEmpty) {
          final fallback = byPhone.docs.first.data();
          return _mapRole(fallback['role'] ?? fallback['accountType']);
        }
      }
    } catch (_) {
      return AppRole.user;
    }

    return AppRole.user;
  }

  AppRole _mapRole(Object? rawRole) {
    final normalized = rawRole?.toString().trim().toLowerCase() ?? 'user';
    if (normalized == 'admin') {
      return AppRole.admin;
    }
    if (normalized == 'lawyer') {
      return AppRole.lawyer;
    }
    return AppRole.user;
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
