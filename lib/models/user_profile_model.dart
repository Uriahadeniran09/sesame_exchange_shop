class UserProfileModel {
  final String uid;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final String? bio;
  final String? profilePictureUrl;
  final List<String> additionalPictureUrls;
  final DateTime? dateOfBirth;
  final Map<String, dynamic> preferences; // User preferences like notification settings
  final Map<String, dynamic> socialLinks; // Social media links
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfileModel({
    required this.uid,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.bio,
    this.profilePictureUrl,
    this.additionalPictureUrls = const [],
    this.dateOfBirth,
    this.preferences = const {},
    this.socialLinks = const {},
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    }
    return '';
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'bio': bio,
      'profilePictureUrl': profilePictureUrl,
      'additionalPictureUrls': additionalPictureUrls,
      'dateOfBirth': dateOfBirth?.millisecondsSinceEpoch,
      'preferences': preferences,
      'socialLinks': socialLinks,
      'isVerified': isVerified,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory UserProfileModel.fromMap(Map<String, dynamic> map) {
    return UserProfileModel(
      uid: map['uid'] ?? '',
      firstName: map['firstName'],
      lastName: map['lastName'],
      phoneNumber: map['phoneNumber'],
      bio: map['bio'],
      profilePictureUrl: map['profilePictureUrl'],
      additionalPictureUrls: List<String>.from(map['additionalPictureUrls'] ?? []),
      dateOfBirth: map['dateOfBirth'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dateOfBirth'])
          : null,
      preferences: Map<String, dynamic>.from(map['preferences'] ?? {}),
      socialLinks: Map<String, dynamic>.from(map['socialLinks'] ?? {}),
      isVerified: map['isVerified'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
    );
  }

  UserProfileModel copyWith({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? bio,
    String? profilePictureUrl,
    List<String>? additionalPictureUrls,
    DateTime? dateOfBirth,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? socialLinks,
    bool? isVerified,
  }) {
    return UserProfileModel(
      uid: uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bio: bio ?? this.bio,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      additionalPictureUrls: additionalPictureUrls ?? this.additionalPictureUrls,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      preferences: preferences ?? this.preferences,
      socialLinks: socialLinks ?? this.socialLinks,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
