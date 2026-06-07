import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppRole { user, lawyer, admin }

class AuthState extends ChangeNotifier {
  bool _isLoggedIn = false;
  AppRole? _role;

  static const String _roleHintsPrefsKey = 'roleHintsByIdentifier';

  bool get isLoggedIn => _isLoggedIn;
  AppRole? get role => _role;

  /// Initialize the auth state from local storage
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final roleString = prefs.getString('userRole');

    if (roleString != null) {
      _role = AppRole.values.firstWhere(
        (e) => e.toString() == roleString,
        orElse: () => AppRole.user,
      );
    }
    notifyListeners();
  }

  void loginAs(AppRole appRole) {
    _isLoggedIn = true;
    _role = appRole;
    notifyListeners();
    _saveState(appRole);
  }

  void logout() {
    _isLoggedIn = false;
    _role = null;
    notifyListeners();
    _clearState();
  }

  Future<void> _saveState(AppRole appRole) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userRole', appRole.toString());
  }

  Future<void> _clearState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userRole');
  }

  Future<void> cacheRoleHint({
    required String identifier,
    required AppRole role,
  }) async {
    final normalizedIdentifier = identifier.trim().toLowerCase();
    if (normalizedIdentifier.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final hints = _readRoleHints(prefs);
    hints[normalizedIdentifier] = role.toString();
    await prefs.setString(_roleHintsPrefsKey, jsonEncode(hints));
  }

  Future<AppRole?> resolveRoleHint(String identifier) async {
    final normalizedIdentifier = identifier.trim().toLowerCase();
    if (normalizedIdentifier.isEmpty) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final hints = _readRoleHints(prefs);
    final roleString = hints[normalizedIdentifier];
    if (roleString == null) {
      return null;
    }

    return _roleFromString(roleString);
  }

  Map<String, String> _readRoleHints(SharedPreferences prefs) {
    final raw = prefs.getString(_roleHintsPrefsKey);
    if (raw == null || raw.isEmpty) {
      return <String, String>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <String, String>{};
      }

      return decoded.map(
        (key, value) => MapEntry(key.toLowerCase(), value.toString()),
      );
    } catch (_) {
      return <String, String>{};
    }
  }

  AppRole? _roleFromString(String? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.trim().toLowerCase();
    if (normalized == 'approle.user') return AppRole.user;
    if (normalized == 'approle.lawyer') return AppRole.lawyer;
    if (normalized == 'approle.admin') return AppRole.admin;
    if (normalized == 'user') return AppRole.user;
    if (normalized == 'lawyer') return AppRole.lawyer;
    if (normalized == 'admin') return AppRole.admin;
    return null;
  }
}

final AuthState authState = AuthState();
