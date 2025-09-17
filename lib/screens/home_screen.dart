import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import '../widgets/custom_bottom_nav.dart';
import '../utils/string_extensions.dart';
import 'add_item_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'messages_screen.dart';
import 'firebase_test_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _selectedCategory = 'all';

  int get _bottomNavCurrentIndex {
    // Map internal index to bottom nav display index
    switch (_currentIndex) {
      case 0:
        return 0; // Home
      case 1:
        return 2; // Messages
      case 2:
        return 3; // Profile
      default:
        return 0; // Fallback to home
    }
  }

  void _onTabTapped(int index) {
    // Handle the add button (index 1) specially
    if (index == 1) {
      // Navigate to AddItemScreen and listen for result
      Navigator.pushNamed(context, '/add_item').then((result) {
        // Handle navigation result from AddItemScreen
        if (result is Map<String, dynamic> && result['tab'] != null) {
          final targetTab = result['tab'] as String;
          int newIndex;

          switch (targetTab) {
            case 'home':
              newIndex = 0; // Home internal index
              break;
            case 'messages':
              newIndex = 1; // Messages internal index
              break;
            case 'profile':
              newIndex = 2; // Profile internal index
              break;
            default:
              newIndex = 0; // Home fallback
          }

          setState(() {
            _currentIndex = newIndex;
          });
        }
      });
      return;
    }

    // For other tabs, map bottom nav indices to internal indices immediately
    // Bottom nav: [Home(0), Add(1), Messages(2), Profile(3)]
    // Internal:   [Home(0),        Messages(1), Profile(2)]
    int actualIndex;
    if (index == 0) {
      actualIndex = 0; // Home
    } else if (index == 2) {
      actualIndex = 1; // Messages
    } else if (index == 3) {
      actualIndex = 2; // Profile
    } else {
      actualIndex = 0; // Fallback to home
    }

    setState(() {
      _currentIndex = actualIndex;
    });
  }

  Future<void> _handlePostLike(PostModel post) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    final currentUser = authService.currentUser;
    if (currentUser != null) {
      await firestoreService.togglePostLike(post.id, currentUser.uid);
    }
  }

  void _handlePostComment(PostModel post) {
    // Navigate to post detail screen for comments
    Navigator.pushNamed(context, '/post_detail', arguments: post);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        return Scaffold(
          appBar: _currentIndex == 0 ? _buildHomeAppBar() : null,
          body: _buildBody(),
          bottomNavigationBar: CustomBottomNav(
            currentIndex: _bottomNavCurrentIndex, // Use the mapped index
            onTap: _onTabTapped,
          ),
          floatingActionButton: _currentIndex == 0
              ? FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddItemScreen(),
                      ),
                    ).then((_) {
                      // Clear focus when returning from AddItemScreen
                      FocusScope.of(context).unfocus();
                    });
                  },
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }

  AppBar _buildHomeAppBar() {
    return AppBar(
      title: const Text(
        'Sesame Exchange',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            // TODO: Implement search functionality
          },
          icon: const Icon(Icons.search),
        ),
        IconButton(
          onPressed: () {
            // TODO: Implement notifications
          },
          icon: const Icon(Icons.notifications_outlined),
        ),
      ],
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: _buildCategoryTabs(),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final categories = [
      'all',
      'furniture',
      'electronics',
      'clothing',
      'books',
      'sports',
      'toys',
      'home',
      'other'
    ];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilterChip(
              label: Text(
                category == 'all' ? 'All' : category.capitalize(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              selectedColor: Theme.of(context).primaryColor,
              backgroundColor: Colors.grey[200],
              checkmarkColor: Colors.white,
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeFeed();
      case 1:
        return const MessagesScreen(); // Messages moved to index 1 (was index 2)
      case 2:
        return const ProfileScreen(); // Profile moved to index 2 (was index 3)
      default:
        return _buildHomeFeed();
    }
  }

  Widget _buildHomeFeed() {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    return StreamBuilder<List<PostModel>>(
      stream: firestoreService.getPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Home Screen Error Details: ${snapshot.error}');

          // Enhanced error detection
          final errorMessage = snapshot.error.toString();
          final isPermissionError = errorMessage.contains('permission') ||
                                   errorMessage.contains('PERMISSION_DENIED') ||
                                   errorMessage.contains('insufficient permissions');

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPermissionError ? Icons.lock_outline : Icons.error_outline,
                    size: 64,
                    color: Colors.grey[400]
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isPermissionError ? 'Firestore Permission Error' : 'Error Loading Posts',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isPermissionError) ...[
                    const Text(
                      'Your Firebase security rules need to be updated.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FirebaseTestScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.build),
                      label: const Text('Fix Firestore Issues'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Error: ${errorMessage.length > 100 ? "${errorMessage.substring(0, 100)}..." : errorMessage}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {}); // Trigger rebuild
                        },
                        child: const Text('Retry'),
                      ),
                      TextButton(
                        onPressed: () => _showFirebaseInstructions(),
                        child: const Text('Manual Fix'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        List<PostModel> posts = snapshot.data ?? [];

        // Filter posts by category
        if (_selectedCategory != 'all') {
          posts = posts.where((post) => post.category == _selectedCategory).toList();
        }

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _selectedCategory == 'all'
                      ? 'No posts yet'
                      : 'No posts in ${_selectedCategory.capitalize()}',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to share something!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddItemScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add First Post'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {}); // Trigger rebuild to refresh data
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final currentUser = authService.currentUser;

              return FutureBuilder<bool>(
                future: currentUser != null
                    ? firestoreService.hasUserLikedPost(post.id, currentUser.uid)
                    : Future.value(false),
                builder: (context, likeSnapshot) {
                  final isLiked = likeSnapshot.data ?? false;
                  final postWithLikeStatus = post.copyWith(isLikedByCurrentUser: isLiked);

                  return PostCard(
                    post: postWithLikeStatus,
                    onLike: () => _handlePostLike(post),
                    onComment: () => _handlePostComment(post),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showFirebaseInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fix Firestore Permissions'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'To fix this error, update your Firestore security rules:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('1. Go to Firebase Console'),
              Text('2. Navigate to Firestore Database'),
              Text('3. Click on "Rules" tab'),
              Text('4. Replace the rules with:'),
              SizedBox(height: 8),
              SelectableText(
                '''rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read/write access to all documents
    match /{document=**} {
      allow read, write: if true;
    }
  }
}''',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  backgroundColor: Color(0xFFF5F5F5),
                ),
              ),
              SizedBox(height: 8),
              Text('5. Click "Publish"'),
              SizedBox(height: 12),
              Text(
                'Note: These rules allow all access. For production, implement proper authentication-based rules.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
