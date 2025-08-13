// lib/src/admin_pages/create_team.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:office_task_managemet/utils/colors.dart';

class CreateTeamPage extends StatefulWidget {
  const CreateTeamPage({Key? key}) : super(key: key);

  @override
  State<CreateTeamPage> createState() => _CreateTeamPageState();
}

class _CreateTeamPageState extends State<CreateTeamPage> {
  final _teamNameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _users = [];
  final Set<String> _selectedUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('displayName')
          .get();
      setState(() => _users = snapshot.docs);
    } catch (e) {
      setState(() => _error = 'Failed to load users');
    }
  }

  Future<void> _createTeam() async {
    if (!_formKey.currentState!.validate() || _selectedUserIds.isEmpty) {
      setState(() {
        _error = _selectedUserIds.isEmpty
            ? 'Select at least one team member'
            : null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final teamName = _teamNameCtrl.text.trim();

    try {
      // 1️⃣ Save team in Firestore
      final teamRef = await FirebaseFirestore.instance.collection('teams').add({
        'name': teamName,
        'members': _selectedUserIds.toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2️⃣ Optional Cloud Function call - won't fail if function doesn't exist
      try {
        final fn = FirebaseFunctions.instanceFor(
          region: 'us-central1',
        ).httpsCallable('notifyTeamCreation');
        await fn.call(<String, dynamic>{
          'teamId': teamRef.id,
          'teamName': teamName,
          'memberIds': _selectedUserIds.toList(),
        });
        print('Team notification sent successfully');
      } catch (e) {
        // Log the error but don't fail the team creation
        print('Notification failed (team still created): ${e.toString()}');
      }

      // 3️⃣ Show success and navigate to admin home
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team Created Successfully')),
        );
        // Replace with your admin home route:
        context.go('/admin');
      }
    } on FirebaseFunctionsException catch (e) {
      // Handle remaining function errors
      setState(() => _error = 'Function error: ${e.message}');
    } catch (e) {
      // Handle general errors
      setState(() => _error = 'Error creating team: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Team', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.gray800,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Error message
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                ),

              // Team name field
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _teamNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Team Name',
                    prefixIcon: Icon(Icons.group),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter team name'
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // Selected members count
              if (_selectedUserIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Selected: ${_selectedUserIds.length} member(s)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),

              // Member list
              Flexible(
                child: _users.isEmpty
                    ? _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : const Center(child: Text('No users found'))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _users.length,
                        itemBuilder: (_, i) {
                          final doc = _users[i];
                          final uid = doc.id;
                          final data = doc.data();
                          final name = data['displayName'] ?? data['email'];
                          return CheckboxListTile(
                            title: Text(name),
                            subtitle: data['email'] != null
                                ? Text(data['email'])
                                : null,
                            value: _selectedUserIds.contains(uid),
                            onChanged: (sel) {
                              setState(() {
                                if (sel == true) {
                                  _selectedUserIds.add(uid);
                                } else {
                                  _selectedUserIds.remove(uid);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),

              const SizedBox(height: 16),

              // Create button
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Create Team'),
                      onPressed: _createTeam,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _teamNameCtrl.dispose();
    super.dispose();
  }
}
