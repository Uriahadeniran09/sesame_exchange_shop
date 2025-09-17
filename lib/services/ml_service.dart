import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image/image.dart' as img;

class MLService {
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();

  final ImagePicker _imagePicker = ImagePicker();
  ImageLabeler? _imageLabeler;

  // Enhanced categories with better keyword matching
  static const Map<String, List<String>> categoryMappings = {
    'clothing': ['shirt', 'dress', 'pants', 'jeans', 'jacket', 'coat', 'sweater', 'blouse', 'skirt', 'shorts', 'sock', 'shoe', 'boot', 'sneaker', 'hat', 'cap', 'scarf', 'glove', 'tie', 'belt', 'underwear', 'clothing', 'apparel', 'garment', 'textile', 'fabric', 'wear', 'fashion'],
    'electronics': ['phone', 'computer', 'laptop', 'tablet', 'television', 'tv', 'monitor', 'speaker', 'headphone', 'camera', 'keyboard', 'mouse', 'charger', 'cable', 'remote', 'game console', 'watch', 'electronic', 'device', 'gadget', 'mobile phone', 'smartphone', 'tech'],
    'furniture': ['chair', 'table', 'sofa', 'bed', 'desk', 'cabinet', 'shelf', 'couch', 'stool', 'bench', 'dresser', 'wardrobe', 'bookshelf', 'nightstand', 'lamp', 'furniture', 'seat', 'armchair', 'dining'],
    'vehicles': ['car', 'bicycle', 'bike', 'motorcycle', 'vehicle', 'wheel', 'tire', 'automotive', 'transport'],
    'sports': ['ball', 'bat', 'racket', 'bicycle', 'helmet', 'glove', 'equipment', 'sports', 'exercise', 'fitness', 'gym', 'workout', 'athletic', 'game'],
    'kitchenware': ['plate', 'cup', 'bowl', 'spoon', 'fork', 'knife', 'pot', 'pan', 'bottle', 'glass', 'mug', 'utensil', 'cookware', 'tableware', 'kitchen', 'cooking'],
    'toys': ['toy', 'doll', 'puzzle', 'game', 'block', 'figure', 'stuffed animal', 'teddy bear', 'plaything', 'play'],
    'tools': ['hammer', 'screwdriver', 'wrench', 'drill', 'saw', 'tool', 'equipment', 'instrument', 'hardware'],
    'bags': ['bag', 'purse', 'backpack', 'suitcase', 'handbag', 'wallet', 'briefcase', 'luggage', 'pouch'],
    'accessories': ['jewelry', 'necklace', 'bracelet', 'ring', 'earring', 'watch', 'sunglasses', 'glasses', 'accessory']
  };

  // Enhanced color keywords
  static const List<String> colorKeywords = [
    'red', 'blue', 'green', 'yellow', 'orange', 'purple', 'pink', 'brown',
    'black', 'white', 'gray', 'grey', 'silver', 'gold', 'beige', 'navy',
    'maroon', 'turquoise', 'lime', 'olive', 'teal', 'aqua', 'fuchsia',
    'crimson', 'scarlet', 'emerald', 'azure', 'violet', 'magenta', 'cyan',
    'amber', 'coral', 'ivory', 'khaki', 'lavender', 'salmon', 'tan',
    'cream', 'rust', 'burgundy', 'mint', 'peach', 'rose', 'bronze',
    'platinum', 'copper', 'mahogany', 'charcoal', 'slate', 'pearl'
  ];

  // Brand keywords
  static const List<String> brandKeywords = [
    'apple', 'samsung', 'nike', 'adidas', 'sony', 'lg', 'dell', 'hp',
    'canon', 'nikon', 'microsoft', 'google', 'amazon', 'ikea', 'levi',
    'zara', 'h&m', 'uniqlo', 'target', 'walmart'
  ];

  Future<void> initialize() async {
    try {
      _imageLabeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.1));
      print('✅ ML Kit ImageLabeler initialized with confidence threshold: 0.1');
    } catch (e) {
      print('❌ Error initializing ML Kit: $e');
    }
  }

  Future<void> dispose() async {
    await _imageLabeler?.close();
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

  /// Analyze image using ML Kit and generate intelligent description
  Future<Map<String, dynamic>> analyzeImage(File imageFile) async {
    try {
      print('🔍 Starting ML Kit analysis for image: ${imageFile.path}');

      if (_imageLabeler == null) {
        print('⚠️ ImageLabeler is null, initializing...');
        await initialize();
        if (_imageLabeler == null) {
          print('❌ Failed to initialize ImageLabeler');
          return getFallbackDescription();
        }
      }

      print('📱 Creating InputImage from file...');
      final inputImage = InputImage.fromFile(imageFile);

      print('🤖 Processing image with ML Kit...');
      final labels = await _imageLabeler!.processImage(inputImage);

      print('📊 ML Kit returned ${labels.length} labels:');
      for (final label in labels) {
        print('  - ${label.label}: ${(label.confidence * 100).toStringAsFixed(1)}%');
      }

      // Detect dominant color from image pixels
      print('🎨 Analyzing image colors...');
      final String? dominantColor = await _detectDominantColor(imageFile);

      if (labels.isEmpty) {
        print('❌ No labels detected by ML Kit');
        final fallback = getFallbackDescription();
        if (dominantColor != null) {
          fallback['color'] = dominantColor;
          fallback['description'] = 'This is a $dominantColor item for exchange';
        }
        return fallback;
      }

      // Extract information from labels with color information
      final analysis = _analyzeLabels(labels, dominantColor);
      print('✅ Analysis completed: $analysis');

      return {
        'category': analysis['category'],
        'labels': labels.map((label) => {
          'text': label.label,
          'confidence': label.confidence,
        }).toList(),
        'confidence': analysis['confidence'],
        'description': analysis['description'],
        'color': dominantColor ?? analysis['color'],
        'brand': analysis['brand'],
        'primaryItem': analysis['primaryItem'],
        'additionalFeatures': analysis['additionalFeatures'],
      };
    } catch (e) {
      print('❌ Error analyzing image: $e');
      return getFallbackDescription();
    }
  }

  /// Detect dominant color from image pixels
  Future<String?> _detectDominantColor(File imageFile) async {
    try {
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        print('❌ Could not decode image for color analysis');
        return null;
      }

      print('🔍 Analyzing ${image.width}x${image.height} image for colors...');

      Map<String, int> colorCounts = {};

      // Sample multiple points across the image (grid sampling)
      final int sampleSize = 20; // 20x20 grid = 400 samples
      final int stepX = math.max(1, image.width ~/ sampleSize);
      final int stepY = math.max(1, image.height ~/ sampleSize);

      int totalSamples = 0;

      for (int y = 0; y < image.height; y += stepY) {
        for (int x = 0; x < image.width; x += stepX) {
          final img.Pixel pixel = image.getPixel(x, y);
          final int r = pixel.r.toInt();
          final int g = pixel.g.toInt();
          final int b = pixel.b.toInt();

          // Skip very light, very dark, or very grey pixels to focus on actual colors
          final int brightness = ((r + g + b) / 3).round();
          final int colorfulness = math.max(math.max((r - g).abs(), (g - b).abs()), (r - b).abs());

          if (brightness > 40 && brightness < 220 && colorfulness > 20) {
            final String? colorName = _getColorName(r, g, b);
            if (colorName != null) {
              colorCounts[colorName] = (colorCounts[colorName] ?? 0) + 1;
              totalSamples++;
            }
          }
        }
      }

      print('🎨 Sampled $totalSamples color points');
      print('🎨 Color distribution: $colorCounts');

      // Return the most frequent color if we have enough samples
      if (colorCounts.isNotEmpty && totalSamples > 10) {
        final dominantColorEntry = colorCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b);

        // Only return if the dominant color appears in at least 15% of samples
        if (dominantColorEntry.value >= (totalSamples * 0.15)) {
          print('🎨 Detected dominant color: ${dominantColorEntry.key} (${dominantColorEntry.value}/$totalSamples samples)');
          return dominantColorEntry.key;
        }
      }

      print('🎨 No dominant color detected');
      return null;
    } catch (e) {
      print('❌ Error detecting color: $e');
      return null;
    }
  }

  /// Convert RGB values to color name
  String? _getColorName(int r, int g, int b) {
    // Red variants
    if (r > 140 && g < 100 && b < 100) return 'red';
    if (r > 120 && g < 80 && b < 80 && r > g + 40) return 'red';

    // Blue variants
    if (b > 140 && r < 100 && g < 100) return 'blue';
    if (b > 120 && r < 80 && g < 80 && b > r + 40) return 'blue';

    // Green variants
    if (g > 140 && r < 100 && b < 100) return 'green';
    if (g > 120 && r < 80 && b < 80 && g > r + 40) return 'green';

    // Yellow (high red and green, low blue)
    if (r > 130 && g > 130 && b < 100) return 'yellow';
    if (r > 120 && g > 120 && b < 80 && (r + g) > (b + 160)) return 'yellow';

    // Orange (high red, medium green, low blue)
    if (r > 140 && g > 80 && g < 140 && b < 80) return 'orange';

    // Purple/Violet (high red and blue, low green)
    if (r > 100 && b > 100 && g < 80) return 'purple';
    if (r > 120 && b > 120 && g < 100 && (r + b) > (g + 140)) return 'purple';

    // Pink (high red, medium green and blue)
    if (r > 140 && g > 100 && b > 100 && r > g + 20 && r > b + 20) return 'pink';

    // Brown (medium red, lower green and blue)
    if (r > 80 && r < 160 && g > 40 && g < 120 && b > 20 && b < 80 && r > g && g > b) return 'brown';

    // Black (all low)
    if (r < 60 && g < 60 && b < 60) return 'black';

    // White (all high)
    if (r > 200 && g > 200 && b > 200) return 'white';

    // Gray (all similar and medium)
    final int avg = (r + g + b) ~/ 3;
    final int variance = math.max(math.max((r - avg).abs(), (g - avg).abs()), (b - avg).abs());
    if (variance < 30 && avg > 60 && avg < 200) return 'gray';

    // Silver/metallic (high values, low variance)
    if (variance < 20 && avg > 140 && avg < 200) return 'silver';

    return null;
  }

  /// Analyze ML Kit labels to extract meaningful information
  Map<String, dynamic> _analyzeLabels(List<ImageLabel> labels, String? dominantColor) {
    String category = 'other';
    String? color;
    String? brand;
    String primaryItem = 'item';
    List<String> additionalFeatures = [];
    double confidence = 0.0;

    print('🔍 Starting label analysis with ${labels.length} labels');

    // Sort labels by confidence
    final sortedLabels = labels..sort((a, b) => b.confidence.compareTo(a.confidence));

    if (sortedLabels.isNotEmpty) {
      confidence = sortedLabels.first.confidence;
      print('📈 Highest confidence: ${(confidence * 100).toStringAsFixed(1)}%');
    }

    // Extract information from labels
    for (final label in sortedLabels) {
      final labelText = label.label.toLowerCase();
      print('🏷️ Processing label: "$labelText" (${(label.confidence * 100).toStringAsFixed(1)}%)');

      // Determine category
      if (category == 'other') {
        String foundCategory = _determineCategory(labelText);
        if (foundCategory != 'other') {
          category = foundCategory;
          print('📂 Category found: $category');
        }
      }

      // Extract colors from labels
      if (color == null) {
        String? foundColor = _extractColor(labelText);
        if (foundColor != null) {
          color = foundColor;
          print('🎨 Color found in label: $color');
        }
      }

      // Extract brands
      if (brand == null) {
        String? foundBrand = _extractBrand(labelText);
        if (foundBrand != null) {
          brand = foundBrand;
          print('🏷️ Brand found: $brand');
        }
      }

      // Primary item detection
      if (primaryItem == 'item' && label.confidence > 0.2) {
        String refinedItem = _refinePrimaryItem(labelText);
        if (refinedItem != 'item' && !_isGenericLabel(refinedItem)) {
          primaryItem = refinedItem;
          print('🎯 Primary item found: $primaryItem');
        }
      }

      // Use highest confidence non-generic label as primary item
      if (primaryItem == 'item' && label == sortedLabels.first && !_isGenericLabel(labelText)) {
        primaryItem = _refinePrimaryItem(labelText);
        print('🎯 Using highest confidence label as primary item: $primaryItem');
      }

      // Collect additional features
      if (label.confidence > 0.15 && !_isGenericLabel(labelText)) {
        additionalFeatures.add(labelText);
        print('➕ Added feature: $labelText');
      }
    }

    // Fallback for primary item
    if (primaryItem == 'item') {
      for (final label in sortedLabels) {
        final labelText = label.label.toLowerCase();
        if (!_isGenericLabel(labelText) && label.confidence > 0.1) {
          primaryItem = _refinePrimaryItem(labelText);
          print('🎯 Fallback primary item: $primaryItem');
          break;
        }
      }
    }

    // Enhanced description generation
    final description = _generateEnhancedDescription(
      primaryItem, category, dominantColor ?? color, brand, additionalFeatures, confidence, labels
    );

    final result = {
      'category': category,
      'color': dominantColor ?? color,
      'brand': brand,
      'primaryItem': primaryItem,
      'additionalFeatures': additionalFeatures,
      'confidence': confidence,
      'description': description,
    };

    print('📋 Final analysis result: $result');
    return result;
  }

  /// Generate enhanced, more natural descriptions
  String _generateEnhancedDescription(
    String primaryItem,
    String category,
    String? color,
    String? brand,
    List<String> additionalFeatures,
    double confidence,
    List<ImageLabel> allLabels
  ) {
    final buffer = StringBuffer();

    // Start with more natural phrasing
    if (color != null) {
      buffer.write('This appears to be a $color ');
    } else {
      buffer.write('This appears to be a ');
    }

    // Add primary item
    buffer.write(primaryItem);

    // Add brand with better phrasing
    if (brand != null) {
      buffer.write(' made by $brand');
    }

    // Add category context with more natural language
    String categoryDescription = _getCategoryDescription(category, primaryItem);
    if (categoryDescription.isNotEmpty) {
      buffer.write(categoryDescription);
    }

    // Add material/texture information if detected
    String materialInfo = _extractMaterialInfo(allLabels);
    if (materialInfo.isNotEmpty) {
      buffer.write('. $materialInfo');
    }

    // Add condition/style information
    String conditionInfo = _extractConditionInfo(allLabels);
    if (conditionInfo.isNotEmpty) {
      buffer.write('. $conditionInfo');
    }

    // Add relevant features with better phrasing
    final relevantFeatures = additionalFeatures
        .where((feature) => feature != primaryItem && feature != color && feature != brand)
        .where((feature) => !_isMaterialOrCondition(feature))
        .take(2)
        .toList();

    if (relevantFeatures.isNotEmpty) {
      buffer.write('. Notable features include: ');
      buffer.write(relevantFeatures.join(' and '));
    }

    // Add confidence note with better language
    if (confidence < 0.5) {
      buffer.write('. Please verify the details as the auto-detection confidence is low');
    } else if (confidence < 0.7) {
      buffer.write('. Auto-detection is moderately confident, please double-check details');
    }

    buffer.write('.');

    return buffer.toString();
  }

  /// Get more natural category descriptions
  String _getCategoryDescription(String category, String primaryItem) {
    switch (category) {
      case 'clothing':
        return ', which is a piece of clothing or apparel';
      case 'electronics':
        return ', an electronic device or gadget';
      case 'furniture':
        return ', a piece of furniture for your home';
      case 'vehicles':
        return ', a vehicle or transportation item';
      case 'sports':
        return ', sports or fitness equipment';
      case 'kitchenware':
        return ', a kitchen utensil or cooking item';
      case 'toys':
        return ', a toy or game for entertainment';
      case 'tools':
        return ', a tool or hardware item';
      case 'bags':
        return ', a bag or carrying accessory';
      case 'accessories':
        return ', a fashion accessory or personal item';
      default:
        return '';
    }
  }

  /// Extract material information from labels
  String _extractMaterialInfo(List<ImageLabel> labels) {
    final materials = ['metal', 'plastic', 'wood', 'leather', 'fabric', 'glass', 'ceramic', 'rubber', 'cotton', 'denim'];

    for (final label in labels) {
      final labelText = label.label.toLowerCase();
      for (final material in materials) {
        if (labelText.contains(material) && label.confidence > 0.3) {
          return 'It appears to be made of $material';
        }
      }
    }
    return '';
  }

  /// Extract condition/style information from labels
  String _extractConditionInfo(List<ImageLabel> labels) {
    final Map<String, String> conditionMappings = {
      'vintage': 'It has a vintage or retro style',
      'modern': 'It has a modern design',
      'antique': 'It appears to be an antique piece',
      'new': 'It looks to be in new condition',
      'used': 'It appears to be pre-owned',
      'worn': 'It shows some signs of wear',
      'classic': 'It has a classic design',
      'decorative': 'It serves a decorative purpose',
    };

    for (final label in labels) {
      final labelText = label.label.toLowerCase();
      for (final condition in conditionMappings.keys) {
        if (labelText.contains(condition) && label.confidence > 0.3) {
          return conditionMappings[condition]!;
        }
      }
    }
    return '';
  }

  /// Check if a feature is material or condition related
  bool _isMaterialOrCondition(String feature) {
    final materialConditionTerms = ['metal', 'plastic', 'wood', 'leather', 'fabric', 'glass', 'ceramic', 'rubber', 'cotton', 'denim', 'vintage', 'modern', 'antique', 'new', 'used', 'worn', 'classic', 'decorative'];
    return materialConditionTerms.any((term) => feature.contains(term));
  }

  /// Determine category from label
  String _determineCategory(String label) {
    for (final category in categoryMappings.keys) {
      if (categoryMappings[category]!.any((keyword) => label.contains(keyword))) {
        return category;
      }
    }
    return 'other';
  }

  /// Extract color from label
  String? _extractColor(String label) {
    final labelLower = label.toLowerCase();

    // Direct color match
    for (final color in colorKeywords) {
      if (labelLower.contains(color)) {
        print('🎨 Direct color match found: $color in "$label"');
        return color;
      }
    }

    // Pattern matching
    for (final color in colorKeywords) {
      if (labelLower.startsWith('$color ') ||
          labelLower.endsWith(' $color') ||
          labelLower.contains(' $color ')) {
        print('🎨 Pattern color match found: $color in "$label"');
        return color;
      }
    }

    return null;
  }

  /// Extract brand from label
  String? _extractBrand(String label) {
    for (final brand in brandKeywords) {
      if (label.toLowerCase().contains(brand)) {
        return brand;
      }
    }
    return null;
  }

  /// Refine primary item name
  String _refinePrimaryItem(String label) {
    final specificTerms = label.split(' ').where((term) =>
      !['the', 'a', 'an', 'and', 'or', 'of', 'in', 'on', 'at'].contains(term)
    ).toList();

    return specificTerms.isNotEmpty ? specificTerms.first : label;
  }

  /// Check if label is too generic
  bool _isGenericLabel(String label) {
    const genericLabels = ['object', 'thing', 'item', 'product', 'material', 'stuff', 'pattern', 'design', 'texture'];
    return genericLabels.any((generic) => label.contains(generic));
  }

  /// Get fallback description when analysis is not possible
  Map<String, dynamic> getFallbackDescription() {
    return {
      'category': 'other',
      'labels': [],
      'confidence': 0.0,
      'description': 'This item is available for exchange. Please add more details manually.',
      'color': null,
      'brand': null,
      'primaryItem': 'item',
      'additionalFeatures': [],
    };
  }

  /// Get available categories for manual selection
  static List<String> get availableCategories => categoryMappings.keys.toList()..add('other');
}
