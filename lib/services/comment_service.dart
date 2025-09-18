import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/comment_model.dart';

class CommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Add a comment to a post
  Future<bool> addComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get user data
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() ?? {};
      final userName = userData['name'] ?? userData['displayName'] ?? 'Anonymous';
      final userProfilePicture = userData['profilePicture'];

      final comment = Comment(
        id: '', // Firestore will generate this
        postId: postId,
        userId: currentUser.uid,
        userName: userName,
        userProfilePicture: userProfilePicture,
        content: content,
        createdAt: DateTime.now(),
        parentCommentId: parentCommentId,
      );

      // Add comment to Firestore
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .add(comment.toMap());

      // Update post comments count
      await _firestore.collection('posts').doc(postId).update({
        'commentsCount': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      print('Error adding comment: $e');
      return false;
    }
  }

  /// Get comments for a post
  Stream<List<Comment>> getComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .where('parentCommentId', isNull: true) // Only get top-level comments
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Comment.fromMap(data);
      }).toList();
    });
  }

  /// Get replies for a comment
  Stream<List<Comment>> getReplies(String postId, String commentId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .where('parentCommentId', isEqualTo: commentId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Comment.fromMap(data);
      }).toList();
    });
  }

  /// Toggle like on a comment - Updated to use subcollection like posts
  Future<bool> toggleCommentLike(String postId, String commentId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final commentRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);

      final likesRef = commentRef.collection('likes').doc(currentUser.uid);

      final likeDoc = await likesRef.get();

      if (likeDoc.exists) {
        // Unlike the comment
        await likesRef.delete();
        await commentRef.update({
          'likesCount': FieldValue.increment(-1),
        });
      } else {
        // Like the comment
        await likesRef.set({
          'userId': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await commentRef.update({
          'likesCount': FieldValue.increment(1),
        });
      }

      return true;
    } catch (e) {
      print('Error toggling comment like: $e');
      return false;
    }
  }

  /// Check if user has liked a comment - Updated to use subcollection
  Future<bool> hasUserLikedComment(String postId, String commentId, String userId) async {
    try {
      final likeDoc = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .collection('likes')
          .doc(userId)
          .get();

      return likeDoc.exists;
    } catch (e) {
      print('Error checking comment like: $e');
      return false;
    }
  }

  /// Delete a comment
  Future<bool> deleteComment(String postId, String commentId, String userId) async {
    try {
      final commentDoc = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .get();

      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final commentData = commentDoc.data()!;
      final commentUserId = commentData['userId'];

      // Only allow deletion by comment author
      if (commentUserId != userId) {
        throw Exception('Not authorized to delete this comment');
      }

      // Delete comment
      await commentDoc.reference.delete();

      // Update post comments count
      await _firestore.collection('posts').doc(postId).update({
        'commentsCount': FieldValue.increment(-1),
      });

      return true;
    } catch (e) {
      print('Error deleting comment: $e');
      return false;
    }
  }

  /// Get real-time like status for a comment - Updated to use subcollection
  Stream<bool> getCommentLikeStatus(String postId, String commentId, String userId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }
}
