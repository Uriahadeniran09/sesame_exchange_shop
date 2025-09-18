import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userProfilePicture;
  final String content;
  final DateTime createdAt;
  final int likesCount;
  final String? parentCommentId; // For nested replies

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userProfilePicture,
    required this.content,
    required this.createdAt,
    this.likesCount = 0,
    this.parentCommentId,
  });

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'] ?? '',
      postId: map['postId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userProfilePicture: map['userProfilePicture'],
      content: map['content'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: map['likesCount'] ?? 0,
      parentCommentId: map['parentCommentId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'userProfilePicture': userProfilePicture,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'likesCount': likesCount,
      'parentCommentId': parentCommentId,
    };
  }

  Comment copyWith({
    String? id,
    String? postId,
    String? userId,
    String? userName,
    String? userProfilePicture,
    String? content,
    DateTime? createdAt,
    int? likesCount,
    String? parentCommentId,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfilePicture: userProfilePicture ?? this.userProfilePicture,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      parentCommentId: parentCommentId ?? this.parentCommentId,
    );
  }
}
