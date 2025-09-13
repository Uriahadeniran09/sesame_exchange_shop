import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';
import '../models/user_profile_model.dart';
import '../models/address_model.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _profilesCollection => _firestore.collection('user_profiles');

  /// Create a new user in Firestore
  Future<bool> createUser(UserModel user) async {
    try {
      await _usersCollection.doc(user.uid).set(user.toMap());

      // Create initial profile
      final profile = UserProfileModel(
        uid: user.uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _profilesCollection.doc(user.uid).set(profile.toMap());

      return true;
    } catch (e) {
      print('Error creating user: $e');
      return false;
    }
  }

  /// Get user by ID
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  /// Get user profile by ID
  Future<UserProfileModel?> getUserProfile(String uid) async {
    try {
      final doc = await _profilesCollection.doc(uid).get();
      if (doc.exists) {
        return UserProfileModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  /// Update user profile
  Future<bool> updateUserProfile(UserProfileModel profile) async {
    try {
      await _profilesCollection.doc(profile.uid).update(profile.toMap());
      return true;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }

  /// Upload profile picture
  Future<String?> uploadProfilePicture(String uid, File imageFile) async {
    try {
      final ref = _storage.ref().child('users/$uid/profile_picture.jpg');
      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Update profile with new picture URL
      await _profilesCollection.doc(uid).update({
        'profilePictureUrl': downloadUrl,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      return downloadUrl;
    } catch (e) {
      print('Error uploading profile picture: $e');
      return null;
    }
  }

  /// Upload additional pictures for user
  Future<List<String>> uploadAdditionalPictures(String uid, List<File> imageFiles) async {
    List<String> urls = [];
    try {
      for (int i = 0; i < imageFiles.length; i++) {
        final ref = _storage.ref().child('users/$uid/additional_pictures/${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        final uploadTask = await ref.putFile(imageFiles[i]);
        final url = await uploadTask.ref.getDownloadURL();
        urls.add(url);
      }

      // Get current additional pictures and append new ones
      final profile = await getUserProfile(uid);
      if (profile != null) {
        final updatedUrls = [...profile.additionalPictureUrls, ...urls];
        await _profilesCollection.doc(uid).update({
          'additionalPictureUrls': updatedUrls,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }

      return urls;
    } catch (e) {
      print('Error uploading additional pictures: $e');
      return [];
    }
  }

  /// Remove additional picture
  Future<bool> removeAdditionalPicture(String uid, String pictureUrl) async {
    try {
      final profile = await getUserProfile(uid);
      if (profile != null) {
        final updatedUrls = profile.additionalPictureUrls.where((url) => url != pictureUrl).toList();
        await _profilesCollection.doc(uid).update({
          'additionalPictureUrls': updatedUrls,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });

        // Delete from storage
        try {
          final ref = _storage.refFromURL(pictureUrl);
          await ref.delete();
        } catch (e) {
          print('Error deleting picture from storage: $e');
        }

        return true;
      }
      return false;
    } catch (e) {
      print('Error removing additional picture: $e');
      return false;
    }
  }

  /// Add user address
  Future<bool> addUserAddress(String uid, AddressModel address) async {
    try {
      // If this is set as default, remove default from other addresses
      if (address.isDefault) {
        await _setAllAddressesNonDefault(uid);
      }

      await _usersCollection.doc(uid).collection('addresses').doc(address.id).set(address.toMap());
      return true;
    } catch (e) {
      print('Error adding user address: $e');
      return false;
    }
  }

  /// Get user addresses
  Future<List<AddressModel>> getUserAddresses(String uid) async {
    try {
      final snapshot = await _usersCollection.doc(uid).collection('addresses').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return AddressModel.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error getting user addresses: $e');
      return [];
    }
  }

  /// Update user address
  Future<bool> updateUserAddress(String uid, AddressModel address) async {
    try {
      // If this is set as default, remove default from other addresses
      if (address.isDefault) {
        await _setAllAddressesNonDefault(uid);
      }

      await _usersCollection.doc(uid).collection('addresses').doc(address.id).update(address.toMap());
      return true;
    } catch (e) {
      print('Error updating user address: $e');
      return false;
    }
  }

  /// Delete user address
  Future<bool> deleteUserAddress(String uid, String addressId) async {
    try {
      await _usersCollection.doc(uid).collection('addresses').doc(addressId).delete();
      return true;
    } catch (e) {
      print('Error deleting user address: $e');
      return false;
    }
  }

  /// Get default user address
  Future<AddressModel?> getDefaultUserAddress(String uid) async {
    try {
      final snapshot = await _usersCollection.doc(uid)
          .collection('addresses')
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        data['id'] = snapshot.docs.first.id;
        return AddressModel.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Error getting default user address: $e');
      return null;
    }
  }

  /// Stream user profile changes
  Stream<UserProfileModel?> getUserProfileStream(String uid) {
    return _profilesCollection.doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserProfileModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }

  /// Stream user addresses changes
  Stream<List<AddressModel>> getUserAddressesStream(String uid) {
    return _usersCollection.doc(uid).collection('addresses').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return AddressModel.fromMap(data);
      }).toList();
    });
  }

  /// Search users by name or email
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final emailQuery = await _usersCollection
          .where('email', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('email', isLessThan: query.toLowerCase() + 'z')
          .get();

      final nameQuery = await _usersCollection
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThan: query + 'z')
          .get();

      final Set<String> seenUids = {};
      final List<UserModel> users = [];

      for (final doc in [...emailQuery.docs, ...nameQuery.docs]) {
        final uid = doc.id;
        if (!seenUids.contains(uid)) {
          seenUids.add(uid);
          users.add(UserModel.fromMap(doc.data() as Map<String, dynamic>));
        }
      }

      return users;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  /// Private helper method to set all addresses as non-default
  Future<void> _setAllAddressesNonDefault(String uid) async {
    try {
      final snapshot = await _usersCollection.doc(uid).collection('addresses').get();
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isDefault': false});
      }

      await batch.commit();
    } catch (e) {
      print('Error setting addresses non-default: $e');
    }
  }

  /// Update user preferences
  Future<bool> updateUserPreferences(String uid, Map<String, dynamic> preferences) async {
    try {
      await _profilesCollection.doc(uid).update({
        'preferences': preferences,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    } catch (e) {
      print('Error updating user preferences: $e');
      return false;
    }
  }

  /// Update user social links
  Future<bool> updateUserSocialLinks(String uid, Map<String, dynamic> socialLinks) async {
    try {
      await _profilesCollection.doc(uid).update({
        'socialLinks': socialLinks,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    } catch (e) {
      print('Error updating user social links: $e');
      return false;
    }
  }
}
