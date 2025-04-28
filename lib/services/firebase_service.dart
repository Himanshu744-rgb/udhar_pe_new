import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Future<UserCredential?> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
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
    // Get shared preferences instance
    final prefs = await SharedPreferences.getInstance();
    // Keep the rememberMe setting but remove credentials
    final rememberMe = prefs.getBool('rememberMe') ?? false;
    
    // Clear user credentials but preserve the rememberMe setting
    if (rememberMe) {
      // If rememberMe is true, keep the setting but remove credentials
      await prefs.setBool('rememberMe', true);
      // We don't remove email, password, and userType here to preserve them
    }
    
    await FirebaseAuth.instance.signOut();
    await googleSignIn.signOut();
  }

  // Add password reset method
  Future<void> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: ActionCodeSettings(
          url: 'https://first-app-39408.firebaseapp.com/__/auth/action',
          handleCodeInApp: true,
          androidPackageName: 'com.example.udhar_pe_new',
          androidInstallApp: true,
          androidMinimumVersion: '12',
        ),
      );
    } catch (e) {
      print("Error sending password reset email: $e");
      rethrow;
    }
  }

  // Add method to get current user
  User? getCurrentUser() {
    return FirebaseAuth.instance.currentUser;
  }
}

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addData(String collection, Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User is not authenticated");
    }

    await _firestore.collection(collection).add({
      ...data,
      'userId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<QuerySnapshot> getData(String collection) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User is not authenticated");
    }

    return await _firestore
        .collection(collection)
        .where('userId', isEqualTo: user.uid)
        .get();
  }
}
