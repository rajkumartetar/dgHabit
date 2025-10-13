
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
            footerBuilder: (context, action) {
              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: () async {
                      try {
                        await FirebaseAuth.instance.signInAnonymously();
                      } on FirebaseAuthException catch (e) {
                        String msg = 'Anonymous sign-in failed: ${e.code}';
                        if (e.code == 'operation-not-allowed') {
                          msg = 'Anonymous sign-in is disabled in Firebase. Enable it in Firebase Console > Authentication > Sign-in method.';
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Anonymous sign-in failed: $e')));
                        }
                      }
                    },
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Continue without account (dev)')
                  ),
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
