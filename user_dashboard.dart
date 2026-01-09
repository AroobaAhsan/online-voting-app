import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/auth_service.dart';
import '../../../services/election_service.dart';
import 'election_vote_screen.dart';

class UserDashboard extends StatelessWidget {
  const UserDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Dashboard'),
        actions: [
          Center(child: Padding(padding: const EdgeInsets.only(right: 12), child: Text(email))),
          IconButton(onPressed: AuthService.signOut, icon: const Icon(Icons.logout)),
        ],
      ),

      // ✅ show ONLY open polls
      body: StreamBuilder(
        stream: ElectionService.electionsStream(status: 'open'),
        builder: (context, snap) {
          // ✅ loading
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ✅ IMPORTANT: show the real Firestore error
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Firestore error:\n${snap.error}\n\n'
                  'Most common reasons:\n'
                  '1) Permission denied (Firestore rules)\n'
                  '2) Index required (query needs composite index)\n'
                  '3) status field missing / wrong value\n',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // ✅ no data
          if (!snap.hasData) {
            return const Center(child: Text('No data received from Firestore.'));
          }

          final docs = snap.data!.docs;

          // ✅ empty list
          if (docs.isEmpty) {
            return const Center(
              child: Text('No live polls right now (status must be "open").'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final d = docs[i];
              final data = d.data();

              final title = (data['title'] ?? 'Untitled').toString();
              final status = (data['status'] ?? '').toString();

              return Card(
                child: ListTile(
                  title: Text(title),
                  subtitle: Text('Status: $status'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ElectionVoteScreen(
                        electionId: d.id,
                        userId: uid,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}