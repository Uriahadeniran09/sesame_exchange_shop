import 'package:flutter/material.dart';
import '../services/messaging_service.dart';
import '../screens/chat_screen.dart';

class MessageButton extends StatelessWidget {
  final String postOwnerId;
  final String postId;
  final String postTitle;
  final String? currentUserId;

  const MessageButton({
    Key? key,
    required this.postOwnerId,
    required this.postId,
    required this.postTitle,
    this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Don't show message button if user is not logged in or it's their own post
    if (currentUserId == null || currentUserId == postOwnerId) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: const Icon(Icons.message),
      onPressed: () => _startConversation(context),
      tooltip: 'Message seller',
      color: Colors.blue,
    );
  }

  void _startConversation(BuildContext context) async {
    final messagingService = MessagingService();
    final conversationId = messagingService.getConversationId(currentUserId!, postOwnerId);

    // Navigate to chat screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversationId,
          otherUserId: postOwnerId,
          otherUserName: 'Loading...', // Will be loaded in ChatScreen
          postTitle: postTitle,
        ),
      ),
    );
  }
}

class MessageIconWithBadge extends StatelessWidget {
  final VoidCallback onTap;

  const MessageIconWithBadge({
    Key? key,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final messagingService = MessagingService();

    return StreamBuilder<int>(
      stream: messagingService.getUnreadMessageCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: onTap,
              tooltip: 'Messages',
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
