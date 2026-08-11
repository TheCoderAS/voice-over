// Smoke test for the app shell: it boots to the Record tab and shows the
// bottom navigation. Replace/extend as features land.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:voice_over/main.dart';

void main() {
  testWidgets('app boots to the Record tab with navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VoiceOverApp());
    await tester.pump();

    // Bottom navigation is present with the main destinations.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Record'), findsWidgets);
    expect(find.text('Library'), findsWidgets);
    expect(find.text('Studio'), findsWidgets);
    expect(find.text('Voice'), findsWidgets);

    // Record tab shows its ready state.
    expect(find.text('Ready to record'), findsOneWidget);
  });
}
