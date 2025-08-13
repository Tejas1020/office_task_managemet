import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class ViewLeadsPage extends StatefulWidget {
  const ViewLeadsPage({Key? key}) : super(key: key);

  @override
  State<ViewLeadsPage> createState() => _ViewLeadsPageState();
}

class _ViewLeadsPageState extends State<ViewLeadsPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _filteredLeads = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  String _currentUserId = '';
  int _currentPage = 1;
  int _itemsPerPage = 10;
  String _sortColumn = 'createdAt';
  bool _sortAscending = false;

  final List<String> _statusOptions = [
    'New',
    'Bad Timing',
    'In Follow-up',
    'Callback',
    'SVP',
    'RVP',
    'Visit Done',
    'Booked',
    'Lost',
    'Follow up',
    'Long Time Follow-up',
    'Customer',
    'EOI Done',
    'Bad timing',
  ];

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      _isAdmin = user.email?.endsWith('@admin.com') ?? false;
      await _fetchLeads();
    }
  }

  Future<void> _fetchLeads() async {
    setState(() => _isLoading = true);

    try {
      Query query = _firestore.collection('leads');

      if (_isAdmin) {
        // Admin can see all leads with sorting
        query = query.orderBy(_sortColumn, descending: !_sortAscending);
      } else {
        // For non-admin users, filter by assignedTo without additional ordering
        // This avoids the need for composite index
        query = query.where('assignedTo', isEqualTo: _currentUserId);
      }

      final QuerySnapshot snapshot = await query.get();

      List<Map<String, dynamic>> fetchedLeads = await Future.wait(
        snapshot.docs.map((doc) async {
          final data = doc.data() as Map<String, dynamic>;

          // Fetch assigned user details
          String assignedUserName = 'Unknown';
          if (data['assignedTo'] != null) {
            try {
              final userDoc = await _firestore
                  .collection('users')
                  .doc(data['assignedTo'])
                  .get();
              if (userDoc.exists) {
                assignedUserName = userDoc.data()?['displayName'] ?? 'Unknown';
              }
            } catch (e) {
              print('Error fetching user: $e');
            }
          }

          return {'id': doc.id, 'assignedUserName': assignedUserName, ...data};
        }).toList(),
      );

      // For non-admin users, sort the results in memory to avoid composite index requirement
      if (!_isAdmin) {
        fetchedLeads.sort((a, b) {
          dynamic aValue = a[_sortColumn];
          dynamic bValue = b[_sortColumn];

          // Handle null values
          if (aValue == null && bValue == null) return 0;
          if (aValue == null) return _sortAscending ? -1 : 1;
          if (bValue == null) return _sortAscending ? 1 : -1;

          // Handle Timestamp objects
          if (aValue is Timestamp && bValue is Timestamp) {
            return _sortAscending
                ? aValue.compareTo(bValue)
                : bValue.compareTo(aValue);
          }

          // Handle strings
          if (aValue is String && bValue is String) {
            return _sortAscending
                ? aValue.compareTo(bValue)
                : bValue.compareTo(aValue);
          }

          // Default comparison
          return _sortAscending
              ? aValue.toString().compareTo(bValue.toString())
              : bValue.toString().compareTo(aValue.toString());
        });
      }

      _leads = fetchedLeads;
      _filteredLeads = List.from(_leads);
    } catch (e) {
      print('Error fetching leads: $e');

      // Check if it's the index error and provide helpful message
      if (e.toString().contains('requires an index')) {
        _showErrorSnackBar(
          'Database setup required. Please contact your administrator to configure the database index.',
        );
      } else {
        _showErrorSnackBar('Error loading leads: ${e.toString()}');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterLeads(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredLeads = List.from(_leads);
      } else {
        _filteredLeads = _leads.where((lead) {
          return lead['name']?.toLowerCase().contains(query.toLowerCase()) ??
              false ||
                  lead['email']?.toLowerCase().contains(query.toLowerCase()) ??
              false || lead['phone']!.toString().contains(query) ??
              false ||
                  lead['assignedUserName']?.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ??
              false;
        }).toList();
      }
      _currentPage = 1;
    });
  }

  Future<void> _updateLeadStatus(String leadId, String newStatus) async {
    try {
      await _firestore.collection('leads').doc(leadId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local data
      final leadIndex = _leads.indexWhere((lead) => lead['id'] == leadId);
      if (leadIndex != -1) {
        setState(() {
          _leads[leadIndex]['status'] = newStatus;
          _filteredLeads = List.from(_leads);
          _filterLeads(_searchController.text);
        });
      }

      _showSuccessSnackBar('Status updated successfully');
    } catch (e) {
      _showErrorSnackBar('Error updating status: $e');
    }
  }

  Future<void> _showAddNoteDialog(String leadId, String leadName) async {
    final TextEditingController noteController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.note_add, color: Color(0xFF6366F1)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Note',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    leadName,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: TextField(
          controller: noteController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Enter your note about this lead...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (noteController.text.trim().isNotEmpty) {
                await _addNote(leadId, noteController.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Add Note',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addNote(String leadId, String note) async {
    try {
      final user = _auth.currentUser;
      await _firestore.collection('leads').doc(leadId).collection('notes').add({
        'note': note,
        'addedBy': user?.uid,
        'addedByName': user?.displayName ?? 'Unknown',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showSuccessSnackBar('Note added successfully');
    } catch (e) {
      _showErrorSnackBar('Error adding note: $e');
    }
  }

  Future<void> _showNotesDialog(String leadId, String leadName) async {
    final notesSnapshot = await _firestore
        .collection('leads')
        .doc(leadId)
        .collection('notes')
        .orderBy('createdAt', descending: true)
        .get();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.notes, color: Color(0xFF6366F1)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lead Notes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    leadName,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: notesSnapshot.docs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No notes yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: notesSnapshot.docs.length,
                  itemBuilder: (context, index) {
                    final note = notesSnapshot.docs[index].data();
                    final timestamp = note['createdAt'] as Timestamp?;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                note['addedByName'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              if (timestamp != null)
                                Text(
                                  _formatDateTime(timestamp.toDate()),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(note['note'] ?? ''),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showAddNoteDialog(leadId, leadName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Add Note',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _showLeadDetailsDialog(Map<String, dynamic> lead) async {
    // Fetch notes for this lead
    final notesSnapshot = await _firestore
        .collection('leads')
        .doc(lead['id'])
        .collection('notes')
        .orderBy('createdAt', descending: true)
        .get();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lead['name'] ?? 'Unknown Lead',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Lead Details & Progress',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lead Information Section
                      _buildDetailSection(
                        'Lead Information',
                        Icons.info_outline,
                        Column(
                          children: [
                            _buildDetailRow('Name', lead['name'] ?? 'N/A'),
                            _buildDetailRow('Email', lead['email'] ?? 'N/A'),
                            _buildDetailRow('Phone', lead['phone'] ?? 'N/A'),
                            _buildDetailRow('Status', lead['status'] ?? 'N/A'),
                            _buildDetailRow('Source', lead['source'] ?? 'N/A'),
                            _buildDetailRow(
                              'Assigned To',
                              lead['assignedUserName'] ?? 'Unassigned',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Project & Purpose Section
                      if (lead['project'] != null || lead['purpose'] != null)
                        _buildDetailSection(
                          'Project Details',
                          Icons.folder,
                          Column(
                            children: [
                              if (lead['project'] != null)
                                _buildDetailRow('Project', lead['project']),
                              if (lead['purpose'] != null)
                                _buildDetailRow(
                                  'Purpose/Visit Plan',
                                  lead['purpose'],
                                ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Tags Section
                      if (lead['tags'] != null &&
                          lead['tags'].toString().isNotEmpty)
                        _buildDetailSection(
                          'Tags',
                          Icons.local_offer,
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: lead['tags'].toString().split(',').map((
                              tag,
                            ) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF6366F1,
                                    ).withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  tag.trim(),
                                  style: const TextStyle(
                                    color: Color(0xFF6366F1),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Notes Section
                      _buildDetailSection(
                        'Notes & Progress',
                        Icons.notes,
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${notesSnapshot.docs.length} notes recorded',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showAddNoteDialog(
                                      lead['id'],
                                      lead['name'],
                                    );
                                  },
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Note'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Notes List
                            if (notesSnapshot.docs.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(32),
                                child: const Column(
                                  children: [
                                    Icon(
                                      Icons.note_outlined,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No notes yet',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    Text(
                                      'Add the first note to track progress',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ...notesSnapshot.docs.map((noteDoc) {
                                final note =
                                    noteDoc.data() as Map<String, dynamic>;
                                final timestamp =
                                    note['createdAt'] as Timestamp?;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF6366F1,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              Icons.person,
                                              size: 12,
                                              color: Color(0xFF6366F1),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            note['addedByName'] ?? 'Unknown',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (timestamp != null)
                                            Text(
                                              _formatDateTime(
                                                timestamp.toDate(),
                                              ),
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        note['note'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddNoteDialog(lead['id'], lead['name']);
                        },
                        icon: const Icon(Icons.note_add, size: 16),
                        label: const Text('Add Note'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, IconData icon, Widget content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF6366F1), size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    final paginatedLeads = _filteredLeads.sublist(
      startIndex,
      endIndex > _filteredLeads.length ? _filteredLeads.length : endIndex,
    );
    final totalPages = (_filteredLeads.length / _itemsPerPage).ceil();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6366F1),
                    Color(0xFF8B5CF6),
                    Color(0xFFA855F7),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.go('/'),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isAdmin ? 'All Leads' : 'My Leads',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isAdmin
                                    ? 'Manage all leads in the system'
                                    : 'View and manage your assigned leads',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_filteredLeads.length} leads',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Action Buttons
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            context.go('/create_leads');
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text(
                            'New Lead',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.upload_file,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Import',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _fetchLeads,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Search and Filters
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterLeads,
                      decoration: InputDecoration(
                        hintText: 'Search leads by name, email, phone...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF6B7280),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<int>(
                      value: _itemsPerPage,
                      underline: const SizedBox(),
                      items: [5, 10, 25, 50].map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value per page'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _itemsPerPage = value!;
                          _currentPage = 1;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Table Header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Lead Details',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Status',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Assigned',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Source',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    'Actions',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Table Body
                          Expanded(
                            child: paginatedLeads.isEmpty
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.inbox,
                                          size: 64,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'No leads found',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: paginatedLeads.length,
                                    itemBuilder: (context, index) {
                                      final lead = paginatedLeads[index];
                                      return InkWell(
                                        onTap: () =>
                                            _showLeadDetailsDialog(lead),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.grey.shade200,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              // Lead Details (Name, Email, Phone)
                                              Expanded(
                                                flex: 3,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      lead['name'] ?? 'Unknown',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 14,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    if (lead['email'] != null &&
                                                        lead['email']
                                                            .toString()
                                                            .isNotEmpty)
                                                      Text(
                                                        lead['email'],
                                                        style: TextStyle(
                                                          color: Colors
                                                              .grey
                                                              .shade600,
                                                          fontSize: 12,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    if (lead['phone'] != null &&
                                                        lead['phone']
                                                            .toString()
                                                            .isNotEmpty)
                                                      Text(
                                                        lead['phone'],
                                                        style: TextStyle(
                                                          color: Colors
                                                              .grey
                                                              .shade600,
                                                          fontSize: 12,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                  ],
                                                ),
                                              ),

                                              // Status
                                              Expanded(
                                                flex: 2,
                                                child: Container(
                                                  constraints:
                                                      const BoxConstraints(
                                                        minWidth: 0,
                                                      ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: _getStatusColor(
                                                        lead['status'],
                                                      ).withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: DropdownButton<String>(
                                                      value: lead['status'],
                                                      isExpanded: true,
                                                      underline:
                                                          const SizedBox(),
                                                      style: TextStyle(
                                                        color: _getStatusColor(
                                                          lead['status'],
                                                        ),
                                                        fontSize: 11,
                                                      ),
                                                      items: _statusOptions.map((
                                                        status,
                                                      ) {
                                                        return DropdownMenuItem<
                                                          String
                                                        >(
                                                          value: status,
                                                          child: Text(
                                                            status,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        );
                                                      }).toList(),
                                                      onChanged: (newStatus) {
                                                        if (newStatus != null) {
                                                          _updateLeadStatus(
                                                            lead['id'],
                                                            newStatus,
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // Assigned
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  lead['assignedUserName'] ??
                                                      'Unassigned',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),

                                              // Source
                                              Expanded(
                                                flex: 2,
                                                child: Container(
                                                  constraints:
                                                      const BoxConstraints(
                                                        minWidth: 0,
                                                      ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      lead['source'] ??
                                                          'Unknown',
                                                      style: const TextStyle(
                                                        color: Colors.blue,
                                                        fontSize: 11,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // Actions
                                              SizedBox(
                                                width: 100,
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      onPressed: () =>
                                                          _showAddNoteDialog(
                                                            lead['id'],
                                                            lead['name'],
                                                          ),
                                                      icon: const Icon(
                                                        Icons.note_add,
                                                        color: Colors.green,
                                                        size: 18,
                                                      ),
                                                      tooltip: 'Add Note',
                                                      constraints:
                                                          const BoxConstraints(
                                                            minWidth: 32,
                                                            minHeight: 32,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                            4,
                                                          ),
                                                    ),
                                                    IconButton(
                                                      onPressed: () =>
                                                          _showLeadDetailsDialog(
                                                            lead,
                                                          ),
                                                      icon: const Icon(
                                                        Icons.visibility,
                                                        color: Color(
                                                          0xFF6366F1,
                                                        ),
                                                        size: 18,
                                                      ),
                                                      tooltip: 'View Details',
                                                      constraints:
                                                          const BoxConstraints(
                                                            minWidth: 32,
                                                            minHeight: 32,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                            4,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),

                          // Pagination
                          if (totalPages > 1)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Showing ${startIndex + 1}-${endIndex > _filteredLeads.length ? _filteredLeads.length : endIndex} of ${_filteredLeads.length}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: _currentPage > 1
                                            ? () =>
                                                  setState(() => _currentPage--)
                                            : null,
                                        icon: const Icon(Icons.chevron_left),
                                      ),
                                      Text('$_currentPage of $totalPages'),
                                      IconButton(
                                        onPressed: _currentPage < totalPages
                                            ? () =>
                                                  setState(() => _currentPage++)
                                            : null,
                                        icon: const Icon(Icons.chevron_right),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'new':
        return Colors.blue;
      case 'in follow-up':
      case 'follow up':
        return Colors.orange;
      case 'booked':
      case 'customer':
        return Colors.green;
      case 'lost':
        return Colors.red;
      case 'callback':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
