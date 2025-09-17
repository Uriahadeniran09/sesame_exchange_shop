import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/ml_service.dart';
import '../models/post_model.dart';
import '../utils/string_extensions.dart';
import '../widgets/custom_bottom_nav.dart';

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

  final List<String> _categories = [
    'furniture',
    'electronics',
    'clothing',
    'books',
    'sports',
    'toys',
    'home',
    'other'
  ];

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
          // Add new images to existing ones instead of replacing
          _selectedImages.addAll(pickedFiles.map((file) => File(file.path)).toList());
        });

        // Analyze the first new image for ML analysis
        if (pickedFiles.isNotEmpty) {
          final analysis = _mlService.analyzeImage(File(pickedFiles.first.path), selectedCategory: _selectedCategory);

          setState(() {
            _mlAnalysis = analysis;
            _selectedCategory = analysis['category'] ?? 'furniture';

            // Pre-fill form with ML analysis only if fields are empty
            if (_titleController.text.isEmpty && analysis['description'] != null) {
              _titleController.text = analysis['description'];
            }

            if (_descriptionController.text.isEmpty) {
              _generateDescription(analysis);
            }
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e')),
      );
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
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

        // Analyze image
        final analysis = _mlService.analyzeImage(File(pickedFile.path), selectedCategory: _selectedCategory);

        setState(() {
          _mlAnalysis = analysis;
          _selectedCategory = analysis['category'] ?? 'furniture';

          // Pre-fill form with ML analysis
          if (_titleController.text.isEmpty && analysis['description'] != null) {
            _titleController.text = analysis['description'];
          }

          if (_descriptionController.text.isEmpty) {
            _generateDescription(analysis);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  void _generateDescription(Map<String, dynamic> analysis) {
    final List<String> descriptionParts = [];

    if (analysis['color'] != null) {
      descriptionParts.add('Color: ${analysis['color']}');
    }

    if (analysis['brand'] != null) {
      descriptionParts.add('Brand: ${analysis['brand']}');
    }

    if (analysis['size'] != null) {
      descriptionParts.add('Size: ${analysis['size']}');
    }

    final labels = analysis['labels'] as List<dynamic>? ?? [];
    if (labels.isNotEmpty) {
      final topLabels = labels.take(3).map((label) => label['text']).join(', ');
      descriptionParts.add('Detected features: $topLabels');
    }

    _descriptionController.text = descriptionParts.join('\n');
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

      // Upload images to Firebase Storage
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

      // Get user profile for additional info
      final userProfile = await firestoreService.getUserProfile(currentUser.uid);

      final post = PostModel(
        id: '', // Will be set by Firestore
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
        Navigator.pop(context); // Go back to home screen
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
        ],
      ),
    );
  }

  void _onNavTapped(int index) {
    // Prevent multiple rapid taps
    if (_isUploading) return;

    // Handle navigation from AddItemScreen with immediate response
    switch (index) {
      case 0: // Home
        // Use immediate pop with result for faster response
        Navigator.pop(context, {'tab': 'home'});
        break;
      case 1: // Add (current screen)
        // Already on add screen, do nothing
        return;
      case 2: // Messages
        Navigator.pop(context, {'tab': 'messages'});
        break;
      case 3: // Profile
        Navigator.pop(context, {'tab': 'profile'});
        break;
      default:
        Navigator.pop(context, {'tab': 'home'});
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
            SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 1, // Highlight the add button since we're on add screen
        onTap: _onNavTapped,
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
            // Display selected images
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
                        // Remove button
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

            // Image index indicator
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

            // Loading indicator
            if (_isAnalyzing)
              const Center(
                child: CircularProgressIndicator(),
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
              ],
            ),
            const SizedBox(height: 12),
            if (_mlAnalysis!['category'] != null)
              Chip(
                label: Text('Category: ${_mlAnalysis!['category'].toString().capitalize()}'),
                backgroundColor: Colors.blue[50],
              ),
            if (_mlAnalysis!['description'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Suggested Title: ${_mlAnalysis!['description']}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            if (_mlAnalysis!['labels'] != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: (_mlAnalysis!['labels'] as List)
                    .take(5)
                    .map((label) => Chip(
                          label: Text(
                            label['text'],
                            style: const TextStyle(fontSize: 12),
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
        // Category dropdown
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

        // Title field
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

        // Description field
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

        // Location field
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
