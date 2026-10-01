import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('splash hands over to the entry chooser', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump();

    expect(find.byType(ChooseEntryScreen), findsOneWidget);
  });

  testWidgets('entry chooser offers BoaMe App and Admin', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChooseEntryScreen()));
    await tester.pump();

    expect(find.text('BoaMe App'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    // The old kiosk / mobile-app wording is gone.
    expect(find.text('KIOSK'), findsNothing);
    expect(find.text('MOBILE APP'), findsNothing);
  });

  testWidgets('entry chooser labels both audiences', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChooseEntryScreen()));
    await tester.pump();

    expect(find.text('Members and ambassadors'), findsOneWidget);
    expect(find.text('Network administrators'), findsOneWidget);
  });

  testWidgets('data service failure replaces the splash animation',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen(firebaseError: 'offline')),
    );
    await tester.pump();

    expect(find.text('The data service could not start.'), findsOneWidget);
    expect(find.text('BoaMe'), findsOneWidget);
  });
}
