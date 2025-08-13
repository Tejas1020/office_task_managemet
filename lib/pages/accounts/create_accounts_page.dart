import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:office_task_managemet/utils/colors.dart';

class CreateAccountsPage extends StatefulWidget {
  const CreateAccountsPage({Key? key}) : super(key: key);

  @override
  State<CreateAccountsPage> createState() => _CreateAccountsPageState();
}

class _CreateAccountsPageState extends State<CreateAccountsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  // Form controllers
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _raiseAmountController = TextEditingController();
  final TextEditingController _pendingAmountController =
      TextEditingController();
  final TextEditingController _followupsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Display controllers for formatted values
  final TextEditingController _targetDisplayController =
      TextEditingController();
  final TextEditingController _raiseDisplayController = TextEditingController();

  // Selected values
  String _selectedMonth = DateTime.now().month.toString();
  int _selectedYear = DateTime.now().year;

  // Month names for display
  final List<Map<String, dynamic>> _months = [
    {'value': '1', 'name': 'January'},
    {'value': '2', 'name': 'February'},
    {'value': '3', 'name': 'March'},
    {'value': '4', 'name': 'April'},
    {'value': '5', 'name': 'May'},
    {'value': '6', 'name': 'June'},
    {'value': '7', 'name': 'July'},
    {'value': '8', 'name': 'August'},
    {'value': '9', 'name': 'September'},
    {'value': '10', 'name': 'October'},
    {'value': '11', 'name': 'November'},
    {'value': '12', 'name': 'December'},
  ];

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

  @override
  void initState() {
    super.initState();
    // Add listeners to automatically calculate pending amount and format money
    _targetController.addListener(_onTargetChanged);
    _raiseAmountController.addListener(_onRaiseChanged);
  }

  @override
  void dispose() {
    _targetController.removeListener(_onTargetChanged);
    _raiseAmountController.removeListener(_onRaiseChanged);
    _targetController.dispose();
    _raiseAmountController.dispose();
    _targetDisplayController.dispose();
    _raiseDisplayController.dispose();
    _pendingAmountController.dispose();
    _followupsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Handle target amount changes
  void _onTargetChanged() {
    _formatMoneyDisplay(_targetController, _targetDisplayController);
    _calculatePendingAmount();
  }

  // Handle raise amount changes
  void _onRaiseChanged() {
    _formatMoneyDisplay(_raiseAmountController, _raiseDisplayController);
    _calculatePendingAmount();
  }

  // Format money display with commas
  void _formatMoneyDisplay(
    TextEditingController sourceController,
    TextEditingController displayController,
  ) {
    final value =
        double.tryParse(sourceController.text.replaceAll(',', '')) ?? 0.0;
    if (value > 0) {
      displayController.text = _formatNumberWithCommas(value);
    } else {
      displayController.text = '';
    }
  }

  // Format number with commas
  String _formatNumberWithCommas(double number) {
    if (number == 0) return '0';
    final formatter = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final intPart = number.toInt();
    return intPart.toString().replaceAll(formatter, ',');
  }

  // Calculate pending amount automatically
  void _calculatePendingAmount() {
    final target =
        double.tryParse(_targetController.text.replaceAll(',', '')) ?? 0.0;
    final raised =
        double.tryParse(_raiseAmountController.text.replaceAll(',', '')) ?? 0.0;
    final pending = target - raised;

    setState(() {
      // Update pending amount field
      if (pending >= 0) {
        _pendingAmountController.text = pending.toStringAsFixed(2);
      } else {
        _pendingAmountController.text = '0.00';
        // Show a brief message if raised exceeds target
        if (target > 0 && raised > target) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '🎉 Great! Raised amount exceeds target by ₹${_formatNumberWithCommas(raised - target)}',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          });
        }
      }
    });
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
                Icon(Icons.security, color: Colors.orange[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Security Verification',
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
                  'Enter passcode to create account:',
                  style: GoogleFonts.montserrat(color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                TextField(
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Passcode',
                    prefixIcon: Icon(Icons.lock, color: Colors.orange[600]),
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
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Verify',
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

  // Validate and create account with passcode
  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to create accounts'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show passcode dialog first
    final isPasscodeValid = await _showPasscodeDialog();

    if (!isPasscodeValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Invalid passcode! Account creation cancelled.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if account for this month/year already exists
      final existingAccount = await _firestore
          .collection('accounts')
          .where('userId', isEqualTo: currentUser!.uid)
          .where('month', isEqualTo: _selectedMonth)
          .where('year', isEqualTo: _selectedYear)
          .get();

      if (existingAccount.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Account for ${_months.firstWhere((m) => m['value'] == _selectedMonth)['name']} $_selectedYear already exists!',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final target =
          double.tryParse(_targetController.text.replaceAll(',', '')) ?? 0.0;
      final raised =
          double.tryParse(_raiseAmountController.text.replaceAll(',', '')) ??
          0.0;
      final pending = target - raised; // Calculate pending amount

      final accountData = {
        'userId': currentUser!.uid,
        'userName': displayName,
        'userEmail': currentUser!.email,
        'userRole': userRole,
        'month': _selectedMonth,
        'monthName': _months.firstWhere(
          (m) => m['value'] == _selectedMonth,
        )['name'],
        'year': _selectedYear,
        'target': target,
        'raiseAmount': raised,
        'pendingAmount': pending >= 0 ? pending : 0.0, // Ensure non-negative
        'followups': int.tryParse(_followupsController.text) ?? 0,
        'notes': _notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('accounts').add(accountData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Account for ${_months.firstWhere((m) => m['value'] == _selectedMonth)['name']} $_selectedYear created successfully!',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Clear form
      _targetController.clear();
      _raiseAmountController.clear();
      _targetDisplayController.clear();
      _raiseDisplayController.clear();
      _pendingAmountController.clear();
      _followupsController.clear();
      _notesController.clear();
      setState(() {
        _selectedMonth = DateTime.now().month.toString();
        _selectedYear = DateTime.now().year;
      });
      // Trigger pending amount calculation after clearing
      _calculatePendingAmount();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Reset form
  void _resetForm() {
    _formKey.currentState?.reset();
    _targetController.clear();
    _raiseAmountController.clear();
    _targetDisplayController.clear();
    _raiseDisplayController.clear();
    _pendingAmountController.clear();
    _followupsController.clear();
    _notesController.clear();
    setState(() {
      _selectedMonth = DateTime.now().month.toString();
      _selectedYear = DateTime.now().year;
    });
    // Trigger pending amount calculation (will show 0.00)
    _calculatePendingAmount();
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Create Account',
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
                'Please log in to create accounts',
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
              'Create Account',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.account_balance,
                              color: Colors.blue[600],
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'New Account Entry',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.gray800,
                                  ),
                                ),
                                Text(
                                  'Create a new account record for tracking',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: Colors.green[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Creating as: $displayName',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Month and Year Selection
              Text(
                'Period Selection',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray800,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  // Month Dropdown
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _selectedMonth,
                      decoration: InputDecoration(
                        labelText: 'Month',
                        prefixIcon: Icon(
                          Icons.calendar_month,
                          color: Colors.blue[600],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.gray800,
                            width: 2,
                          ),
                        ),
                        labelStyle: GoogleFonts.montserrat(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                      items: _months.map((month) {
                        return DropdownMenuItem<String>(
                          value: month['value'],
                          child: Text(
                            month['name'],
                            style: GoogleFonts.montserrat(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedMonth = value;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a month';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Year Dropdown
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      value: _selectedYear,
                      decoration: InputDecoration(
                        labelText: 'Year',
                        prefixIcon: Icon(
                          Icons.date_range,
                          color: Colors.blue[600],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.gray800,
                            width: 2,
                          ),
                        ),
                        labelStyle: GoogleFonts.montserrat(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                      ),
                      items: List.generate(5, (index) {
                        final year = DateTime.now().year - 2 + index;
                        return DropdownMenuItem<int>(
                          value: year,
                          child: Text(
                            year.toString(),
                            style: GoogleFonts.montserrat(fontSize: 14),
                          ),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedYear = value;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Select year';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Financial Details Section
              Text(
                'Financial Details',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray800,
                ),
              ),
              const SizedBox(height: 12),

              // Target Amount with Money Display
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _targetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Target Amount',
                      prefixIcon: Icon(Icons.flag, color: Colors.green[600]),
                      prefixText: '₹ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.gray800,
                          width: 2,
                        ),
                      ),
                      labelStyle: GoogleFonts.montserrat(),
                      helperText: 'Monthly target amount to achieve',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter target amount';
                      }
                      if (double.tryParse(value.replaceAll(',', '')) == null) {
                        return 'Please enter a valid number';
                      }
                      if (double.parse(value.replaceAll(',', '')) <= 0) {
                        return 'Target amount must be greater than 0';
                      }
                      return null;
                    },
                  ),
                  if (_targetDisplayController.text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(
                          width: 48,
                        ), // Align with text field content
                        Text(
                          '₹ ${_targetDisplayController.text}',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Raise Amount with Money Display
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _raiseAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Raise Amount',
                      prefixIcon: Icon(
                        Icons.trending_up,
                        color: Colors.blue[600],
                      ),
                      prefixText: '₹ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.gray800,
                          width: 2,
                        ),
                      ),
                      labelStyle: GoogleFonts.montserrat(),
                      helperText:
                          'Amount raised/achieved so far (can exceed target)',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter raise amount';
                      }
                      if (double.tryParse(value.replaceAll(',', '')) == null) {
                        return 'Please enter a valid number';
                      }
                      final raised = double.parse(value.replaceAll(',', ''));
                      if (raised < 0) {
                        return 'Raise amount cannot be negative';
                      }
                      // Optional warning if raised exceeds target (but don't prevent submission)
                      final target =
                          double.tryParse(
                            _targetController.text.replaceAll(',', ''),
                          ) ??
                          0.0;
                      if (target > 0 && raised > target) {
                        // This is actually good news, so we don't return an error
                        return null;
                      }
                      return null;
                    },
                  ),
                  if (_raiseDisplayController.text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(
                          width: 48,
                        ), // Align with text field content
                        Text(
                          '₹ ${_raiseDisplayController.text}',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Calculation Info Card with Real-time Values
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calculate,
                          color: Colors.blue[600],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Auto Calculation',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '₹${_targetDisplayController.text.isNotEmpty ? _targetDisplayController.text : (_targetController.text.isEmpty ? "0" : _targetController.text)}',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          ' - ',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '₹${_raiseDisplayController.text.isNotEmpty ? _raiseDisplayController.text : (_raiseAmountController.text.isEmpty ? "0" : _raiseAmountController.text)}',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          ' = ',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '₹${_pendingAmountController.text.isEmpty
                              ? "0.00"
                              : double.tryParse(_pendingAmountController.text) != null
                              ? _formatNumberWithCommas(double.parse(_pendingAmountController.text))
                              : _pendingAmountController.text}',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Target - Raised = Pending',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Pending Amount (Auto-calculated)
              TextFormField(
                controller: _pendingAmountController,
                keyboardType: TextInputType.number,
                readOnly: true, // Make it read-only
                decoration: InputDecoration(
                  labelText: 'Pending Amount (Auto-calculated)',
                  prefixIcon: Icon(Icons.calculate, color: Colors.grey[600]),
                  prefixText: '₹ ',
                  suffixIcon: Icon(
                    Icons.lock_outline,
                    color: Colors.grey[400],
                    size: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[400]!, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  labelStyle: GoogleFonts.montserrat(color: Colors.grey[600]),
                  helperText: 'Automatically calculated as Target - Raised',
                  helperStyle: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.blue[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                style: GoogleFonts.montserrat(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
                // Remove validation since it's auto-calculated
                validator: null,
              ),
              const SizedBox(height: 24),

              // Activity Details Section
              Text(
                'Activity Details',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray800,
                ),
              ),
              const SizedBox(height: 12),

              // Followups
              TextFormField(
                controller: _followupsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Follow-ups',
                  prefixIcon: Icon(Icons.phone, color: Colors.purple[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.gray800, width: 2),
                  ),
                  labelStyle: GoogleFonts.montserrat(),
                  helperText: 'Number of follow-up calls/meetings',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter number of follow-ups';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  if (int.parse(value) < 0) {
                    return 'Follow-ups cannot be negative';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Notes (Optional)
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  prefixIcon: Icon(Icons.notes, color: Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.gray800, width: 2),
                  ),
                  labelStyle: GoogleFonts.montserrat(),
                  helperText: 'Additional notes or comments',
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _resetForm,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _createAccount,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _isLoading ? 'Creating...' : 'Create Account',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gray800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:go_router/go_router.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:office_task_managemet/utils/colors.dart';

// class CreateAccountsPage extends StatefulWidget {
//   const CreateAccountsPage({Key? key}) : super(key: key);

//   @override
//   State<CreateAccountsPage> createState() => _CreateAccountsPageState();
// }

// class _CreateAccountsPageState extends State<CreateAccountsPage> {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final _formKey = GlobalKey<FormState>();

//   bool get isWeb => kIsWeb;
//   bool get isMobile => !kIsWeb;

//   bool _isScreenWide(BuildContext context) {
//     return MediaQuery.of(context).size.width > 800;
//   }

//   bool _isLoading = false;

//   // Form controllers
//   final TextEditingController _targetController = TextEditingController();
//   final TextEditingController _raiseAmountController = TextEditingController();
//   final TextEditingController _pendingAmountController =
//       TextEditingController();
//   final TextEditingController _followupsController = TextEditingController();
//   final TextEditingController _notesController = TextEditingController();

//   // Display controllers for formatted values
//   final TextEditingController _targetDisplayController =
//       TextEditingController();
//   final TextEditingController _raiseDisplayController = TextEditingController();

//   // Selected values
//   String _selectedMonth = DateTime.now().month.toString();
//   int _selectedYear = DateTime.now().year;

//   // Month names for display
//   final List<Map<String, dynamic>> _months = [
//     {'value': '1', 'name': 'January'},
//     {'value': '2', 'name': 'February'},
//     {'value': '3', 'name': 'March'},
//     {'value': '4', 'name': 'April'},
//     {'value': '5', 'name': 'May'},
//     {'value': '6', 'name': 'June'},
//     {'value': '7', 'name': 'July'},
//     {'value': '8', 'name': 'August'},
//     {'value': '9', 'name': 'September'},
//     {'value': '10', 'name': 'October'},
//     {'value': '11', 'name': 'November'},
//     {'value': '12', 'name': 'December'},
//   ];

//   User? get currentUser => _auth.currentUser;

//   // Check user roles
//   bool get isAdmin {
//     if (currentUser?.email == null) return false;
//     final email = currentUser!.email!.toLowerCase();
//     return email.endsWith('@admin.com');
//   }

//   bool get isManager {
//     if (currentUser?.email == null) return false;
//     final email = currentUser!.email!.toLowerCase();
//     return email.endsWith('@manager.com');
//   }

//   String get userRole {
//     if (isAdmin) return 'ADMIN';
//     if (isManager) return 'MANAGER';
//     return 'EMPLOYEE';
//   }

//   Color get roleBadgeColor {
//     if (isAdmin) return Colors.red[600]!;
//     if (isManager) return Colors.orange[600]!;
//     return Colors.blue[600]!;
//   }

//   String get displayName {
//     return currentUser?.displayName?.isNotEmpty == true
//         ? currentUser!.displayName!
//         : currentUser?.email?.split('@')[0] ?? 'User';
//   }

//   @override
//   void initState() {
//     super.initState();
//     // Add listeners to automatically calculate pending amount and format money
//     _targetController.addListener(_onTargetChanged);
//     _raiseAmountController.addListener(_onRaiseChanged);
//   }

//   @override
//   void dispose() {
//     _targetController.removeListener(_onTargetChanged);
//     _raiseAmountController.removeListener(_onRaiseChanged);
//     _targetController.dispose();
//     _raiseAmountController.dispose();
//     _targetDisplayController.dispose();
//     _raiseDisplayController.dispose();
//     _pendingAmountController.dispose();
//     _followupsController.dispose();
//     _notesController.dispose();
//     super.dispose();
//   }

//   // Handle target amount changes
//   void _onTargetChanged() {
//     _formatMoneyDisplay(_targetController, _targetDisplayController);
//     _calculatePendingAmount();
//   }

//   // Handle raise amount changes
//   void _onRaiseChanged() {
//     _formatMoneyDisplay(_raiseAmountController, _raiseDisplayController);
//     _calculatePendingAmount();
//   }

//   // Format money display with commas
//   void _formatMoneyDisplay(
//     TextEditingController sourceController,
//     TextEditingController displayController,
//   ) {
//     final value =
//         double.tryParse(sourceController.text.replaceAll(',', '')) ?? 0.0;
//     if (value > 0) {
//       displayController.text = _formatNumberWithCommas(value);
//     } else {
//       displayController.text = '';
//     }
//   }

//   // Format number with commas
//   String _formatNumberWithCommas(double number) {
//     if (number == 0) return '0';
//     final formatter = RegExp(r'\B(?=(\d{3})+(?!\d))');
//     final intPart = number.toInt();
//     return intPart.toString().replaceAll(formatter, ',');
//   }

//   // Calculate pending amount automatically
//   void _calculatePendingAmount() {
//     final target =
//         double.tryParse(_targetController.text.replaceAll(',', '')) ?? 0.0;
//     final raised =
//         double.tryParse(_raiseAmountController.text.replaceAll(',', '')) ?? 0.0;
//     final pending = target - raised;

//     setState(() {
//       // Update pending amount field
//       if (pending >= 0) {
//         _pendingAmountController.text = pending.toStringAsFixed(2);
//       } else {
//         _pendingAmountController.text = '0.00';
//         // Show a brief message if raised exceeds target
//         if (target > 0 && raised > target) {
//           Future.delayed(const Duration(milliseconds: 100), () {
//             if (mounted) {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(
//                   content: Text(
//                     '🎉 Great! Raised amount exceeds target by ₹${_formatNumberWithCommas(raised - target)}',
//                   ),
//                   backgroundColor: Colors.green,
//                   duration: const Duration(seconds: 2),
//                 ),
//               );
//             }
//           });
//         }
//       }
//     });
//   }

//   // Show passcode dialog
//   Future<bool> _showPasscodeDialog() async {
//     String enteredPasscode = '';

//     try {
//       final bool? result = await showDialog<bool>(
//         context: context,
//         barrierDismissible: false,
//         builder: (BuildContext dialogContext) => StatefulBuilder(
//           builder: (context, setState) => AlertDialog(
//             title: Row(
//               children: [
//                 Icon(Icons.security, color: Colors.orange[600]),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     'Security Verification',
//                     style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
//                   ),
//                 ),
//               ],
//             ),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Enter passcode to create account:',
//                   style: GoogleFonts.montserrat(color: Colors.grey[700]),
//                 ),
//                 const SizedBox(height: 12),
//                 TextField(
//                   keyboardType: TextInputType.number,
//                   obscureText: true,
//                   maxLength: 6,
//                   decoration: InputDecoration(
//                     labelText: 'Passcode',
//                     prefixIcon: Icon(Icons.lock, color: Colors.orange[600]),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     counterText: '',
//                     hintText: 'Enter 6-digit passcode',
//                   ),
//                   autofocus: true,
//                   onChanged: (value) {
//                     enteredPasscode = value.trim();
//                   },
//                   onSubmitted: (value) {
//                     enteredPasscode = value.trim();
//                     Navigator.of(
//                       dialogContext,
//                     ).pop(enteredPasscode == '147258');
//                   },
//                 ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   Navigator.of(dialogContext).pop(false);
//                 },
//                 child: Text('Cancel', style: GoogleFonts.montserrat()),
//               ),
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.of(dialogContext).pop(enteredPasscode == '147258');
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.orange,
//                   foregroundColor: Colors.white,
//                 ),
//                 child: Text(
//                   'Verify',
//                   style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );

//       return result ?? false;
//     } catch (e) {
//       print('Passcode dialog error: $e');
//       return false;
//     }
//   }

//   // Validate and create account with passcode
//   Future<void> _createAccount() async {
//     if (!_formKey.currentState!.validate()) {
//       return;
//     }

//     if (currentUser == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please log in to create accounts'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }

//     // Show passcode dialog first
//     final isPasscodeValid = await _showPasscodeDialog();

//     if (!isPasscodeValid) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('❌ Invalid passcode! Account creation cancelled.'),
//           backgroundColor: Colors.red,
//           duration: Duration(seconds: 3),
//         ),
//       );
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       // Check if account for this month/year already exists
//       final existingAccount = await _firestore
//           .collection('accounts')
//           .where('userId', isEqualTo: currentUser!.uid)
//           .where('month', isEqualTo: _selectedMonth)
//           .where('year', isEqualTo: _selectedYear)
//           .get();

//       if (existingAccount.docs.isNotEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               'Account for ${_months.firstWhere((m) => m['value'] == _selectedMonth)['name']} $_selectedYear already exists!',
//             ),
//             backgroundColor: Colors.orange,
//           ),
//         );
//         setState(() {
//           _isLoading = false;
//         });
//         return;
//       }

//       final target =
//           double.tryParse(_targetController.text.replaceAll(',', '')) ?? 0.0;
//       final raised =
//           double.tryParse(_raiseAmountController.text.replaceAll(',', '')) ??
//           0.0;
//       final pending = target - raised; // Calculate pending amount

//       final accountData = {
//         'userId': currentUser!.uid,
//         'userName': displayName,
//         'userEmail': currentUser!.email,
//         'userRole': userRole,
//         'month': _selectedMonth,
//         'monthName': _months.firstWhere(
//           (m) => m['value'] == _selectedMonth,
//         )['name'],
//         'year': _selectedYear,
//         'target': target,
//         'raiseAmount': raised,
//         'pendingAmount': pending >= 0 ? pending : 0.0, // Ensure non-negative
//         'followups': int.tryParse(_followupsController.text) ?? 0,
//         'notes': _notesController.text.trim(),
//         'createdAt': FieldValue.serverTimestamp(),
//         'updatedAt': FieldValue.serverTimestamp(),
//       };

//       await _firestore.collection('accounts').add(accountData);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             '✅ Account for ${_months.firstWhere((m) => m['value'] == _selectedMonth)['name']} $_selectedYear created successfully!',
//           ),
//           backgroundColor: Colors.green,
//           duration: const Duration(seconds: 3),
//         ),
//       );

//       // Clear form
//       _targetController.clear();
//       _raiseAmountController.clear();
//       _targetDisplayController.clear();
//       _raiseDisplayController.clear();
//       _pendingAmountController.clear();
//       _followupsController.clear();
//       _notesController.clear();
//       setState(() {
//         _selectedMonth = DateTime.now().month.toString();
//         _selectedYear = DateTime.now().year;
//       });
//       // Trigger pending amount calculation after clearing
//       _calculatePendingAmount();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error creating account: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   // Reset form
//   void _resetForm() {
//     _formKey.currentState?.reset();
//     _targetController.clear();
//     _raiseAmountController.clear();
//     _targetDisplayController.clear();
//     _raiseDisplayController.clear();
//     _pendingAmountController.clear();
//     _followupsController.clear();
//     _notesController.clear();
//     setState(() {
//       _selectedMonth = DateTime.now().month.toString();
//       _selectedYear = DateTime.now().year;
//     });
//     // Trigger pending amount calculation (will show 0.00)
//     _calculatePendingAmount();
//   }

//   // Build sidebar item for web layout
//   Widget _buildSidebarItem(IconData icon, String title, String route) {
//     final currentRoute = GoRouterState.of(context).uri.toString();
//     final isActive = currentRoute == route;
    
//     return InkWell(
//       onTap: () => context.go(route),
//       child: Container(
//         margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         decoration: BoxDecoration(
//           color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
//           borderRadius: BorderRadius.circular(8),
//         ),
//         child: Row(
//           children: [
//             Icon(
//               icon,
//               color: isActive ? Colors.white : Colors.white70,
//               size: 20,
//             ),
//             const SizedBox(width: 12),
//             Text(
//               title,
//               style: TextStyle(
//                 color: isActive ? Colors.white : Colors.white70,
//                 fontSize: 14,
//                 fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   String _getHomeRoute() {
//     if (isAdmin) return '/admin';
//     if (isManager) return '/manager';
//     return '/employee';
//   }

//   @override
//   Widget build(BuildContext context) {
//     return _isScreenWide(context) ? _buildWebLayout() : _buildMobileLayout();
//   }

//   Widget _buildMobileLayout() {
//     if (currentUser == null) {
//       return Scaffold(
//         appBar: AppBar(
//           title: Text(
//             'Create Account',
//             style: GoogleFonts.montserrat(
//               fontSize: 20,
//               fontWeight: FontWeight.w600,
//               color: Colors.white,
//             ),
//           ),
//           backgroundColor: AppColors.gray800,
//         ),
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(Icons.login, size: 64, color: Colors.grey[400]),
//               const SizedBox(height: 16),
//               Text(
//                 'Please log in to create accounts',
//                 style: GoogleFonts.montserrat(
//                   fontSize: 16,
//                   color: Colors.grey[600],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Row(
//           children: [
//             Text(
//               'Create Account',
//               style: GoogleFonts.montserrat(
//                 fontSize: 20,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.white,
//               ),
//             ),
//             const SizedBox(width: 8),
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//               decoration: BoxDecoration(
//                 color: roleBadgeColor,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Text(
//                 userRole,
//                 style: GoogleFonts.montserrat(
//                   fontSize: 10,
//                   fontWeight: FontWeight.w700,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//           ],
//         ),
//         backgroundColor: AppColors.gray800,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => context.go('/'),
//         ),
//       ),
//       body: _buildFormContent(),
//     );
//   }

//   Widget _buildWebLayout() {
//     if (currentUser == null) {
//       return _buildMobileLayout(); // Fallback to mobile layout for unauthenticated users
//     }

//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       body: Row(
//         children: [
//           // Sidebar for web
//           Container(
//             width: 280,
//             color: AppColors.gray800,
//             child: Column(
//               children: [
//                 // Header section
//                 Container(
//                   padding: const EdgeInsets.all(24),
//                   decoration: BoxDecoration(
//                     color: AppColors.gray800,
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.1),
//                         blurRadius: 4,
//                         offset: const Offset(0, 2),
//                       ),
//                     ],
//                   ),
//                   child: Row(
//                     children: [
//                       CircleAvatar(
//                         backgroundColor: roleBadgeColor,
//                         child: Icon(
//                           Icons.add_business,
//                           color: Colors.white,
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Text(
//                               'Create Account',
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             Text(
//                               '$userRole Portal',
//                               style: TextStyle(
//                                 color: Colors.white70,
//                                 fontSize: 14,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
                
//                 // Navigation menu
//                 Expanded(
//                   child: ListView(
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     children: [
//                       _buildSidebarItem(Icons.home_outlined, 'Home', _getHomeRoute()),
//                       _buildSidebarItem(Icons.account_balance, 'View Accounts', '/view_accounts'),
//                       _buildSidebarItem(Icons.add_business, 'Create Account', '/create_accounts'),
//                       _buildSidebarItem(Icons.analytics_outlined, 'Dashboard', '/target_dashboard'),
//                       const Divider(color: Colors.white24, height: 32),
//                       Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                         child: Text(
//                           'Form Actions',
//                           style: TextStyle(
//                             color: Colors.white54,
//                             fontSize: 12,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ),
//                       _buildSidebarItem(Icons.refresh, 'Reset Form', '/create_accounts'),
//                       _buildSidebarItem(Icons.save, 'Save Account', '/create_accounts'),
//                     ],
//                   ),
//                 ),

//                 // Form summary at bottom (web only)
//                 Container(
//                   margin: const EdgeInsets.all(16),
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Quick Summary',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 12,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Text(
//                         'User: $displayName',
//                         style: TextStyle(
//                           color: Colors.white70,
//                           fontSize: 11,
//                         ),
//                       ),
//                       Text(
//                         'Period: ${_months.firstWhere((m) => m['value'] == _selectedMonth)['name']} $_selectedYear',
//                         style: TextStyle(
//                           color: Colors.white70,
//                           fontSize: 11,
//                         ),
//                       ),
//                       if (_pendingAmountController.text.isNotEmpty)
//                         Text(
//                           'Pending: ₹${_pendingAmountController.text}',
//                           style: TextStyle(
//                             color: Colors.orange[300],
//                             fontSize: 11,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
          
//           // Main content area
//           Expanded(
//             child: Column(
//               children: [
//                 // Top bar for web
//                 Container(
//                   height: 60,
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.05),
//                         blurRadius: 4,
//                         offset: const Offset(0, 2),
//                       ),
//                     ],
//                   ),
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 24),
//                     child: Row(
//                       children: [
//                         Text(
//                           'Create New Account',
//                           style: TextStyle(
//                             fontSize: 24,
//                             fontWeight: FontWeight.bold,
//                             color: AppColors.gray800,
//                           ),
//                         ),
//                         const SizedBox(width: 16),
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                           decoration: BoxDecoration(
//                             color: Colors.orange[100],
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Icon(Icons.security, size: 14, color: Colors.orange[600]),
//                               const SizedBox(width: 4),
//                               Text(
//                                 'PASSCODE REQUIRED',
//                                 style: TextStyle(
//                                   fontSize: 10,
//                                   fontWeight: FontWeight.w700,
//                                   color: Colors.orange[700],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         const Spacer(),
//                         OutlinedButton.icon(
//                           onPressed: _isLoading ? null : _resetForm,
//                           icon: const Icon(Icons.refresh, size: 16),
//                           label: const Text('Reset'),
//                           style: OutlinedButton.styleFrom(
//                             side: BorderSide(color: Colors.grey[400]!),
//                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         ElevatedButton.icon(
//                           onPressed: _isLoading ? null : _createAccount,
//                           icon: _isLoading
//                               ? const SizedBox(
//                                   width: 16,
//                                   height: 16,
//                                   child: CircularProgressIndicator(
//                                     strokeWidth: 2,
//                                     valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                                   ),
//                                 )
//                               : const Icon(Icons.save, size: 16),
//                           label: Text(_isLoading ? 'Creating...' : 'Create Account'),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: AppColors.gray800,
//                             foregroundColor: Colors.white,
//                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
                
//                 // Main form content
//                 Expanded(
//                   child: _buildFormContent(),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFormContent() {
//     return SingleChildScrollView(
//       padding: EdgeInsets.all(_isScreenWide(context) ? 24 : 16),
//       child: Form(
//         key: _formKey,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Header Card (Only show on mobile or make it smaller on web)
//             if (!_isScreenWide(context))
//               Card(
//                 elevation: 2,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.all(20),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Container(
//                             padding: const EdgeInsets.all(12),
//                             decoration: BoxDecoration(
//                               color: Colors.blue[50],
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: Icon(
//                               Icons.account_balance,
//                               color: Colors.blue[600],
//                               size: 24,
//                             ),
//                           ),
//                           const SizedBox(width: 16),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   'New Account Entry',
//                                   style: GoogleFonts.montserrat(
//                                     fontSize: 20,
//                                     fontWeight: FontWeight.w700,
//                                     color: AppColors.gray800,
//                                   ),
//                                 ),
//                                 Text(
//                                   'Create a new account record for tracking',
//                                   style: GoogleFonts.montserrat(
//                                     fontSize: 14,
//                                     color: Colors.grey[600],
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 16),
//                       Container(
//                         padding: const EdgeInsets.all(12),
//                         decoration: BoxDecoration(
//                           color: Colors.green[50],
//                           borderRadius: BorderRadius.circular(8),
//                           border: Border.all(color: Colors.green[200]!),
//                         ),
//                         child: Row(
//                           children: [
//                             Icon(
//                               Icons.person,
//                               color: Colors.green[600],
//                               size: 20,
//                             ),
//                             const SizedBox(width: 8),
//                             Text(
//                               'Creating as: $displayName',
//                               style: GoogleFonts.montserrat(
//                                 fontWeight: FontWeight.w600,
//                                 color: Colors.green[700],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
            
//             // Add spacing based on layout
//             SizedBox(height: _isScreenWide(context) ? 16 : 24),

//             // Form content in a card for web, direct for mobile
//             Widget formContent = Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Period Selection
//                 Text(
//                   'Period Selection',
//                   style: GoogleFonts.montserrat(
//                     fontSize: 18,
//                     fontWeight: FontWeight.w600,
//                     color: AppColors.gray800,
//                   ),
//                 ),
//                 const SizedBox(height: 12),

//                 Row(
//                   children: [
//                     // Month Dropdown
//                     Expanded(
//                       flex: 3,
//                       child: DropdownButtonFormField<String>(
//                         value: _selectedMonth,
//                         decoration: InputDecoration(
//                           labelText: 'Month',
//                           prefixIcon: Icon(
//                             Icons.calendar_month,
//                             color: Colors.blue[600],
//                           ),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           focusedBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: BorderSide(
//                               color: AppColors.gray800,
//                               width: 2,
//                             ),
//                           ),
//                           labelStyle: GoogleFonts.montserrat(),
//                           contentPadding: const EdgeInsets.symmetric(
//                             horizontal: 12,
//                             vertical: 16,
//                           ),
//                         ),
//                         items: _months.map((month) {
//                           return DropdownMenuItem<String>(
//                             value: month['value'],
//                             child: Text(
//                               month['name'],
//                               style: GoogleFonts.montserrat(fontSize: 14),
//                             ),
//                           );
//                         }).toList(),
//                         onChanged: (value) {
//                           if (value != null) {
//                             setState(() {
//                               _selectedMonth = value;
//                             });
//                           }
//                         },
//                         validator: (value) {
//                           if (value == null || value.isEmpty) {
//                             return 'Please select a month';
//                           }
//                           return null;
//                         },
//                       ),
//                     ),
//                     const SizedBox(width: 12),

//                     // Year Dropdown
//                     Expanded(
//                       flex: 2,
//                       child: DropdownButtonFormField<int>(
//                         value: _selectedYear,
//                         decoration: InputDecoration(
//                           labelText: 'Year',
//                           prefixIcon: Icon(
//                             Icons.date_range,
//                             color: Colors.blue[600],
//                           ),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           focusedBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: BorderSide(
//                               color: AppColors.gray800,
//                               width: 2,
//                             ),
//                           ),
//                           labelStyle: GoogleFonts.montserrat(),
//                           contentPadding: const EdgeInsets.symmetric(
//                             horizontal: 8,
//                             vertical: 16,
//                           ),
//                         ),
//                         items: List.generate(5, (index) {
//                           final year = DateTime.now().year - 2 + index;
//                           return DropdownMenuItem<int>(
//                             value: year,
//                             child: Text(
//                               year.toString(),
//                               style: GoogleFonts.montserrat(fontSize: 14),
//                             ),
//                           );
//                         }),
//                         onChanged: (value) {
//                           if (value != null) {
//                             setState(() {
//                               _selectedYear = value;
//                             });
//                           }
//                         },
//                         validator: (value) {
//                           if (value == null) {
//                             return 'Select year';
//                           }
//                           return null;
//                         },
//                       ),
//                     ),
//                   ],
//                 ),

//                 const SizedBox(height: 24),

//                 // Financial Details Section
//                 Text(
//                   'Financial Details',
//                   style: GoogleFonts.montserrat(
//                     fontSize: 18,
//                     fontWeight: FontWeight.w600,
//                     color: AppColors.gray800,
//                   ),
//                 ),
//                 const SizedBox(height: 12),

//                 // Target Amount with Money Display
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     TextFormField(
//                       controller: _targetController,
//                       keyboardType: TextInputType.number,
//                       decoration: InputDecoration(
//                         labelText: 'Target Amount',
//                         prefixIcon: Icon(Icons.flag, color: Colors.green[600]),
//                         prefixText: '₹ ',
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           borderSide: BorderSide(
//                             color: AppColors.gray800,
//                             width: 2,
//                           ),
//                         ),
//                         labelStyle: GoogleFonts.montserrat(),
//                         helperText: 'Monthly target amount to achieve',
//                       ),
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return 'Please enter target amount';
//                         }
//                         if (double.tryParse(value.replaceAll(',', '')) == null) {
//                           return 'Please enter a valid number';
//                         }
//                         if (double.parse(value.replaceAll(',', '')) <= 0) {
//                           return 'Target amount must be greater than 0';
//                         }
//                         return null;
//                       },
//                     ),
//                     if (_targetDisplayController.text.isNotEmpty) ...[
//                       const SizedBox(height: 4),
//                       Row(
//                         children: [
//                           const SizedBox(
//                             width: 48,
//                           ), // Align with text field content
//                           Text(
//                             '₹ ${_targetDisplayController.text}',
//                             style: GoogleFonts.montserrat(
//                               fontSize: 12,
//                               color: Colors.green[600],
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ],
//                 ),
//                 const SizedBox(height: 16),

//                 // Raise Amount with Money Display
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     TextFormField(
//                       controller: _raiseAmountController,
//                       keyboardType: TextInputType.number,
//                       decoration: InputDecoration(
//                         labelText: 'Raise Amount',
//                         prefixIcon: Icon(
//                           Icons.trending_up,
//                           color: Colors.blue[600],
//                         ),
//                         prefixText: '₹ ',
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           borderSide: BorderSide(
//                             color: AppColors.gray800,
//                             width: 2,
//                           ),
//                         ),
//                         labelStyle: GoogleFonts.montserrat(),
//                         helperText:
//                             'Amount raised/achieved so far (can exceed target)',
//                       ),
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return 'Please enter raise amount';
//                         }
//                         if (double.tryParse(value.replaceAll(',', '')) == null) {
//                           return 'Please enter a valid number';
//                         }
//                         final raised = double.parse(value.replaceAll(',', ''));
//                         if (raised < 0) {
//                           return 'Raise amount cannot be negative';
//                         }
//                         // Optional warning if raised exceeds target (but don't prevent submission)
//                         final target =
//                             double.tryParse(
//                               _targetController.text.replaceAll(',', ''),
//                             ) ??
//                             0.0;
//                         if (target > 0 && raised > target) {
//                           // This is actually good news, so we don't return an error
//                           return null;
//                         }
//                         return null;
//                       },
//                     ),
//                     if (_raiseDisplayController.text.isNotEmpty) ...[
//                       const SizedBox(height: 4),
//                       Row(
//                         children: [
//                           const SizedBox(
//                             width: 48,
//                           ), // Align with text field content
//                           Text(
//                             '₹ ${_raiseDisplayController.text}',
//                             style: GoogleFonts.montserrat(
//                               fontSize: 12,
//                               color: Colors.green[600],
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ],
//                 ),
//                 const SizedBox(height: 16),

//                 // Calculation Info Card with Real-time Values
//                 Container(
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.blue[50],
//                     borderRadius: BorderRadius.circular(8),
//                     border: Border.all(color: Colors.blue[200]!),
//                   ),
//                   child: Column(
//                     children: [
//                       Row(
//                         children: [
//                           Icon(
//                             Icons.calculate,
//                             color: Colors.blue[600],
//                             size: 20,
//                           ),
//                           const SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               'Auto Calculation',
//                               style: GoogleFonts.montserrat(
//                                 fontSize: 13,
//                                 color: Colors.blue[700],
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 6),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Text(
//                             '₹${_targetDisplayController.text.isNotEmpty ? _targetDisplayController.text : (_targetController.text.isEmpty ? "0" : _targetController.text)}',
//                             style: GoogleFonts.montserrat(
//                               fontSize: 12,
//                               color: Colors.green[700],
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                           Text(
//                             ' - ',
//                             style: GoogleFonts.montserrat(
//                               fontSize: 12,
//                               color: Colors.grey[600],
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                           Text(
//                             '₹${_raiseDisplayController.text.isNotEmpty ? _raiseDisplayController.text : (_raiseAmountController.text.isEmpty ? "0" : _raiseAmountController.text)}',
//                             style: GoogleFonts.montserrat(
//                               fontSize: 12,
//                               color: Colors.blue[700],
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                           Text(
//                             ' = ',
//                             style: GoogleFonts.montserrat(
//                               fontSize: 12,
//                               color: Colors.grey[600],
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                           Text(
//                             '₹${_pendingAmountController.text.isEmpty
//                                 ? "0.00"
//                                 : double.tryParse(_pendingAmountController.text) != null
//                                 ? _formatNumberWithCommas(double.parse(_pendingAmountController.text))
//                                 : _pendingAmountController.text}',
//                             style: GoogleFonts.montserrat(
//                               fontSize: 12,
//                               color: Colors.orange[700],
//                               fontWeight: FontWeight.w700,
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         'Target - Raised = Pending',
//                         style: GoogleFonts.montserrat(
//                           fontSize: 10,
//                           color: Colors.grey[600],
//                           fontStyle: FontStyle.italic,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 12),

//                 // Pending Amount (Auto-calculated)
//                 TextFormField(
//                   controller: _pendingAmountController,
//                   keyboardType: TextInputType.number,
//                   readOnly: true, // Make it read-only
//                   decoration: InputDecoration(
//                     labelText: 'Pending Amount (Auto-calculated)',
//                     prefixIcon: Icon(Icons.calculate, color: Colors.grey[600]),
//                     prefixText: '₹ ',
//                     suffixIcon: Icon(
//                       Icons.lock_outline,
//                       color: Colors.grey[400],
//                       size: 16,
//                     ),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                       borderSide: BorderSide(color: Colors.grey[400]!, width: 2),
//                     ),
//                     filled: true,
//                     fillColor: Colors.grey[50],
//                     labelStyle: GoogleFonts.montserrat(color: Colors.grey[600]),
//                     helperText: 'Automatically calculated as Target - Raised',
//                     helperStyle: GoogleFonts.montserrat(
//                       fontSize: 12,
//                       color: Colors.blue[600],
//                       fontStyle: FontStyle.italic,
//                     ),
//                   ),
//                   style: GoogleFonts.montserrat(
//                     color: Colors.grey[700],
//                     fontWeight: FontWeight.w600,
//                   ),
//                   // Remove validation since it's auto-calculated
//                   validator: null,
//                 ),
//                 const SizedBox(height: 24),

//                 // Activity Details Section
//                 Text(
//                   'Activity Details',
//                   style: GoogleFonts.montserrat(
//                     fontSize: 18,
//                     fontWeight: FontWeight.w600,
//                     color: AppColors.gray800,
//                   ),
//                 ),
//                 const SizedBox(height: 12),

//                 // Followups
//                 TextFormField(
//                   controller: _followupsController,
//                   keyboardType: TextInputType.number,
//                   decoration: InputDecoration(
//                     labelText: 'Follow-ups',
//                     prefixIcon: Icon(Icons.phone, color: Colors.purple[600]),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                       borderSide: BorderSide(color: AppColors.gray800, width: 2),
//                     ),
//                     labelStyle: GoogleFonts.montserrat(),
//                     helperText: 'Number of follow-up calls/meetings',
//                   ),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter number of follow-ups';
//                     }
//                     if (int.tryParse(value) == null) {
//                       return 'Please enter a valid number';
//                     }
//                     if (int.parse(value) < 0) {
//                       return 'Follow-ups cannot be negative';
//                     }
//                     return null;
//                   },
//                 ),
//                 const SizedBox(height: 16),

//                 // Notes (Optional)
//                 TextFormField(
//                   controller: _notesController,
//                   maxLines: 4,
//                   decoration: InputDecoration(
//                     labelText: 'Notes (Optional)',
//                     prefixIcon: Icon(Icons.notes, color: Colors.grey[600]),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                       borderSide: BorderSide(color: AppColors.gray800, width: 2),
//                     ),
//                     labelStyle: GoogleFonts.montserrat(),
//                     helperText: 'Additional notes or comments',
//                   ),
//                 ),
//                 const SizedBox(height: 32),

//                 // Action Buttons (Only show on mobile - web has them in top bar)
//                 if (!_isScreenWide(context))
//                   Row(
//                     children: [
//                       Expanded(
//                         child: OutlinedButton.icon(
//                           onPressed: _isLoading ? null : _resetForm,
//                           icon: const Icon(Icons.refresh),
//                           label: const Text('Reset'),
//                           style: OutlinedButton.styleFrom(
//                             padding: const EdgeInsets.symmetric(vertical: 16),
//                             side: BorderSide(color: Colors.grey[400]!),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 16),
//                       Expanded(
//                         flex: 2,
//                         child: ElevatedButton.icon(
//                           onPressed: _isLoading ? null : _createAccount,
//                           icon: _isLoading
//                               ? const SizedBox(
//                                   width: 20,
//                                   height: 20,
//                                   child: CircularProgressIndicator(
//                                     strokeWidth: 2,
//                                     valueColor: AlwaysStoppedAnimation<Color>(
//                                       Colors.white,
//                                     ),
//                                   ),
//                                 )
//                               : const Icon(Icons.save),
//                           label: Text(
//                             _isLoading ? 'Creating...' : 'Create Account',
//                           ),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: AppColors.gray800,
//                             foregroundColor: Colors.white,
//                             padding: const EdgeInsets.symmetric(vertical: 16),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 const SizedBox(height: 20),
//               ],
          
//             );

//             // Wrap in card for web layout
//             if (_isScreenWide(context)) {
//               return Card(
//                 elevation: 2,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.all(24),
//                   child: formContent,
//                 ),
//               );
//             } else {
//               return formContent;
//             }
//           ],
//         ),
//       ),
//     );
//   }
// }