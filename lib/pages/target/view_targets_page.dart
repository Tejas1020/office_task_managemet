import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:office_task_managemet/utils/colors.dart';

class ViewTargetsPage extends StatefulWidget {
  const ViewTargetsPage({Key? key}) : super(key: key);

  @override
  State<ViewTargetsPage> createState() => _ViewTargetsPageState();
}

class _ViewTargetsPageState extends State<ViewTargetsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _filterStatus = 'all';
  String _filterTargetType = 'all';

  final List<String> _statusFilters = ['all', 'active', 'completed', 'paused'];
  final List<String> _targetTypeFilters = [
    'all',
    'Revenue',
    'Bookings',
    'EOI',
    'Agreement Value',
    'Invoice',
  ];

  final Map<String, IconData> _targetTypeIcons = {
    'all': Icons.all_inclusive,
    'Revenue': Icons.monetization_on,
    'Bookings': Icons.book_online,
    'EOI': Icons.contact_mail,
    'Agreement Value': Icons.handshake,
    'Invoice': Icons.receipt_long,
  };

  final Map<String, Color> _targetTypeColors = {
    'all': Colors.grey,
    'Revenue': Colors.green,
    'Bookings': Colors.blue,
    'EOI': Colors.orange,
    'Agreement Value': Colors.purple,
    'Invoice': Colors.teal,
  };

  final Map<String, Color> _statusColors = {
    'active': Colors.blue,
    'completed': Colors.green,
    'paused': Colors.orange,
  };

  User? get currentUser => _auth.currentUser;

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

  // Check if current user can manage targets (admin or manager)
  bool get canManageTargets => isAdmin || isManager;

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

  // Get current user's team name from user document
  Future<String?> _getCurrentUserTeamName() async {
    try {
      final userEmail = currentUser!.email;
      if (userEmail == null) return null;

      final userDoc = await _firestore
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      if (userDoc.docs.isNotEmpty) {
        final userData = userDoc.docs.first.data();
        return userData['teamName'] as String?;
      }
    } catch (e) {
      print('Error getting user team: $e');
    }
    return null;
  }

  // Check if current user is assigned to a specific target
  bool _isCurrentUserAssignedToTarget(
    Map<String, dynamic> targetData,
    String? userTeamName,
  ) {
    final assignmentType = targetData['assignmentType'] ?? 'individual';
    final assignedToUserName = targetData['assignedToUserName'] ?? '';
    final assignedToTeamName = targetData['assignedToTeamName'] ?? '';
    final userName = _getCurrentUserName();

    if (assignmentType == 'individual') {
      return assignedToUserName.isNotEmpty && assignedToUserName == userName;
    } else if (assignmentType == 'team') {
      return userTeamName != null &&
          userTeamName.isNotEmpty &&
          assignedToTeamName.isNotEmpty &&
          assignedToTeamName == userTeamName;
    }
    return false;
  }

  // Get current user name consistently
  String _getCurrentUserName() {
    final userEmail = currentUser?.email;
    if (userEmail == null) return '';

    // Try display name first, then extract from email
    return currentUser!.displayName?.isNotEmpty == true
        ? currentUser!.displayName!
        : userEmail.split('@')[0];
  }

  // Get filtered stream based on user role
  Stream<QuerySnapshot> _getTargetsStream() {
    if (canManageTargets) {
      // Admins and managers can see all targets
      return _firestore.collection('targets').snapshots();
    } else {
      // Regular users can see all targets (we'll filter in the UI based on assignment)
      return _firestore.collection('targets').snapshots();
    }
  }

  // Update target status (admin and manager only)
  Future<void> _updateTargetStatus(String targetId, String newStatus) async {
    if (!canManageTargets) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only admins and managers can update target status'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _firestore.collection('targets').doc(targetId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Target status updated to $newStatus'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating target: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Update target progress (admin, manager, or assigned user)
  Future<void> _showProgressDialog(
    String targetId,
    double currentProgress,
    double targetValue,
    Map<String, dynamic> targetData,
    String? userTeamName,
  ) async {
    // Check if user can update this target
    bool canUpdate =
        canManageTargets ||
        _isCurrentUserAssignedToTarget(targetData, userTeamName);

    if (!canUpdate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only update targets assigned to you'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final TextEditingController progressController = TextEditingController(
      text: (currentProgress * targetValue / 100).toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Update Progress',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Target Value: ₹${_formatCurrency(targetValue.toString())}',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: progressController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Achieved Amount (₹)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.currency_rupee),
              ),
              style: GoogleFonts.montserrat(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final achievedValue =
                  double.tryParse(progressController.text) ?? 0;
              final newProgress = (achievedValue / targetValue * 100).clamp(
                0,
                100,
              );

              await _firestore.collection('targets').doc(targetId).update({
                'achievedValue': achievedValue,
                'progress': newProgress,
                'updatedAt': FieldValue.serverTimestamp(),
              });

              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Progress updated successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // Delete target (admin and manager only)
  Future<void> _deleteTarget(String targetId, String targetName) async {
    if (!canManageTargets) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Target',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "$targetName"?',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _firestore.collection('targets').doc(targetId).delete();
              Navigator.of(context).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Target deleted successfully!'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Format currency
  String _formatCurrency(String value) {
    if (value.isEmpty) return '0';
    final number = double.tryParse(value.replaceAll(',', '')) ?? 0;
    return number
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  // Format date
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

  // Build stats cards
  Widget _buildStatsCards(
    List<QueryDocumentSnapshot> allTargets,
    String? userTeamName,
  ) {
    List<QueryDocumentSnapshot> visibleTargets;

    if (canManageTargets) {
      // Admins and managers see all targets
      visibleTargets = allTargets;
    } else {
      // Regular users see only their assigned targets (individual or team)
      final userName = _getCurrentUserName();

      visibleTargets = allTargets.where((target) {
        final data = target.data() as Map<String, dynamic>;
        final assignmentType = data['assignmentType'] ?? 'individual';
        final assignedToUserName = data['assignedToUserName'] ?? '';
        final assignedToTeamName = data['assignedToTeamName'] ?? '';

        if (assignmentType == 'individual') {
          return assignedToUserName.isNotEmpty &&
              assignedToUserName == userName;
        } else if (assignmentType == 'team') {
          return userTeamName != null &&
              userTeamName.isNotEmpty &&
              assignedToTeamName.isNotEmpty &&
              assignedToTeamName == userTeamName;
        }
        return false;
      }).toList();
    }

    final myTargets = visibleTargets.length;

    final activeTargets = visibleTargets.where((target) {
      final data = target.data() as Map<String, dynamic>;
      return data['status'] == 'active';
    }).length;

    final completedTargets = visibleTargets.where((target) {
      final data = target.data() as Map<String, dynamic>;
      return data['status'] == 'completed';
    }).length;

    final totalValue = visibleTargets.fold(0.0, (sum, target) {
      final data = target.data() as Map<String, dynamic>;
      return sum + (data['targetValue'] ?? 0.0);
    });

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              canManageTargets ? 'Total' : 'My Targets',
              myTargets.toString(),
              Icons.flag,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Active',
              activeTargets.toString(),
              Icons.play_arrow,
              Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Completed',
              completedTargets.toString(),
              Icons.check_circle,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Value',
              '₹${_formatCurrency((totalValue / 1000000).toStringAsFixed(1))}M',
              Icons.monetization_on,
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
            'Targets',
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
                'Please log in to view targets',
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
              'Targets',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (canManageTargets) ...[
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
          ],
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
              if (value.startsWith('status_')) {
                setState(() {
                  _filterStatus = value.replaceFirst('status_', '');
                });
              } else if (value.startsWith('type_')) {
                setState(() {
                  _filterTargetType = value.replaceFirst('type_', '');
                });
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
                      Icon(
                        status == 'all'
                            ? Icons.all_inclusive
                            : status == 'active'
                            ? Icons.play_arrow
                            : status == 'completed'
                            ? Icons.check_circle
                            : Icons.pause,
                        color: _filterStatus == status
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status == 'all' ? 'All Status' : status.toUpperCase(),
                      ),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                enabled: false,
                child: Text(
                  'Filter by Type',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ..._targetTypeFilters.map(
                (type) => PopupMenuItem(
                  value: 'type_$type',
                  child: Row(
                    children: [
                      Icon(
                        _targetTypeIcons[type],
                        color: _filterTargetType == type
                            ? _targetTypeColors[type]
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(type == 'all' ? 'All Types' : type),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getTargetsStream(),
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
                    'Error loading targets',
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

          final allTargets = snapshot.data?.docs ?? [];

          return FutureBuilder<String?>(
            future: canManageTargets
                ? Future.value(null)
                : _getCurrentUserTeamName(),
            builder: (context, teamSnapshot) {
              // Show loading if we're still fetching team info for regular users
              if (!canManageTargets &&
                  teamSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // final userName = _getCurrentUserName();
              // final userTeamName = teamSnapshot.data;

              // Apply filters
              List<QueryDocumentSnapshot> filteredTargets = allTargets.where((
                target,
              ) {
                final data = target.data() as Map<String, dynamic>;
                final status = data['status'] ?? 'active';
                final targetType = data['targetType'] ?? '';
                final assignmentType = data['assignmentType'] ?? 'individual';
                final assignedToUserName = data['assignedToUserName'] ?? '';
                final assignedToTeamName = data['assignedToTeamName'] ?? '';

                // Role-based visibility filter
                if (!canManageTargets) {
                  final userName = _getCurrentUserName();
                  final userTeamName = teamSnapshot.data;

                  bool canSeeTarget = false;

                  if (assignmentType == 'individual') {
                    // User can see if assigned to them individually
                    canSeeTarget =
                        assignedToUserName?.isNotEmpty == true &&
                        assignedToUserName == userName;
                  } else if (assignmentType == 'team') {
                    // User can see if assigned to their team
                    canSeeTarget =
                        userTeamName != null &&
                        userTeamName.isNotEmpty &&
                        assignedToTeamName?.isNotEmpty == true &&
                        assignedToTeamName == userTeamName;
                  }

                  if (!canSeeTarget) {
                    return false;
                  }
                }

                // Status filter
                if (_filterStatus != 'all' && status != _filterStatus) {
                  return false;
                }

                // Target type filter
                if (_filterTargetType != 'all' &&
                    targetType != _filterTargetType) {
                  return false;
                }

                return true;
              }).toList();

              // Sort by due date (urgent first)
              filteredTargets.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aDueDate = aData['dueDate'] as Timestamp?;
                final bDueDate = bData['dueDate'] as Timestamp?;

                if (aDueDate == null || bDueDate == null) return 0;
                return aDueDate.compareTo(bDueDate);
              });

              return Column(
                children: [
                  // Stats cards
                  _buildStatsCards(allTargets, teamSnapshot.data),

                  // Active filters indicator
                  if (_filterStatus != 'all' || _filterTargetType != 'all')
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
                          Text(
                            'Filtered: ${_filterStatus != 'all' ? _filterStatus : ''} ${_filterTargetType != 'all' ? _filterTargetType : ''}',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Targets list
                  Expanded(
                    child: filteredTargets.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.flag_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No targets found!',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  canManageTargets
                                      ? 'No targets have been created yet'
                                      : 'No targets assigned to you or your team',
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
                            itemCount: filteredTargets.length,
                            itemBuilder: (context, index) {
                              final target = filteredTargets[index];
                              final data =
                                  target.data() as Map<String, dynamic>;
                              final targetId = target.id;
                              final targetName = data['targetName'] ?? '';
                              final targetType = data['targetType'] ?? '';
                              final targetValue = data['targetValue'] ?? 0.0;
                              final achievedValue =
                                  data['achievedValue'] ?? 0.0;
                              final progress = data['progress'] ?? 0.0;
                              final status = data['status'] ?? 'active';
                              final assignedToUserName =
                                  data['assignedToUserName'] ?? '';
                              final assignedToTeamName =
                                  data['assignedToTeamName'] ?? '';
                              final assignmentType =
                                  data['assignmentType'] ?? 'individual';
                              final startDate = data['startDate'] as Timestamp?;
                              final dueDate = data['dueDate'] as Timestamp?;
                              final createdByName =
                                  data['createdByName'] ?? 'Unknown';

                              final isOverdue =
                                  dueDate != null &&
                                  DateTime.now().isAfter(dueDate.toDate()) &&
                                  status != 'completed';

                              // Handle assignment display properly
                              String assigneeName = '';
                              if (assignmentType == 'individual') {
                                assigneeName =
                                    assignedToUserName?.isNotEmpty == true
                                    ? assignedToUserName
                                    : 'Unknown User';
                              } else if (assignmentType == 'team') {
                                assigneeName =
                                    assignedToTeamName?.isNotEmpty == true
                                    ? 'Team $assignedToTeamName'
                                    : 'Unknown Team';
                              } else {
                                assigneeName = 'Unassigned';
                              }

                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: isOverdue
                                        ? Border.all(
                                            color: Colors.red,
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Header row
                                        Row(
                                          children: [
                                            // Target type icon
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color:
                                                    _targetTypeColors[targetType]
                                                        ?.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                _targetTypeIcons[targetType] ??
                                                    Icons.flag,
                                                size: 20,
                                                color:
                                                    _targetTypeColors[targetType],
                                              ),
                                            ),
                                            const SizedBox(width: 12),

                                            // Target name and info
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          targetName,
                                                          style:
                                                              GoogleFonts.montserrat(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: AppColors
                                                                    .gray800,
                                                              ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      if (isOverdue)
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                Colors.red[100],
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            'OVERDUE',
                                                            style:
                                                                GoogleFonts.montserrat(
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: Colors
                                                                      .red[700],
                                                                ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  // Target type and assignment on separate lines
                                                  Text(
                                                    targetType,
                                                    style: GoogleFonts.montserrat(
                                                      fontSize: 12,
                                                      color:
                                                          _targetTypeColors[targetType],
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Assigned to $assigneeName',
                                                    style:
                                                        GoogleFonts.montserrat(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  if (canManageTargets &&
                                                      createdByName.isNotEmpty)
                                                    Text(
                                                      'Created by $createdByName',
                                                      style:
                                                          GoogleFonts.montserrat(
                                                            fontSize: 10,
                                                            color: Colors
                                                                .grey[500],
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                ],
                                              ),
                                            ),

                                            // Status badge
                                            Row(
                                              children: [
                                                // "My Target" indicator for assigned users
                                                if (!canManageTargets &&
                                                    _isCurrentUserAssignedToTarget(
                                                      data,
                                                      teamSnapshot.data,
                                                    ))
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          right: 8,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green[100],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      'MY TARGET',
                                                      style:
                                                          GoogleFonts.montserrat(
                                                            fontSize: 9,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Colors
                                                                .green[700],
                                                          ),
                                                    ),
                                                  ),
                                                // Status badge
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: _statusColors[status]
                                                        ?.withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    status.toUpperCase(),
                                                    style: GoogleFonts.montserrat(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          _statusColors[status],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 16),

                                        // Progress section
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Progress',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            Text(
                                              '${progress.toStringAsFixed(1)}%',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: progress >= 100
                                                    ? Colors.green
                                                    : Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: progress / 100,
                                            backgroundColor: Colors.grey[200],
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  progress >= 100
                                                      ? Colors.green
                                                      : progress >= 75
                                                      ? Colors.blue
                                                      : progress >= 50
                                                      ? Colors.orange
                                                      : Colors.red,
                                                ),
                                            minHeight: 6,
                                          ),
                                        ),

                                        const SizedBox(height: 12),

                                        // Value section
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Target Value',
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 11,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                Text(
                                                  '₹${_formatCurrency(targetValue.toString())}',
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.green[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'Achieved',
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 11,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                Text(
                                                  '₹${_formatCurrency(achievedValue.toString())}',
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.blue[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 12),

                                        // Timeline
                                        Wrap(
                                          spacing: 16,
                                          runSpacing: 4,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.calendar_today,
                                                  size: 14,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  startDate != null
                                                      ? 'Started ${_formatDate(startDate.toDate())}'
                                                      : 'Start date not set',
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 11,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.event,
                                                  size: 14,
                                                  color: isOverdue
                                                      ? Colors.red
                                                      : Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  dueDate != null
                                                      ? 'Due ${_formatDate(dueDate.toDate())}'
                                                      : 'Due date not set',
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 11,
                                                    color: isOverdue
                                                        ? Colors.red
                                                        : Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),

                                        // Management actions
                                        if (canManageTargets ||
                                            _isCurrentUserAssignedToTarget(
                                              data,
                                              teamSnapshot.data,
                                            )) ...[
                                          const SizedBox(height: 16),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              // Update progress button (for admins, managers, and assigned users)
                                              SizedBox(
                                                width: 140,
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _showProgressDialog(
                                                        targetId,
                                                        progress,
                                                        targetValue,
                                                        data,
                                                        teamSnapshot.data,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.trending_up,
                                                    size: 16,
                                                  ),
                                                  label: Text(
                                                    'Update Progress',
                                                    style:
                                                        GoogleFonts.montserrat(
                                                          fontSize: 11,
                                                        ),
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        Colors.blue,
                                                    side: BorderSide(
                                                      color: Colors.blue[300]!,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              // Admin/Manager only actions
                                              if (canManageTargets) ...[
                                                // Status dropdown
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    border: Border.all(
                                                      color: Colors.grey[300]!,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: DropdownButton<String>(
                                                    value: status,
                                                    icon: Icon(
                                                      Icons.keyboard_arrow_down,
                                                      size: 16,
                                                      color: Colors.grey[600],
                                                    ),
                                                    underline: Container(),
                                                    style:
                                                        GoogleFonts.montserrat(
                                                          fontSize: 12,
                                                          color: Colors.black,
                                                        ),
                                                    dropdownColor: Colors.white,
                                                    items:
                                                        [
                                                          'active',
                                                          'completed',
                                                          'paused',
                                                        ].map((s) {
                                                          return DropdownMenuItem(
                                                            value: s,
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical: 4,
                                                                  ),
                                                              child: Text(
                                                                s.toUpperCase(),
                                                                style: GoogleFonts.montserrat(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color:
                                                                      _statusColors[s] ??
                                                                      Colors
                                                                          .black,
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        }).toList(),
                                                    onChanged: (newStatus) {
                                                      if (newStatus != null) {
                                                        _updateTargetStatus(
                                                          targetId,
                                                          newStatus,
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ),
                                                // Delete button
                                                IconButton(
                                                  onPressed: () =>
                                                      _deleteTarget(
                                                        targetId,
                                                        targetName,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 18,
                                                  ),
                                                  style: IconButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                    backgroundColor:
                                                        Colors.red[50],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/create_target'),
        backgroundColor: AppColors.gray800,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
