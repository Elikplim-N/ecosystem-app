import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecosytem/screens/auth_gate.dart';
import 'package:ecosytem/screens/splash_screen.dart';

void main() {
  // The splash pulses forever by design, so the tests advance time
  // explicitly rather than using pumpAndSettle.

  testWidgets('splash shows the BoaMe wordmark', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('BoaMe'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump();
  });

  testWidgets('splash renders the brand logo', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(Image), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump();
  });

  testWidgets('splash hands over to auth gate', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump();

    expect(find.byType(AuthGate), findsOneWidget);
  });

  testWidgets('startup failure replaces the splash animation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen(startupError: 'offline')),
    );
    await tester.pump();

    expect(find.text('The data service could not start.'), findsOneWidget);
    expect(find.text('BoaMe'), findsOneWidget);
  });
}
