import 'package:cloud_firestore/cloud_firestore.dart';

class Election {
  final String id;
  final String title;
  final String status; // draft, open, closed
  final String createdBy;
  final Timestamp? createdAt;

  Election({
    required this.id,
    required this.title,
    required this.status,
    required this.createdBy,
    required this.createdAt,
  });

  factory Election.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Election(
      id: doc.id,
      title: (d['title'] ?? '') as String,
      status: (d['status'] ?? 'draft') as String,
      createdBy: (d['createdBy'] ?? '') as String,
      createdAt: d['createdAt'] as Timestamp?,
    );
  }
}
