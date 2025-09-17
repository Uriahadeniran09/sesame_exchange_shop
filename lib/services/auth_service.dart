import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
  // Configure GoogleSignIn with proper web client ID for web platforms
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'openid',
      'email',
      'profile',
    ],
    // Use the correct web client ID for web platforms
    clientId: kIsWeb ? '115934502087-255fobjb78705pdr2qvgsrucjq3jbm32.apps.googleusercontent.com' : null,
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
      print('Platform: ${kIsWeb ? "Web" : "Mobile"}');

      if (kIsWeb) {
        // For web platforms, use Firebase Auth's GoogleAuthProvider directly
        return await _signInWithGoogleWeb();
      } else {
        // For mobile platforms, use the existing GoogleSignIn flow
        return await _signInWithGoogleMobile();
      }
    } catch (e) {
      print('Error signing in with Google: $e');
      print('Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Web-specific Google Sign-in using Firebase Auth directly
  Future<UserCredential?> _signInWithGoogleWeb() async {
    try {
      print('Using Firebase Auth GoogleAuthProvider for web...');

      // Create a GoogleAuthProvider instance
      GoogleAuthProvider googleProvider = GoogleAuthProvider();

      // Add the required scopes
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      googleProvider.addScope('openid');

      // Set custom parameters to ensure we get ID tokens
      googleProvider.setCustomParameters({
        'prompt': 'select_account',
        'include_granted_scopes': 'true',
      });

      print('Attempting Firebase Auth popup sign-in...');

      // Sign in with popup
      final UserCredential result = await _auth.signInWithPopup(googleProvider);

      print('Firebase Auth popup sign-in successful!');
      print('User: ${result.user?.email}');
      print('User ID: ${result.user?.uid}');

      // Store user data in Firestore
      if (result.user != null) {
        print('Storing user data in Firestore...');
        await _storeUserData(result.user!);
        print('User data stored successfully');
      }

      print('Web Google Sign-in complete for user: ${result.user?.email}');
      return result;

    } catch (e) {
      print('Web Google Sign-in failed: $e');

      // If popup fails, try redirect
      if (e.toString().contains('popup')) {
        print('Popup blocked, trying redirect method...');
        return await _signInWithGoogleWebRedirect();
      }

      rethrow;
    }
  }

  /// Fallback web sign-in using redirect
  Future<UserCredential?> _signInWithGoogleWebRedirect() async {
    try {
      print('Using Firebase Auth redirect for web...');

      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      googleProvider.addScope('openid');

      // Use redirect method
      await _auth.signInWithRedirect(googleProvider);

      // Note: This will redirect the page, so we won't reach this point
      // The app will reload and you'll need to handle the result on app initialization
      return null;

    } catch (e) {
      print('Redirect Google Sign-in failed: $e');
      rethrow;
    }
  }

  /// Mobile-specific Google Sign-in using GoogleSignIn plugin
  Future<UserCredential?> _signInWithGoogleMobile() async {
    try {
      print('Using GoogleSignIn plugin for mobile...');

      // Clear any previous session
      await _googleSignIn.signOut();
      print('Signed out from previous session');

      print('Attempting Google Sign-in...');

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('Google Sign-in cancelled by user');
        return null;
      }

      print('Google account selected: ${googleUser.email}');
      print('Display name: ${googleUser.displayName}');

      // Obtain the auth details from the request
      print('Getting authentication details...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      print('AccessToken available: ${googleAuth.accessToken != null}');
      print('IdToken available: ${googleAuth.idToken != null}');

      if (googleAuth.accessToken == null) {
        throw Exception('Failed to get access token from Google');
      }

      if (googleAuth.idToken == null) {
        throw Exception('Failed to get ID token from Google');
      }

      print('Both tokens received successfully');

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

      print('Mobile Google Sign-in complete for user: ${userCredential.user?.email}');
      return userCredential;
    } catch (e) {
      print('Mobile Google Sign-in failed: $e');
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
