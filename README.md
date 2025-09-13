# sesame_exchange_shop

A cross-platform messaging application built with Flutter and Firebase. Users can sign in, view conversations, and exchange messages securely.

## Features

- User authentication (Firebase)
- Real-time messaging using Firestore
- Conversation grouping by sender
- Unread message indicators
- Robust error handling for permission and connectivity issues
- Friendly UI with Material Design

## Messages Screen

The messages screen displays user conversations grouped by sender. It uses a `StreamBuilder` to listen for real-time updates from Firestore. Key features:

- **Authentication Check:** Prompts users to sign in if not authenticated.
- **Error Handling:** Detects Firestore permission errors and displays a specific message with a button to help fix Firebase issues. Other errors show a truncated error message and a retry button.
- **Empty State:** Shows a friendly message when there are no messages.
- **Conversation Grouping:** Messages are grouped by sender, showing unread counts and latest message previews.
- **Mark as Read:** Tapping a conversation marks all unread messages as read for that sender.
- **Navigation:** Users can tap a conversation to view details in a separate screen.

Error handling is robust, with clear UI feedback for permission issues and other errors, helping users and developers quickly identify and resolve problems.

## Getting Started

1. **Clone the repository**
2. **Install dependencies**
   ```
   flutter pub get
   ```
3. **Configure Firebase**
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Set up Firestore security rules for messaging

4. **Run the app**
   ```
   flutter run
   ```

## Project Structure

- `lib/screens/messages_screen.dart`: Main messages screen
- `lib/services/auth_service.dart`: Authentication logic
- `lib/services/firestore_service.dart`: Firestore operations
- `lib/widgets/message_dialog.dart`: Message dialog UI

## Requirements

- Flutter SDK
- Firebase project (Firestore & Auth enabled)

## License

MIT
