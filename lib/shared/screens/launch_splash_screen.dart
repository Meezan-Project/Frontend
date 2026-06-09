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

    final role = await _resolveRoleForCurrentUser(
      user,
      loginIdentifier: user.email,
    );
    authState.loginAs(role);

    switch (role) {
      case AppRole.admin:
        return AppRoutes.adminHome;
      case AppRole.lawyer:
        return AppRoutes.lawyerHome;
      case AppRole.secretary:
        return AppRoutes.secretaryHome;
      case AppRole.user:
        return AppRoutes.userHome;
    }
  }

  Future<AppRole> _resolveRoleForCurrentUser(
    User user, {
    String? loginIdentifier,
  }) async {
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

      // 2) Query lawyers by phone
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
        // 3) Query lawyers by emailLower first, then email.
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

      // 4) Fast path by UID in users collection.
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
        // 5) Query users by emailLower first, then email.
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
      debugPrint('Firestore unavailable: $e');
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
