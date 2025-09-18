import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';

class MessagingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send a message in a conversation
  Future<void> sendMessage({
    required String receiverId,
    required String content,
    String? postId,
    String? postTitle,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Prevent users from messaging themselves
      if (currentUser.uid == receiverId) {
        throw Exception('Cannot send message to yourself');
      }

      // Generate conversation ID from user IDs
      final userIds = [currentUser.uid, receiverId]..sort();
      final conversationId = userIds.join('_');

      final message = Message(
        id: '', // Firestore will generate this
        conversationId: conversationId,
        senderId: currentUser.uid,
        receiverId: receiverId,
        content: content,
        timestamp: DateTime.now(),
        isRead: false,
        messageType: MessageType.text,
      );

      // Create conversation if it doesn't exist
      await _createConversationIfNotExists(
        conversationId,
        [currentUser.uid, receiverId],
        postTitle,
      );

      // Send the message
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add(message.toMap());

      // Update conversation last message
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'lastMessage': content,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUser.uid,
      });
    } catch (e) {
      print('Error sending message: $e');
      throw e;
    }
  }

  /// Create conversation if it doesn't exist
  Future<void> _createConversationIfNotExists(
    String conversationId,
    List<String> participants,
    String? postTitle,
  ) async {
    final conversationDoc = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .get();

    if (!conversationDoc.exists) {
      final conversation = Conversation(
        id: conversationId,
        participants: participants,
        createdAt: DateTime.now(),
        lastMessage: '',
        lastMessageTimestamp: DateTime.now(),
        lastMessageSenderId: '',
        postTitle: postTitle,
      );

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .set(conversation.toMap());
    }
  }

  /// Get messages for a conversation
  Stream<List<Message>> getMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Message.fromMap(data);
      }).toList();
    });
  }

  /// Get conversations for current user
  Stream<List<Conversation>> getConversations() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Conversation.fromMap(data);
      }).toList();
    });
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String conversationId, [String? senderId]) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      Query messagesQuery = _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false);

      // If senderId is provided, filter by that as well
      if (senderId != null) {
        messagesQuery = messagesQuery.where('senderId', isEqualTo: senderId);
      }

      final querySnapshot = await messagesQuery.get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  /// Get user info for conversation
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data();
      }
      return <String, dynamic>{}; // Return empty map instead of null
    } catch (e) {
      print('Error getting user info: $e');
      return <String, dynamic>{}; // Return empty map instead of null
    }
  }

  /// Get conversation ID from two user IDs
  String getConversationId(String userId1, String userId2) {
    final userIds = [userId1, userId2]..sort();
    return userIds.join('_');
  }

  /// Get total unread message count for current user (all conversations)
  Stream<int> getUnreadMessageCount() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUser.uid)
        .snapshots()
        .asyncMap((snapshot) async {
      int totalUnread = 0;

      for (final doc in snapshot.docs) {
        final conversationId = doc.id;
        final unreadCount = await getUnreadMessageCountForConversation(conversationId);
        totalUnread += unreadCount;
      }

      return totalUnread;
    });
  }

  /// Get unread message count for a specific conversation
  Future<int> getUnreadMessageCountForConversation(String conversationId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 0;

      final unreadQuery = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false)
          .get();

      return unreadQuery.docs.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Delete all messages in the conversation
      final messagesQuery = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (final doc in messagesQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete the conversation document
      batch.delete(_firestore.collection('conversations').doc(conversationId));

      await batch.commit();
    } catch (e) {
      print('Error deleting conversation: $e');
      throw e;
    }
  }

  /// Clean up old messages (optional - for storage management)
  Future<void> cleanupOldMessages() async {
    try {
      final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));

      // This is a simplified version - in production, you'd want to use Firebase Functions
      print('Message cleanup scheduled');
    } catch (e) {
      print('Error during cleanup: $e');
    }
  }
}
