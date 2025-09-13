import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// AuthService - Handles Firebase Authentication and Google Sign-in
///
/// CRITICAL: This file MUST import 'package:firebase_auth/firebase_auth.dart'
/// Without this import, FirebaseAuth, User, and UserCredential types are undefined
/// which causes "depend on inherited widget of exact type" errors.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Configure GoogleSignIn to automatically use configuration from google-services.json
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize AuthService and verify Firebase is properly configured
  Future<void> initialize() async {
    try {
      // Verify Firebase Auth is properly initialized
      await _auth.authStateChanges().first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      print('AuthService: Firebase Auth initialized successfully');
    } catch (e) {
      print('AuthService: Firebase Auth initialization failed: $e');
      rethrow;
    }
  }

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('Starting Google Sign-in process...');

      // Don't sign out first - this might be causing issues
      // await _googleSignIn.signOut();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        print('Google Sign-in cancelled by user');
        return null;
      }

      print('Google account selected: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      print('Got Google auth tokens - AccessToken: ${googleAuth.accessToken != null}, IdToken: ${googleAuth.idToken != null}');

      // Check if we got the tokens
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('Failed to get Google auth tokens');
        throw Exception('Failed to get authentication tokens from Google');
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Created Firebase credential, attempting Firebase sign-in...');

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      print('Firebase sign-in successful! User: ${userCredential.user?.email}');

      // Store user data in Firestore
      if (userCredential.user != null) {
        print('Storing user data in Firestore...');
        await _storeUserData(userCredential.user!);
        print('User data stored successfully');
      }

      print('Google Sign-in complete for user: ${userCredential.user?.email}');
      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      print('Error type: ${e.runtimeType}');

      // Provide more specific error handling
      if (e.toString().contains('network_error')) {
        print('Network error - check internet connection');
        throw Exception('Network error - please check your internet connection');
      } else if (e.toString().contains('sign_in_canceled')) {
        print('Sign-in was canceled');
        return null;
      } else if (e.toString().contains('sign_in_failed')) {
        print('Sign-in failed - check Firebase configuration');
        throw Exception('Sign-in failed - please check your configuration');
      } else if (e.toString().contains('PlatformException')) {
        print('Platform exception occurred');
        throw Exception('Platform error occurred during sign-in');
      }

      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  /// Store user data in Firestore
  Future<void> _storeUserData(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();

      final userModel = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'Anonymous',
        photoURL: user.photoURL,
        createdAt: docSnapshot.exists
            ? DateTime.fromMillisecondsSinceEpoch(docSnapshot.data()!['createdAt'] ?? 0)
            : DateTime.now(),
        lastSignIn: DateTime.now(),
      );

      await userDoc.set(userModel.toMap(), SetOptions(merge: true));
    } catch (e) {
      print('Error storing user data: $e');
    }
  }

  /// Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  /// Update user profile
  Future<bool> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      // Update Firebase Auth profile
      await user.updateDisplayName(displayName);
      await user.updatePhotoURL(photoURL);

      // Update Firestore document
      final updates = <String, dynamic>{};
      if (displayName != null) updates['displayName'] = displayName;
      if (photoURL != null) updates['photoURL'] = photoURL;

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).update(updates);
      }

      return true;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }
}
