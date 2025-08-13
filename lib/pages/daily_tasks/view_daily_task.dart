import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:office_task_managemet/utils/colors.dart';

class ViewDailyTasksPage extends StatefulWidget {
  const ViewDailyTasksPage({Key? key}) : super(key: key);

  @override
  State<ViewDailyTasksPage> createState() => _ViewDailyTasksPageState();
}

class _ViewDailyTasksPageState extends State<ViewDailyTasksPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Filter states
  String _filterStatus = 'all';
  String _filterPriority = 'all';
  DateTime? _filterDate;

  final List<String> _statusFilters = [
    'all',
    'pending',
    'in_progress',
    'completed',
  ];
  final List<String> _priorityFilters = [
    'all',
    'low',
    'medium',
    'high',
    'urgent',
  ];

  User? get currentUser => _auth.currentUser;

  // Check user roles with debug logging
  bool get isAdmin {
    if (currentUser?.email == null) {
      print('DEBUG: No current user email found');
      return false;
    }
    final email = currentUser!.email!.toLowerCase();
    final isAdminUser = email.endsWith('@admin.com');
    print('DEBUG: User email: $email, isAdmin: $isAdminUser');
    return isAdminUser;
  }

  bool get isManager {
    if (currentUser?.email == null) {
      print('DEBUG: No current user email found for manager check');
      return false;
    }
    final email = currentUser!.email!.toLowerCase();
    final isManagerUser = email.endsWith('@manager.com');
    print('DEBUG: User email: $email, isManager: $isManagerUser');
    return isManagerUser;
  }

  bool get canManageTasks {
    final canManage = isAdmin || isManager;
    print(
      'DEBUG: canManageTasks: $canManage (isAdmin: $isAdmin, isManager: $isManager)',
    );
    return canManage;
  }

  String get userRole {
    if (isAdmin) return 'ADMIN';
    if (isManager) return 'MANAGER';
    return 'EMPLOYEE'; // Changed from 'USER' to 'EMPLOYEE' for clarity
  }

  Color get roleBadgeColor {
    if (isAdmin) return Colors.red[600]!;
    if (isManager) return Colors.orange[600]!;
    return Colors.blue[600]!;
  }

  String get displayName {
    return currentUser?.displayName?.isNotEmpty == true
        ? currentUser!.displayName!
        : currentUser?.email?.split('@')[0] ?? 'User';
  }

  // Get priority color
  Color getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Get status color
  Color getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      case 'pending':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // Enhanced filtered stream with debug logging - no compound query
  Stream<QuerySnapshot> _getDailyTasksStream() {
    print('DEBUG: Setting up task stream...');
    print('DEBUG: Current user UID: ${currentUser!.uid}');
    print('DEBUG: Current user email: ${currentUser!.email}');
    print('DEBUG: User role: $userRole');
    print('DEBUG: canManageTasks: $canManageTasks');

    Query query = _firestore.collection('dailyTasks');

    if (!canManageTasks) {
      // For employees: Only filter by userId (no orderBy to avoid compound query)
      print(
        'DEBUG: Applying userId filter for employee. Filtering by userId: ${currentUser!.uid}',
      );
      query = query.where('userId', isEqualTo: currentUser!.uid);
    } else {
      // For admins/managers: Show all tasks with date ordering
      print(
        'DEBUG: Admin/Manager detected - showing all tasks (no userId filter applied)',
      );
      query = query.orderBy('date', descending: true);
    }

    return query.snapshots();
  }

  // Add method to verify user data in tasks
  void _debugTaskData(List<QueryDocumentSnapshot> tasks) {
    print('DEBUG: === TASK DATA ANALYSIS ===');
    print('DEBUG: Total tasks found: ${tasks.length}');
    print('DEBUG: Current user UID: ${currentUser!.uid}');
    print('DEBUG: User role: $userRole');

    for (int i = 0; i < tasks.length && i < 5; i++) {
      // Show first 5 tasks
      final data = tasks[i].data() as Map<String, dynamic>;
      print('DEBUG: Task ${i + 1}:');
      print('  - Task ID: ${tasks[i].id}');
      print('  - Task Name: ${data['taskName']}');
      print('  - userId in task: ${data['userId']}');
      print(
        '  - Does userId match current user? ${data['userId'] == currentUser!.uid}',
      );
      print('  - userName in task: ${data['userName']}');
      print('  - userEmail in task: ${data['userEmail']}');
      print('  ---');
    }
    print('DEBUG: === END TASK DATA ANALYSIS ===');
  }

  // Delete daily task (admin and manager only)
  Future<void> _deleteDailyTask(String taskId, String taskName) async {
    if (!canManageTasks) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only admins and managers can delete tasks'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
        await _firestore.collection('dailyTasks').doc(taskId).delete();

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

  // Update task status
  Future<void> _updateTaskStatus(
    String taskId,
    String newStatus,
    String taskName,
  ) async {
    try {
      await _firestore.collection('dailyTasks').doc(taskId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Task "$taskName" status updated to ${newStatus.replaceAll('_', ' ')}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
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
  }

  // Show task details dialog
  void _showTaskDetailsDialog(Map<String, dynamic> taskData, String taskId) {
    String newStatus = taskData['status'] ?? 'pending';
    final bool isMyTask = taskData['userId'] == currentUser?.uid;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  taskData['taskName'] ?? 'Task',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: getPriorityColor(
                    taskData['priority'] ?? 'medium',
                  ).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  (taskData['priority'] ?? 'medium').toUpperCase(),
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: getPriorityColor(taskData['priority'] ?? 'medium'),
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [            

                // User info - Always show who created the task
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMyTask ? Colors.green[50] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isMyTask ? Colors.green[200]! : Colors.blue[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: isMyTask ? Colors.green[600] : Colors.blue[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMyTask ? 'Your Task' : 'Created by',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: isMyTask
                                    ? Colors.green[600]
                                    : Colors.blue[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              isMyTask
                                  ? 'You (${taskData['userRole'] ?? 'User'})'
                                  : '${taskData['userName'] ?? 'Unknown'} (${taskData['userRole'] ?? 'User'})',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w600,
                                color: isMyTask
                                    ? Colors.green[700]
                                    : Colors.blue[700],
                              ),
                            ),
                            if (taskData['userEmail'] != null && !isMyTask)
                              Text(
                                taskData['userEmail'],
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Date
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Date: ${_formatDate((taskData['date'] as Timestamp?)?.toDate() ?? DateTime.now())}',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  'Description:',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Text(
                    taskData['description'] ?? 'No description',
                    style: GoogleFonts.montserrat(),
                  ),
                ),

                // Notes (if any)
                if ((taskData['notes'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Notes:',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      taskData['notes'],
                      style: GoogleFonts.montserrat(),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Status dropdown
                DropdownButtonFormField<String>(
                  value: newStatus,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: const OutlineInputBorder(),
                    labelStyle: GoogleFonts.montserrat(),
                  ),
                  items: ['pending', 'in_progress', 'completed'].map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: getStatusColor(status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(status.replaceAll('_', ' ').toUpperCase()),
                        ],
                      ),
                    );
                  }).toList(),
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
            if (canManageTasks)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _deleteDailyTask(taskId, taskData['taskName'] ?? 'Task');
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: Text(
                  'Delete',
                  style: GoogleFonts.montserrat(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _updateTaskStatus(
                  taskId,
                  newStatus,
                  taskData['taskName'] ?? 'Task',
                );
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  // Date picker for filtering
  Future<void> _selectFilterDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null) {
      setState(() {
        _filterDate = pickedDate;
      });
    }
  }

  // Clear date filter
  void _clearDateFilter() {
    setState(() {
      _filterDate = null;
    });
  }

  // Format date
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Build stats cards
  Widget _buildStatsCards(List<QueryDocumentSnapshot> allTasks) {
    final myTasks = allTasks.where((task) {
      final data = task.data() as Map<String, dynamic>;
      return data['userId'] == currentUser!.uid;
    }).length;

    final totalTasks = allTasks.length;
    final completedTasks = allTasks.where((task) {
      final data = task.data() as Map<String, dynamic>;
      return data['status'] == 'completed';
    }).length;

    final todayTasks = allTasks.where((task) {
      final data = task.data() as Map<String, dynamic>;
      final taskDate = (data['date'] as Timestamp?)?.toDate();
      final today = DateTime.now();
      return taskDate != null &&
          taskDate.year == today.year &&
          taskDate.month == today.month &&
          taskDate.day == today.day;
    }).length;

    // Count unique users (for admin/manager view)
    final uniqueUsers = canManageTasks
        ? allTasks
              .map((task) {
                final data = task.data() as Map<String, dynamic>;
                return data['userId'] ?? '';
              })
              .where((userId) => userId.isNotEmpty)
              .toSet()
              .length
        : 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              canManageTasks ? 'Total' : 'My Tasks',
              canManageTasks ? totalTasks.toString() : myTasks.toString(),
              Icons.task_alt,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Completed',
              completedTasks.toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Today',
              todayTasks.toString(),
              Icons.today,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              canManageTasks ? 'Users' : userRole,
              canManageTasks ? uniqueUsers.toString() : '👤',
              canManageTasks ? Icons.group : Icons.person,
              roleBadgeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Daily Tasks',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: AppColors.gray800,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.login, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Please log in to view daily tasks',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Daily Tasks',
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
        actions: [
          // Filter menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (value) {
              if (value.startsWith('status_')) {
                setState(() {
                  _filterStatus = value.replaceFirst('status_', '');
                });
              } else if (value.startsWith('priority_')) {
                setState(() {
                  _filterPriority = value.replaceFirst('priority_', '');
                });
              } else if (value == 'date') {
                _selectFilterDate();
              } else if (value == 'clear_date') {
                _clearDateFilter();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                enabled: false,
                child: Text(
                  'Filter by Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ..._statusFilters.map(
                (status) => PopupMenuItem(
                  value: 'status_$status',
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: status == 'all'
                              ? Colors.grey
                              : getStatusColor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status == 'all'
                            ? 'All Status'
                            : status.replaceAll('_', ' ').toUpperCase(),
                      ),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                enabled: false,
                child: Text(
                  'Filter by Priority',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ..._priorityFilters.map(
                (priority) => PopupMenuItem(
                  value: 'priority_$priority',
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: priority == 'all'
                              ? Colors.grey
                              : getPriorityColor(priority),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        priority == 'all'
                            ? 'All Priority'
                            : priority.toUpperCase(),
                      ),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16),
                    SizedBox(width: 8),
                    Text('Filter by Date'),
                  ],
                ),
              ),
              if (_filterDate != null)
                const PopupMenuItem(
                  value: 'clear_date',
                  child: Row(
                    children: [
                      Icon(Icons.clear, size: 16),
                      SizedBox(width: 8),
                      Text('Clear Date Filter'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getDailyTasksStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
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
                      color: Colors.red,
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
                ],
              ),
            );
          }

          final allTasks = snapshot.data?.docs ?? [];

          // Add debug logging
          _debugTaskData(allTasks);

          // Sort tasks by date (client-side sorting for employees to avoid compound query)
          if (!canManageTasks) {
            allTasks.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aDate =
                  (aData['date'] as Timestamp?)?.toDate() ?? DateTime.now();
              final bDate =
                  (bData['date'] as Timestamp?)?.toDate() ?? DateTime.now();
              return bDate.compareTo(aDate); // Descending order
            });
          }

          // Apply filters
          List<QueryDocumentSnapshot> filteredTasks = allTasks.where((task) {
            final data = task.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final priority = data['priority'] ?? 'medium';
            final taskDate = (data['date'] as Timestamp?)?.toDate();

            // Status filter
            if (_filterStatus != 'all' && status != _filterStatus) {
              return false;
            }

            // Priority filter
            if (_filterPriority != 'all' && priority != _filterPriority) {
              return false;
            }

            // Date filter
            if (_filterDate != null && taskDate != null) {
              if (taskDate.year != _filterDate!.year ||
                  taskDate.month != _filterDate!.month ||
                  taskDate.day != _filterDate!.day) {
                return false;
              }
            }

            return true;
          }).toList();

          return Column(
            children: [
              // Stats cards
              _buildStatsCards(allTasks),

              // Active filters indicator
              if (_filterStatus != 'all' ||
                  _filterPriority != 'all' ||
                  _filterDate != null)
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.filter_list,
                        size: 16,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Filters: ${_filterStatus != 'all' ? _filterStatus : ''} ${_filterPriority != 'all' ? _filterPriority : ''} ${_filterDate != null ? _formatDate(_filterDate!) : ''}'
                              .trim(),
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Tasks list
              Expanded(
                child: filteredTasks.isEmpty
                    ? Center(
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
                              'No daily tasks found!',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              canManageTasks
                                  ? 'No daily tasks found with current filters'
                                  : 'No daily tasks found for you',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => context.go('/create_daily_task'),
                              icon: const Icon(Icons.add),
                              label: const Text('Create Daily Task'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gray800,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: filteredTasks.length,
                        itemBuilder: (context, index) {
                          final task = filteredTasks[index];
                          final data = task.data() as Map<String, dynamic>;
                          final taskId = task.id;
                          final taskName = data['taskName'] ?? '';
                          final description = data['description'] ?? '';
                          final status = data['status'] ?? 'pending';
                          final priority = data['priority'] ?? 'medium';
                          final userName = data['userName'] ?? 'Unknown';
                          final userRole = data['userRole'] ?? 'User';
                          final taskDate =
                              (data['date'] as Timestamp?)?.toDate() ??
                              DateTime.now();
                          final isMyTask = data['userId'] == currentUser?.uid;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _showTaskDetailsDialog(data, taskId),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header row
                                    Row(
                                      children: [
                                        // Priority indicator
                                        Container(
                                          width: 4,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: getPriorityColor(priority),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Task info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      taskName,
                                                      style:
                                                          GoogleFonts.montserrat(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: AppColors
                                                                .gray800,
                                                          ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  // Priority badge
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: getPriorityColor(
                                                        priority,
                                                      ).withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      priority.toUpperCase(),
                                                      style:
                                                          GoogleFonts.montserrat(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                getPriorityColor(
                                                                  priority,
                                                                ),
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              // User name display
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.person,
                                                    size: 14,
                                                    color: isMyTask
                                                        ? Colors.green[600]
                                                        : Colors.blue[600],
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    isMyTask
                                                        ? 'You ($userRole)'
                                                        : '$userName ($userRole)',
                                                    style:
                                                        GoogleFonts.montserrat(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: isMyTask
                                                              ? Colors
                                                                    .green[600]
                                                              : Colors
                                                                    .blue[600],
                                                        ),
                                                  ),
                                                  if (isMyTask) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 4,
                                                            vertical: 1,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.green[100],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        'ME',
                                                        style:
                                                            GoogleFonts.montserrat(
                                                              fontSize: 8,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: Colors
                                                                  .green[700],
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                description,
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Status badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: getStatusColor(
                                              status,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            status
                                                .replaceAll('_', ' ')
                                                .toUpperCase(),
                                            style: GoogleFonts.montserrat(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: getStatusColor(status),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    // Footer row
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDate(taskDate),
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const Spacer(),

                                        // Show creation time if available
                                        if (data['createdAt'] != null) ...[
                                          Icon(
                                            Icons.access_time,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Added ${_formatDate((data['createdAt'] as Timestamp).toDate())}',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/create_daily_task'),
        backgroundColor: AppColors.gray800,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Create Daily Task',
      ),
    );
  }
}

