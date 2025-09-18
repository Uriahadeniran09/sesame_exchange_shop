import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../services/firestore_service.dart';
import '../services/messaging_service.dart';
import '../screens/chat_screen.dart';
import '../screens/post_detail_screen.dart';
import '../screens/comments_screen.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onRefresh;

  const PostCard({
    super.key,
    required this.post,
    this.onRefresh,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with TickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final MessagingService _messagingService = MessagingService();
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // optimistic like state
  bool _isLiked = false;
  bool _initialLiked = false;
  int _commentsCount = 0;
  bool _isLoading = false;
  int _localLikesCount = 0;

  late final AnimationController _likeAnimationController;
  late final Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
    _initialLiked = widget.post.isLikedByCurrentUser;
    _isLiked = _initialLiked;
    _commentsCount = widget.post.commentsCount;
    _localLikesCount = widget.post.likesCount;

    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _likeAnimationController, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshUserLikeFromServer());
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  Future<void> _refreshUserLikeFromServer() async {
    if (currentUserId == null) return;
    try {
      final liked = await _firestoreService.hasUserLikedPost(widget.post.id, currentUserId!);
      if (!mounted) return;
      setState(() {
        _initialLiked = liked;
        if ((_isLiked ? 1 : 0) - (_initialLiked ? 1 : 0) == 0) {
          _isLiked = _initialLiked;
        }
        if (_initialLiked && _localLikesCount == 0) _localLikesCount = 1;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _toggleLike() async {
    if (currentUserId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to like posts')));
      return;
    }

    if (_isLoading) return;

    final prev = _isLiked;
    setState(() {
      _isLoading = true;
      _isLiked = !_isLiked; // optimistic
      _localLikesCount += _isLiked ? 1 : -1;
      if (_localLikesCount < 0) _localLikesCount = 0;
    });

    try {
      final updatedCount = await _firestoreService.togglePostLikeAndGetCount(widget.post.id, currentUserId!);
      if (!mounted) return;

      if (updatedCount != null) {
        setState(() {
          _initialLiked = _isLiked;
          _localLikesCount = updatedCount;
        });
        _likeAnimationController.forward().then((_) => _likeAnimationController.reverse());
      } else {
        final success = await _firestoreService.togglePostLike(widget.post.id, currentUserId!);
        if (!mounted) return;
        if (success) {
          setState(() {
            _initialLiked = _isLiked;
          });
        } else {
          setState(() {
            _isLiked = prev;
            _localLikesCount += _isLiked ? 1 : -1; // undo
            if (_localLikesCount < 0) _localLikesCount = 0;
          });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update like')));
        }
      }
    } catch (_) {
      setState(() {
        _isLiked = prev;
        _localLikesCount += _isLiked ? 1 : -1;
        if (_localLikesCount < 0) _localLikesCount = 0;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update like')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.id != oldWidget.post.id) {
      _initialLiked = widget.post.isLikedByCurrentUser;
      _isLiked = _initialLiked;
      _commentsCount = widget.post.commentsCount;
      _localLikesCount = widget.post.likesCount;
      return;
    }

    final int oldServerLikes = oldWidget.post.likesCount;
    final int newServerLikes = widget.post.likesCount;
    final int serverDiff = newServerLikes - oldServerLikes;
    final int delta = (_isLiked ? 1 : 0) - (_initialLiked ? 1 : 0);

    if (serverDiff != 0) {
      _localLikesCount = widget.post.likesCount;
      if (serverDiff == delta && delta != 0) {
        _initialLiked = _isLiked;
      }
      _refreshUserLikeFromServer();
    }

    if (widget.post.likesCount != oldWidget.post.likesCount) {
      _localLikesCount = widget.post.likesCount;
    }
  }

  Future<void> _openDirectMessage() async {
    if (currentUserId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to send messages')));
      return;
    }

    try {
      final conversationId = _messaging_service_getIdSafe(currentUserId!, widget.post.userId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversationId,
            otherUserId: widget.post.userId,
            otherUserName: widget.post.userName,
            postTitle: widget.post.title,
          ),
        ),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to open message')));
    }
  }

  String _messaging_service_getIdSafe(String a, String b) {
    try {
      return _messagingService.getConversationId(a, b);
    } catch (_) {
      final ids = [a, b]..sort();
      return ids.join('_');
    }
  }

  void _openComments() {
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => CommentsScreen(post: widget.post)));
  }

  void _openPostDetail() {
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(post: widget.post)));
  }

  @override
  Widget build(BuildContext context) {
    final int displayedLikes = _localLikesCount;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: _openPostDetail,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserHeader(),
            _buildPostImage(),
            _buildPostContent(),
            _buildActionButtons(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (displayedLikes > 0) ...[
                    Text('$displayedLikes ${displayedLikes == 1 ? 'like' : 'likes'}', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                  if (displayedLikes > 0 && _commentsCount > 0) const Text(' • ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  if (_commentsCount > 0) Text('$_commentsCount ${_commentsCount == 1 ? 'comment' : 'comments'}', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: widget.post.userProfilePicture != null ? CachedNetworkImageProvider(widget.post.userProfilePicture!) : null,
            child: widget.post.userProfilePicture == null
                ? Text(widget.post.userName.isNotEmpty ? widget.post.userName[0].toUpperCase() : 'U', style: const TextStyle(fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.post.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (widget.post.location != null) Text(widget.post.location!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Text(_formatDateTime(widget.post.createdAt), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPostImage() {
    if (widget.post.imageUrls.isEmpty) {
      return Container(height: 200, color: Colors.grey[200], child: const Center(child: Icon(Icons.image_not_supported, size: 50)));
    }

    return GestureDetector(
      onTap: _openPostDetail,
      child: SizedBox(
        width: double.infinity,
        height: 250,
        child: PageView.builder(
          itemCount: widget.post.imageUrls.length,
          itemBuilder: (context, index) => CachedNetworkImage(
            imageUrl: widget.post.imageUrls[index],
            fit: BoxFit.cover,
            placeholder: (c, u) => Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())),
            errorWidget: (c, u, e) => Container(color: Colors.grey[200], child: const Icon(Icons.error)),
          ),
        ),
      ),
    );
  }

  Widget _buildPostContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.post.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text(widget.post.description, style: TextStyle(color: Colors.grey[700], fontSize: 14), maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)), child: Text(widget.post.category.toUpperCase(), style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.w500))),
            const SizedBox(width: 8),
            if (widget.post.isAvailable) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)), child: Text('AVAILABLE', style: TextStyle(color: Colors.green[700], fontSize: 12, fontWeight: FontWeight.w500))),
          ])
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          AnimatedBuilder(animation: _likeAnimation, builder: (context, child) {
            return Transform.scale(
              scale: _likeAnimation.value,
              child: IconButton(
                onPressed: _isLoading ? null : _toggleLike,
                icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.red : Colors.grey[600], size: 24),
                tooltip: _isLiked ? 'Unlike' : 'Like',
              ),
            );
          }),
          IconButton(onPressed: _openDirectMessage, icon: Icon(Icons.message_outlined, color: Colors.blue[600], size: 24), tooltip: 'Send Message'),
          IconButton(onPressed: _openComments, icon: Icon(Icons.comment_outlined, color: Colors.grey[600], size: 24), tooltip: 'View Comments'),
          const Spacer(),
          IconButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share functionality coming soon!'))), icon: Icon(Icons.share_outlined, color: Colors.grey[600], size: 24), tooltip: 'Share'),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}
