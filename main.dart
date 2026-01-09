import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

import 'services/user_service.dart';

import '/screens/auth/login_screen.dart' as auth;
import '/screens/admin/admin_dashboard.dart';
import '/screens/officer/officer_dashboard.dart';
import '/screens/user/user_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const VotingApp());
}

class VotingApp extends StatelessWidget {
  const VotingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Election Voting',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = authSnap.data;

        // Not logged in -> Login screen (Register is opened from Login screen)
        if (user == null) return const auth.LoginScreen();

        // Logged in -> Route by role
        return StreamBuilder<String?>(
          stream: UserService.roleStream(user.uid),
          builder: (_, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final role = roleSnap.data;

            // If profile doc missing, show a clear error (fix by creating users/{uid})
            if (role == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Profile Missing')),
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Your Firestore user profile is missing.',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      Text('Fix: ensure users/{uid} exists with field role = "user" / "officer" / "admin".'),
                    ],
                  ),
                ),
              );
            }

            if (role == 'admin') return const AdminDashboard();
            if (role == 'officer') return const OfficerDashboard();
            return const UserDashboard(); // default: user
          },
        );
      },
    );
  }
}
