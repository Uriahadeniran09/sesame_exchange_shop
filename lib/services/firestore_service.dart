import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/item_model.dart';
import '../models/user_model.dart';
import '../models/user_profile_model.dart';
import '../models/address_model.dart';
import '../models/post_model.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Collection references
  CollectionReference get _itemsCollection => _firestore.collection('items');
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _profilesCollection => _firestore.collection('user_profiles');
  CollectionReference get _messagesCollection => _firestore.collection('messages');

  /// ============ CONNECTING TO YOUR SPECIFIC FIREBASE DATA ============

  /// Connect to specific user ID in your Firebase - oRD1eNmcTz1vkvCDk4u3
  Future<UserModel?> getSpecificUser() async {
    const String specificUserId = 'oRD1eNmcTz1vkvCDk4u3';
    try {
      final doc = await _usersCollection.doc(specificUserId).get();
      if (doc.exists) {
        print('Found specific user: ${doc.data()}');
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      } else {
        print('User with ID $specificUserId does not exist');
        return null;
      }
    } catch (e) {
      print('Error getting specific user: $e');
      return null;
    }
  }

  /// Link current user data to your specific Firebase user ID
  Future<bool> linkToSpecificUser(String currentUserId) async {
    const String specificUserId = 'oRD1eNmcTz1vkvCDk4u3';
    try {
      // Get current user data
      final currentUserDoc = await _usersCollection.doc(currentUserId).get();
      if (!currentUserDoc.exists) {
        print('Current user $currentUserId does not exist');
        return false;
      }

      // Copy current user data to the specific user ID
      final userData = currentUserDoc.data() as Map<String, dynamic>;
      await _usersCollection.doc(specificUserId).set(userData);

      print('Successfully linked $currentUserId to $specificUserId');
      return true;
    } catch (e) {
      print('Error linking to specific user: $e');
      return false;
    }
  }

  /// ============ REAL FIREBASE STORAGE IMPLEMENTATION ============

  /// Upload profile picture - REAL IMPLEMENTATION
  Future<String?> uploadProfilePicture(String uid, File imageFile) async {
    try {
      final String fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child('users/$uid/profile/$fileName');

      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Update profile with new picture URL
      await _profilesCollection.doc(uid).update({
        'profilePictureUrl': downloadUrl,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      print('Profile picture uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile picture: $e');
      return null;
    }
  }

  /// Upload post image to Firebase Storage - REAL IMPLEMENTATION
  Future<String?> uploadPostImage(String uid, File imageFile, int index) async {
    try {
      final String fileName = 'post_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
      final Reference ref = _storage.ref().child('posts/$uid/$fileName');

      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      print('Post image $index uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading post image: $e');
      return null;
    }
  }

  /// Upload additional pictures for user - REAL IMPLEMENTATION
  Future<List<String>> uploadAdditionalPictures(String uid, List<File> imageFiles) async {
    List<String> urls = [];
    try {
      for (int i = 0; i < imageFiles.length; i++) {
        final String fileName = 'additional_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final Reference ref = _storage.ref().child('users/$uid/additional/$fileName');

        final UploadTask uploadTask = ref.putFile(imageFiles[i]);
        final TaskSnapshot snapshot = await uploadTask;
        final String url = await snapshot.ref.getDownloadURL();
        urls.add(url);

        print('Additional image $i uploaded: $url');
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

  /// Remove additional picture - REAL IMPLEMENTATION
  Future<bool> removeAdditionalPicture(String uid, String pictureUrl) async {
    try {
      final profile = await getUserProfile(uid);
      if (profile != null) {
        final updatedUrls = profile.additionalPictureUrls.where((url) => url != pictureUrl).toList();
        await _profilesCollection.doc(uid).update({
          'additionalPictureUrls': updatedUrls,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });

        // Delete from Firebase Storage
        try {
          final Reference ref = _storage.refFromURL(pictureUrl);
          await ref.delete();
          print('Image deleted from storage: $pictureUrl');
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

  /// ============ USER MANAGEMENT METHODS ============

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

  /// Stream user profile changes
  Stream<UserProfileModel?> getUserProfileStream(String uid) {
    return _profilesCollection.doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserProfileModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }

  /// ============ POST MANAGEMENT METHODS ============

  /// Add new post to Firestore
  Future<bool> addPost(PostModel post) async {
    try {
      final docRef = await _firestore.collection('posts').add(post.toMap());
      // Update the post with the generated ID
      await docRef.update({'id': docRef.id});
      return true;
    } catch (e) {
      print('Error adding post: $e');
      return false;
    }
  }

  /// Get all posts for home feed
  Stream<List<PostModel>> getPosts() {
    return _firestore.collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return PostModel.fromMap(data);
      }).toList();
    });
  }

  /// Get posts by user ID
  Stream<List<PostModel>> getUserPosts(String userId) {
    return _firestore.collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return PostModel.fromMap(data);
      }).toList();
    });
  }

  /// Update post
  Future<bool> updatePost(String postId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('posts').doc(postId).update(updates);
      return true;
    } catch (e) {
      print('Error updating post: $e');
      return false;
    }
  }

  /// Delete post
  Future<bool> deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
      return true;
    } catch (e) {
      print('Error deleting post: $e');
      return false;
    }
  }

  /// Like/unlike a post
  Future<bool> togglePostLike(String postId, String userId) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final likesRef = postRef.collection('likes').doc(userId);

      final likeDoc = await likesRef.get();

      if (likeDoc.exists) {
        // Unlike the post
        await likesRef.delete();
        await postRef.update({
          'likesCount': FieldValue.increment(-1),
        });
      } else {
        // Like the post
        await likesRef.set({
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await postRef.update({
          'likesCount': FieldValue.increment(1),
        });
      }

      return true;
    } catch (e) {
      print('Error toggling post like: $e');
      return false;
    }
  }

  /// Check if user has liked a post
  Future<bool> hasUserLikedPost(String postId, String userId) async {
    try {
      final likeDoc = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(userId)
          .get();
      return likeDoc.exists;
    } catch (e) {
      print('Error checking post like: $e');
      return false;
    }
  }

  /// ============ ADDRESS MANAGEMENT METHODS ============

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

  /// ============ ITEM MANAGEMENT METHODS ============

  /// Add new item to Firestore
  Future<String?> addItem(ItemModel item) async {
    try {
      final docRef = await _itemsCollection.add(item.toMap());
      // Update the item with the generated ID
      await docRef.update({'id': docRef.id});
      return docRef.id;
    } catch (e) {
      print('Error adding item: $e');
      return null;
    }
  }

  /// Get all available items (home feed)
  Stream<List<ItemModel>> getAvailableItems() {
    return _itemsCollection
        .where('isAvailable', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return ItemModel.fromMap(data);
      }).toList();
    });
  }

  /// Get items by user ID
  Stream<List<ItemModel>> getUserItems(String userId) {
    return _itemsCollection
        .where('ownerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return ItemModel.fromMap(data);
      }).toList();
    });
  }

  /// Update item
  Future<bool> updateItem(String itemId, Map<String, dynamic> updates) async {
    try {
      await _itemsCollection.doc(itemId).update(updates);
      return true;
    } catch (e) {
      print('Error updating item: $e');
      return false;
    }
  }

  /// Delete item
  Future<bool> deleteItem(String itemId) async {
    try {
      await _itemsCollection.doc(itemId).delete();
      return true;
    } catch (e) {
      print('Error deleting item: $e');
      return false;
    }
  }

  /// Send message between users
  Future<bool> sendMessage({
    required String senderId,
    required String receiverId,
    required String message,
    String? itemId,
  }) async {
    try {
      await _messagesCollection.add({
        'senderId': senderId,
        'receiverId': receiverId,
        'message': message,
        'itemId': itemId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  /// Get messages for a user
  Stream<List<Map<String, dynamic>>> getMessages(String userId) {
    return _messagesCollection
        .where('receiverId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort by timestamp in memory to avoid composite index requirement
      messages.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime); // Descending order (newest first)
      });

    });
  }

  /// Get conversation between two users
  Stream<List<Map<String, dynamic>>> getConversation(
    String userId1,
    String userId2
  ) {
    return _messagesCollection
        .where('senderId', whereIn: [userId1, userId2])
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      // Filter messages between the two users
      return messages.where((message) {
        final senderId = message['senderId'];
        final receiverId = message['receiverId'];
        return (senderId == userId1 && receiverId == userId2) ||
               (senderId == userId2 && receiverId == userId1);
      }).toList()
        ..sort((a, b) {
          final aTime = a['timestamp'] as Timestamp?;
          final bTime = b['timestamp'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });
    });
  }

  /// Mark message as read
  Future<bool> markMessageAsRead(String messageId) async {
    try {
      await _messagesCollection.doc(messageId).update({'isRead': true});
      return true;
    } catch (e) {
      print('Error marking message as read: $e');
      return false;
    }
  }
}
