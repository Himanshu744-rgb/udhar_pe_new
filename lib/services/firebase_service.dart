import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final GoogleSignIn googleSignIn = GoogleSignIn(
    serverClientId:
        "579875864029-5teho4rlhu3rbduepbi54km3sd9lbtv2.apps.googleusercontent.com",
  );

  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  // Ensure email/password sign-in method is correctly defined
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print("Error signing in with email and password: $e");
      return null;
    }
  }

  // Add email/password sign-up method
  Future<UserCredential?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      return await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print("Error signing up with email and password: $e");
      return null;
    }
  }

  // Add sign-out method
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await googleSignIn.signOut();
  }

  // Add password reset method
  Future<void> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } catch (e) {
      print("Error sending password reset email: $e");
    }
  }

  // Add method to get current user
  User? getCurrentUser() {
    return FirebaseAuth.instance.currentUser;
  }
}
