import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:office_task_managemet/utils/colors.dart';

class ViewWorkLinksPage extends StatefulWidget {
  const ViewWorkLinksPage({Key? key}) : super(key: key);

  @override
  State<ViewWorkLinksPage> createState() => _ViewWorkLinksPageState();
}

class _ViewWorkLinksPageState extends State<ViewWorkLinksPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _filterCategory = 'all';

  final List<String> _categories = [
    'all',
    'Work',
    'Documentation',
    'Resources',
    'Tools',
    'Projects',
    'Learning',
    'Other',
  ];

  final List<IconData> _categoryIcons = [
    Icons.all_inclusive,
    Icons.work,
    Icons.description,
    Icons.library_books,
    Icons.build,
    Icons.folder_open,
    Icons.school,
    Icons.bookmark,
  ];

  User? get currentUser => _auth.currentUser;

  // Check if current user is admin (only @admin.com)
  bool get isAdmin {
    if (currentUser?.email == null) return false;
    final email = currentUser!.email!.toLowerCase();
    return email.endsWith('@admin.com');
  }

  // Check if current user is manager (only @manager.com)
  bool get isManager {
    if (currentUser?.email == null) return false;
    final email = currentUser!.email!.toLowerCase();
    return email.endsWith('@manager.com');
  }

  // Check if current user can delete links (admin or manager only)
  bool get canDeleteLinks => isAdmin || isManager;

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

  // Delete work link (only admins and managers)
  Future<void> _deleteWorkLink(String linkId) async {
    if (!canDeleteLinks) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only admins and managers can delete links'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _firestore.collection('workLinks').doc(linkId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link deleted successfully!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting link: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Copy URL to clipboard with enhanced feedback
  void _copyToClipboard(String url, String title) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Copied "$title" URL to clipboard!',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Show delete confirmation dialog
  void _showDeleteDialog(String linkId, String title) {
    if (!canDeleteLinks) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Link',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "$title"?',
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
              _deleteWorkLink(linkId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Get category icon
  IconData _getCategoryIcon(String category) {
    final index = _categories.indexOf(category);
    return index != -1 ? _categoryIcons[index] : Icons.bookmark;
  }

  // Get category color
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'all':
        return Colors.grey;
      case 'Work':
        return Colors.blue;
      case 'Documentation':
        return Colors.green;
      case 'Resources':
        return Colors.orange;
      case 'Tools':
        return Colors.purple;
      case 'Projects':
        return Colors.teal;
      case 'Learning':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  // Get filtered stream - Everyone can see all links
  Stream<QuerySnapshot> _getLinksStream() {
    // All users can see all work links
    return _firestore.collection('workLinks').snapshots();
  }

  // Build stats cards
  Widget _buildStatsCards(List<QueryDocumentSnapshot> allLinks) {
    final myLinks = allLinks.where((link) {
      final data = link.data() as Map<String, dynamic>;
      return data['userId'] == currentUser!.uid;
    }).length;

    final totalLinks = allLinks.length;
    final categories = allLinks
        .map((link) {
          final data = link.data() as Map<String, dynamic>;
          return data['category'] ?? 'Other';
        })
        .toSet()
        .length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'My Links',
              myLinks.toString(),
              Icons.person,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Total Links',
              totalLinks.toString(),
              Icons.link,
              Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Categories',
              categories.toString(),
              Icons.category,
              Colors.orange,
            ),
          ),
          if (canDeleteLinks) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                userRole,
                '👑',
                Icons.admin_panel_settings,
                roleBadgeColor,
              ),
            ),
          ],
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
            'Work Links',
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
                'Please log in to view work links',
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
              'Work Links',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (canDeleteLinks) ...[
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
              setState(() {
                _filterCategory = value;
              });
            },
            itemBuilder: (context) => _categories.map((category) {
              return PopupMenuItem(
                value: category,
                child: Row(
                  children: [
                    Icon(
                      _getCategoryIcon(category),
                      color: _filterCategory == category
                          ? _getCategoryColor(category)
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(category == 'all' ? 'All Categories' : category),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getLinksStream(),
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
                    'Error loading links',
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

          final allLinks = snapshot.data?.docs ?? [];

          // Filter by category
          List<QueryDocumentSnapshot> filteredLinks = allLinks.where((link) {
            final data = link.data() as Map<String, dynamic>;
            final category = data['category'] ?? 'Other';

            if (_filterCategory == 'all') return true;
            return category == _filterCategory;
          }).toList();

          // Sort by creation date (newest first)
          filteredLinks.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = aData['createdAt'] as Timestamp?;
            final bDate = bData['createdAt'] as Timestamp?;

            if (aDate == null || bDate == null) return 0;
            return bDate.compareTo(aDate);
          });

          return Column(
            children: [
              // Stats cards
              _buildStatsCards(allLinks),

              // Instructions banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[600], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All work links are visible to everyone. Tap any card to copy URL to clipboard.',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter indicator
              if (_filterCategory != 'all')
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
                    color: _getCategoryColor(_filterCategory).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getCategoryColor(
                        _filterCategory,
                      ).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getCategoryIcon(_filterCategory),
                        size: 16,
                        color: _getCategoryColor(_filterCategory),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Showing $_filterCategory links',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _getCategoryColor(_filterCategory),
                        ),
                      ),
                    ],
                  ),
                ),

              // Links list
              Expanded(
                child: filteredLinks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.link_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _filterCategory == 'all'
                                  ? 'No work links yet!'
                                  : 'No $_filterCategory links found!',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to add a work link to share with the team',
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
                        itemCount: filteredLinks.length,
                        itemBuilder: (context, index) {
                          final link = filteredLinks[index];
                          final data = link.data() as Map<String, dynamic>;
                          final linkId = link.id;
                          final url = data['url'] ?? '';
                          final title = data['title'] ?? '';
                          final description = data['description'] ?? '';
                          final category = data['category'] ?? 'Other';
                          final createdAt = data['createdAt'] as Timestamp?;
                          final userId = data['userId'] ?? '';
                          final userName = data['userName'] ?? 'Unknown';
                          final userEmail = data['userEmail'] ?? '';

                          final isOwner = currentUser!.uid == userId;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              // Copies URL to clipboard
                              onTap: () => _copyToClipboard(url, title),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // Category icon
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: _getCategoryColor(
                                                category,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              _getCategoryIcon(category),
                                              size: 20,
                                              color: _getCategoryColor(
                                                category,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // Title and owner info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        title,
                                                        style:
                                                            GoogleFonts.montserrat(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: AppColors
                                                                  .gray800,
                                                            ),
                                                      ),
                                                    ),
                                                    // Copy indicator
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue[100],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.content_copy,
                                                            size: 12,
                                                            color: Colors
                                                                .blue[700],
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            'Tap to copy',
                                                            style:
                                                                GoogleFonts.montserrat(
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Colors
                                                                      .blue[700],
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      category,
                                                      style:
                                                          GoogleFonts.montserrat(
                                                            fontSize: 12,
                                                            color:
                                                                _getCategoryColor(
                                                                  category,
                                                                ),
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                    ),
                                                    Text(
                                                      ' • by $userName',
                                                      style:
                                                          GoogleFonts.montserrat(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .grey[500],
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          ),
                                                    ),
                                                    if (isOwner) ...[
                                                      Text(
                                                        ' (Mine)',
                                                        style:
                                                            GoogleFonts.montserrat(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .green[600],
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Delete button (only for admins and managers)
                                          if (canDeleteLinks)
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.red[50],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  size: 18,
                                                ),
                                                onPressed: () =>
                                                    _showDeleteDialog(
                                                      linkId,
                                                      title,
                                                    ),
                                                tooltip:
                                                    'Delete (Admin/Manager only)',
                                                style: IconButton.styleFrom(
                                                  foregroundColor:
                                                      Colors.red[600],
                                                  minimumSize: const Size(
                                                    36,
                                                    36,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),

                                      if (description.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          description,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 12),

                                      // URL display
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.link,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                url,
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 13,
                                                  color: Colors.grey[600],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Footer info
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          if (createdAt != null)
                                            Text(
                                              'Added ${_formatDate(createdAt.toDate())}',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 11,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          if (canDeleteLinks)
                                            Text(
                                              userEmail,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 11,
                                                color: Colors.grey[500],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
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
        onPressed: () => context.go(
          '/create_works_link_page',
        ), // Navigate to add work link page
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
