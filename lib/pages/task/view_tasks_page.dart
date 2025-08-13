import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:multiavatar/multiavatar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:office_task_managemet/utils/colors.dart';

class AdminViewTasksPage extends StatelessWidget {
  const AdminViewTasksPage({Key? key}) : super(key: key);

  // Get current user
  User? get currentUser => FirebaseAuth.instance.currentUser;

  // Check if current user is admin
  bool get isAdmin {
    if (currentUser?.email == null) return false;
    final email = currentUser!.email!.toLowerCase();
    return email.endsWith('@admin.com');
  }

  // Check if current user is manager
  bool get isManager {
    if (currentUser?.email == null) return false;
    final email = currentUser!.email!.toLowerCase();
    return email.endsWith('@manager.com');
  }

  // Check if current user can delete tasks (admin or manager)
  bool get canDeleteTasks => isAdmin || isManager;

  // Check if current user can see all tasks (admin or manager)
  bool get canSeeAllTasks => isAdmin || isManager;

  // Get user role for display
  String get userRole {
    if (isAdmin) return 'ADMIN';
    if (isManager) return 'MANAGER';
    return 'USER';
  }

  // Get role badge color
  Color get roleBadgeColor {
    if (isAdmin) return Colors.red[600]!;
    if (isManager) return Colors.orange[600]!;
    return Colors.blue[600]!;
  }

  // Get display name for a user ID or email
  Future<String> getUserDisplayName(String userIdOrEmail) async {
    try {
      // First try to get by document ID (for user IDs like kD90vI00esY3JwzitFHLxUUPuiP2)
      final userDocById = await FirebaseFirestore.instance
          .collection('users')
          .doc(userIdOrEmail)
          .get();

      if (userDocById.exists) {
        final userData = userDocById.data();
        final displayName = userData?['displayName'] ?? userData?['name'];
        if (displayName != null && displayName.toString().isNotEmpty) {
          return displayName.toString();
        }
      }

      // If not found by ID and it looks like an email, try email-based lookup
      if (userIdOrEmail.contains('@')) {
        final userDocByEmail = await FirebaseFirestore.instance
            .collection('users')
            .doc(userIdOrEmail.toLowerCase())
            .get();

        if (userDocByEmail.exists) {
          final userData = userDocByEmail.data();
          final displayName = userData?['displayName'] ?? userData?['name'];
          if (displayName != null && displayName.toString().isNotEmpty) {
            return displayName.toString();
          }
        }
      }

      // Fallback for emails: create friendly name
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

      // For user IDs, return shortened version
      if (userIdOrEmail.length > 10) {
        return 'User ${userIdOrEmail.substring(0, 8)}...';
      }

      return userIdOrEmail;
    } catch (e) {
      print('Error getting user display name for $userIdOrEmail: $e');
      return userIdOrEmail.contains('@')
          ? userIdOrEmail.split('@')[0]
          : userIdOrEmail;
    }
  }

  // Get user's teams from various possible sources
  Future<List<String>> getUserTeams() async {
    final userEmail = currentUser?.email?.toLowerCase();
    if (userEmail == null) return [];

    try {
      List<String> userTeams = [];

      // Method 1: Check if user document contains teams
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userEmail)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          final teams = userData?['teams'];
          if (teams is List) {
            userTeams.addAll(List<String>.from(teams));
          }
        }
      } catch (e) {
        print('Error getting user teams from users collection: $e');
      }

      // Method 2: Check teams collection where user is a member
      try {
        final teamsQuery = await FirebaseFirestore.instance
            .collection('teams')
            .where('members', arrayContains: userEmail)
            .get();

        for (final teamDoc in teamsQuery.docs) {
          if (!userTeams.contains(teamDoc.id)) {
            userTeams.add(teamDoc.id);
          }
          // Also add team name if it's different from ID
          final teamName = teamDoc.data()['name'] as String?;
          if (teamName != null && !userTeams.contains(teamName)) {
            userTeams.add(teamName);
          }
        }
      } catch (e) {
        print('Error getting teams from teams collection: $e');
      }

      print('User teams found: $userTeams');
      return userTeams;
    } catch (e) {
      print('Error getting user teams: $e');
      return [];
    }
  }

  // Enhanced filter that handles both individual and team assignments
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> filterTasksForUserAsync(
    List<DocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (canSeeAllTasks) {
      return docs; // Admins and managers see all tasks
    }

    final userEmail = currentUser?.email?.toLowerCase();
    if (userEmail == null) return [];

    // Get user's teams
    final userTeams = await getUserTeams();
    final userName =
        currentUser?.displayName?.toLowerCase() ??
        userEmail.split('@')[0].replaceAll('.', ' ');

    return docs.where((doc) {
      final data = doc.data();
      final assignmentType = data?['assignmentType'] ?? '';

      print('Checking task: ${data?['taskName']}, type: $assignmentType');

      if (assignmentType == 'individual') {
        // Check individual assignments

        // Method 1: Direct email match
        if (data!.containsKey('assignedToUserEmail')) {
          final assignedEmail = data['assignedToUserEmail']
              ?.toString()
              .toLowerCase();
          if (assignedEmail == userEmail) {
            print('✓ Individual task matched by email');
            return true;
          }
        }

        // Method 2: User ID match
        if (data.containsKey('assignedToUserId')) {
          final assignedUserId = data['assignedToUserId'];
          if (assignedUserId == currentUser?.uid) {
            print('✓ Individual task matched by UID');
            return true;
          }
        }

        // Method 3: Name-based matching (fallback)
        if (data.containsKey('assignedToUserName')) {
          final assignedName = data['assignedToUserName']
              ?.toString()
              .toLowerCase();
          if (assignedName != null &&
              (assignedName.contains(userName) ||
                  userName.contains(assignedName))) {
            print('✓ Individual task matched by name similarity');
            return true;
          }
        }
      } else if (assignmentType == 'team') {
        // Check team assignments

        // Method 1: Direct team member check (could be email or user ID)
        if (data!.containsKey('teamMembers')) {
          final teamMembers = data['teamMembers'];
          if (teamMembers is List) {
            // Check if user email is in the list
            if (teamMembers.contains(userEmail)) {
              print('✓ Team task matched - user email in teamMembers list');
              return true;
            }
            // Check if user ID is in the list
            if (teamMembers.contains(currentUser?.uid)) {
              print('✓ Team task matched - user ID in teamMembers list');
              return true;
            }
          }
        }

        // Method 2: Team name matching
        if (data!.containsKey('assignedToTeamName')) {
          final assignedTeam = data['assignedToTeamName']?.toString();
          if (assignedTeam != null && userTeams.contains(assignedTeam)) {
            print('✓ Team task matched - team name in user teams');
            return true;
          }
        }

        // Method 3: Team ID matching
        if (data.containsKey('assignedToTeamId')) {
          final assignedTeamId = data['assignedToTeamId']?.toString();
          if (assignedTeamId != null && userTeams.contains(assignedTeamId)) {
            print('✓ Team task matched - team ID in user teams');
            return true;
          }
        }
      }

      // Method 4: Check if user created the task
      if (data!.containsKey('createdBy')) {
        final createdBy = data['createdBy']?.toString().toLowerCase();
        if (createdBy == userEmail) {
          print('✓ Task matched - user is creator');
          return true;
        }
      }

      print('✗ Task not matched');
      return false;
    }).toList();
  }

  // Safe stream that works with existing data structure
  Stream<QuerySnapshot<Map<String, dynamic>>> get tasksStream {
    final collection = FirebaseFirestore.instance.collection('tasks');

    if (canSeeAllTasks) {
      // Admin and Manager can see all tasks
      return collection.orderBy('createdAt', descending: true).snapshots();
    } else {
      // For regular users, return all tasks first, then filter on client side
      return collection.orderBy('createdAt', descending: true).snapshots();
    }
  }

  // Delete task function
  Future<void> _deleteTask(
    BuildContext context,
    String taskId,
    String taskName,
  ) async {
    if (!canDeleteTasks) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only admins and managers can delete tasks'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Task',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "$taskName"?\n\nThis action cannot be undone.',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await FirebaseFirestore.instance
            .collection('tasks')
            .doc(taskId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task "$taskName" deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              canSeeAllTasks ? 'All Tasks' : 'My Tasks',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: roleBadgeColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                userRole,
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.gray800,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/'),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: tasksStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print('Firestore error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading tasks',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error: ${snapshot.error}',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Trigger a rebuild to retry
                      (context as Element).markNeedsBuild();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final allDocs = snapshot.data?.docs ?? [];

          // Use FutureBuilder for async team filtering
          return FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
            future: filterTasksForUserAsync(allDocs),
            builder: (context, filterSnapshot) {
              if (filterSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading your tasks...'),
                    ],
                  ),
                );
              }

              final filteredDocs = filterSnapshot.data ?? [];

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.task_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        canSeeAllTasks
                            ? 'No tasks found'
                            : 'No tasks assigned to you',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        canSeeAllTasks
                            ? 'Tasks will appear here once they are created'
                            : 'Individual and team tasks assigned to you will appear here',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (!canSeeAllTasks) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Total tasks in system: ${allDocs.length}',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your filtered tasks: ${filteredDocs.length}',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data();
                  final String taskId = doc.id;
                  final String taskName = data?['taskName'] ?? 'No Title';
                  final String notes = data?['notes'] ?? '';
                  final String status = data?['status'] ?? 'pending';
                  final String assignmentType = data?['assignmentType'] ?? '';
                  final String assignedName = assignmentType == 'individual'
                      ? (data?['assignedToUserName'] ?? '')
                      : (data?['assignedToTeamName'] ?? '');
                  final DateTime startDate =
                      (data?['startDate'] as Timestamp?)?.toDate() ??
                      DateTime.now();
                  final DateTime dueDate =
                      (data?['dueDate'] as Timestamp?)?.toDate() ??
                      DateTime.now();

                  // Check if task is overdue
                  final bool isOverdue =
                      DateTime.now().isAfter(dueDate) && status != 'completed';

                  // Determine progress bar value & color
                  double progress;
                  Color progColor;
                  switch (status) {
                    case 'completed':
                      progress = 1.0;
                      progColor = Colors.green;
                      break;
                    case 'progress':
                      progress = 0.5;
                      progColor = AppColors.progressYellow;
                      break;
                    default:
                      progress = 0.1;
                      progColor = Colors.grey;
                  }

                  void showDetailsDialog() {
                    String newStatus = status;
                    showDialog(
                      context: context,
                      builder: (context) => StatefulBuilder(
                        builder: (context, setState) => AlertDialog(
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  taskName,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isOverdue)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'OVERDUE',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.red[700],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Debug info (remove this in production)
                                if (!canSeeAllTasks) ...[
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.yellow[100],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Debug: Task visible because of: ${_getVisibilityReason(data!)}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Assignment info
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            assignmentType == 'individual'
                                                ? Icons.person
                                                : Icons.group,
                                            color: Colors.blue[600],
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Assigned to: $assignedName',
                                              style: GoogleFonts.montserrat(
                                                fontWeight: FontWeight.w500,
                                                color: Colors.blue[700],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Show team members for team tasks
                                      if (assignmentType == 'team' &&
                                          data!.containsKey('teamMembers')) ...[
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Team Members:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        FutureBuilder<List<String>>(
                                          future: Future.wait(
                                            (data['teamMembers'] as List? ?? [])
                                                .map<Future<String>>(
                                                  (memberIdOrEmail) =>
                                                      getUserDisplayName(
                                                        memberIdOrEmail
                                                            .toString(),
                                                      ),
                                                )
                                                .toList(),
                                          ),
                                          builder: (context, memberSnapshot) {
                                            if (memberSnapshot
                                                    .connectionState ==
                                                ConnectionState.waiting) {
                                              return const SizedBox(
                                                height: 20,
                                                child: Center(
                                                  child: SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                ),
                                              );
                                            }

                                            final memberNames =
                                                memberSnapshot.data ?? [];
                                            return Wrap(
                                              spacing: 4,
                                              runSpacing: 4,
                                              children: memberNames.map<Widget>(
                                                (memberName) {
                                                  return Chip(
                                                    label: Text(
                                                      memberName,
                                                      style: const TextStyle(
                                                        fontSize: 9,
                                                      ),
                                                    ),
                                                    materialTapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                  );
                                                },
                                              ).toList(),
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Date info
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Start Date',
                                            style: GoogleFonts.montserrat(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          Text(
                                            '${startDate.day}/${startDate.month}/${startDate.year}',
                                            style: GoogleFonts.montserrat(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Due Date',
                                            style: GoogleFonts.montserrat(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              color: isOverdue
                                                  ? Colors.red
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                          Text(
                                            '${dueDate.day}/${dueDate.month}/${dueDate.year}',
                                            style: GoogleFonts.montserrat(
                                              color: isOverdue
                                                  ? Colors.red
                                                  : null,
                                              fontWeight: isOverdue
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Notes section
                                if (notes.isNotEmpty) ...[
                                  Text(
                                    'Notes:',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Text(
                                      notes,
                                      style: GoogleFonts.montserrat(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Status dropdown
                                DropdownButtonFormField<String>(
                                  value: newStatus,
                                  decoration: InputDecoration(
                                    labelText: 'Status',
                                    border: const OutlineInputBorder(),
                                    labelStyle: GoogleFonts.montserrat(),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'pending',
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: const BoxDecoration(
                                              color: Colors.grey,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('Pending'),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'progress',
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: AppColors.progressYellow,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('In Progress'),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'completed',
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: const BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('Completed'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        newStatus = val;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            // Delete button (only for admins and managers)
                            if (canDeleteTasks)
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _deleteTask(context, taskId, taskName);
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                label: Text(
                                  'Delete',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('tasks')
                                      .doc(doc.id)
                                      .update({'status': newStatus});
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Task status updated successfully',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error updating task: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Generate simple multiavatar widget
                  Widget buildAvatar() {
                    if (assignedName.isEmpty) {
                      return CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.gray200,
                        child: Icon(
                          Icons.person,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                      );
                    }

                    return Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: SvgPicture.string(
                          multiavatar(assignedName),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: showDetailsDialog,
                    child: Card(
                      elevation: 3,
                      shadowColor: AppColors.shadow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isOverdue
                            ? BorderSide(color: Colors.red, width: 1.5)
                            : BorderSide.none,
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 20,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          taskName,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.gray800,
                                          ),
                                        ),
                                      ),
                                      if (isOverdue)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red[100],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            'OVERDUE',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.red[700],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Progress bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      color: progColor,
                                      backgroundColor: AppColors.progressTrack,
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Assignment and status info
                                  Row(
                                    children: [
                                      Icon(
                                        assignmentType == 'individual'
                                            ? Icons.person
                                            : Icons.group,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          assignedName,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: progColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: GoogleFonts.montserrat(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: progColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            buildAvatar(),
                            const SizedBox(width: 8),
                            // Actions menu
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                switch (value) {
                                  case 'details':
                                    showDetailsDialog();
                                    break;
                                  case 'delete':
                                    if (canDeleteTasks) {
                                      _deleteTask(context, taskId, taskName);
                                    }
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'details',
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 18),
                                      SizedBox(width: 8),
                                      Text('View Details'),
                                    ],
                                  ),
                                ),
                                if (canDeleteTasks)
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
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
          );
        },
      ),
    );
  }

  // Helper method to determine why a task is visible (for debugging)
  String _getVisibilityReason(Map<String, dynamic> data) {
    final userEmail = currentUser?.email?.toLowerCase();
    final assignmentType = data['assignmentType'] ?? '';

    if (assignmentType == 'individual') {
      if (data.containsKey('assignedToUserEmail')) {
        final assignedEmail = data['assignedToUserEmail']
            ?.toString()
            .toLowerCase();
        if (assignedEmail == userEmail)
          return 'Individual: assignedToUserEmail matches';
      }

      if (data.containsKey('assignedToUserId')) {
        final assignedUserId = data['assignedToUserId'];
        if (assignedUserId == currentUser?.uid)
          return 'Individual: assignedToUserId matches';
      }

      if (data.containsKey('assignedToUserName')) {
        final assignedName = data['assignedToUserName']
            ?.toString()
            .toLowerCase();
        final userName =
            currentUser?.displayName?.toLowerCase() ??
            userEmail?.split('@')[0].replaceAll('.', ' ');
        if (assignedName != null &&
            userName != null &&
            (assignedName.contains(userName) ||
                userName.contains(assignedName))) {
          return 'Individual: assignedToUserName similar';
        }
      }
    } else if (assignmentType == 'team') {
      if (data.containsKey('teamMembers')) {
        final teamMembers = data['teamMembers'];
        if (teamMembers is List && teamMembers.contains(userEmail)) {
          return 'Team: user in teamMembers list';
        }
      }

      if (data.containsKey('assignedToTeamName')) {
        final assignedTeam = data['assignedToTeamName']?.toString();
        return 'Team: assignedToTeamName = $assignedTeam (checking membership)';
      }

      if (data.containsKey('assignedToTeamId')) {
        final assignedTeamId = data['assignedToTeamId']?.toString();
        return 'Team: assignedToTeamId = $assignedTeamId (checking membership)';
      }
    }

    if (data.containsKey('createdBy')) {
      final createdBy = data['createdBy']?.toString().toLowerCase();
      if (createdBy == userEmail) return 'createdBy matches';
    }

    return 'No matching field found for assignment type: $assignmentType';
  }
}
