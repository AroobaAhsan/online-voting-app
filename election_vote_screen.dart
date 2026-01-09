import 'package:flutter/material.dart';
import '../../../services/election_service.dart';

class ElectionVoteScreen extends StatelessWidget {
  final String electionId;
  final String userId;

  const ElectionVoteScreen({
    super.key,
    required this.electionId,
    required this.userId,
  });

  Future<void> _showConfirmDialog(
    BuildContext context,
    String partyId,
    String partyName,
  ) async {
    final theme = Theme.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Your Vote'),
        content: RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium,
            children: [
              const TextSpan(text: 'Are you sure you want to vote for '),
              TextSpan(
                text: partyName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const TextSpan(text: '?\n\nThis action cannot be undone.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Vote'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await _executeVote(context, partyId);
    }
  }

  Future<void> _executeVote(BuildContext context, String partyId) async {
    // Loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ElectionService.voteOnceGlobal(
        electionId: electionId,
        uid: userId,
        partyId: partyId,
      );

      if (!context.mounted) return;

      Navigator.pop(context); // close loading

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vote submitted successfully.')),
      );

      Navigator.pop(context); // back to dashboard
    } catch (e) {
      if (!context.mounted) return;

      Navigator.pop(context); // close loading

      final s = e.toString();
      final msg = (s.contains('ALREADY_VOTED_GLOBAL') || s.contains('ALREADY_VOTED'))
          ? 'You already gave vote.'
          : 'Vote failed. Try again.';

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Vote Not Allowed'),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cast Your Ballot')),
      body: FutureBuilder<bool>(
        // ✅ Global vote rule (one vote in whole app)
        future: ElectionService.hasVotedGlobal(uid: userId),
        builder: (context, votedSnap) {
          final alreadyVoted = votedSnap.data == true;

          return StreamBuilder(
            stream: ElectionService.partiesStream(electionId),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;

              if (docs.isEmpty) {
                return const Center(child: Text('No candidates registered.'));
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (alreadyVoted) _buildAlreadyVotedWarning(theme),
                  const SizedBox(height: 16),
                  Text(
                    'Select a candidate',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.hintColor,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...docs.map((d) {
                    final data = d.data();
                    final name = (data['name'] ?? 'Unknown').toString().trim();
                    final symbol = (data['symbol'] ?? '').toString().trim();

                    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: theme.dividerColor),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(initial),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: symbol.isNotEmpty ? Text('Symbol: $symbol') : null,
                          trailing: ElevatedButton(
                            onPressed: alreadyVoted ? null : () => _showConfirmDialog(context, d.id, name),
                            child: const Text('Vote'),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAlreadyVotedWarning(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'You already gave vote.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
