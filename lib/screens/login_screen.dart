import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('LoginScreen: Starting Google Sign-in...');
      final userCredential = await _authService.signInWithGoogle();

      print('LoginScreen: Sign-in result - userCredential: ${userCredential != null}');

      if (userCredential != null && mounted) {
        print('LoginScreen: Authentication successful, user: ${userCredential.user?.email}');
        // Don't navigate manually - let AuthWrapper handle this
        // The AuthWrapper will automatically navigate to HomeScreen when auth state changes
      } else {
        // Check if user is actually signed in despite null userCredential
        // This can happen with redirect-based auth on web
        final currentUser = _authService.currentUser;
        if (currentUser != null) {
          print('LoginScreen: Authentication successful (redirect flow), user: ${currentUser.email}');
          // User is actually signed in, don't show error
        } else {
          print('LoginScreen: Authentication failed or was cancelled');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sign-in was cancelled')),
            );
          }
        }
      }
    } catch (e) {
      print('LoginScreen: Error during sign-in: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.8),
              Theme.of(context).primaryColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Logo and Title
                Icon(
                  Icons.swap_horiz,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),

                Text(
                  'Sesame Exchange',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Share furniture & clothing with friends',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),

                const SizedBox(height: 60),

                // Features List
                _buildFeatureItem(
                  icon: Icons.photo_camera,
                  title: 'Smart Photo Upload',
                  description: 'Easily add photos of your items',
                ),

                const SizedBox(height: 16),

                _buildFeatureItem(
                  icon: Icons.message,
                  title: 'Real-time Messaging',
                  description: 'Chat with friends about exchanges',
                ),

                const SizedBox(height: 16),

                _buildFeatureItem(
                  icon: Icons.people,
                  title: 'Friend Network',
                  description: 'Safe exchanges within your circle',
                ),

                const SizedBox(height: 60),

                // Google Sign-in Button
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                          ),
                        )
                      : Image.asset(
                          'assets/google_logo.png', // You'll need to add this
                          height: 20,
                          width: 20,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.login, color: Colors.blue);
                          },
                        ),
                  label: Text(
                    _isLoading ? 'Signing in...' : 'Continue with Google',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 3,
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'By signing in, you agree to our Terms of Service\nand Privacy Policy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
