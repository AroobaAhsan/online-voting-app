import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/election_service.dart';

class LiveResultsScreen extends StatelessWidget {
  const LiveResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Results')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ElectionService.electionsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData) {
            return const Center(child: Text('No data found.'));
          }

          final elections = snap.data!.docs;

          if (elections.isEmpty) {
            return const Center(child: Text('No elections yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: elections.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final eDoc = elections[i];
              final e = eDoc.data();

              final title = (e['title'] ?? 'Untitled').toString();
              final status = (e['status'] ?? 'open').toString();

              return Card(
                child: ExpansionTile(
                  title: Text(title),
                  subtitle: Text('Status: $status'),
                  childrenPadding: const EdgeInsets.all(12),
                  children: [
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: ElectionService.partiesStream(eDoc.id),
                      builder: (context, psnap) {
                        if (psnap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(8),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (!psnap.hasData) {
                          return const Text('No parties data found.');
                        }

                        final parties = psnap.data!.docs;
                        if (parties.isEmpty) {
                          return const Text('No parties added yet.');
                        }

                        return Column(
                          children: parties.map((p) {
                            final pd = p.data();
                            final name = (pd['name'] ?? 'Party').toString();
                            final symbol = (pd['symbol'] ?? '').toString();

                            return ListTile(
                              leading: const Icon(Icons.flag_outlined),
                              title: Text(name),
                              subtitle: symbol.isEmpty ? null : Text('Symbol: $symbol'),
                              trailing: StreamBuilder<int>(
                                stream: ElectionService.partyVoteCountStream(
                                  electionId: eDoc.id,
                                  partyId: p.id,
                                ),
                                builder: (context, cSnap) {
                                  final count = cSnap.data ?? 0;
                                  return Text(
                                    'Votes: $count',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
