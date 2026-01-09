class AppUser {
  final String uid;
  final String email;
  final String role; // admin, officer, user

  AppUser({required this.uid, required this.email, required this.role});

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: (data['email'] ?? '') as String,
      role: (data['role'] ?? 'user') as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'role': role,
      };
}
