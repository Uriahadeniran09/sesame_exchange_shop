import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/ml_service.dart';
import 'services/firestore_service.dart';
import 'services/messaging_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/add_item_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/post_detail_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'widgets/auth_wrapper.dart';
import 'models/post_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully for ${kIsWeb ? 'web' : 'mobile'}');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
    // Still run the app but with error handling
  }

  runApp(const SesameExchangeApp());
}

class SesameExchangeApp extends StatelessWidget {
  const SesameExchangeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<MLService>(create: (_) => MLService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<MessagingService>(create: (_) => MessagingService()),
      ],
      child: MaterialApp(
        title: 'Sesame Exchange Shop',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.deepPurple,
          primaryColor: Colors.deepPurple,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const AuthWrapper(),
        routes: {
          '/post_detail': (context) {
            final PostModel post = ModalRoute.of(context)!.settings.arguments as PostModel;
            return PostDetailScreen(post: post);
          },
          '/home': (context) => const HomeScreen(),
          '/add_item': (context) => const AddItemScreen(),
          '/messages': (context) => const MessagesScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/chat': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            return ChatScreen(
              conversationId: args['conversationId'] ?? '',
              otherUserId: args['recipientId'],
              otherUserName: args['recipientName'],
              postTitle: args['postTitle'],
            );
          },
        },
      ),
    );
  }
}
