import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../widgets/firestore_test_widget.dart';

/// This screen demonstrates how to connect to your specific Firebase user ID
/// and test the real Firebase Storage implementation
class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;
  String _status = 'Ready to test Firebase connection';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Connection Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quick Firestore Access Test Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FirestoreTestWidget(),
                  ),
                );
              },
              icon: const Icon(Icons.bug_report),
              label: const Text('🔧 Fix "Error Loading" Issues'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Firebase Configuration',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Project ID: sesame-exchange-app'),
                    const Text('Storage Bucket: sesame-exchange-app.firebasestorage.app'),
                    const Text('Specific User ID: oRD1eNmcTz1vkvCDk4u3'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Status: $_status',
              style: TextStyle(
                color: _status.contains('Error') ? Colors.red : Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isLoading ? null : _testGetSpecificUser,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Test: Get Specific User (oRD1eNmcTz1vkvCDk4u3)'),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: _isLoading ? null : _testLinkCurrentUser,
              child: const Text('Test: Link Current User to Specific ID'),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: _isLoading ? null : _testUpdateUserCollection,
              child: const Text('Test: Update Users Collection (userid, email, pictures)'),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: _isLoading ? null : _testCreatePost,
              child: const Text('Test: Create Sample Post'),
            ),

            const SizedBox(height: 20),

            const Text(
              'How to Use Your Firebase:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Test connection to your specific user ID\n'
              '2. Link your current user data to the specific ID\n'
              '3. Upload real images to Firebase Storage\n'
              '4. All data will be stored in your Firebase project',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testGetSpecificUser() async {
    setState(() {
      _isLoading = true;
      _status = 'Connecting to Firebase...';
    });

    try {
      final user = await _firestoreService.getSpecificUser();
      setState(() {
        if (user != null) {
          _status = 'SUCCESS: Found user - ${user.displayName ?? user.email}';
        } else {
          _status = 'User ID oRD1eNmcTz1vkvCDk4u3 not found in Firebase';
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testLinkCurrentUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      setState(() {
        _status = 'Error: No current user signed in';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Linking current user to specific ID...';
    });

    try {
      final success = await _firestoreService.linkToSpecificUser(currentUser.uid);
      setState(() {
        if (success) {
          _status = 'SUCCESS: Linked ${currentUser.email} to oRD1eNmcTz1vkvCDk4u3';
        } else {
          _status = 'Failed to link user data';
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Error linking user: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testUpdateUserCollection() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      setState(() {
        _status = 'Error: No current user signed in';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Updating users collection with userid, email, and pictures...';
    });

    try {
      // Update the users collection directly using Firestore
      const String specificUserId = 'oRD1eNmcTz1vkvCDk4u3';
      await FirebaseFirestore.instance.collection('users').doc(specificUserId).set({
        'userid': specificUserId,
        'email': currentUser.email ?? 'test@example.com',
        'pictures': [
          'https://via.placeholder.com/150x150.png?text=Profile+Picture',
          'https://via.placeholder.com/400x300.png?text=Picture+1',
          'https://via.placeholder.com/400x300.png?text=Picture+2',
          'https://via.placeholder.com/400x300.png?text=Picture+3',
        ],
      });

      setState(() {
        _status = 'SUCCESS: Updated users collection with userid: $specificUserId, email: ${currentUser.email}, and 4 pictures!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error updating user collection: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testCreatePost() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      setState(() {
        _status = 'Error: No current user signed in';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Creating sample post...';
    });

    try {
      // Create a sample post with your specific user ID
      final samplePost = {
        'userId': 'oRD1eNmcTz1vkvCDk4u3',
        'userName': 'Test User',
        'title': 'Sample Post from Firebase Test',
        'description': 'This is a test post created from the Firebase connection test.',
        'location': 'Test Location',
        'category': 'electronics',
        'imageUrls': ['https://via.placeholder.com/400x300.png?text=Sample+Image'],
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'isAvailable': true,
        'likesCount': 0,
        'commentsCount': 0,
      };

      await FirebaseFirestore.instance.collection('posts').add(samplePost);

      setState(() {
        _status = 'SUCCESS: Created sample post in Firebase!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error creating post: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
