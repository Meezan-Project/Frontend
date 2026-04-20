import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseSessionService {
  FirebaseSessionService._();

  static Future<void> signOutAll() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Ignore and continue to clear Google session.
    }

    final googleSignIn = GoogleSignIn();
    try {
      final isSignedIn = await googleSignIn.isSignedIn();
      if (isSignedIn) {
        await googleSignIn.signOut();
      }
    } catch (_) {
      // Ignore; user is still locally logged out from app state.
    }
  }
}
