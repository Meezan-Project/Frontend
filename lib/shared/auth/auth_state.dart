import 'package:flutter/foundation.dart';

enum AppRole { user, lawyer, admin }

class AuthState extends ChangeNotifier {
  bool _isLoggedIn = false;
  AppRole? _role;

  bool get isLoggedIn => _isLoggedIn;
  AppRole? get role => _role;

  void loginAs(AppRole appRole) {
    _isLoggedIn = true;
    _role = appRole;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    _role = null;
    notifyListeners();
  }
}

final AuthState authState = AuthState();
