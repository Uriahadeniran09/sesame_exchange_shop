import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/ml_service.dart';
import '../models/post_model.dart';
import '../utils/string_extensions.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final MLService _mlService = MLService();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  List<File> _selectedImages = [];
  Map<String, dynamic>? _mlAnalysis;
  bool _isAnalyzing = false;
  bool _isUploading = false;
  String _selectedCategory = 'furniture';
  int _currentImageIndex = 0;

  final List<String> _categories = MLService.availableCategories;

  @override
  void initState() {
    super.initState();
    _initializeMLService();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _mlService.dispose();
    super.dispose();
  }

  Future<void> _initializeMLService() async {
    await _mlService.initialize();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();

      if (pickedFiles.isNotEmpty) {
        setState(() {
          _isAnalyzing = true;
          _selectedImages.addAll(pickedFiles.map((file) => File(file.path)).toList());
        });

        if (pickedFiles.isNotEmpty) {
          final analysis = await _mlService.analyzeImage(File(pickedFiles.first.path));

          setState(() {
            _mlAnalysis = analysis;
            _selectedCategory = analysis['category'] ?? 'other';

            if (_titleController.text.isEmpty && analysis['primaryItem'] != null) {
              _titleController.text = analysis['primaryItem'];
            }

            if (_descriptionController.text.isEmpty && analysis['description'] != null) {
              _descriptionController.text = analysis['description'];
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _pickSingleImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);

      if (pickedFile != null) {
        setState(() {
          _isAnalyzing = true;
          _selectedImages.add(File(pickedFile.path));
        });

        final analysis = await _mlService.analyzeImage(File(pickedFile.path));

        setState(() {
          _mlAnalysis = analysis;
          _selectedCategory = analysis['category'] ?? 'other';

          if (_titleController.text.isEmpty && analysis['primaryItem'] != null) {
            _titleController.text = analysis['primaryItem'];
          }

          if (_descriptionController.text.isEmpty && analysis['description'] != null) {
            _descriptionController.text = analysis['description'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _submitPost() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one image')),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to add posts')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);

      List<String> imageUrls = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        final imageUrl = await firestoreService.uploadPostImage(
          currentUser.uid,
          _selectedImages[i],
          i
        );
        if (imageUrl != null) {
          imageUrls.add(imageUrl);
        }
      }

      final userProfile = await firestoreService.getUserProfile(currentUser.uid);

      final post = PostModel(
        id: '',
        userId: currentUser.uid,
        userName: userProfile?.fullName.isNotEmpty == true
            ? userProfile!.fullName
            : (currentUser.displayName ?? 'Anonymous'),
        userProfilePicture: userProfile?.profilePictureUrl,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrls: imageUrls,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        createdAt: DateTime.now(),
        category: _selectedCategory,
        isAvailable: true,
      );

      final success = await firestoreService.addPost(post);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post added successfully!')),
        );
        _resetForm();
        Navigator.pop(context);
      } else {
        throw Exception('Failed to add post');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding post: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _resetForm() {
    setState(() {
      _selectedImages = [];
      _mlAnalysis = null;
      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();
      _selectedCategory = 'furniture';
      _currentImageIndex = 0;
    });
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      if (_currentImageIndex >= _selectedImages.length && _selectedImages.isNotEmpty) {
        _currentImageIndex = _selectedImages.length - 1;
      }
    });
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Pick Multiple Images'),
            onTap: () {
              Navigator.pop(context);
              _pickImages();
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Take Photo'),
            onTap: () {
              Navigator.pop(context);
              _pickSingleImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text('Choose from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickSingleImage(ImageSource.gallery);
            },
          ),
          if (kDebugMode) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.science, color: Colors.orange),
              title: const Text('Test ML Kit (Mock Data)'),
              subtitle: const Text('Test with simulated analysis'),
              onTap: () {
                Navigator.pop(context);
                _testMLKitWithSampleData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_search, color: Colors.blue),
              title: const Text('Test with Sample Images'),
              subtitle: const Text('Use your actual images with real ML Kit'),
              onTap: () {
                Navigator.pop(context);
                _showSampleImagePicker();
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showSampleImagePicker() {
    final sampleImages = [
      {
        'name': 'Sample Image 1',
        'file': '70587EFB-9F35-4BEF-BC4A-FA881EDF1CE6.jpeg',
        'description': 'Test ML Kit with your first sample image',
      },
      {
        'name': 'Sample Image 2',
        'file': '8452361a-f65d-4a54-a818-18775c423c60.jpg',
        'description': 'Test ML Kit with your second sample image',
      },
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test ML Kit with Your Sample Images',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...sampleImages.map((image) => Card(
              child: ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.blue[50],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/sample_images/${image['file']}',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.image,
                          color: Colors.blue[700],
                        );
                      },
                    ),
                  ),
                ),
                title: Text(image['name'] as String),
                subtitle: Text(image['description'] as String),
                trailing: const Icon(Icons.science, color: Colors.green),
                onTap: () {
                  Navigator.pop(context);
                  _testWithAssetImage(image['file'] as String);
                },
              ),
            )),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Real ML Kit Testing',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'These options will use your actual images from assets/sample_images/ and run them through Google ML Kit for real object detection!',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testMLKitWithSampleData() async {
    setState(() {
      _isAnalyzing = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    final testScenarios = [
      {
        'category': 'kitchenware',
        'primaryItem': 'bottle',
        'description': 'This is a green bottle, a kitchen item. It appears to have features related to: plastic, beverage, container.',
        'color': 'green',
        'brand': null,
        'confidence': 0.85,
        'labels': [
          {'text': 'Bottle', 'confidence': 0.95},
          {'text': 'Plastic', 'confidence': 0.80},
          {'text': 'Green', 'confidence': 0.75},
          {'text': 'Beverage', 'confidence': 0.70},
          {'text': 'Container', 'confidence': 0.65},
        ],
        'additionalFeatures': ['plastic', 'beverage', 'container'],
      },
      {
        'category': 'electronics',
        'primaryItem': 'smartphone',
        'description': 'This is a black smartphone by Apple, an electronic device. It appears to have features related to: mobile, communication, device.',
        'color': 'black',
        'brand': 'apple',
        'confidence': 0.92,
        'labels': [
          {'text': 'Mobile phone', 'confidence': 0.95},
          {'text': 'Smartphone', 'confidence': 0.90},
          {'text': 'Black', 'confidence': 0.85},
          {'text': 'Apple', 'confidence': 0.80},
          {'text': 'Electronic', 'confidence': 0.75},
        ],
        'additionalFeatures': ['mobile', 'communication', 'device'],
      },
      {
        'category': 'clothing',
        'primaryItem': 'shirt',
        'description': 'This is a blue shirt, a piece of clothing. It appears to have features related to: cotton, casual, apparel.',
        'color': 'blue',
        'brand': null,
        'confidence': 0.78,
        'labels': [
          {'text': 'Shirt', 'confidence': 0.90},
          {'text': 'Blue', 'confidence': 0.85},
          {'text': 'Cotton', 'confidence': 0.70},
          {'text': 'Clothing', 'confidence': 0.75},
          {'text': 'Casual', 'confidence': 0.65},
        ],
        'additionalFeatures': ['cotton', 'casual', 'apparel'],
      },
      {
        'category': 'furniture',
        'primaryItem': 'chair',
        'description': 'This is a brown chair, a furniture item. It appears to have features related to: wood, seat, office.',
        'color': 'brown',
        'brand': 'ikea',
        'confidence': 0.88,
        'labels': [
          {'text': 'Chair', 'confidence': 0.95},
          {'text': 'Furniture', 'confidence': 0.90},
          {'text': 'Wood', 'confidence': 0.80},
          {'text': 'Brown', 'confidence': 0.75},
          {'text': 'Seat', 'confidence': 0.70},
        ],
        'additionalFeatures': ['wood', 'seat', 'office'],
      },
    ];

    final random = DateTime.now().millisecondsSinceEpoch % testScenarios.length;
    final selectedScenario = testScenarios[random];

    setState(() {
      _mlAnalysis = selectedScenario;
      _selectedCategory = selectedScenario['category'] as String;

      if (_titleController.text.isEmpty) {
        _titleController.text = selectedScenario['primaryItem'] as String;
      }

      if (_descriptionController.text.isEmpty) {
        _descriptionController.text = selectedScenario['description'] as String;
      }

      _isAnalyzing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Test ML Kit analysis completed! Detected: ${selectedScenario['primaryItem']}'),
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: 'Reset',
          onPressed: () {
            setState(() {
              _mlAnalysis = null;
              _titleController.clear();
              _descriptionController.clear();
            });
          },
        ),
      ),
    );
  }

  Future<File> _loadAssetImage(String assetPath) async {
    final byteData = await rootBundle.load('assets/sample_images/$assetPath');
    final file = File('${(await getTemporaryDirectory()).path}/$assetPath');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  Future<void> _testWithAssetImage(String assetPath) async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      print('Loading asset image: $assetPath');
      final imageFile = await _loadAssetImage(assetPath);
      print('Image loaded, starting ML analysis...');

      final analysis = await _mlService.analyzeImage(imageFile);
      print('ML Analysis result: $analysis');

      // Force setState to ensure UI updates with the new analysis
      if (mounted) {
        setState(() {
          _mlAnalysis = analysis;
          _selectedCategory = analysis['category'] ?? 'other';

          // Always update the fields with ML analysis results
          _titleController.text = analysis['primaryItem'] ?? 'item';
          _descriptionController.text = analysis['description'] ?? '';
        });

        // Show detailed results in snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Asset image analyzed! Detected: ${analysis['primaryItem']}'),
                if (analysis['category'] != 'other')
                  Text('Category: ${analysis['category']}'),
                if (analysis['color'] != null)
                  Text('Color: ${analysis['color']}'),
                if (analysis['confidence'] != null)
                  Text('Confidence: ${(analysis['confidence'] * 100).toInt()}%'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('Error analyzing asset image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing asset image: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Item'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showImagePickerOptions,
            icon: const Icon(Icons.add_a_photo),
            tooltip: 'Add Images',
          ),
          if (_selectedImages.isNotEmpty)
            TextButton(
              onPressed: _resetForm,
              child: const Text('Clear'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImagePicker(),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showImagePickerOptions,
              icon: const Icon(Icons.add_photo_alternate),
              label: Text(_selectedImages.isEmpty ? 'Add Images' : 'Add More Images'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_mlAnalysis != null) _buildMLAnalysis(),
            const SizedBox(height: 24),
            _buildFormFields(),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isUploading ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isUploading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Adding Post...'),
                      ],
                    )
                  : const Text(
                      'Share Post',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _selectedImages.isEmpty ? _showImagePickerOptions : null,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            if (_selectedImages.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PageView.builder(
                  itemCount: _selectedImages.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentImageIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Image.file(
                            _selectedImages[index],
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to add photos',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            if (_selectedImages.length > 1)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < _selectedImages.length; i++)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2.0),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentImageIndex == i
                              ? Colors.blue[600]
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
            if (_isAnalyzing)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 8),
                      Text(
                        'Analyzing with ML Kit...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMLAnalysis() {
    if (_mlAnalysis == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.smart_toy, color: Colors.blue[600]),
                const SizedBox(width: 8),
                const Text(
                  'AI Analysis',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_mlAnalysis!['confidence'] != null)
                  Chip(
                    label: Text('${(_mlAnalysis!['confidence'] * 100).toInt()}%'),
                    backgroundColor: _mlAnalysis!['confidence'] > 0.7
                        ? Colors.green[100]
                        : Colors.orange[100],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_mlAnalysis!['category'] != null)
              Chip(
                label: Text('Category: ${_mlAnalysis!['category'].toString().capitalize()}'),
                backgroundColor: Colors.blue[50],
              ),
            if (_mlAnalysis!['primaryItem'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Detected Item: ${_mlAnalysis!['primaryItem']}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
            if (_mlAnalysis!['color'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Color: ${_mlAnalysis!['color']}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            if (_mlAnalysis!['brand'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Brand: ${_mlAnalysis!['brand']}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            if (_mlAnalysis!['labels'] != null && (_mlAnalysis!['labels'] as List).isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Detection Labels:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: (_mlAnalysis!['labels'] as List)
                    .take(5)
                    .map((label) => Chip(
                          label: Text(
                            '${label['text']} (${(label['confidence'] * 100).toInt()}%)',
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.grey[100],
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedCategory,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: _categories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category.capitalize()),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedCategory = value;
              });
            }
          },
        ),
        const SizedBox(height: 20),
        const Text(
          'Title *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: 'What are you sharing?',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          maxLength: 100,
        ),
        const SizedBox(height: 20),
        const Text(
          'Description',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            hintText: 'Tell us more about this item...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          maxLines: 4,
          maxLength: 500,
        ),
        const SizedBox(height: 20),
        const Text(
          'Location (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _locationController,
          decoration: InputDecoration(
            hintText: 'Where is this item located?',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            prefixIcon: const Icon(Icons.location_on),
          ),
          maxLength: 100,
        ),
      ],
    );
  }
}
