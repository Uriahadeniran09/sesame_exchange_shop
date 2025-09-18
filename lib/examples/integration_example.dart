// Example of how to integrate the MessageButton into your existing post cards
// Add this to wherever you display posts (like in your home screen or post detail screen)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/message_widgets.dart';
import '../models/post_model.dart';
import '../screens/messages_screen.dart'; // Added missing import

class PostCard extends StatelessWidget {
  final PostModel post;

  const PostCard({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Card(
      child: Column(
        children: [
          // Your existing post content
          ListTile(
            title: Text(post.title),
            subtitle: Text(post.description),
            // Add other post details
          ),

          // Action buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Your existing buttons (like, share, etc.)
              IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () {
                  // Like functionality
                },
              ),

              // NEW: Message button
              MessageButton(
                postOwnerId: post.userId, // The post owner's ID
                postId: post.id,
                postTitle: post.title,
                currentUserId: currentUser?.uid,
              ),

              // Other buttons...
            ],
          ),
        ],
      ),
    );
  }
}

// Integration example for your navigation bar or app bar
class AppBarWithMessages extends StatelessWidget implements PreferredSizeWidget {
  const AppBarWithMessages({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Sesame Exchange'),
      actions: [
        // NEW: Message icon with unread badge
        MessageIconWithBadge(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MessagesScreen(), // Updated to use existing screen
              ),
            );
          },
        ),
        // Your other app bar actions...
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
