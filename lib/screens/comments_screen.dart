import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../services/comment_service.dart';

class CommentsScreen extends StatefulWidget {
  final PostModel post;

  const CommentsScreen({
    super.key,
    required this.post,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final CommentService _commentService = CommentService();
  final TextEditingController _commentController = TextEditingController();
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _isLoading = false;

  // Optimistic like state
  final Map<String, bool> _optimisticLikes = {};
  final Map<String, int> _optimisticLikeCounts = {};

  // Local state for comments
  List<Comment> _comments = [];
  bool _commentsLoading = true;
  String? _commentsError;

  Future<void> _toggleCommentLikeOptimistic(Comment comment) async {
    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to like comments')),
        );
      }
      return;
    }
    final commentId = comment.id;
    final wasLiked = _optimisticLikes[commentId] ?? false;
    final currentCount = _optimisticLikeCounts[commentId] ?? comment.likesCount;
    setState(() {
      _optimisticLikes[commentId] = !wasLiked;
      _optimisticLikeCounts[commentId] = wasLiked ? (currentCount - 1) : (currentCount + 1);
    });
    try {
      await _commentService.toggleCommentLike(widget.post.id, commentId);
    } catch (e) {
      // Revert on error
      setState(() {
        _optimisticLikes[commentId] = wasLiked;
        _optimisticLikeCounts[commentId] = currentCount;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update like')),
        );
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    setState(() {
      _commentsLoading = true;
      _commentsError = null;
    });
    try {
      final comments = await _commentService.getComments(widget.post.id).first;
      setState(() {
        _comments = comments;
        _commentsLoading = false;
      });
    } catch (e) {
      setState(() {
        _commentsError = 'Error: ' + e.toString();
        _commentsLoading = false;
      });
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to comment')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _commentService.addComment(
        postId: widget.post.id,
        content: _commentController.text.trim(),
      );

      if (mounted) {
        if (success) {
          _commentController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Comment added successfully')),
          );
          await _fetchComments();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add comment')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error adding comment')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Post preview
          _buildPostPreview(),

          const Divider(height: 1),

          // Comments list
          Expanded(
            child: _commentsLoading
                ? const Center(child: CircularProgressIndicator())
                : _commentsError != null
                    ? Center(child: Text(_commentsError!))
                    : _comments.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.comment_outlined, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No comments yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Be the first to comment!',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _comments.length,
                            itemBuilder: (context, index) {
                              return _buildCommentItem(_comments[index]);
                            },
                          ),
          ),

          // Comment input
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildPostPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Post image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: widget.post.imageUrls.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: widget.post.imageUrls.first,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image),
                    ),
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image),
                  ),
          ),

          const SizedBox(width: 12),

          // Post info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'by ${widget.post.userName}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User avatar
          CircleAvatar(
            radius: 20,
            backgroundImage: comment.userProfilePicture != null
                ? CachedNetworkImageProvider(comment.userProfilePicture!)
                : null,
            child: comment.userProfilePicture == null
                ? Text(
                    comment.userName.isNotEmpty
                        ? comment.userName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : null,
          ),

          const SizedBox(width: 12),

          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User name and time
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDateTime(comment.createdAt),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Comment text
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 14),
                ),

                const SizedBox(height: 8),

                // Comment actions
                Row(
                  children: [
                    if (currentUserId != null)
                      InkWell(
                        onTap: () => _toggleCommentLikeOptimistic(comment),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                (_optimisticLikes[comment.id] ?? false)
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 16,
                                color: (_optimisticLikes[comment.id] ?? false)
                                    ? Colors.red
                                    : Colors.grey[600],
                              ),
                              if ((_optimisticLikeCounts[comment.id] ?? comment.likesCount) > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  (_optimisticLikeCounts[comment.id] ?? comment.likesCount).toString(),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    else
                      InkWell(
                        onTap: () {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please sign in to like comments')),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite_border,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              if (comment.likesCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  comment.likesCount.toString(),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    // You can add a reply button here if needed
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Row(
          children: [
            // User avatar
            if (currentUserId != null)
              CircleAvatar(
                radius: 16,
                child: Text(
                  FirebaseAuth.instance.currentUser?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),

            const SizedBox(width: 12),

            // Text input
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),

            const SizedBox(width: 8),

            // Send button
            IconButton(
              onPressed: _isLoading ? null : _addComment,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }
}
