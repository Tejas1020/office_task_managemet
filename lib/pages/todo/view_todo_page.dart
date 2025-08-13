import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:office_task_managemet/utils/colors.dart';

class ViewTodosPage extends StatefulWidget {
  const ViewTodosPage({Key? key}) : super(key: key);

  @override
  State<ViewTodosPage> createState() => _ViewTodosPageState();
}

class _ViewTodosPageState extends State<ViewTodosPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _filterType = 'all'; // all, completed, pending

  User? get currentUser => _auth.currentUser;

  // Toggle todo completion status
  Future<void> _toggleTodoCompletion(String todoId, bool currentStatus) async {
    try {
      await _firestore.collection('todos').doc(todoId).update({
        'isCompleted': !currentStatus,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentStatus
                ? 'Todo marked as completed!'
                : 'Todo marked as pending!',
          ),
          backgroundColor: !currentStatus ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating todo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Delete todo
  Future<void> _deleteTodo(String todoId) async {
    try {
      await _firestore.collection('todos').doc(todoId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todo deleted successfully!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting todo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show delete confirmation dialog
  void _showDeleteDialog(String todoId, String todoTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Todo',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "$todoTitle"?',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteTodo(todoId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Get filtered stream based on filter type
  Stream<QuerySnapshot> _getTodosStream() {
    try {
      Query query = _firestore
          .collection('todos')
          .where('userId', isEqualTo: currentUser!.uid);

      // Note: orderBy with where requires a composite index in Firestore
      // For now, we'll sort in the UI to avoid index issues
      return query.snapshots();
    } catch (e) {
      print('Error creating todos stream: $e');
      rethrow;
    }
  }

  // Get stats for todos
  Widget _buildStatsCards(List<QueryDocumentSnapshot> todos) {
    final totalTodos = todos.length;
    final completedTodos = todos.where((todo) {
      final data = todo.data() as Map<String, dynamic>;
      return data['isCompleted'] == true;
    }).length;
    final pendingTodos = totalTodos - completedTodos;
    final completionRate = totalTodos > 0
        ? (completedTodos / totalTodos * 100).round()
        : 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total',
              totalTodos.toString(),
              Icons.list_alt,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Completed',
              completedTodos.toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Pending',
              pendingTodos.toString(),
              Icons.pending,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Progress',
              '$completionRate%',
              Icons.trending_up,
              Colors.purple,
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
            'My Todos',
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
                'Please log in to view your todos',
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
        title: Text(
          'My Todos',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.gray800,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/'),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (value) {
              setState(() {
                _filterType = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(
                      Icons.list_alt,
                      color: _filterType == 'all'
                          ? AppColors.gray800
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text('All Todos'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'pending',
                child: Row(
                  children: [
                    Icon(
                      Icons.pending,
                      color: _filterType == 'pending'
                          ? Colors.orange
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text('Pending'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'completed',
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: _filterType == 'completed'
                          ? Colors.green
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text('Completed'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getTodosStream(),
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
                    'Error loading todos',
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {}); // Refresh the page
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final allTodos = snapshot.data?.docs ?? [];

          // Filter and sort todos manually
          List<QueryDocumentSnapshot> filteredTodos = allTodos.where((todo) {
            final data = todo.data() as Map<String, dynamic>;
            final isCompleted = data['isCompleted'] ?? false;

            if (_filterType == 'completed') {
              return isCompleted == true;
            } else if (_filterType == 'pending') {
              return isCompleted == false;
            }
            return true; // 'all' filter
          }).toList();

          // Sort by creation date (newest first)
          filteredTodos.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = aData['createdAt'] as Timestamp?;
            final bDate = bData['createdAt'] as Timestamp?;

            if (aDate == null || bDate == null) return 0;
            return bDate.compareTo(aDate); // Descending order
          });

          // Get all todos for stats (unfiltered)
          return Column(
            children: [
              // Stats cards
              _buildStatsCards(allTodos),

              // Filter indicator
              if (_filterType != 'all')
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
                    color: _filterType == 'completed'
                        ? Colors.green[50]
                        : Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _filterType == 'completed'
                          ? Colors.green[200]!
                          : Colors.orange[200]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _filterType == 'completed'
                            ? Icons.check_circle
                            : Icons.pending,
                        size: 16,
                        color: _filterType == 'completed'
                            ? Colors.green[600]
                            : Colors.orange[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Showing ${_filterType} todos',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _filterType == 'completed'
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),

              // Todos list
              Expanded(
                child: filteredTodos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _filterType == 'all'
                                  ? Icons.check_circle_outline
                                  : _filterType == 'completed'
                                  ? Icons.celebration
                                  : Icons.pending_actions,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _filterType == 'all'
                                  ? 'No todos yet!'
                                  : _filterType == 'completed'
                                  ? 'No completed todos!'
                                  : 'No pending todos!',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _filterType == 'all'
                                  ? 'Create your first todo to get started'
                                  : _filterType == 'completed'
                                  ? 'Complete some todos to see them here'
                                  : 'All your todos are completed!',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                color: Colors.grey[500],
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
                        itemCount: filteredTodos.length,
                        itemBuilder: (context, index) {
                          final todo = filteredTodos[index];
                          final data = todo.data() as Map<String, dynamic>;
                          final todoId = todo.id;
                          final title = data['title'] ?? '';
                          final isCompleted = data['isCompleted'] ?? false;
                          final createdAt = data['createdAt'] as Timestamp?;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              leading: GestureDetector(
                                onTap: () =>
                                    _toggleTodoCompletion(todoId, isCompleted),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isCompleted
                                        ? Colors.green
                                        : Colors.white,
                                    border: Border.all(
                                      color: isCompleted
                                          ? Colors.green
                                          : Colors.grey[400]!,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    size: 16,
                                    color: isCompleted
                                        ? Colors.white
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                              title: Text(
                                title,
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  color: isCompleted
                                      ? Colors.grey[500]
                                      : Colors.black,
                                ),
                              ),
                              subtitle: createdAt != null
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Created ${_formatDate(createdAt.toDate())}',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Status chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCompleted
                                          ? Colors.green[100]
                                          : Colors.orange[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isCompleted ? 'Done' : 'Pending',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isCompleted
                                            ? Colors.green[700]
                                            : Colors.orange[700],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Delete button
                                  GestureDetector(
                                    onTap: () =>
                                        _showDeleteDialog(todoId, title),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red[50],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.delete_outline,
                                        color: Colors.red[400],
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
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
        onPressed: () =>
            context.go('/create_todo_list'), // Navigate to add todo page
        backgroundColor: AppColors.gray800,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
