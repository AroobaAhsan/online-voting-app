import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/user_service.dart';

class ManageOfficersScreen extends StatefulWidget {
  const ManageOfficersScreen({super.key});

  @override
  State<ManageOfficersScreen> createState() => _ManageOfficersScreenState();
}

class _ManageOfficersScreenState extends State<ManageOfficersScreen> {
  bool _isPicking = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  Future<void> _pickRandomOfficer(List docs) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final eligible = docs.where((d) {
      final data = d.data();
      final role = (data['role'] ?? 'user') as String;
      return role == 'user' && d.id != currentUid;
    }).toList();

    if (eligible.isEmpty) {
      _showSnackBar('No eligible users to promote.');
      return;
    }

    setState(() => _isPicking = true);
    try {
      final randomDoc = eligible[Random().nextInt(eligible.length)];
      final email = (randomDoc.data()['email'] ?? '') as String;

      await UserService.setRole(uid: randomDoc.id, role: 'officer');
      _showSnackBar('Promoted to Officer: $email', isSuccess: true);
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Staff Management'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'All Users', icon: Icon(Icons.people_outline)),
              Tab(text: 'Officers', icon: Icon(Icons.shield_outlined)),
            ],
          ),
        ),
        body: StreamBuilder(
          stream: UserService.usersStream(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final allDocs = snap.data!.docs;
            
            // Filter logic
            final filteredDocs = allDocs.where((d) {
              final email = (d.data()['email'] ?? '').toString().toLowerCase();
              return email.contains(_searchQuery.toLowerCase());
            }).toList();

            final officers = filteredDocs.where((d) => d.data()['role'] == 'officer').toList();

            return TabBarView(
              children: [
                _buildUserList(context, filteredDocs, allDocs, "Search all users..."),
                _buildUserList(context, officers, allDocs, "Search officers...", isOfficerTab: true),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildUserList(BuildContext context, List docs, List allDocs, String hint, {bool isOfficerTab = false}) {
    return Column(
      children: [
        // --- SEARCH & RANDOM PICK HEADER ---
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              if (!isOfficerTab) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isPicking ? null : () => _pickRandomOfficer(allDocs),
                    icon: _isPicking 
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.shuffle),
                    label: Text(_isPicking ? 'Selecting...' : 'Lucky Draw New Officer'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.deepPurple),
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // --- USER LIST ---
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();
              final email = data['email'] ?? '';
              final role = data['role'] ?? 'user';
              final isOfficer = role == 'officer';

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isOfficer ? Colors.blue.shade100 : Colors.grey.shade200,
                    child: Icon(
                      isOfficer ? Icons.shield : Icons.person,
                      color: isOfficer ? Colors.blue.shade800 : Colors.grey.shade600,
                    ),
                  ),
                  title: Text(email, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(role.toString().toUpperCase(), 
                    style: TextStyle(color: isOfficer ? Colors.blue : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  trailing: Switch(
                    value: isOfficer,
                    activeColor: Colors.blue,
                    onChanged: (val) => _confirmRoleChange(context, d.id, email, val ? 'officer' : 'user'),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmRoleChange(BuildContext context, String uid, String email, String newRole) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Permissions?'),
        content: Text('Are you sure you want to make $email a ${newRole == 'officer' ? 'Voting Officer' : 'Regular User'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              UserService.setRole(uid: uid, role: newRole);
              Navigator.pop(ctx);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}