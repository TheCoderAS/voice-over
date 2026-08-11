// Basic smoke test for the app shell. It exists mainly so `flutter test` in CI
// has something real to run; replace it as actual features land.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:voice_over/main.dart';

void main() {
  testWidgets('app boots and shows the home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VoiceOverApp());

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Voice Over'), findsWidgets);
    expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
  });
}
