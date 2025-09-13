class ItemModel {
  final String id;
  final String title;
  final String description;
  final String category; // 'furniture' or 'clothing'
  final List<String> imageUrls;
  final String ownerId;
  final String ownerName;
  final DateTime createdAt;
  final bool isAvailable;
  final Map<String, dynamic> mlLabels; // ML Kit detected labels
  final double confidence; // Overall ML confidence score
  final String? condition; // 'new', 'like-new', 'good', 'fair'
  final String? size; // For clothing
  final String? color;
  final String? brand;

  ItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.imageUrls,
    required this.ownerId,
    required this.ownerName,
    required this.createdAt,
    this.isAvailable = true,
    this.mlLabels = const {},
    this.confidence = 0.0,
    this.condition,
    this.size,
    this.color,
    this.brand,
  });

  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      ownerId: map['ownerId'] ?? '',
      ownerName: map['ownerName'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      isAvailable: map['isAvailable'] ?? true,
      mlLabels: Map<String, dynamic>.from(map['mlLabels'] ?? {}),
      confidence: (map['confidence'] ?? 0.0).toDouble(),
      condition: map['condition'],
      size: map['size'],
      color: map['color'],
      brand: map['brand'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'imageUrls': imageUrls,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isAvailable': isAvailable,
      'mlLabels': mlLabels,
      'confidence': confidence,
      'condition': condition,
      'size': size,
      'color': color,
      'brand': brand,
    };
  }
}
