import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/election_service.dart';

class ElectionManageScreen extends StatefulWidget {
  final String electionId;
  const ElectionManageScreen({super.key, required this.electionId});

  @override
  State<ElectionManageScreen> createState() => _ElectionManageScreenState();
}

class _ElectionManageScreenState extends State<ElectionManageScreen> {
  final _partyName = TextEditingController();
  final _partySymbol = TextEditingController();
  bool _isAdding = false;

  Future<void> _addParty() async {
    final name = _partyName.text.trim();
    if (name.isEmpty) return;

    setState(() => _isAdding = true);
    try {
      await ElectionService.addParty(
        electionId: widget.electionId,
        name: name,
        symbol: _partySymbol.text.trim(),
      );
      _partyName.clear();
      _partySymbol.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Party added!')));
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Poll Details')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('elections').doc(widget.electionId).snapshots(),
        builder: (context, electionSnap) {
          if (!electionSnap.hasData) return const Center(child: CircularProgressIndicator());
          
          final election = electionSnap.data!.data() as Map<String, dynamic>;
          final status = election['status'] ?? 'draft';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- STATUS BANNER ---
              _buildStatusBanner(status, theme),
              const SizedBox(height: 24),

              // --- ADD PARTY FORM ---
              Text('Configuration', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _partyName,
                        decoration: const InputDecoration(
                          labelText: 'Candidate / Party Name',
                          prefixIcon: Icon(Icons.person_add_alt_1_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _partySymbol,
                        decoration: const InputDecoration(
                          labelText: 'Symbol / Motto',
                          prefixIcon: Icon(Icons.auto_awesome_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isAdding ? null : _addParty,
                          icon: _isAdding 
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add),
                          label: const Text('Add to Ballot'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- PARTY LIST ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ballot Preview', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Icon(Icons.visibility_outlined, size: 20, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              _buildPartyList(theme),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner(String status, ThemeData theme) {
    final bool isOpen = status == 'open';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOpen ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOpen ? Colors.green : Colors.orange),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(isOpen ? Icons.check_circle_rounded : Icons.pause_circle_rounded, 
                   color: isOpen ? Colors.green : Colors.orange),
              const SizedBox(width: 12),
              Text(
                'Status: ${status.toUpperCase()}',
                style: TextStyle(fontWeight: FontWeight.bold, color: isOpen ? Colors.green : Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: status == 'open' ? null : () => ElectionService.setElectionStatus(electionId: widget.electionId, status: 'open'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                  child: const Text('Open Voting'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: status == 'closed' ? null : () => ElectionService.setElectionStatus(electionId: widget.electionId, status: 'closed'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Close Voting'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPartyList(ThemeData theme) {
    return StreamBuilder(
      stream: ElectionService.partiesStream(widget.electionId),
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('No parties added to this election yet.', style: TextStyle(color: Colors.grey))),
          );
        }

        return Column(
          children: docs.map((d) {
            // ignore: unnecessary_cast
            final data = d.data() as Map<String, dynamic>;
            return Card(
              elevation: 0,
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(data['symbol'] ?? 'No symbol provided'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(d.id),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _confirmDelete(String partyId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Party?'),
        content: const Text('This will remove the candidate from the ballot.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              // Implementation of deleteParty service would go here
              FirebaseFirestore.instance
                  .collection('elections')
                  .doc(widget.electionId)
                  .collection('parties')
                  .doc(partyId)
                  .delete();
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}