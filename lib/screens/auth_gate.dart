import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'admin_home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiService();

    return StreamBuilder<UserModel?>(
      stream: api.userStream,
      initialData: api.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data ?? api.currentUser;

        if (user == null) {
          return const LoginScreen();
        }

        if (user.isAdmin) {
          return const AdminHomeScreen();
        }

        return const HomeScreen();
      },
    );
  }
}