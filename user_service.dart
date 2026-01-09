import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  static final _db = FirebaseFirestore.instance;

  static Stream<String?> roleStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((d) => d.data()?['role'] as String?);
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> officersStream() {
    return _db.collection('users').where('role', isEqualTo: 'officer').snapshots();
  }

  // Admin-only action (rules enforce admin update ability)
  static Future<void> setRole({required String uid, required String role}) async {
    await _db.collection('users').doc(uid).update({'role': role});
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> usersStream() {
    return _db.collection('users').orderBy('createdAt', descending: true).snapshots();
  }
}
