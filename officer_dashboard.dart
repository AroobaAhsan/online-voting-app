import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../services/auth_service.dart';
import '../shared/live_results_screen.dart';
import 'create_election_screen.dart';
import 'officer_my_polls_screen.dart';

class OfficerDashboard extends StatelessWidget {
  const OfficerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.2),
      appBar: AppBar(
        title: const Text('Officer Control Panel', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () => _confirmSignOut(context),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // --- HEADER SECTION ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome back,', style: theme.textTheme.titleMedium),
                  Text(
                    user?.email?.split('@')[0] ?? 'Officer',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('You are authorized to manage local election nodes.',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),

          // --- STATS OVERVIEW ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _QuickStatsRow(uid: user?.uid ?? ''),
            ),
          ),

          // --- ACTIONS SECTION ---
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _ActionCard(
                  title: 'Create Poll',
                  subtitle: 'Initialize new election',
                  icon: Icons.add_chart_rounded,
                  color: Colors.blue,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateElectionScreen())),
                ),
                _ActionCard(
                  title: 'My Polls',
                  subtitle: 'Manage active ballots',
                  icon: Icons.ballot_rounded,
                  color: Colors.orange,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OfficerMyPollsScreen())),
                ),
                _ActionCard(
                  title: 'Live Results',
                  subtitle: 'Real-time monitoring',
                  icon: Icons.sensors_rounded,
                  color: Colors.green,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveResultsScreen())),
                ),
                _ActionCard(
                  title: 'Settings',
                  subtitle: 'Account & Logs',
                  icon: Icons.settings_applications_rounded,
                  color: Colors.blueGrey,
                  onTap: () { /* Future Implementation */ },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Sign Out'),
        content: const Text('Are you sure you want to exit the Officer Panel?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Stay')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              AuthService.signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  final String uid;
  const _QuickStatsRow({required this.uid});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('elections').where('createdBy', isEqualTo: uid).snapshots(),
      builder: (context, snap) {
        final totalCreated = snap.data?.docs.length ?? 0;
        final activePolls = snap.data?.docs.where((d) => d['status'] == 'open').length ?? 0;

        return Row(
          children: [
            _StatChip(label: 'Total Created', value: '$totalCreated', icon: Icons.history, theme: theme),
            const SizedBox(width: 12),
            _StatChip(label: 'Currently Open', value: '$activePolls', icon: Icons.bolt, theme: theme, highlight: true),
          ],
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final ThemeData theme;
  final bool highlight;

  const _StatChip({required this.label, required this.value, required this.icon, required this.theme, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlight ? theme.colorScheme.primary : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: highlight ? theme.colorScheme.onPrimary : theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: highlight ? theme.colorScheme.onPrimary : null)),
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: highlight ? theme.colorScheme.onPrimary.withOpacity(0.8) : null)),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                radius: 28,
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }
}