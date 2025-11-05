
// lib/screens/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as fui;
import 'home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // User is not signed in, show sign-in screen
          return fui.SignInScreen(
            providers: [
              fui.EmailAuthProvider(),
            ],
            headerBuilder: (context, constraints, shrinkOffset) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset('assets/brand/icon_1024.png', width: 48, height: 48, fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 12),
                    Text('Welcome to dgHabit', style: Theme.of(context).textTheme.headlineSmall),
                  ],
                ),
              );
            },
          );
        }
        // User is signed in, show home screen
        return const HomeScreen();
      },
    );
  }
}
