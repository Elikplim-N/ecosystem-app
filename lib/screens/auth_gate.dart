import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_role.dart';
import 'admin_home_screen.dart';
import 'demo_data.dart';
import 'home_screen.dart';
import 'ui_helpers.dart';
import 'welcome_screen.dart';

/// Which side of BoaMe the person picked on the entry screen.
enum AppEntry {
  /// Members and ambassadors.
  app,

  /// Network administrators.
  admin,
}

/// Routes a signed-in account to the right experience.
///
/// Ambassadors deliberately land on the normal dashboard with their
/// extra tools revealed inside it, rather than a separate app — the
/// recycling side of the product is still their main job.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.entry = AppEntry.app});

  /// The surface chosen before signing in. An admin account always wins;
  /// this only decides what a non-admin account is allowed to preview.
  final AppEntry entry;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF006158)),
            ),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return WelcomeScreen(entry: entry);
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF006158)),
                ),
              );
            }

            // A signed-in account with no profile yet still gets a usable
            // home screen; the profile screen is what complains about it.
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const HomeScreen();
            }

            final data = userSnapshot.data!.data() as Map<String, dynamic>;
            final role = AppRole.fromString(data['role']);

            if (data['accountDisabled'] == true) {
              return const DisabledAccountView();
            }

            if (role == AppRole.admin) return const AdminHomeScreen();

            // Admins are never blocked from the app side. Going the other
            // way is only allowed while demo data is on, so a member
            // account cannot reach the admin console by picking a button.
            if (entry == AppEntry.admin) {
              return kDemoMode ? const AdminHomeScreen() : const _NotAnAdminView();
            }

            return HomeScreen(role: role);
          },
        );
      },
    );
  }
}

/// Shown when a non-admin account picked the admin side of the app.
class _NotAnAdminView extends StatelessWidget {
  const _NotAnAdminView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAdminBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kMetricBlueTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 36,
                  color: kMetricBlue,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Admins only',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: kTextDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This account is not an administrator. Sign in with an admin '
                'account, or head back to the BoaMe app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: kTextMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              ElevatedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                        builder: (_) => const AuthGate(entry: AppEntry.app),
                      ),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('BACK TO THE APP'),
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when an admin has disabled an account.
class DisabledAccountView extends StatelessWidget {
  const DisabledAccountView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F3),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE9EF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pause_circle_rounded,
                  size: 38,
                  color: Color(0xFFC0392B),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Account disabled',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF12312D),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This account is currently on hold. Speak to an administrator '
                'if you think this is a mistake.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF6F807C),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              OutlinedButton.icon(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('SIGN OUT'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
