import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/message_dialog.dart';
import 'firebase_test_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please sign in to view messages'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.getMessages(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print('Messages Screen Error Details: ${snapshot.error}');

            // Enhanced error detection
            final errorMessage = snapshot.error.toString();
            final isPermissionError = errorMessage.contains('permission') ||
                errorMessage.contains('PERMISSION_DENIED') ||
                errorMessage.contains('insufficient permissions');

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPermissionError ? Icons.lock_outline : Icons.error_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isPermissionError ? 'Firestore Permission Error' : 'Error Loading Messages',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isPermissionError) ...[
                      const Text(
                        'Your Firebase security rules need to be updated to access messages.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FirebaseTestScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.build),
                        label: const Text('Fix Firestore Issues'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Error: ${errorMessage.length > 100 ? "${errorMessage.substring(0, 100)}..." : errorMessage}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {}); // Trigger rebuild
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.message_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a conversation by messaging someone about their posts!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final messages = snapshot.data!;

          // Group messages by sender to create conversations
          final Map<String, List<Map<String, dynamic>>> conversations = {};
          for (final message in messages) {
            final senderId = message['senderId'] as String;
            if (!conversations.containsKey(senderId)) {
              conversations[senderId] = [];
            }
            conversations[senderId]!.add(message);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final senderId = conversations.keys.elementAt(index);
              final conversationMessages = conversations[senderId]!;
              final latestMessage = conversationMessages.first;

              return _buildConversationCard(
                senderId: senderId,
                latestMessage: latestMessage,
                unreadCount: conversationMessages.where((m) => !(m['isRead'] as bool)).length,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildConversationCard({
    required String senderId,
    required Map<String, dynamic> latestMessage,
    required int unreadCount,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            senderId[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          'User ${senderId.substring(0, 8)}...', // Show first 8 chars of user ID
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          latestMessage['message'] as String,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
            fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTimestamp(latestMessage['timestamp']),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        onTap: () {
          // Mark messages as read
          _markConversationAsRead(senderId);

          // Navigate to conversation screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConversationScreen(
                otherUserId: senderId,
                otherUserName: 'User ${senderId.substring(0, 8)}...',
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      final DateTime dateTime = timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Now';
      }
    } catch (e) {
      return '';
    }
  }

  Future<void> _markConversationAsRead(String senderId) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    try {
      // Get all unread messages from this sender
      final messages = await _firestoreService.getMessages(currentUser.uid).first;
      final unreadMessages = messages
          .where((m) => m['senderId'] == senderId && !(m['isRead'] as bool))
          .toList();

      // Mark each unread message as read
      for (final message in unreadMessages) {
        await _firestoreService.markMessageAsRead(message['id'] as String);
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }
}
