import 'dart:io';
import 'package:image_picker/image_picker.dart';

class MLService {
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();

  final ImagePicker _imagePicker = ImagePicker();

  // Basic categories for manual selection
  static const List<String> availableCategories = ['furniture', 'clothing', 'electronics', 'books', 'sports', 'other'];

  Future<void> initialize() async {
    // No initialization needed without ML Kit
  }

  Future<void> dispose() async {
    // No cleanup needed without ML Kit
  }

  /// Pick image from camera or gallery
  Future<File?> pickImage({required ImageSource source}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  /// Generate basic item analysis without ML
  Map<String, dynamic> analyzeImage(File imageFile, {String? selectedCategory}) {
    return {
      'category': selectedCategory ?? 'other',
      'labels': [],
      'confidence': 0.0,
      'description': _generateBasicDescription(selectedCategory),
      'color': null,
      'brand': null,
      'size': null,
    };
  }

  /// Generate basic description based on category
  String _generateBasicDescription(String? category) {
    switch (category) {
      case 'furniture':
        return 'Furniture item';
      case 'clothing':
        return 'Clothing item';
      case 'electronics':
        return 'Electronic item';
      case 'books':
        return 'Book';
      case 'sports':
        return 'Sports equipment';
      default:
        return 'Item for exchange';
    }
  }

  /// Get fallback description when analysis is not possible
  Map<String, dynamic> getFallbackDescription() {
    return {
      'category': 'other',
      'labels': [],
      'confidence': 0.0,
      'description': 'Item for exchange',
      'color': null,
      'brand': null,
      'size': null,
    };
  }
}
