import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:office_task_managemet/utils/colors.dart';

class ViewAccountsPage extends StatefulWidget {
  const ViewAccountsPage({Key? key}) : super(key: key);

  @override
  State<ViewAccountsPage> createState() => _ViewAccountsPageState();
}

class _ViewAccountsPageState extends State<ViewAccountsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Filter states
  String _filterMonth = 'all';
  String _filterYear = 'all';

  // Add error handling state
  bool _hasQueryError = false;
  String _errorMessage = '';

  // Add passcode verification state
  bool _isPasscodeVerified = false;
  bool _isVerifyingPasscode = false;

  // Add refresh state
  bool _isRefreshing = false;
  DateTime? _lastRefreshTime;

  final List<String> _monthFilters = [
    'all',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
  ];

  final List<String> _monthNames = [
    'All Months',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  // Refresh accounts data
  Future<void> _refreshAccounts() async {
    setState(() {
      _isRefreshing = true;
      _hasQueryError = false; // Reset error state
    });

    // Small delay to show refresh animation
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      _isRefreshing = false;
      _lastRefreshTime = DateTime.now();
    });

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text('✅ Accounts data refreshed successfully'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // Format last refresh time
  String _formatLastRefreshTime() {
    if (_lastRefreshTime == null) return 'Never';
    final now = DateTime.now();
    final difference = now.difference(_lastRefreshTime!);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${_lastRefreshTime!.hour.toString().padLeft(2, '0')}:${_lastRefreshTime!.minute.toString().padLeft(2, '0')}';
    }
  }

  // Build refresh button module
  Widget _buildRefreshModule() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isRefreshing ? null : _refreshAccounts,
                  icon: _isRefreshing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.refresh, size: 20),
                  label: Text(
                    _isRefreshing ? 'Refreshing...' : 'Refresh Accounts',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: IconButton(
                  onPressed: _isRefreshing
                      ? null
                      : () {
                          // Show refresh options
                          _showRefreshOptions();
                        },
                  icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                  tooltip: 'Refresh Options',
                ),
              ),
            ],
          ),
          if (_lastRefreshTime != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Last updated: ${_formatLastRefreshTime()}',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Show refresh options menu
  void _showRefreshOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Refresh Options',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.gray800,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.refresh, color: Colors.blue[600]),
              title: Text(
                'Standard Refresh',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Reload account data from server',
                style: GoogleFonts.montserrat(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _refreshAccounts();
              },
            ),
            ListTile(
              leading: Icon(Icons.restore, color: Colors.orange[600]),
              title: Text(
                'Reset Filters',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Clear all applied filters',
                style: GoogleFonts.montserrat(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _filterMonth = 'all';
                  _filterYear = 'all';
                });
                _refreshAccounts();
              },
            ),
            ListTile(
              leading: Icon(Icons.bug_report, color: Colors.yellow[700]),
              title: Text(
                'Force Fallback Mode',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Use basic query if having issues',
                style: GoogleFonts.montserrat(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _hasQueryError = true;
                });
                _refreshAccounts();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Set initial load time
    _lastRefreshTime = DateTime.now();
    // Show passcode verification when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentUser != null) {
        _showPasscodeVerification();
      }
    });
  }

  // Show passcode verification dialog
  Future<void> _showPasscodeVerification() async {
    if (_isVerifyingPasscode || _isPasscodeVerified) return;

    setState(() {
      _isVerifyingPasscode = true;
    });

    final isValid = await _showPasscodeDialog();

    if (isValid) {
      setState(() {
        _isPasscodeVerified = true;
        _isVerifyingPasscode = false;
      });
    } else {
      // If passcode is wrong, go back to previous page
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Access denied! Invalid passcode.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        context.go('/'); // Navigate back to home
      }
    }
  }

  // Show passcode dialog
  Future<bool> _showPasscodeDialog() async {
    String enteredPasscode = '';

    try {
      final bool? result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.security, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Account Access',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter passcode to view account details:',
                  style: GoogleFonts.montserrat(color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[600],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This page contains sensitive financial information',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Passcode',
                    prefixIcon: Icon(Icons.lock, color: Colors.blue[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    counterText: '',
                    hintText: 'Enter 6-digit passcode',
                  ),
                  autofocus: true,
                  onChanged: (value) {
                    enteredPasscode = value.trim();
                  },
                  onSubmitted: (value) {
                    enteredPasscode = value.trim();
                    Navigator.of(
                      dialogContext,
                    ).pop(enteredPasscode == '147258');
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: Text('Cancel', style: GoogleFonts.montserrat()),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(enteredPasscode == '147258');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Access',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );

      return result ?? false;
    } catch (e) {
      print('Passcode dialog error: $e');
      return false;
    }
  }

  User? get currentUser => _auth.currentUser;

  // Check user roles
  bool get isAdmin {
    if (currentUser?.email == null) return false;
    final email = currentUser!.email!.toLowerCase();
    return email.endsWith('@admin.com');
  }

  bool get isManager {
    if (currentUser?.email == null) return false;
    final email = currentUser!.email!.toLowerCase();
    return email.endsWith('@manager.com');
  }

  bool get canManageAccounts => isAdmin || isManager;

  String get userRole {
    if (isAdmin) return 'ADMIN';
    if (isManager) return 'MANAGER';
    return 'EMPLOYEE';
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

  // Add method to debug account data
  void _debugAccountData(List<QueryDocumentSnapshot> accounts) {
    print('DEBUG: === ACCOUNT DATA ANALYSIS ===');
    print('DEBUG: Total accounts found: ${accounts.length}');
    print('DEBUG: Current user UID: ${currentUser!.uid}');
    print('DEBUG: User role: $userRole');

    for (int i = 0; i < accounts.length && i < 3; i++) {
      // Show first 3 accounts
      final data = accounts[i].data() as Map<String, dynamic>;
      print('DEBUG: Account ${i + 1}:');
      print('  - Account ID: ${accounts[i].id}');
      print('  - Month: ${data['monthName']} ${data['year']}');
      print('  - userId in account: ${data['userId']}');
      print(
        '  - Does userId match current user? ${data['userId'] == currentUser!.uid}',
      );
      print('  - userName in account: ${data['userName']}');
      print('  - Target: ${data['target']}, Raised: ${data['raiseAmount']}');
      print('  ---');
    }
    print('DEBUG: === END ACCOUNT DATA ANALYSIS ===');
  }

  // Fallback method with the most basic query possible
  Stream<QuerySnapshot> _getBasicAccountsStream() {
    print('DEBUG: Using basic fallback query - no filtering, no ordering');
    return _firestore.collection('accounts').snapshots();
  }

  // Get accounts stream based on user role - Completely avoid compound queries
  Stream<QuerySnapshot> _getAccountsStream() {
    if (_hasQueryError) {
      print('DEBUG: Using fallback query due to previous error');
      return _getBasicAccountsStream();
    }

    print('DEBUG: Setting up accounts stream...');
    print('DEBUG: Current user UID: ${currentUser!.uid}');
    print('DEBUG: User role: $userRole');
    print('DEBUG: canManageAccounts: $canManageAccounts');

    try {
      // Use the simplest possible queries to avoid any compound index issues
      if (!canManageAccounts) {
        // For employees: Only use where clause, no ordering
        print('DEBUG: Employee query - only filtering by userId');
        return _firestore
            .collection('accounts')
            .where('userId', isEqualTo: currentUser!.uid)
            .snapshots();
      } else {
        // For admin/managers: Get all documents without any filtering
        print(
          'DEBUG: Admin/Manager query - getting all accounts without filtering',
        );
        return _firestore.collection('accounts').snapshots();
      }
    } catch (e) {
      print('DEBUG: Query setup error: $e');
      setState(() {
        _hasQueryError = true;
        _errorMessage = e.toString();
      });
      return _getBasicAccountsStream();
    }
  }

  // Update account fields
  Future<void> _updateAccount(
    String accountId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('accounts').doc(accountId).update(updates);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account updated successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show account details dialog
  void _showAccountDetailsDialog(
    Map<String, dynamic> accountData,
    String accountId,
  ) {
    final TextEditingController targetController = TextEditingController(
      text: accountData['target']?.toString() ?? '',
    );
    final TextEditingController raiseController = TextEditingController(
      text: accountData['raiseAmount']?.toString() ?? '',
    );
    final TextEditingController pendingController = TextEditingController(
      text: accountData['pendingAmount']?.toString() ?? '',
    );
    final TextEditingController followupsController = TextEditingController(
      text: accountData['followups']?.toString() ?? '',
    );
    final TextEditingController notesController = TextEditingController(
      text: accountData['notes']?.toString() ?? '',
    );

    final bool isMyAccount = accountData['userId'] == currentUser?.uid;

    // Function to calculate pending amount automatically
    void calculatePendingAmount() {
      final target = double.tryParse(targetController.text) ?? 0.0;
      final raised = double.tryParse(raiseController.text) ?? 0.0;
      final pending = target - raised;
      pendingController.text = pending >= 0
          ? pending.toStringAsFixed(2)
          : '0.00';
    }

    // Add listener to raise amount controller
    raiseController.addListener(calculatePendingAmount);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '${accountData['monthName']} ${accountData['year']}',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isMyAccount ? Colors.green[100] : Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isMyAccount
                      ? 'MY ACCOUNT'
                      : accountData['userRole'] ?? 'USER',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isMyAccount ? Colors.green[700] : Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMyAccount ? Colors.green[50] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isMyAccount
                          ? Colors.green[200]!
                          : Colors.blue[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: isMyAccount
                            ? Colors.green[600]
                            : Colors.blue[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMyAccount ? 'Your Account' : 'Created by',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: isMyAccount
                                    ? Colors.green[600]
                                    : Colors.blue[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              isMyAccount
                                  ? 'You (${accountData['userRole'] ?? 'User'})'
                                  : '${accountData['userName'] ?? 'Unknown'} (${accountData['userRole'] ?? 'User'})',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w600,
                                color: isMyAccount
                                    ? Colors.green[700]
                                    : Colors.blue[700],
                              ),
                            ),
                            if (accountData['userEmail'] != null &&
                                !isMyAccount)
                              Text(
                                accountData['userEmail'],
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

                // Financial Summary Cards (Current Values)
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Current Target',
                        '₹${_formatNumber(accountData['target'] ?? 0)}',
                        Icons.flag,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSummaryCard(
                        'Current Raised',
                        '₹${_formatNumber(accountData['raiseAmount'] ?? 0)}',
                        Icons.trending_up,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Current Pending',
                        '₹${_formatNumber(accountData['pendingAmount'] ?? 0)}',
                        Icons.pending,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSummaryCard(
                        'Follow-ups',
                        (accountData['followups'] ?? 0).toString(),
                        Icons.phone,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Current progress indicator
                _buildProgressIndicator(accountData),
                const SizedBox(height: 20),

                // Update Section Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Update Account Values',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Target Amount (Read-only)
                TextFormField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Target Amount',
                    prefixText: '₹ ',
                    border: const OutlineInputBorder(),
                    labelStyle: GoogleFonts.montserrat(),
                    helperText: 'Monthly target (can be updated)',
                  ),
                ),
                const SizedBox(height: 12),

                // Raise Amount (Editable)
                TextFormField(
                  controller: raiseController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Raise Amount (Editable)',
                    prefixText: '₹ ',
                    prefixIcon: Icon(
                      Icons.trending_up,
                      color: Colors.blue[600],
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.blue[300]!,
                        width: 2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.blue[600]!,
                        width: 2,
                      ),
                    ),
                    labelStyle: GoogleFonts.montserrat(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
                    ),
                    helperText: 'Update this value to recalculate pending',
                    helperStyle: GoogleFonts.montserrat(
                      color: Colors.blue[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                          
                const SizedBox(height: 12),

                // Pending Amount (Auto-calculated, Read-only)
                TextFormField(
                  controller: pendingController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Pending Amount (Auto-calculated)',
                    prefixText: '₹ ',
                    prefixIcon: Icon(Icons.calculate, color: Colors.grey[600]),
                    suffixIcon: Icon(
                      Icons.lock_outline,
                      color: Colors.grey[400],
                      size: 16,
                    ),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[50],
                    labelStyle: GoogleFonts.montserrat(color: Colors.grey[600]),
                    helperText: 'Automatically calculated as Target - Raised',
                    helperStyle: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.orange[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  style: GoogleFonts.montserrat(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                // Follow-ups
                TextFormField(
                  controller: followupsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Follow-ups',
                    border: const OutlineInputBorder(),
                    labelStyle: GoogleFonts.montserrat(),
                  ),
                ),
                const SizedBox(height: 12),

                // Notes
                TextFormField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    border: const OutlineInputBorder(),
                    labelStyle: GoogleFonts.montserrat(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Clean up listener
                raiseController.removeListener(calculatePendingAmount);
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final target = double.tryParse(targetController.text) ?? 0.0;
                final raised = double.tryParse(raiseController.text) ?? 0.0;
                final pending = target - raised;

                final updates = {
                  'target': target,
                  'raiseAmount': raised,
                  'pendingAmount': pending >= 0
                      ? pending
                      : 0.0, // Ensure non-negative
                  'followups': int.tryParse(followupsController.text) ?? 0,
                  'notes': notesController.text.trim(),
                };

                // Clean up listener
                raiseController.removeListener(calculatePendingAmount);
                Navigator.of(context).pop();
                await _updateAccount(accountId, updates);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gray800,
              ),
              child: const Text(
                'Update Account',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build progress indicator
  Widget _buildProgressIndicator(Map<String, dynamic> accountData) {
    final target = (accountData['target'] ?? 0.0).toDouble();
    final raised = (accountData['raiseAmount'] ?? 0.0).toDouble();
    final progress = target > 0 ? (raised / target).clamp(0.0, 1.0) : 0.0;
    final percentage = (progress * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            Text(
              '$percentage%',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                color: progress >= 1.0 ? Colors.green : Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            progress >= 1.0 ? Colors.green : Colors.blue,
          ),
        ),
      ],
    );
  }

  // Build summary card
  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 12,
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

  // Format number for display
  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    final numericValue = number is num
        ? number
        : (double.tryParse(number.toString()) ?? 0);
    if (numericValue >= 10000000) {
      return '${(numericValue / 10000000).toStringAsFixed(1)}Cr';
    } else if (numericValue >= 100000) {
      return '${(numericValue / 100000).toStringAsFixed(1)}L';
    } else if (numericValue >= 1000) {
      return '${(numericValue / 1000).toStringAsFixed(1)}K';
    }
    return numericValue.toStringAsFixed(0);
  }

  // Build stats cards
  Widget _buildStatsCards(List<QueryDocumentSnapshot> allAccounts) {
    final myAccounts = allAccounts.where((account) {
      final data = account.data() as Map<String, dynamic>;
      return data['userId'] == currentUser!.uid;
    }).length;

    final totalAccounts = allAccounts.length;

    double totalTarget = 0;
    double totalRaised = 0;
    double totalPending = 0;
    int totalFollowups = 0;

    for (var account in allAccounts) {
      final data = account.data() as Map<String, dynamic>;
      if (canManageAccounts || data['userId'] == currentUser!.uid) {
        totalTarget += (data['target'] ?? 0.0).toDouble();
        totalRaised += (data['raiseAmount'] ?? 0.0).toDouble();
        totalPending += (data['pendingAmount'] ?? 0.0).toDouble();
        totalFollowups += (data['followups'] ?? 0) as int;
      }
    }

    final uniqueUsers = canManageAccounts
        ? allAccounts
              .map((account) {
                final data = account.data() as Map<String, dynamic>;
                return data['userId'] ?? '';
              })
              .where((userId) => userId.isNotEmpty)
              .toSet()
              .length
        : 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  canManageAccounts ? 'Total' : 'My Accounts',
                  canManageAccounts
                      ? totalAccounts.toString()
                      : myAccounts.toString(),
                  Icons.account_balance,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Target',
                  '₹${_formatNumber(totalTarget)}',
                  Icons.flag,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Raised',
                  '₹${_formatNumber(totalRaised)}',
                  Icons.trending_up,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  canManageAccounts ? 'Users' : userRole,
                  canManageAccounts ? uniqueUsers.toString() : '👤',
                  canManageAccounts ? Icons.group : Icons.person,
                  roleBadgeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  '₹${_formatNumber(totalPending)}',
                  Icons.pending,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Follow-ups',
                  totalFollowups.toString(),
                  Icons.phone,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Success Rate',
                  totalTarget > 0
                      ? '${((totalRaised / totalTarget) * 100).toInt()}%'
                      : '0%',
                  Icons.analytics,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey, size: 20),
                      const SizedBox(height: 4),
                      Text(
                        'View Only',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        'Mode',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          color: Colors.grey.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
            'View Accounts',
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
                'Please log in to view accounts',
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

    // Show loading screen while verifying passcode
    if (_isVerifyingPasscode || !_isPasscodeVerified) {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Text(
                'Accounts',
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
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'PROTECTED',
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.security, size: 64, color: Colors.blue[600]),
              ),
              const SizedBox(height: 24),
              Text(
                'Security Verification Required',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter passcode to access account details',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              if (_isVerifyingPasscode)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _showPasscodeVerification,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Enter Passcode'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Show main content only after passcode verification
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Accounts',
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
            const SizedBox(width: 4),
          ],
        ),
        backgroundColor: AppColors.gray800,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/'),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getAccountsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print('DEBUG: Stream error: ${snapshot.error}');
            setState(() {
              _hasQueryError = true;
              _errorMessage = snapshot.error.toString();
            });

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Query Error Detected',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'This is likely a Firebase index issue. Switching to fallback mode...',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _hasQueryError = true; // Force fallback mode
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Use Fallback Mode'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gray800,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          final allAccountsFromFirebase = snapshot.data?.docs ?? [];

          // Add debug logging
          _debugAccountData(allAccountsFromFirebase);

          // Filter accounts for employees client-side if using fallback query
          List<QueryDocumentSnapshot> allAccounts = allAccountsFromFirebase;
          if (!canManageAccounts &&
              (_hasQueryError || allAccountsFromFirebase.isNotEmpty)) {
            // Filter to show only current user's accounts
            allAccounts = allAccountsFromFirebase.where((account) {
              final data = account.data() as Map<String, dynamic>;
              return data['userId'] == currentUser!.uid;
            }).toList();
            print(
              'DEBUG: Filtered ${allAccountsFromFirebase.length} accounts down to ${allAccounts.length} for current user',
            );
          }

          // Sort ALL accounts by year and month (client-side sorting to avoid any compound query issues)
          if (allAccounts.isNotEmpty) {
            print('DEBUG: Sorting ${allAccounts.length} accounts client-side');
            allAccounts.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aYear = (aData['year'] ?? 0) as int;
              final bYear = (bData['year'] ?? 0) as int;
              final aMonth =
                  int.tryParse(aData['month']?.toString() ?? '0') ?? 0;
              final bMonth =
                  int.tryParse(bData['month']?.toString() ?? '0') ?? 0;

              // Sort by year first (descending), then by month (descending)
              if (bYear != aYear) {
                return bYear.compareTo(aYear);
              }
              return bMonth.compareTo(aMonth);
            });
            print('DEBUG: Sorting completed');
          }

          // Apply filters
          List<QueryDocumentSnapshot> filteredAccounts = allAccounts.where((
            account,
          ) {
            final data = account.data() as Map<String, dynamic>;
            final month = data['month']?.toString() ?? '';
            final year = data['year']?.toString() ?? '';

            // Month filter
            if (_filterMonth != 'all' && month != _filterMonth) {
              return false;
            }

            // Year filter
            if (_filterYear != 'all' && year != _filterYear) {
              return false;
            }

            return true;
          }).toList();

          return Column(
            children: [
              // Security notice banner
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user,
                      color: Colors.green[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Secure Access: Account data is protected by passcode verification',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.lock_outline,
                        color: Colors.green[600],
                        size: 16,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasscodeVerified = false;
                        });
                        _showPasscodeVerification();
                      },
                      tooltip: 'Re-verify passcode',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),

              // Refresh button module
              _buildRefreshModule(),

              // Stats cards
              _buildStatsCards(allAccounts),

              // Debug info card (show if in fallback mode)
              if (_hasQueryError)
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
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.orange[600],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Running in fallback mode - all features work normally',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Active filters indicator
              if (_filterMonth != 'all' || _filterYear != 'all')
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
                          'Filters: ${_filterMonth != 'all' ? _monthNames[_monthFilters.indexOf(_filterMonth)] : ''} ${_filterYear != 'all' ? _filterYear : ''}'
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

              // Accounts list
              Expanded(
                child: filteredAccounts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No accounts found!',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              canManageAccounts
                                  ? 'No accounts found with current filters'
                                  : 'No accounts found for you',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '🔐 Passcode verified ✓',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _refreshAccounts,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Refresh'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      context.go('/create_accounts'),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create Account'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.gray800,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: filteredAccounts.length,
                        itemBuilder: (context, index) {
                          final account = filteredAccounts[index];
                          final data = account.data() as Map<String, dynamic>;
                          final accountId = account.id;
                          final monthName = data['monthName'] ?? 'Unknown';
                          final year = data['year']?.toString() ?? '';
                          final target = (data['target'] ?? 0.0).toDouble();
                          final raised = (data['raiseAmount'] ?? 0.0)
                              .toDouble();
                          final pending = (data['pendingAmount'] ?? 0.0)
                              .toDouble();
                          final followups = (data['followups'] ?? 0) as int;
                          final userName = data['userName'] ?? 'Unknown';
                          final userRole = data['userRole'] ?? 'User';
                          final isMyAccount =
                              data['userId'] == currentUser?.uid;

                          final progress = target > 0.0
                              ? (raised / target).clamp(0.0, 1.0)
                              : 0.0;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () =>
                                  _showAccountDetailsDialog(data, accountId),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header row
                                    Row(
                                      children: [
                                        // Progress indicator
                                        Container(
                                          width: 4,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: progress >= 1.0
                                                ? Colors.green
                                                : (progress >= 0.7
                                                      ? Colors.blue
                                                      : Colors.orange),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Account info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      '$monthName $year',
                                                      style:
                                                          GoogleFonts.montserrat(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: AppColors
                                                                .gray800,
                                                          ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: progress >= 1.0
                                                          ? Colors.green[100]
                                                          : Colors.blue[100],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '${(progress * 100).toInt()}%',
                                                      style:
                                                          GoogleFonts.montserrat(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                progress >= 1.0
                                                                ? Colors
                                                                      .green[700]
                                                                : Colors
                                                                      .blue[700],
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
                                                    color: isMyAccount
                                                        ? Colors.green[600]
                                                        : Colors.blue[600],
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    isMyAccount
                                                        ? 'You ($userRole)'
                                                        : '$userName ($userRole)',
                                                    style:
                                                        GoogleFonts.montserrat(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: isMyAccount
                                                              ? Colors
                                                                    .green[600]
                                                              : Colors
                                                                    .blue[600],
                                                        ),
                                                  ),
                                                  if (isMyAccount) ...[
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
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 16),

                                    // Financial summary row
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildAccountStat(
                                            'Target',
                                            '₹${_formatNumber(target)}',
                                            Icons.flag,
                                            Colors.green,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildAccountStat(
                                            'Raised',
                                            '₹${_formatNumber(raised)}',
                                            Icons.trending_up,
                                            Colors.blue,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildAccountStat(
                                            'Pending',
                                            '₹${_formatNumber(pending)}',
                                            Icons.pending,
                                            Colors.orange,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildAccountStat(
                                            'Calls',
                                            followups.toString(),
                                            Icons.phone,
                                            Colors.purple,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    // Progress bar
                                    LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: Colors.grey[300],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        progress >= 1.0
                                            ? Colors.green
                                            : (progress >= 0.7
                                                  ? Colors.blue
                                                  : Colors.orange),
                                      ),
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
        onPressed: () => context.go('/create_accounts'),
        backgroundColor: AppColors.gray800,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Create Account (Requires Passcode)',
      ),
    );
  }

  Widget _buildAccountStat(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 10,
            color: color.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
