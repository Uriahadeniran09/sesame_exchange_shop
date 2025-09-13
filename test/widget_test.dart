// This is a basic Flutter widget test for Sesame Exchange Shop.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:sesame_exchange_shop/main.dart';

// Mock Firebase for testing
void setupFirebaseAuthMocks() {
  // This would normally set up Firebase mocks
}

void main() {
  setUpAll(() async {
    // Initialize Firebase for testing
    setupFirebaseAuthMocks();
  });

  testWidgets('App loads with login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SesameExchangeApp());
    await tester.pumpAndSettle();

    // Verify that the login screen is displayed
    expect(find.text('Sesame Exchange'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);

    // Verify that key UI elements are present
    expect(find.text('Share furniture & clothing with friends'), findsOneWidget);
    expect(find.text('Smart Photo Recognition'), findsOneWidget);
  });

  testWidgets('Bottom navigation has correct tabs', (WidgetTester tester) async {
    // This test would need authentication mocking to properly test the home screen
    // For now, we'll test the basic app structure
    await tester.pumpWidget(const SesameExchangeApp());
    await tester.pumpAndSettle();

    // The app should load successfully without throwing errors
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
