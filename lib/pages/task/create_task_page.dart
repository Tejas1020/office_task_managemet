// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:office_task_managemet/utils/colors.dart';

// class CreateTaskPage extends StatefulWidget {
//   const CreateTaskPage({Key? key}) : super(key: key);

//   @override
//   State<CreateTaskPage> createState() => _CreateTaskPageState();
// }

// class _CreateTaskPageState extends State<CreateTaskPage> {
//   final _taskNameCtrl = TextEditingController();
//   final _notesCtrl = TextEditingController();
//   final _formKey = GlobalKey<FormState>();

//   bool _isLoading = false;
//   String? _error;

//   // Assignment options
//   String _assignmentType = 'individual'; // 'individual' or 'team'
//   String? _selectedIndividualId;
//   String? _selectedTeamId;

//   // Task details
//   DateTime? _startDate;
//   DateTime? _dueDate;
//   String _priority = 'medium';
//   String _status = 'pending';

//   // Data lists
//   List<QueryDocumentSnapshot<Map<String, dynamic>>> _users = [];
//   List<QueryDocumentSnapshot<Map<String, dynamic>>> _teams = [];

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   // Get display name for a user email
//   String getUserDisplayName(String email) {
//     // Look for user in loaded data
//     for (final userDoc in _users) {
//       final userData = userDoc.data();
//       final userEmail = userData['email']?.toString().toLowerCase();

//       if (userEmail == email.toLowerCase()) {
//         final displayName = userData['displayName'] ?? userData['name'];
//         if (displayName != null && displayName.toString().isNotEmpty) {
//           return displayName.toString();
//         }
//         break;
//       }
//     }

//     // Fallback: Create friendly name from email
//     if (email.contains('@')) {
//       final username = email.split('@')[0];
//       final parts = username.split('.');
//       if (parts.length > 1) {
//         return parts
//             .map(
//               (part) => part.isNotEmpty
//                   ? part[0].toUpperCase() + part.substring(1).toLowerCase()
//                   : part,
//             )
//             .join(' ');
//       } else {
//         return username.isNotEmpty
//             ? username[0].toUpperCase() + username.substring(1).toLowerCase()
//             : username;
//       }
//     }

//     return email;
//   }

//   Future<void> _loadData() async {
//     setState(() => _isLoading = true);

//     try {
//       // Load users and teams in parallel
//       final futures = await Future.wait([
//         FirebaseFirestore.instance
//             .collection('users')
//             .orderBy('displayName')
//             .get(),
//         FirebaseFirestore.instance.collection('teams').orderBy('name').get(),
//       ]);

//       setState(() {
//         _users = futures[0].docs;
//         _teams = futures[1].docs;
//       });
//     } catch (e) {
//       setState(() => _error = 'Failed to load data: ${e.toString()}');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _selectDate(BuildContext context, bool isStartDate) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: DateTime.now(),
//       firstDate: DateTime.now().subtract(const Duration(days: 30)),
//       lastDate: DateTime.now().add(const Duration(days: 365)),
//     );

//     if (picked != null) {
//       setState(() {
//         if (isStartDate) {
//           _startDate = picked;
//           // If due date is before start date, clear it
//           if (_dueDate != null && _dueDate!.isBefore(picked)) {
//             _dueDate = null;
//           }
//         } else {
//           _dueDate = picked;
//         }
//       });
//     }
//   }

//   Future<void> _createTask() async {
//     if (!_formKey.currentState!.validate()) return;

//     // Validate assignment
//     if (_assignmentType == 'individual' && _selectedIndividualId == null) {
//       setState(() => _error = 'Please select an individual to assign the task');
//       return;
//     }

//     if (_assignmentType == 'team' && _selectedTeamId == null) {
//       setState(() => _error = 'Please select a team to assign the task');
//       return;
//     }

//     // Validate dates
//     if (_startDate == null || _dueDate == null) {
//       setState(() => _error = 'Please select both start date and due date');
//       return;
//     }

//     if (_dueDate!.isBefore(_startDate!)) {
//       setState(() => _error = 'Due date cannot be before start date');
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//       _error = null;
//     });

//     try {
//       // Get current user for createdBy field
//       final currentUser = FirebaseAuth.instance.currentUser;

//       // Prepare base task data
//       final taskData = {
//         'taskName': _taskNameCtrl.text.trim(),
//         'notes': _notesCtrl.text.trim(),
//         'assignmentType': _assignmentType,
//         'startDate': Timestamp.fromDate(_startDate!),
//         'dueDate': Timestamp.fromDate(_dueDate!),
//         'priority': _priority,
//         'status': _status,
//         'createdAt': FieldValue.serverTimestamp(),
//         'createdBy': currentUser?.email ?? 'unknown',
//       };

//       // Add assignment details based on type
//       if (_assignmentType == 'individual') {
//         // Get user data for complete assignment info
//         final userDoc = _users.firstWhere(
//           (doc) => doc.id == _selectedIndividualId,
//         );
//         final userData = userDoc.data();

//         taskData.addAll({
//           'assignedToUserId': _selectedIndividualId!,
//           'assignedToUserName':
//               userData['displayName'] ?? userData['email'] ?? 'Unknown User',
//           'assignedToUserEmail':
//               userData['email']?.toString().toLowerCase() ?? '',
//         });
//       } else if (_assignmentType == 'team') {
//         // Get team data for complete assignment info
//         final teamDoc = _teams.firstWhere((doc) => doc.id == _selectedTeamId);
//         final teamData = teamDoc.data();

//         taskData.addAll({
//           'assignedToTeamId': _selectedTeamId!,
//           'assignedToTeamName': teamData['name'] ?? 'Unknown Team',
//         });

//         // Add team members if available
//         if (teamData.containsKey('members') && teamData['members'] is List) {
//           taskData['teamMembers'] = List<String>.from(teamData['members']);
//         } else {
//           // If no members field, create empty list (will need manual assignment)
//           taskData['teamMembers'] = <String>[];
//         }
//       }

//       // Save task to Firestore
//       await FirebaseFirestore.instance.collection('tasks').add(taskData);

//       // Show success and navigate back
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               _assignmentType == 'individual'
//                   ? 'Task assigned to individual successfully'
//                   : 'Task assigned to team successfully',
//             ),
//             backgroundColor: Colors.green,
//           ),
//         );
//         context.go('/admin'); // Navigate back to admin page
//       }
//     } catch (e) {
//       setState(() => _error = 'Error creating task: ${e.toString()}');
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   Widget _buildTeamMemberPreview() {
//     if (_assignmentType != 'team' || _selectedTeamId == null) {
//       return const SizedBox.shrink();
//     }

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const SizedBox(height: 12),
//         const Text(
//           'Team Members:',
//           style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
//         ),
//         const SizedBox(height: 4),
//         Container(
//           padding: const EdgeInsets.all(8),
//           decoration: BoxDecoration(
//             color: Colors.blue[50],
//             borderRadius: BorderRadius.circular(6),
//           ),
//           child: Builder(
//             builder: (context) {
//               // Find the selected team
//               QueryDocumentSnapshot<Map<String, dynamic>>? selectedTeam;
//               for (final team in _teams) {
//                 if (team.id == _selectedTeamId) {
//                   selectedTeam = team;
//                   break;
//                 }
//               }

//               if (selectedTeam == null) {
//                 return Text(
//                   'Team not found',
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: Colors.red[700],
//                     fontStyle: FontStyle.italic,
//                   ),
//                 );
//               }

//               final teamData = selectedTeam.data();
//               final members = teamData['members'];

//               if (members is List && members.isNotEmpty) {
//                 return Wrap(
//                   spacing: 4,
//                   runSpacing: 4,
//                   children: members.map<Widget>((memberEmail) {
//                     final email = memberEmail.toString();
//                     final displayName = getUserDisplayName(email);

//                     final chipWidget = Chip(
//                       label: Text(
//                         displayName,
//                         style: const TextStyle(fontSize: 10),
//                       ),
//                       materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                       visualDensity: VisualDensity.compact,
//                       backgroundColor: email == displayName
//                           ? Colors.orange[100] // If no display name found
//                           : Colors.blue[100], // If display name found
//                     );

//                     // Wrap with Tooltip if display name is different from email
//                     if (email != displayName) {
//                       return Tooltip(message: email, child: chipWidget);
//                     } else {
//                       return chipWidget;
//                     }
//                   }).toList(),
//                 );
//               } else {
//                 return Text(
//                   'No members defined for this team',
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: Colors.orange[700],
//                     fontStyle: FontStyle.italic,
//                   ),
//                 );
//               }
//             },
//           ),
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Create Task', style: TextStyle(color: Colors.white)),
//         backgroundColor: AppColors.gray800,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => context.go('/'),
//         ),
//       ),
//       body: SafeArea(
//         child: _isLoading && _users.isEmpty
//             ? const Center(child: CircularProgressIndicator())
//             : SingleChildScrollView(
//                 padding: const EdgeInsets.all(16),
//                 child: Form(
//                   key: _formKey,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.stretch,
//                     children: [
//                       // Error message
//                       if (_error != null)
//                         Container(
//                           padding: const EdgeInsets.all(12),
//                           margin: const EdgeInsets.only(bottom: 16),
//                           decoration: BoxDecoration(
//                             color: Colors.red.shade100,
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: Text(
//                             _error!,
//                             style: TextStyle(color: Colors.red.shade800),
//                           ),
//                         ),

//                       // Task Name
//                       TextFormField(
//                         controller: _taskNameCtrl,
//                         decoration: const InputDecoration(
//                           labelText: 'Task Name',
//                           prefixIcon: Icon(Icons.task),
//                           border: OutlineInputBorder(),
//                         ),
//                         validator: (v) => (v == null || v.trim().isEmpty)
//                             ? 'Please enter task name'
//                             : null,
//                       ),
//                       const SizedBox(height: 16),

//                       // Assignment Type
//                       Card(
//                         child: Padding(
//                           padding: const EdgeInsets.all(16),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               const Text(
//                                 'Assign To',
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                               const SizedBox(height: 8),

//                               // Assignment type radio buttons
//                               Row(
//                                 children: [
//                                   Expanded(
//                                     child: RadioListTile<String>(
//                                       title: const Text('Individual'),
//                                       value: 'individual',
//                                       groupValue: _assignmentType,
//                                       onChanged: (value) {
//                                         setState(() {
//                                           _assignmentType = value!;
//                                           _selectedTeamId = null;
//                                         });
//                                       },
//                                     ),
//                                   ),
//                                   Expanded(
//                                     child: RadioListTile<String>(
//                                       title: const Text('Team'),
//                                       value: 'team',
//                                       groupValue: _assignmentType,
//                                       onChanged: (value) {
//                                         setState(() {
//                                           _assignmentType = value!;
//                                           _selectedIndividualId = null;
//                                         });
//                                       },
//                                     ),
//                                   ),
//                                 ],
//                               ),

//                               // Assignment dropdown for individuals
//                               if (_assignmentType == 'individual')
//                                 DropdownButtonFormField<String>(
//                                   value: _selectedIndividualId,
//                                   decoration: const InputDecoration(
//                                     labelText: 'Select Individual',
//                                     prefixIcon: Icon(Icons.person),
//                                   ),
//                                   isExpanded: true,
//                                   items: _users.map((doc) {
//                                     final data = doc.data();
//                                     final name =
//                                         data['displayName'] ??
//                                         data['email'] ??
//                                         'Unknown';
//                                     final email = data['email'] ?? '';
//                                     return DropdownMenuItem(
//                                       value: doc.id,
//                                       child: Text(
//                                         email.isNotEmpty
//                                             ? '$name ($email)'
//                                             : name,
//                                         overflow: TextOverflow.ellipsis,
//                                         style: const TextStyle(fontSize: 14),
//                                       ),
//                                     );
//                                   }).toList(),
//                                   onChanged: (value) {
//                                     setState(
//                                       () => _selectedIndividualId = value,
//                                     );
//                                   },
//                                 ),

//                               // Assignment dropdown for teams
//                               if (_assignmentType == 'team')
//                                 DropdownButtonFormField<String>(
//                                   value: _selectedTeamId,
//                                   decoration: const InputDecoration(
//                                     labelText: 'Select Team',
//                                     prefixIcon: Icon(Icons.group),
//                                   ),
//                                   isExpanded: true,
//                                   items: _teams.map((doc) {
//                                     final data = doc.data();
//                                     final teamName =
//                                         data['name'] ?? 'Unknown Team';
//                                     final memberCount = data['members'] is List
//                                         ? (data['members'] as List).length
//                                         : 0;
//                                     return DropdownMenuItem(
//                                       value: doc.id,
//                                       child: Text(
//                                         '$teamName ($memberCount member${memberCount != 1 ? 's' : ''})',
//                                         overflow: TextOverflow.ellipsis,
//                                         style: const TextStyle(fontSize: 14),
//                                       ),
//                                     );
//                                   }).toList(),
//                                   onChanged: (value) {
//                                     setState(() => _selectedTeamId = value);
//                                   },
//                                 ),

//                               // Display team members preview
//                               _buildTeamMemberPreview(),
//                             ],
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 16),

//                       // Date Selection
//                       Card(
//                         child: Padding(
//                           padding: const EdgeInsets.all(16),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               const Text(
//                                 'Dates',
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                               const SizedBox(height: 8),

//                               Row(
//                                 children: [
//                                   Expanded(
//                                     child: ListTile(
//                                       leading: const Icon(Icons.calendar_today),
//                                       title: const Text('Start Date'),
//                                       subtitle: Text(
//                                         _startDate != null
//                                             ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
//                                             : 'Select start date',
//                                       ),
//                                       onTap: () => _selectDate(context, true),
//                                     ),
//                                   ),
//                                   Expanded(
//                                     child: ListTile(
//                                       leading: const Icon(Icons.event),
//                                       title: const Text('Due Date'),
//                                       subtitle: Text(
//                                         _dueDate != null
//                                             ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
//                                             : 'Select due date',
//                                       ),
//                                       onTap: () => _selectDate(context, false),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 16),

//                       // Priority and Status
//                       Row(
//                         children: [
//                           Expanded(
//                             flex: 1,
//                             child: DropdownButtonFormField<String>(
//                               value: _priority,
//                               decoration: const InputDecoration(
//                                 labelText: 'Priority',
//                                 prefixIcon: Icon(Icons.priority_high),
//                                 border: OutlineInputBorder(),
//                                 contentPadding: EdgeInsets.symmetric(
//                                   horizontal: 8,
//                                   vertical: 12,
//                                 ),
//                               ),
//                               isExpanded: true,
//                               items: const [
//                                 DropdownMenuItem(
//                                   value: 'low',
//                                   child: Text('Low'),
//                                 ),
//                                 DropdownMenuItem(
//                                   value: 'medium',
//                                   child: Text('Medium'),
//                                 ),
//                                 DropdownMenuItem(
//                                   value: 'high',
//                                   child: Text('High'),
//                                 ),
//                               ],
//                               onChanged: (value) {
//                                 setState(() => _priority = value!);
//                               },
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             flex: 1,
//                             child: DropdownButtonFormField<String>(
//                               value: _status,
//                               decoration: const InputDecoration(
//                                 labelText: 'Status',
//                                 prefixIcon: Icon(Icons.flag),
//                                 border: OutlineInputBorder(),
//                                 contentPadding: EdgeInsets.symmetric(
//                                   horizontal: 8,
//                                   vertical: 12,
//                                 ),
//                               ),
//                               isExpanded: true,
//                               items: const [
//                                 DropdownMenuItem(
//                                   value: 'pending',
//                                   child: Text('Pending'),
//                                 ),
//                                 DropdownMenuItem(
//                                   value: 'progress',
//                                   child: Text('In Progress'),
//                                 ),
//                                 DropdownMenuItem(
//                                   value: 'completed',
//                                   child: Text('Completed'),
//                                 ),
//                               ],
//                               onChanged: (value) {
//                                 setState(() => _status = value!);
//                               },
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 16),

//                       // Notes
//                       TextFormField(
//                         controller: _notesCtrl,
//                         maxLines: 4,
//                         decoration: const InputDecoration(
//                           labelText: 'Notes',
//                           prefixIcon: Icon(Icons.notes),
//                           border: OutlineInputBorder(),
//                           alignLabelWithHint: true,
//                         ),
//                       ),
//                       const SizedBox(height: 24),

//                       // Create Button
//                       _isLoading
//                           ? const Center(child: CircularProgressIndicator())
//                           : ElevatedButton.icon(
//                               icon: const Icon(Icons.add_task),
//                               label: const Text('Create Task'),
//                               onPressed: _createTask,
//                               style: ElevatedButton.styleFrom(
//                                 padding: const EdgeInsets.symmetric(
//                                   vertical: 16,
//                                 ),
//                                 backgroundColor: AppColors.gray800,
//                                 foregroundColor: Colors.white,
//                               ),
//                             ),
//                     ],
//                   ),
//                 ),
//               ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _taskNameCtrl.dispose();
//     _notesCtrl.dispose();
//     super.dispose();
//   }
// }


// lib/src/admin_pages/create_task.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:office_task_managemet/utils/colors.dart';

class CreateTaskPage extends StatefulWidget {
  const CreateTaskPage({Key? key}) : super(key: key);

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  final _taskNameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _error;

  // Assignment options
  String _assignmentType = 'individual'; // 'individual' or 'team'
  String? _selectedIndividualId;
  String? _selectedTeamId;

  // Task details
  DateTime? _startDate;
  DateTime? _dueDate;
  String _priority = 'medium';
  String _status = 'pending';

  // Data lists
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _users = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _teams = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Get display name for a user ID or email
  String getUserDisplayName(String userIdOrEmail) {
    // First try to find by document ID (for user IDs like kD90vI00esY3JwzitFHLxUUPuiP2)
    for (final userDoc in _users) {
      if (userDoc.id == userIdOrEmail) {
        final userData = userDoc.data();
        final displayName = userData['displayName'] ?? userData['name'];
        if (displayName != null && displayName.toString().isNotEmpty) {
          return displayName.toString();
        }
        // If user found but no display name, try to use email
        final email = userData['email']?.toString();
        if (email != null && email.isNotEmpty) {
          return email.split('@')[0]; // Use email prefix as fallback
        }
        break;
      }
    }

    // If not found by ID, try to find by email (fallback for email-based members)
    for (final userDoc in _users) {
      final userData = userDoc.data();
      final userEmail = userData['email']?.toString().toLowerCase();

      if (userEmail == userIdOrEmail.toLowerCase()) {
        final displayName = userData['displayName'] ?? userData['name'];
        if (displayName != null && displayName.toString().isNotEmpty) {
          return displayName.toString();
        }
        break;
      }
    }

    // If it looks like an email, create friendly name from email
    if (userIdOrEmail.contains('@')) {
      final username = userIdOrEmail.split('@')[0];
      final parts = username.split('.');
      if (parts.length > 1) {
        return parts
            .map(
              (part) => part.isNotEmpty
                  ? part[0].toUpperCase() + part.substring(1).toLowerCase()
                  : part,
            )
            .join(' ');
      } else {
        return username.isNotEmpty
            ? username[0].toUpperCase() + username.substring(1).toLowerCase()
            : username;
      }
    }

    // If it's a user ID that we couldn't find, return a shortened version
    if (userIdOrEmail.length > 10) {
      return 'User ${userIdOrEmail.substring(0, 8)}...';
    }

    return userIdOrEmail;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load users and teams in parallel
      final futures = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .get(), // Remove orderBy since some users might not have displayName
        FirebaseFirestore.instance.collection('teams').get(),
      ]);

      setState(() {
        _users = futures[0].docs;
        _teams = futures[1].docs;
      });

      // Debug: Print loaded data structure
      debugPrint('📋 Loaded ${_users.length} users and ${_teams.length} teams');

      // Debug users
      for (final user in _users.take(3)) {
        // Show first 3 users
        final data = user.data();
        debugPrint(
          '   👤 ${data['displayName'] ?? 'No name'} (ID: ${user.id})',
        );
      }

      // Debug teams
      for (final team in _teams) {
        final data = team.data();
        final members = data['members'] as List? ?? [];
        debugPrint(
          '   🏢 ${data['name'] ?? 'No name'} (${members.length} members)',
        );
      }
    } catch (e) {
      setState(() => _error = 'Failed to load data: ${e.toString()}');
      debugPrint('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // If due date is before start date, clear it
          if (_dueDate != null && _dueDate!.isBefore(picked)) {
            _dueDate = null;
          }
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  Future<void> _createTask() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate assignment
    if (_assignmentType == 'individual' && _selectedIndividualId == null) {
      setState(() => _error = 'Please select an individual to assign the task');
      return;
    }

    if (_assignmentType == 'team' && _selectedTeamId == null) {
      setState(() => _error = 'Please select a team to assign the task');
      return;
    }

    // Validate dates
    if (_startDate == null || _dueDate == null) {
      setState(() => _error = 'Please select both start date and due date');
      return;
    }

    if (_dueDate!.isBefore(_startDate!)) {
      setState(() => _error = 'Due date cannot be before start date');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get current user for createdBy field
      final currentUser = FirebaseAuth.instance.currentUser;

      // Prepare base task data
      final taskData = {
        'taskName': _taskNameCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        'assignmentType': _assignmentType,
        'startDate': Timestamp.fromDate(_startDate!),
        'dueDate': Timestamp.fromDate(_dueDate!),
        'priority': _priority,
        'status': _status,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser?.email ?? 'unknown',
      };

      // Add assignment details based on type
      if (_assignmentType == 'individual') {
        // Get user data for complete assignment info
        final userDoc = _users.firstWhere(
          (doc) => doc.id == _selectedIndividualId,
        );
        final userData = userDoc.data();

        taskData.addAll({
          'assignedToUserId': _selectedIndividualId!,
          'assignedToUserName':
              userData['displayName'] ?? userData['email'] ?? 'Unknown User',
          'assignedToUserEmail':
              userData['email']?.toString().toLowerCase() ?? '',
        });
      } else if (_assignmentType == 'team') {
        // Get team data for complete assignment info
        final teamDoc = _teams.firstWhere((doc) => doc.id == _selectedTeamId);
        final teamData = teamDoc.data();

        taskData.addAll({
          'assignedToTeamId': _selectedTeamId!,
          'assignedToTeamName': teamData['name'] ?? 'Unknown Team',
        });

        // Add team members if available (these will be user IDs)
        if (teamData.containsKey('members') && teamData['members'] is List) {
          taskData['teamMembers'] = List<String>.from(teamData['members']);
        } else {
          // If no members field, create empty list (will need manual assignment)
          taskData['teamMembers'] = <String>[];
        }
      }

      // Save task to Firestore
      await FirebaseFirestore.instance.collection('tasks').add(taskData);

      // Show success and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _assignmentType == 'individual'
                  ? 'Task assigned to individual successfully'
                  : 'Task assigned to team successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/admin'); // Navigate back to admin page
      }
    } catch (e) {
      setState(() => _error = 'Error creating task: ${e.toString()}');
      debugPrint('Task creation error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTeamMemberPreview() {
    if (_assignmentType != 'team' || _selectedTeamId == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Team Members:',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Builder(
            builder: (context) {
              // Find the selected team
              QueryDocumentSnapshot<Map<String, dynamic>>? selectedTeam;
              for (final team in _teams) {
                if (team.id == _selectedTeamId) {
                  selectedTeam = team;
                  break;
                }
              }

              if (selectedTeam == null) {
                return Text(
                  'Team not found',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[700],
                    fontStyle: FontStyle.italic,
                  ),
                );
              }

              final teamData = selectedTeam.data();
              final members = teamData['members'];

              debugPrint('🔍 Team members for ${teamData['name']}: $members');

              if (members is List && members.isNotEmpty) {
                return Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: members.map<Widget>((memberIdOrEmail) {
                    final memberIdentifier = memberIdOrEmail.toString();
                    final displayName = getUserDisplayName(memberIdentifier);

                    debugPrint(
                      '   👤 Member: $memberIdentifier -> $displayName',
                    );

                    // Determine if this is a user ID or email
                    final isUserId = !memberIdentifier.contains('@');
                    final isDisplayNameFound =
                        displayName != memberIdentifier &&
                        !displayName.startsWith('User ');

                    final chipWidget = Chip(
                      label: Text(
                        displayName,
                        style: const TextStyle(fontSize: 10),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: isDisplayNameFound
                          ? Colors.blue[100] // Display name found
                          : Colors.orange[100], // Using fallback
                    );

                    // Show tooltip with user ID or email if different from display name
                    if (isDisplayNameFound) {
                      return Tooltip(
                        message: isUserId
                            ? 'User ID: $memberIdentifier'
                            : memberIdentifier,
                        child: chipWidget,
                      );
                    } else {
                      return Tooltip(
                        message: isUserId
                            ? 'User not found'
                            : 'Using email fallback',
                        child: chipWidget,
                      );
                    }
                  }).toList(),
                );
              } else {
                return Text(
                  'No members defined for this team',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[700],
                    fontStyle: FontStyle.italic,
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Task', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.gray800,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: _isLoading && _users.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
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

                      // Task Name
                      TextFormField(
                        controller: _taskNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Task Name',
                          prefixIcon: Icon(Icons.task),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter task name'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Assignment Type
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Assign To',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Assignment type radio buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: const Text('Individual'),
                                      value: 'individual',
                                      groupValue: _assignmentType,
                                      onChanged: (value) {
                                        setState(() {
                                          _assignmentType = value!;
                                          _selectedTeamId = null;
                                        });
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: const Text('Team'),
                                      value: 'team',
                                      groupValue: _assignmentType,
                                      onChanged: (value) {
                                        setState(() {
                                          _assignmentType = value!;
                                          _selectedIndividualId = null;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              // Assignment dropdown for individuals
                              if (_assignmentType == 'individual')
                                DropdownButtonFormField<String>(
                                  value: _selectedIndividualId,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Individual',
                                    prefixIcon: Icon(Icons.person),
                                  ),
                                  isExpanded: true,
                                  items: _users.map((doc) {
                                    final data = doc.data();
                                    final name =
                                        data['displayName'] ??
                                        data['email'] ??
                                        'Unknown';
                                    final email = data['email'] ?? '';
                                    return DropdownMenuItem(
                                      value: doc.id,
                                      child: Text(
                                        email.isNotEmpty
                                            ? '$name ($email)'
                                            : name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(
                                      () => _selectedIndividualId = value,
                                    );
                                  },
                                ),

                              // Assignment dropdown for teams
                              if (_assignmentType == 'team')
                                DropdownButtonFormField<String>(
                                  value: _selectedTeamId,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Team',
                                    prefixIcon: Icon(Icons.group),
                                  ),
                                  isExpanded: true,
                                  items: _teams.map((doc) {
                                    final data = doc.data();
                                    final teamName =
                                        data['name'] ?? 'Unknown Team';
                                    final memberCount = data['members'] is List
                                        ? (data['members'] as List).length
                                        : 0;
                                    return DropdownMenuItem(
                                      value: doc.id,
                                      child: Text(
                                        '$teamName ($memberCount member${memberCount != 1 ? 's' : ''})',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedTeamId = value);
                                  },
                                ),

                              // Display team members preview
                              _buildTeamMemberPreview(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Date Selection
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Dates',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  Expanded(
                                    child: ListTile(
                                      leading: const Icon(Icons.calendar_today),
                                      title: const Text('Start Date'),
                                      subtitle: Text(
                                        _startDate != null
                                            ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                            : 'Select start date',
                                      ),
                                      onTap: () => _selectDate(context, true),
                                    ),
                                  ),
                                  Expanded(
                                    child: ListTile(
                                      leading: const Icon(Icons.event),
                                      title: const Text('Due Date'),
                                      subtitle: Text(
                                        _dueDate != null
                                            ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                                            : 'Select due date',
                                      ),
                                      onTap: () => _selectDate(context, false),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Priority and Status
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              value: _priority,
                              decoration: const InputDecoration(
                                labelText: 'Priority',
                                prefixIcon: Icon(Icons.priority_high),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                              ),
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'low',
                                  child: Text('Low'),
                                ),
                                DropdownMenuItem(
                                  value: 'medium',
                                  child: Text('Medium'),
                                ),
                                DropdownMenuItem(
                                  value: 'high',
                                  child: Text('High'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() => _priority = value!);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              value: _status,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                prefixIcon: Icon(Icons.flag),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                              ),
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'pending',
                                  child: Text('Pending'),
                                ),
                                DropdownMenuItem(
                                  value: 'progress',
                                  child: Text('In Progress'),
                                ),
                                DropdownMenuItem(
                                  value: 'completed',
                                  child: Text('Completed'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() => _status = value!);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          prefixIcon: Icon(Icons.notes),
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Create Button
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton.icon(
                              icon: const Icon(Icons.add_task),
                              label: const Text('Create Task'),
                              onPressed: _createTask,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                backgroundColor: AppColors.gray800,
                                foregroundColor: Colors.white,
                              ),
                            ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _taskNameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }
}
