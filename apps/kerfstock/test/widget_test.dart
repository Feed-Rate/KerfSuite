// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kerfstock/screens/login_screen.dart';

void main() {
  testWidgets('Login screen smoke test', (WidgetTester tester) async {
    // Build our widget.
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    // Verify that the login title and input fields are rendered.
    expect(find.text('KERFSTOCK'), findsOneWidget);
    expect(find.text('INVENTORY SYSTEM'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('AUTHENTICATE'), findsOneWidget);
  });
}
