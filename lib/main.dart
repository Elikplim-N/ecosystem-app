import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/ui_helpers.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore the saved base URL, tokens and cached member before the first
  // frame, so the app can go straight to the right screen instead of flashing
  // the welcome screen and then the dashboard.
  //
  // A failure here is not fatal: the splash screen says so and the app still
  // opens, because a bad server address should not mean a black screen.
  Object? startupError;
  try {
    await auth.restore();
  } catch (e) {
    startupError = e;
  }

  runApp(EcosystemApp(startupError: startupError));
}

class EcosystemApp extends StatelessWidget {
  const EcosystemApp({super.key, this.startupError});

  /// Set when the saved session could not be read; the splash screen shows it.
  final Object? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ecosystem',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: kBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: kTextDark,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kPrimaryColor,
            side: const BorderSide(color: kPrimaryColor, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: kPrimaryColor),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: kPrimaryDark,
          contentTextStyle: const TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      home: SplashScreen(startupError: startupError),
    );
  }
}
