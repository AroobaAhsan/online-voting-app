import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminLiveMonitorScreen extends StatelessWidget {
  const AdminLiveMonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.2),
      appBar: AppBar(
        title: const Text('Live Poll Monitor', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('elections').where('status', isEqualTo: 'open').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final elections = snap.data?.docs ?? [];

          if (elections.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sensors_off, size: 64, color: theme.disabledColor), // ✅ fixed icon
                  const SizedBox(height: 16),
                  const Text(
                    'No live polls active',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: elections.length,
            itemBuilder: (context, i) {
              final eDoc = elections[i];
              final e = eDoc.data();
              return _ElectionMonitorCard(eDocId: eDoc.id, data: e);
            },
          );
        },
      ),
    );
  }
}

class _ElectionMonitorCard extends StatelessWidget {
  final String eDocId;
  final Map<String, dynamic> data;

  const _ElectionMonitorCard({required this.eDocId, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = (data['title'] ?? 'Untitled Election').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant), // ✅ fixed Card side
      ),
      child: ExpansionTile(
        backgroundColor: theme.colorScheme.surface,
        collapsedBackgroundColor: theme.colorScheme.surface,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: const Text('Tap to view live results & voter log'),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          const Divider(),
          const SizedBox(height: 8),
          _ResultsGraph(electionId: eDocId),
          const SizedBox(height: 24),
          _VotersTable(electionId: eDocId),
        ],
      ),
    );
  }
}

class _ResultsGraph extends StatelessWidget {
  final String electionId;
  const _ResultsGraph({required this.electionId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('elections').doc(electionId).collection('parties').snapshots(),
      builder: (context, partySnap) {
        if (!partySnap.hasData) {
          return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
        }

        final parties = partySnap.data!.docs;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('elections').doc(electionId).collection('votes').snapshots(),
          builder: (context, voteSnap) {
            final votes = voteSnap.data?.docs ?? [];

            // Count votes per partyId
            final counts = <String, int>{};
            for (final v in votes) {
              final pid = (v.data()['partyId'] ?? '').toString();
              if (pid.isEmpty) continue;
              counts[pid] = (counts[pid] ?? 0) + 1;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Vote Distribution',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),

                    // ✅ replaced Badge (for older Flutter)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${votes.length} Total Votes',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                AspectRatio(
                  aspectRatio: 1.7,
                  child: BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= parties.length) return const SizedBox.shrink();

                              // ✅ correct access
                              final partyName = (parties[idx].data()['name'] ?? 'P').toString();
                              final label = _safeShort(partyName, 3).toUpperCase();

                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  label,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(parties.length, (i) {
                        final pid = parties[i].id;
                        final y = (counts[pid] ?? 0).toDouble();

                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: y,
                              width: 22,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              // ✅ no gradient (older fl_chart sometimes differs); safe single color
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _safeShort(String text, int max) {
    if (text.isEmpty) return 'P';
    if (text.length <= max) return text;
    return text.substring(0, max);
  }
}

class _VotersTable extends StatelessWidget {
  final String electionId;
  const _VotersTable({required this.electionId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('elections')
                .doc(electionId)
                .collection('votes')
                .orderBy('votedAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const LinearProgressIndicator();
              final votes = snap.data!.docs;

              if (votes.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No votes yet.'),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: votes.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final vote = votes[i].data();
                  final uid = votes[i].id;

                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline, size: 20),
                    title: _VoterEmailText(uid: uid),
                    trailing: Text(
                      _formatTime(vote['votedAt']),
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatTime(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return '--:--';
  }
}

class _VoterEmailText extends StatelessWidget {
  final String uid;
  const _VoterEmailText({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snap) {
        if (!snap.hasData) return const Text('Loading...');
        final email = (snap.data!.data()?['email'] ?? 'Anonymous').toString();
        return Text(email, style: const TextStyle(fontWeight: FontWeight.w500));
      },
    );
  }
}
