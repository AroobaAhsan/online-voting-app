import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/election_service.dart';
import 'election_manage_screen.dart'; // Navigating to the detailed view

class OfficerMyPollsScreen extends StatefulWidget {
  const OfficerMyPollsScreen({super.key});

  @override
  State<OfficerMyPollsScreen> createState() => _OfficerMyPollsScreenState();
}

class _OfficerMyPollsScreenState extends State<OfficerMyPollsScreen> {
  
  // Helper to build status badges
  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'open': color = Colors.green; break;
      case 'closed': color = Colors.red; break;
      default: color = Colors.orange; // draft
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Elections'),
        centerTitle: true,
      ),
      body: StreamBuilder(
        stream: ElectionService.myElectionsStream(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.ballot_outlined, size: 64, color: theme.disabledColor),
                  const SizedBox(height: 16),
                  const Text('No polls created yet.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final eDoc = docs[i];
              final e = eDoc.data() as Map<String, dynamic>;
              final title = e['title'] ?? 'Untitled Poll';
              final status = e['status'] ?? 'draft';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ElectionManageScreen(electionId: eDoc.id),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildStatusBadge(status),
                          ],
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder(
                          stream: ElectionService.partiesStream(eDoc.id),
                          builder: (context, pSnap) {
                            final count = pSnap.data?.docs.length ?? 0;
                            return Text(
                              '$count Candidates Registered',
                              style: theme.textTheme.bodySmall,
                            );
                          },
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tap to manage candidates & status',
                              style: TextStyle(color: theme.colorScheme.primary, fontSize: 12),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 14),
                          ],
                        ),
                      ],
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