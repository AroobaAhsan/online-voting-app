import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static Future<void> signOut() => _auth.signOut();

  static Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  static Future<void> register(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    // Create Firestore user profile (default role user)
    await _db.collection('users').doc(cred.user!.uid).set({
      'email': cred.user!.email ?? email.trim(),
      'role': 'user',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
