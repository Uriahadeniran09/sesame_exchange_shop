import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class FirestoreTestWidget extends StatefulWidget {
  const FirestoreTestWidget({super.key});

  @override
  State<FirestoreTestWidget> createState() => _FirestoreTestWidgetState();
}

class _FirestoreTestWidgetState extends State<FirestoreTestWidget> {
  final AuthService _authService = AuthService();
  String _testResult = 'Testing Firestore connection...';

  @override
  void initState() {
    super.initState();
    _testFirestoreAccess();
  }

  Future<void> _testFirestoreAccess() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        setState(() {
          _testResult = 'ERROR: No user signed in';
        });
        return;
      }

      setState(() {
        _testResult = 'Testing Firestore access... Please wait.';
      });

      // Test 1: Simple read access to posts
      print('Testing posts collection access...');
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      // Test 2: Simple read access to messages
      print('Testing messages collection access...');
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('messages')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      // Test 3: Try to write a test document
      print('Testing write access...');
      await FirebaseFirestore.instance
          .collection('test')
          .doc('connection_test')
          .set({
            'timestamp': FieldValue.serverTimestamp(),
            'userId': currentUser.uid,
            'test': true,
          })
          .timeout(const Duration(seconds: 10));

      setState(() {
        _testResult = '''
✅ SUCCESS: Firestore access working!
Posts collection: ${postsSnapshot.docs.length} documents accessible
Messages collection: ${messagesSnapshot.docs.length} documents accessible
User: ${currentUser.email}
Write access: ✅ Working

Your Firestore permissions are correctly configured!
If you're still seeing errors, try:
1. Restart the app completely
2. Clear app data and sign in again
3. Check your internet connection
''';
      });
    } catch (e) {
      print('Firestore test error: $e');

      String errorMessage = e.toString();
      String solution = '';

      if (errorMessage.contains('PERMISSION_DENIED') || errorMessage.contains('permission')) {
        solution = '''
🔥 FIRESTORE RULES ISSUE:
Your Firebase security rules are blocking access.

IMMEDIATE FIX:
1. Go to Firebase Console → console.firebase.google.com
2. Select "sesame-exchange-app" project
3. Go to "Firestore Database" → "Rules" tab
4. Replace ALL rules with this:

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}

5. Click "Publish"
6. Wait 1-2 minutes for rules to propagate
''';
      } else if (errorMessage.contains('timeout') || errorMessage.contains('network')) {
        solution = '''
🌐 NETWORK ISSUE:
Check your internet connection and Firebase project status.
''';
      } else if (errorMessage.contains('not found') || errorMessage.contains('project')) {
        solution = '''
📱 PROJECT CONFIGURATION ISSUE:
Your app might not be properly connected to Firebase.
Check your google-services.json file.
''';
      } else {
        solution = '''
❓ UNKNOWN ERROR:
This might be a temporary Firebase issue or configuration problem.
Try restarting the app or check Firebase status.
''';
      }

      setState(() {
        _testResult = '''
❌ ERROR: Firestore access denied
Error Details: $errorMessage

$solution

If the error persists after following the fix, contact support with this error message.
''';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore Connection Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Firestore Access Test',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(_testResult),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to Fix Firestore Permissions:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text('1. Go to Firebase Console (console.firebase.google.com)'),
                    Text('2. Select your "sesame-exchange-app" project'),
                    Text('3. Navigate to "Firestore Database"'),
                    Text('4. Click on the "Rules" tab'),
                    Text('5. Replace the current rules with:'),
                    SizedBox(height: 8),
                    SelectableText(
                      '''rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
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
                    Text('6. Click "Publish" to save the changes'),
                    SizedBox(height: 12),
                    Text(
                      'Note: These rules allow full access for development. For production, implement proper authentication-based rules.',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _testResult = 'Testing Firestore connection...';
                  });
                  _testFirestoreAccess();
                },
                child: const Text('Test Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
