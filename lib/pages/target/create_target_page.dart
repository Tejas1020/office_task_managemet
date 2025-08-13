// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:go_router/go_router.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:office_task_managemet/utils/colors.dart';

// class CreateTargetPage extends StatefulWidget {
//   const CreateTargetPage({Key? key}) : super(key: key);

//   @override
//   State<CreateTargetPage> createState() => _CreateTargetPageState();
// }

// class _CreateTargetPageState extends State<CreateTargetPage> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _targetNameController = TextEditingController();
//   final TextEditingController _targetValueController = TextEditingController();

//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   bool _isLoading = false;
//   bool _isLoadingAssignees = false;
//   String _assignmentType = 'individual';
//   String _targetType = 'Revenue';
//   String? _selectedAssignee;
//   DateTime _startDate = DateTime.now();
//   DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

//   List<Map<String, dynamic>> _employees = [];
//   List<Map<String, dynamic>> _teams = [];

//   final List<String> _targetTypes = [
//     'Revenue',
//     'Bookings',
//     'EOI',
//     'Agreement Value',
//     'Invoice',
//   ];

//   final Map<String, IconData> _targetTypeIcons = {
//     'Revenue': Icons.currency_rupee,
//     'Bookings': Icons.book_online,
//     'EOI': Icons.contact_mail,
//     'Agreement Value': Icons.handshake,
//     'Invoice': Icons.receipt_long,
//   };

//   final Map<String, Color> _targetTypeColors = {
//     'Revenue': Colors.green,
//     'Bookings': Colors.blue,
//     'EOI': Colors.orange,
//     'Agreement Value': Colors.purple,
//     'Invoice': Colors.teal,
//   };

//   User? get currentUser => _auth.currentUser;

//   @override
//   void initState() {
//     super.initState();
//     _loadEmployees();
//     _loadTeams();
//   }

//   // Load users with @gmail.com emails from Firebase
//   Future<void> _loadEmployees() async {
//     setState(() {
//       _isLoadingAssignees = true;
//     });

//     try {
//       // Get all users from the users collection
//       final querySnapshot = await _firestore.collection('users').get();

//       // Filter users with @gmail.com emails
//       final gmailUsers = querySnapshot.docs
//           .where((doc) {
//             final data = doc.data();
//             final email = data['email'] ?? '';
//             return email.toLowerCase().endsWith('@gmail.com');
//           })
//           .map((doc) {
//             final data = doc.data();
//             return {
//               'id': doc.id,
//               'name':
//                   data['name'] ??
//                   data['displayName'] ??
//                   data['email']?.split('@')[0] ??
//                   'Unknown',
//               'email': data['email'] ?? '',
//               'department': data['department'] ?? 'General',
//               'role': data['role'] ?? 'User',
//             };
//           })
//           .toList();

//       // If no Gmail users found, add some dummy data for testing
//       if (gmailUsers.isEmpty) {
//         gmailUsers.addAll([
//           {
//             'id': '1',
//             'name': 'John Doe',
//             'email': 'john.doe@gmail.com',
//             'department': 'Sales',
//             'role': 'Employee',
//           },
//           {
//             'id': '2',
//             'name': 'Jane Smith',
//             'email': 'jane.smith@gmail.com',
//             'department': 'Marketing',
//             'role': 'Manager',
//           },
//           {
//             'id': '3',
//             'name': 'Mike Johnson',
//             'email': 'mike.johnson@gmail.com',
//             'department': 'Development',
//             'role': 'Developer',
//           },
//           {
//             'id': '4',
//             'name': 'Sarah Wilson',
//             'email': 'sarah.wilson@gmail.com',
//             'department': 'HR',
//             'role': 'HR Specialist',
//           },
//           {
//             'id': '5',
//             'name': 'David Brown',
//             'email': 'david.brown@gmail.com',
//             'department': 'Finance',
//             'role': 'Analyst',
//           },
//           {
//             'id': '6',
//             'name': 'Lisa Garcia',
//             'email': 'lisa.garcia@gmail.com',
//             'department': 'Operations',
//             'role': 'Coordinator',
//           },
//           {
//             'id': '7',
//             'name': 'Tom Anderson',
//             'email': 'tom.anderson@gmail.com',
//             'department': 'Support',
//             'role': 'Support Agent',
//           },
//           {
//             'id': '8',
//             'name': 'Amy Chen',
//             'email': 'amy.chen@gmail.com',
//             'department': 'Design',
//             'role': 'Designer',
//           },
//         ]);
//       }

//       // Sort by name for better UX
//       gmailUsers.sort((a, b) => a['name'].compareTo(b['name']));

//       setState(() {
//         _employees = gmailUsers;
//       });

//       print('Loaded ${gmailUsers.length} Gmail users');
//     } catch (e) {
//       print('Error loading Gmail users: $e');
//       // Fallback to dummy Gmail users
//       setState(() {
//         _employees = [
//           {
//             'id': '1',
//             'name': 'John Doe',
//             'email': 'john.doe@gmail.com',
//             'department': 'Sales',
//             'role': 'Employee',
//           },
//           {
//             'id': '2',
//             'name': 'Jane Smith',
//             'email': 'jane.smith@gmail.com',
//             'department': 'Marketing',
//             'role': 'Manager',
//           },
//           {
//             'id': '3',
//             'name': 'Mike Johnson',
//             'email': 'mike.johnson@gmail.com',
//             'department': 'Development',
//             'role': 'Developer',
//           },
//           {
//             'id': '4',
//             'name': 'Sarah Wilson',
//             'email': 'sarah.wilson@gmail.com',
//             'department': 'HR',
//             'role': 'HR Specialist',
//           },
//           {
//             'id': '5',
//             'name': 'David Brown',
//             'email': 'david.brown@gmail.com',
//             'department': 'Finance',
//             'role': 'Analyst',
//           },
//           {
//             'id': '6',
//             'name': 'Lisa Garcia',
//             'email': 'lisa.garcia@gmail.com',
//             'department': 'Operations',
//             'role': 'Coordinator',
//           },
//           {
//             'id': '7',
//             'name': 'Tom Anderson',
//             'email': 'tom.anderson@gmail.com',
//             'department': 'Support',
//             'role': 'Support Agent',
//           },
//           {
//             'id': '8',
//             'name': 'Amy Chen',
//             'email': 'amy.chen@gmail.com',
//             'department': 'Design',
//             'role': 'Designer',
//           },
//         ];
//       });
//     } finally {
//       setState(() {
//         _isLoadingAssignees = false;
//       });
//     }
//   }

//   // Load teams from Firebase
//   Future<void> _loadTeams() async {
//     try {
//       final querySnapshot = await _firestore.collection('teams').get();

//       final teams = querySnapshot.docs.map((doc) {
//         final data = doc.data();
//         return {
//           'id': doc.id,
//           'name': data['name'] ?? 'Unknown Team',
//           'description': data['description'] ?? '',
//           'memberCount': data['memberCount'] ?? 0,
//           'department': data['department'] ?? 'General',
//         };
//       }).toList();

//       if (teams.isEmpty) {
//         teams.addAll([
//           {
//             'id': '1',
//             'name': 'Sales Team',
//             'description': 'Handle all sales activities',
//             'memberCount': 8,
//             'department': 'Sales',
//           },
//           {
//             'id': '2',
//             'name': 'Marketing Team',
//             'description': 'Digital marketing and campaigns',
//             'memberCount': 5,
//             'department': 'Marketing',
//           },
//           {
//             'id': '3',
//             'name': 'Development Team',
//             'description': 'Software development',
//             'memberCount': 12,
//             'department': 'Tech',
//           },
//           {
//             'id': '4',
//             'name': 'Customer Support',
//             'description': 'Customer service and support',
//             'memberCount': 6,
//             'department': 'Support',
//           },
//           {
//             'id': '5',
//             'name': 'Finance Team',
//             'description': 'Financial operations',
//             'memberCount': 4,
//             'department': 'Finance',
//           },
//         ]);
//       }

//       setState(() {
//         _teams = teams;
//       });
//     } catch (e) {
//       print('Error loading teams: $e');
//       setState(() {
//         _teams = [
//           {
//             'id': '1',
//             'name': 'Sales Team',
//             'description': 'Handle all sales activities',
//             'memberCount': 8,
//             'department': 'Sales',
//           },
//           {
//             'id': '2',
//             'name': 'Marketing Team',
//             'description': 'Digital marketing and campaigns',
//             'memberCount': 5,
//             'department': 'Marketing',
//           },
//           {
//             'id': '3',
//             'name': 'Development Team',
//             'description': 'Software development',
//             'memberCount': 12,
//             'department': 'Tech',
//           },
//           {
//             'id': '4',
//             'name': 'Customer Support',
//             'description': 'Customer service and support',
//             'memberCount': 6,
//             'department': 'Support',
//           },
//           {
//             'id': '5',
//             'name': 'Finance Team',
//             'description': 'Financial operations',
//             'memberCount': 4,
//             'department': 'Finance',
//           },
//         ];
//       });
//     }
//   }

//   // Create new target
//   Future<void> _createTarget() async {
//     if (!_formKey.currentState!.validate() ||
//         currentUser == null ||
//         _selectedAssignee == null) {
//       if (_selectedAssignee == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Please select an assignee'),
//             backgroundColor: Colors.orange,
//           ),
//         );
//       }
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       Map<String, dynamic>? assigneeDetails;
//       if (_assignmentType == 'individual') {
//         assigneeDetails = _employees.firstWhere(
//           (emp) => emp['name'] == _selectedAssignee,
//           orElse: () => {},
//         );
//       } else {
//         assigneeDetails = _teams.firstWhere(
//           (team) => team['name'] == _selectedAssignee,
//           orElse: () => {},
//         );
//       }

//       await _firestore.collection('targets').add({
//         'targetName': _targetNameController.text.trim(),
//         'assignmentType': _assignmentType,
//         'assignedToUserName': _assignmentType == 'individual'
//             ? _selectedAssignee
//             : null,
//         'assignedToTeamName': _assignmentType == 'team'
//             ? _selectedAssignee
//             : null,
//         'assignedToId': assigneeDetails['id'],
//         'assignedToDepartment': assigneeDetails['department'] ?? '',
//         'assignedToEmail': _assignmentType == 'individual'
//             ? assigneeDetails['email']
//             : null,
//         'teamMemberCount': _assignmentType == 'team'
//             ? assigneeDetails['memberCount']
//             : null,
//         'startDate': Timestamp.fromDate(_startDate),
//         'dueDate': Timestamp.fromDate(_dueDate),
//         'targetType': _targetType,
//         'targetValue': double.parse(_targetValueController.text.trim()),
//         'currency': 'INR',
//         'status': 'active',
//         'createdBy': currentUser!.uid,
//         'createdByName':
//             currentUser!.displayName ??
//             currentUser!.email?.split('@')[0] ??
//             'Unknown',
//         'createdByEmail': currentUser!.email,
//         'createdAt': FieldValue.serverTimestamp(),
//         'progress': 0.0,
//         'achievedValue': 0.0,
//       });

//       _targetNameController.clear();
//       _targetValueController.clear();
//       setState(() {
//         _assignmentType = 'individual';
//         _targetType = 'Revenue';
//         _selectedAssignee = null;
//         _startDate = DateTime.now();
//         _dueDate = DateTime.now().add(const Duration(days: 30));
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Row(
//             children: [
//               const Icon(Icons.check_circle, color: Colors.white, size: 20),
//               const SizedBox(width: 8),
//               Text(
//                 'Target created successfully!',
//                 style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
//               ),
//             ],
//           ),
//           backgroundColor: Colors.green,
//           duration: const Duration(seconds: 3),
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error creating target: $e'),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 3),
//         ),
//       );
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   Future<void> _selectDate(bool isStartDate) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: isStartDate ? _startDate : _dueDate,
//       firstDate: DateTime(2020),
//       lastDate: DateTime(2030),
//       builder: (context, child) {
//         return Theme(
//           data: Theme.of(context).copyWith(
//             colorScheme: ColorScheme.light(
//               primary: AppColors.gray800,
//               onPrimary: Colors.white,
//               surface: Colors.white,
//               onSurface: Colors.black,
//             ),
//           ),
//           child: child!,
//         );
//       },
//     );

//     if (picked != null) {
//       setState(() {
//         if (isStartDate) {
//           _startDate = picked;
//           if (_dueDate.isBefore(_startDate)) {
//             _dueDate = _startDate.add(const Duration(days: 1));
//           }
//         } else {
//           _dueDate = picked;
//         }
//       });
//     }
//   }

//   String _formatCurrency(String value) {
//     if (value.isEmpty) return '₹0';
//     final number = double.tryParse(value.replaceAll(',', '')) ?? 0;
//     return '₹${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (currentUser == null) {
//       return Scaffold(
//         appBar: AppBar(
//           title: Text(
//             'Create Target',
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
//                 'Please log in to create targets',
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
//         title: Text(
//           'Create Target',
//           style: GoogleFonts.montserrat(
//             fontSize: 20,
//             fontWeight: FontWeight.w600,
//             color: Colors.white,
//           ),
//         ),
//         backgroundColor: AppColors.gray800,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => context.go('/'),
//         ),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(20),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Set New Target',
//                 style: GoogleFonts.montserrat(
//                   fontSize: 24,
//                   fontWeight: FontWeight.w700,
//                   color: AppColors.gray800,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 'Create measurable goals and track progress towards success',
//                 style: GoogleFonts.montserrat(
//                   fontSize: 16,
//                   color: Colors.grey[600],
//                 ),
//               ),
//               const SizedBox(height: 32),

//               // Target details card
//               Container(
//                 padding: const EdgeInsets.all(24),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(16),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.grey.withOpacity(0.1),
//                       blurRadius: 10,
//                       offset: const Offset(0, 4),
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Target Details',
//                       style: GoogleFonts.montserrat(
//                         fontSize: 18,
//                         fontWeight: FontWeight.w600,
//                         color: AppColors.gray800,
//                       ),
//                     ),
//                     const SizedBox(height: 20),

//                     TextFormField(
//                       controller: _targetNameController,
//                       decoration: InputDecoration(
//                         labelText: 'Target Name *',
//                         hintText: 'e.g., Q1 Sales Target',
//                         prefixIcon: const Icon(Icons.flag),
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
//                         filled: true,
//                         fillColor: Colors.grey[50],
//                       ),
//                       style: GoogleFonts.montserrat(),
//                       validator: (value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return 'Please enter target name';
//                         }
//                         return null;
//                       },
//                     ),

//                     const SizedBox(height: 16),

//                     DropdownButtonFormField<String>(
//                       value: _targetType,
//                       decoration: InputDecoration(
//                         labelText: 'Target Type',
//                         prefixIcon: Icon(_targetTypeIcons[_targetType]),
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
//                         filled: true,
//                         fillColor: Colors.grey[50],
//                       ),
//                       items: _targetTypes.map((type) {
//                         return DropdownMenuItem(
//                           value: type,
//                           child: Row(
//                             children: [
//                               Icon(
//                                 _targetTypeIcons[type],
//                                 size: 18,
//                                 color: _targetTypeColors[type],
//                               ),
//                               const SizedBox(width: 8),
//                               Text(type),
//                             ],
//                           ),
//                         );
//                       }).toList(),
//                       onChanged: (value) {
//                         setState(() {
//                           _targetType = value!;
//                         });
//                       },
//                     ),

//                     const SizedBox(height: 16),

//                     TextFormField(
//                       controller: _targetValueController,
//                       keyboardType: TextInputType.number,
//                       inputFormatters: [
//                         FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
//                       ],
//                       decoration: InputDecoration(
//                         labelText: 'Target Value (INR) *',
//                         hintText: '1000000',
//                         prefixIcon: const Icon(Icons.currency_rupee),
//                         suffix: Text(
//                           _targetValueController.text.isNotEmpty
//                               ? _formatCurrency(_targetValueController.text)
//                               : '',
//                           style: GoogleFonts.montserrat(
//                             fontSize: 12,
//                             color: Colors.green[600],
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
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
//                         filled: true,
//                         fillColor: Colors.grey[50],
//                       ),
//                       style: GoogleFonts.montserrat(),
//                       onChanged: (value) {
//                         setState(() {});
//                       },
//                       validator: (value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return 'Please enter target value';
//                         }
//                         if (double.tryParse(value) == null ||
//                             double.parse(value) <= 0) {
//                           return 'Please enter a valid amount';
//                         }
//                         return null;
//                       },
//                     ),
//                   ],
//                 ),
//               ),

//               const SizedBox(height: 24),

//               // Assignment card
//               Container(
//                 padding: const EdgeInsets.all(24),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(16),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.grey.withOpacity(0.1),
//                       blurRadius: 10,
//                       offset: const Offset(0, 4),
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Assignment',
//                       style: GoogleFonts.montserrat(
//                         fontSize: 18,
//                         fontWeight: FontWeight.w600,
//                         color: AppColors.gray800,
//                       ),
//                     ),
//                     const SizedBox(height: 20),

//                     Text(
//                       'Assign To',
//                       style: GoogleFonts.montserrat(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: Colors.grey[700],
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: RadioListTile<String>(
//                             title: Column(
//                               children: [
//                                 const Icon(Icons.person, size: 18),
//                                 const SizedBox(width: 8),
//                                 Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Text(
//                                       'Individual',
//                                       style: GoogleFonts.montserrat(
//                                         fontSize: 14,
//                                       ),
//                                     ),
//                                     Text(
//                                       'Gmail users only',
//                                       style: GoogleFonts.montserrat(
//                                         fontSize: 11,
//                                         color: Colors.green[600],
//                                         fontWeight: FontWeight.w500,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//                             value: 'individual',
//                             groupValue: _assignmentType,
//                             onChanged: (value) {
//                               setState(() {
//                                 _assignmentType = value!;
//                                 _selectedAssignee = null;
//                               });
//                             },
//                             activeColor: AppColors.gray800,
//                             contentPadding: EdgeInsets.zero,
//                           ),
//                         ),
//                         // Expanded(
//                         //   child: RadioListTile<String>(
//                         //     title: Row(
//                         //       children: [
//                         //         const Icon(Icons.group, size: 18),
//                         //         const SizedBox(width: 8),
//                         //         Text(
//                         //           'Team',
//                         //           style: GoogleFonts.montserrat(fontSize: 14),
//                         //         ),
//                         //       ],
//                         //     ),
//                         //     value: 'team',
//                         //     groupValue: _assignmentType,
//                         //     onChanged: (value) {
//                         //       setState(() {
//                         //         _assignmentType = value!;
//                         //         _selectedAssignee = null;
//                         //       });
//                         //     },
//                         //     activeColor: AppColors.gray800,
//                         //     contentPadding: EdgeInsets.zero,
//                         //   ),
//                         // ),
//                       ],
//                     ),

//                     const SizedBox(height: 16),

//                     _isLoadingAssignees
//                         ? Container(
//                             padding: const EdgeInsets.all(16),
//                             decoration: BoxDecoration(
//                               border: Border.all(color: Colors.grey[300]!),
//                               borderRadius: BorderRadius.circular(12),
//                               color: Colors.grey[50],
//                             ),
//                             child: Row(
//                               children: [
//                                 const SizedBox(
//                                   width: 16,
//                                   height: 16,
//                                   child: CircularProgressIndicator(
//                                     strokeWidth: 2,
//                                   ),
//                                 ),
//                                 const SizedBox(width: 12),
//                                 Text(
//                                   'Loading ${_assignmentType == 'individual' ? 'Gmail users' : 'teams'}...',
//                                   style: GoogleFonts.montserrat(
//                                     color: Colors.grey[600],
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           )
//                         : DropdownButtonFormField<String>(
//                             value: _selectedAssignee,
//                             decoration: InputDecoration(
//                               labelText: _assignmentType == 'individual'
//                                   ? 'Select Gmail User *'
//                                   : 'Select Team *',
//                               hintText: _assignmentType == 'individual'
//                                   ? 'Choose a Gmail user'
//                                   : 'Choose a team',
//                               prefixIcon: Icon(
//                                 _assignmentType == 'individual'
//                                     ? Icons.person
//                                     : Icons.group,
//                               ),
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                               focusedBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(12),
//                                 borderSide: BorderSide(
//                                   color: AppColors.gray800,
//                                   width: 2,
//                                 ),
//                               ),
//                               filled: true,
//                               fillColor: Colors.grey[50],
//                             ),
//                             items: _assignmentType == 'individual'
//                                 ? _employees.map((user) {
//                                     return DropdownMenuItem<String>(
//                                       value: user['name'],
//                                       child: Row(
//                                         children: [
//                                           CircleAvatar(
//                                             radius: 12,
//                                             backgroundColor: Colors.blue[100],
//                                             child: Text(
//                                               user['name'][0].toUpperCase(),
//                                               style: GoogleFonts.montserrat(
//                                                 fontSize: 12,
//                                                 fontWeight: FontWeight.w600,
//                                                 color: Colors.blue[700],
//                                               ),
//                                             ),
//                                           ),
//                                           const SizedBox(width: 12),
//                                           Expanded(
//                                             child: Column(
//                                               crossAxisAlignment:
//                                                   CrossAxisAlignment.start,
//                                               children: [
//                                                 Text(
//                                                   user['name'],
//                                                   style: GoogleFonts.montserrat(
//                                                     fontSize: 14,
//                                                     fontWeight: FontWeight.w500,
//                                                   ),
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     );
//                                   }).toList()
//                                 : _teams.map((team) {
//                                     return DropdownMenuItem<String>(
//                                       value: team['name'],
//                                       child: Row(
//                                         children: [
//                                           Container(
//                                             padding: const EdgeInsets.all(6),
//                                             decoration: BoxDecoration(
//                                               color: Colors.orange[100],
//                                               borderRadius:
//                                                   BorderRadius.circular(6),
//                                             ),
//                                             child: Icon(
//                                               Icons.group,
//                                               size: 16,
//                                               color: Colors.orange[700],
//                                             ),
//                                           ),
//                                           const SizedBox(width: 12),
//                                           Expanded(
//                                             child: Column(
//                                               crossAxisAlignment:
//                                                   CrossAxisAlignment.start,
//                                               children: [
//                                                 Text(
//                                                   team['name'],
//                                                   style: GoogleFonts.montserrat(
//                                                     fontSize: 14,
//                                                     fontWeight: FontWeight.w500,
//                                                   ),
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     );
//                                   }).toList(),
//                             onChanged: (value) {
//                               setState(() {
//                                 _selectedAssignee = value;
//                               });
//                             },
//                             validator: (value) {
//                               if (value == null || value.isEmpty) {
//                                 return 'Please select ${_assignmentType == 'individual' ? 'a Gmail user' : 'a team'}';
//                               }
//                               return null;
//                             },
//                             isExpanded: true,
//                             menuMaxHeight: 300,
//                           ),
//                   ],
//                 ),
//               ),

//               const SizedBox(height: 24),

//               // Timeline card
//               Container(
//                 padding: const EdgeInsets.all(24),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(16),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.grey.withOpacity(0.1),
//                       blurRadius: 10,
//                       offset: const Offset(0, 4),
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Timeline',
//                       style: GoogleFonts.montserrat(
//                         fontSize: 18,
//                         fontWeight: FontWeight.w600,
//                         color: AppColors.gray800,
//                       ),
//                     ),
//                     const SizedBox(height: 20),

//                     Row(
//                       children: [
//                         Expanded(
//                           child: InkWell(
//                             onTap: () => _selectDate(true),
//                             borderRadius: BorderRadius.circular(12),
//                             child: Container(
//                               padding: const EdgeInsets.all(16),
//                               decoration: BoxDecoration(
//                                 border: Border.all(color: Colors.grey[300]!),
//                                 borderRadius: BorderRadius.circular(12),
//                                 color: Colors.grey[50],
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Row(
//                                     children: [
//                                       Icon(
//                                         Icons.calendar_today,
//                                         size: 18,
//                                         color: Colors.grey[600],
//                                       ),
//                                       const SizedBox(width: 8),
//                                       Text(
//                                         'Start Date',
//                                         style: GoogleFonts.montserrat(
//                                           fontSize: 12,
//                                           color: Colors.grey[600],
//                                           fontWeight: FontWeight.w500,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Text(
//                                     '${_startDate.day}/${_startDate.month}/${_startDate.year}',
//                                     style: GoogleFonts.montserrat(
//                                       fontSize: 16,
//                                       fontWeight: FontWeight.w600,
//                                       color: AppColors.gray800,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),

//                         const SizedBox(width: 16),

//                         Expanded(
//                           child: InkWell(
//                             onTap: () => _selectDate(false),
//                             borderRadius: BorderRadius.circular(12),
//                             child: Container(
//                               padding: const EdgeInsets.all(16),
//                               decoration: BoxDecoration(
//                                 border: Border.all(color: Colors.grey[300]!),
//                                 borderRadius: BorderRadius.circular(12),
//                                 color: Colors.grey[50],
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Row(
//                                     children: [
//                                       Icon(
//                                         Icons.event,
//                                         size: 18,
//                                         color: Colors.red[600],
//                                       ),
//                                       const SizedBox(width: 8),
//                                       Text(
//                                         'Due Date',
//                                         style: GoogleFonts.montserrat(
//                                           fontSize: 12,
//                                           color: Colors.grey[600],
//                                           fontWeight: FontWeight.w500,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Text(
//                                     '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
//                                     style: GoogleFonts.montserrat(
//                                       fontSize: 16,
//                                       fontWeight: FontWeight.w600,
//                                       color: Colors.red[600],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),

//                     const SizedBox(height: 16),

//                     Container(
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: Colors.blue[50],
//                         borderRadius: BorderRadius.circular(8),
//                         border: Border.all(color: Colors.blue[200]!),
//                       ),
//                       child: Row(
//                         children: [
//                           Icon(
//                             Icons.schedule,
//                             color: Colors.blue[600],
//                             size: 18,
//                           ),
//                           const SizedBox(width: 8),
//                           Text(
//                             'Duration: ${_dueDate.difference(_startDate).inDays + 1} days',
//                             style: GoogleFonts.montserrat(
//                               fontSize: 14,
//                               color: Colors.blue[700],
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//               const SizedBox(height: 32),

//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: _isLoading ? null : _createTarget,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.gray800,
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     elevation: 2,
//                   ),
//                   child: _isLoading
//                       ? const SizedBox(
//                           height: 20,
//                           width: 20,
//                           child: CircularProgressIndicator(
//                             strokeWidth: 2,
//                             valueColor: AlwaysStoppedAnimation<Color>(
//                               Colors.white,
//                             ),
//                           ),
//                         )
//                       : Text(
//                           'Create Target',
//                           style: GoogleFonts.montserrat(
//                             fontSize: 16,
//                             fontWeight: FontWeight.w600,
//                             color: Colors.white,
//                           ),
//                         ),
//                 ),
//               ),

//               const SizedBox(height: 32),

//               Container(
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   color: Colors.green[50],
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: Colors.green[200]!),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Icon(
//                           Icons.lightbulb_outline,
//                           color: Colors.green[600],
//                           size: 20,
//                         ),
//                         const SizedBox(width: 8),
//                         Text(
//                           'Target Tips',
//                           style: GoogleFonts.montserrat(
//                             fontSize: 16,
//                             fontWeight: FontWeight.w600,
//                             color: Colors.green[800],
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 12),
//                     Text(
//                       '• Set SMART targets (Specific, Measurable, Achievable, Relevant, Time-bound)\n'
//                       '• Break large targets into smaller milestones\n'
//                       '• Regular progress tracking improves achievement rates\n'
//                       '• Assign targets to the right people or teams for success',
//                       style: GoogleFonts.montserrat(
//                         fontSize: 14,
//                         color: Colors.green[700],
//                         height: 1.5,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _targetNameController.dispose();
//     _targetValueController.dispose();
//     super.dispose();
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:office_task_managemet/utils/colors.dart';

class CreateTargetPage extends StatefulWidget {
  const CreateTargetPage({Key? key}) : super(key: key);

  @override
  State<CreateTargetPage> createState() => _CreateTargetPageState();
}

class _CreateTargetPageState extends State<CreateTargetPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _targetNameController = TextEditingController();
  final TextEditingController _targetValueController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isLoadingAssignees = false;
  String _assignmentType = 'individual';
  String _targetType = 'Revenue';
  String? _selectedAssignee;
  DateTime _startDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _teams = [];

  final List<String> _targetTypes = [
    'Revenue',
    'Bookings',
    'EOI',
    'Agreement Value',
    'Invoice',
  ];

  final Map<String, IconData> _targetTypeIcons = {
    'Revenue': Icons.currency_rupee,
    'Bookings': Icons.book_online,
    'EOI': Icons.contact_mail,
    'Agreement Value': Icons.handshake,
    'Invoice': Icons.receipt_long,
  };

  final Map<String, Color> _targetTypeColors = {
    'Revenue': Colors.green,
    'Bookings': Colors.blue,
    'EOI': Colors.orange,
    'Agreement Value': Colors.purple,
    'Invoice': Colors.teal,
  };

  User? get currentUser => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadTeams();
  }

  // Load all users from Firebase (not just Gmail users)
  Future<void> _loadEmployees() async {
    setState(() {
      _isLoadingAssignees = true;
    });

    try {
      // Get all users from the users collection
      final querySnapshot = await _firestore.collection('users').get();

      // Get all users (removed Gmail filter)
      final allUsers = querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name':
                  data['name'] ??
                  data['displayName'] ??
                  data['email']?.split('@')[0] ??
                  'Unknown',
              'email': data['email'] ?? '',
              'department': data['department'] ?? 'General',
              'role': data['role'] ?? 'User',
            };
          })
          .where(
            (user) => user['email'].toString().isNotEmpty,
          ) // Only filter out users without email
          .toList();

      // If no users found, add some dummy data for testing
      if (allUsers.isEmpty) {
        allUsers.addAll([
          {
            'id': '1',
            'name': 'John Doe',
            'email': 'john.doe@gmail.com',
            'department': 'Sales',
            'role': 'Employee',
          },
          {
            'id': '2',
            'name': 'Jane Smith',
            'email': 'jane.smith@manager.com',
            'department': 'Marketing',
            'role': 'Manager',
          },
          {
            'id': '3',
            'name': 'Mike Johnson',
            'email': 'mike.johnson@admin.com',
            'department': 'Development',
            'role': 'Developer',
          },
          {
            'id': '4',
            'name': 'Sarah Wilson',
            'email': 'sarah.wilson@gmail.com',
            'department': 'HR',
            'role': 'HR Specialist',
          },
          {
            'id': '5',
            'name': 'David Brown',
            'email': 'david.brown@employee.com',
            'department': 'Finance',
            'role': 'Analyst',
          },
          {
            'id': '6',
            'name': 'Lisa Garcia',
            'email': 'lisa.garcia@manager.com',
            'department': 'Operations',
            'role': 'Coordinator',
          },
          {
            'id': '7',
            'name': 'Tom Anderson',
            'email': 'tom.anderson@admin.com',
            'department': 'Support',
            'role': 'Support Agent',
          },
          {
            'id': '8',
            'name': 'Amy Chen',
            'email': 'amy.chen@gmail.com',
            'department': 'Design',
            'role': 'Designer',
          },
        ]);
      }

      // Sort by name for better UX
      allUsers.sort((a, b) => a['name'].compareTo(b['name']));

      setState(() {
        _employees = allUsers;
      });

      print('Loaded ${allUsers.length} users (all email domains)');
    } catch (e) {
      print('Error loading users: $e');
      // Fallback to dummy users with mixed email domains
      setState(() {
        _employees = [
          {
            'id': '1',
            'name': 'John Doe',
            'email': 'john.doe@gmail.com',
            'department': 'Sales',
            'role': 'Employee',
          },
          {
            'id': '2',
            'name': 'Jane Smith',
            'email': 'jane.smith@manager.com',
            'department': 'Marketing',
            'role': 'Manager',
          },
          {
            'id': '3',
            'name': 'Mike Johnson',
            'email': 'mike.johnson@admin.com',
            'department': 'Development',
            'role': 'Developer',
          },
          {
            'id': '4',
            'name': 'Sarah Wilson',
            'email': 'sarah.wilson@gmail.com',
            'department': 'HR',
            'role': 'HR Specialist',
          },
          {
            'id': '5',
            'name': 'David Brown',
            'email': 'david.brown@employee.com',
            'department': 'Finance',
            'role': 'Analyst',
          },
          {
            'id': '6',
            'name': 'Lisa Garcia',
            'email': 'lisa.garcia@manager.com',
            'department': 'Operations',
            'role': 'Coordinator',
          },
          {
            'id': '7',
            'name': 'Tom Anderson',
            'email': 'tom.anderson@admin.com',
            'department': 'Support',
            'role': 'Support Agent',
          },
          {
            'id': '8',
            'name': 'Amy Chen',
            'email': 'amy.chen@gmail.com',
            'department': 'Design',
            'role': 'Designer',
          },
        ];
      });
    } finally {
      setState(() {
        _isLoadingAssignees = false;
      });
    }
  }

  // Load teams from Firebase
  Future<void> _loadTeams() async {
    try {
      final querySnapshot = await _firestore.collection('teams').get();

      final teams = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Team',
          'description': data['description'] ?? '',
          'memberCount': data['memberCount'] ?? 0,
          'department': data['department'] ?? 'General',
        };
      }).toList();

      if (teams.isEmpty) {
        teams.addAll([
          {
            'id': '1',
            'name': 'Sales Team',
            'description': 'Handle all sales activities',
            'memberCount': 8,
            'department': 'Sales',
          },
          {
            'id': '2',
            'name': 'Marketing Team',
            'description': 'Digital marketing and campaigns',
            'memberCount': 5,
            'department': 'Marketing',
          },
          {
            'id': '3',
            'name': 'Development Team',
            'description': 'Software development',
            'memberCount': 12,
            'department': 'Tech',
          },
          {
            'id': '4',
            'name': 'Customer Support',
            'description': 'Customer service and support',
            'memberCount': 6,
            'department': 'Support',
          },
          {
            'id': '5',
            'name': 'Finance Team',
            'description': 'Financial operations',
            'memberCount': 4,
            'department': 'Finance',
          },
        ]);
      }

      setState(() {
        _teams = teams;
      });
    } catch (e) {
      print('Error loading teams: $e');
      setState(() {
        _teams = [
          {
            'id': '1',
            'name': 'Sales Team',
            'description': 'Handle all sales activities',
            'memberCount': 8,
            'department': 'Sales',
          },
          {
            'id': '2',
            'name': 'Marketing Team',
            'description': 'Digital marketing and campaigns',
            'memberCount': 5,
            'department': 'Marketing',
          },
          {
            'id': '3',
            'name': 'Development Team',
            'description': 'Software development',
            'memberCount': 12,
            'department': 'Tech',
          },
          {
            'id': '4',
            'name': 'Customer Support',
            'description': 'Customer service and support',
            'memberCount': 6,
            'department': 'Support',
          },
          {
            'id': '5',
            'name': 'Finance Team',
            'description': 'Financial operations',
            'memberCount': 4,
            'department': 'Finance',
          },
        ];
      });
    }
  }

  // Create new target
  Future<void> _createTarget() async {
    if (!_formKey.currentState!.validate() ||
        currentUser == null ||
        _selectedAssignee == null) {
      if (_selectedAssignee == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an assignee'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic>? assigneeDetails;
      if (_assignmentType == 'individual') {
        assigneeDetails = _employees.firstWhere(
          (emp) => emp['name'] == _selectedAssignee,
          orElse: () => {},
        );
      } else {
        assigneeDetails = _teams.firstWhere(
          (team) => team['name'] == _selectedAssignee,
          orElse: () => {},
        );
      }

      await _firestore.collection('targets').add({
        'targetName': _targetNameController.text.trim(),
        'assignmentType': _assignmentType,
        'assignedToUserName': _assignmentType == 'individual'
            ? _selectedAssignee
            : null,
        'assignedToTeamName': _assignmentType == 'team'
            ? _selectedAssignee
            : null,
        'assignedToId': assigneeDetails['id'],
        'assignedToDepartment': assigneeDetails['department'] ?? '',
        'assignedToEmail': _assignmentType == 'individual'
            ? assigneeDetails['email']
            : null,
        'teamMemberCount': _assignmentType == 'team'
            ? assigneeDetails['memberCount']
            : null,
        'startDate': Timestamp.fromDate(_startDate),
        'dueDate': Timestamp.fromDate(_dueDate),
        'targetType': _targetType,
        'targetValue': double.parse(_targetValueController.text.trim()),
        'currency': 'INR',
        'status': 'active',
        'createdBy': currentUser!.uid,
        'createdByName':
            currentUser!.displayName ??
            currentUser!.email?.split('@')[0] ??
            'Unknown',
        'createdByEmail': currentUser!.email,
        'createdAt': FieldValue.serverTimestamp(),
        'progress': 0.0,
        'achievedValue': 0.0,
      });

      _targetNameController.clear();
      _targetValueController.clear();
      setState(() {
        _assignmentType = 'individual';
        _targetType = 'Revenue';
        _selectedAssignee = null;
        _startDate = DateTime.now();
        _dueDate = DateTime.now().add(const Duration(days: 30));
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Target created successfully!',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating target: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.gray800,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_dueDate.isBefore(_startDate)) {
            _dueDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  String _formatCurrency(String value) {
    if (value.isEmpty) return '₹0';
    final number = double.tryParse(value.replaceAll(',', '')) ?? 0;
    return '₹${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  // Helper method to get user color based on email domain
  Color _getUserColor(String email) {
    final domain = _getEmailDomain(email);
    switch (domain) {
      case '@admin.com':
        return Colors.red;
      case '@manager.com':
        return Colors.orange;
      case '@gmail.com':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  // Helper method to get email domain
  String _getEmailDomain(String email) {
    if (email.contains('@')) {
      return '@${email.split('@')[1]}';
    }
    return '@unknown';
  }

  void _handleBackNavigation() {
    // Navigate to appropriate home page based on user role
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.toLowerCase() ?? '';

    if (email.endsWith('@admin.com')) {
      context.go('/admin');
    } else if (email.endsWith('@manager.com')) {
      context.go('/manager');
    } else {
      context.go('/employee');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Create Target',
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
                'Please log in to create targets',
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

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Create Target',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: AppColors.gray800,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _handleBackNavigation,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set New Target',
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create measurable goals and track progress towards success',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),

                // Target details card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Target Details',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray800,
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _targetNameController,
                        decoration: InputDecoration(
                          labelText: 'Target Name *',
                          hintText: 'e.g., Q1 Sales Target',
                          prefixIcon: const Icon(Icons.flag),
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
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        style: GoogleFonts.montserrat(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter target name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _targetType,
                        decoration: InputDecoration(
                          labelText: 'Target Type',
                          prefixIcon: Icon(_targetTypeIcons[_targetType]),
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
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        items: _targetTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Row(
                              children: [
                                Icon(
                                  _targetTypeIcons[type],
                                  size: 18,
                                  color: _targetTypeColors[type],
                                ),
                                const SizedBox(width: 8),
                                Text(type),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _targetType = value!;
                          });
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _targetValueController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Target Value (INR) *',
                          hintText: '1000000',
                          prefixIcon: const Icon(Icons.currency_rupee),
                          suffix: Text(
                            _targetValueController.text.isNotEmpty
                                ? _formatCurrency(_targetValueController.text)
                                : '',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: Colors.green[600],
                              fontWeight: FontWeight.w600,
                            ),
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
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        style: GoogleFonts.montserrat(),
                        onChanged: (value) {
                          setState(() {});
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter target value';
                          }
                          if (double.tryParse(value) == null ||
                              double.parse(value) <= 0) {
                            return 'Please enter a valid amount';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Assignment card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assignment',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray800,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'Assign To',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: Column(
                                children: [
                                  const Icon(Icons.person, size: 18),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Individual',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        'All users',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          color: Colors.blue[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              value: 'individual',
                              groupValue: _assignmentType,
                              onChanged: (value) {
                                setState(() {
                                  _assignmentType = value!;
                                  _selectedAssignee = null;
                                });
                              },
                              activeColor: AppColors.gray800,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          // Expanded(
                          //   child: RadioListTile<String>(
                          //     title: Row(
                          //       children: [
                          //         const Icon(Icons.group, size: 18),
                          //         const SizedBox(width: 8),
                          //         Text(
                          //           'Team',
                          //           style: GoogleFonts.montserrat(fontSize: 14),
                          //         ),
                          //       ],
                          //     ),
                          //     value: 'team',
                          //     groupValue: _assignmentType,
                          //     onChanged: (value) {
                          //       setState(() {
                          //         _assignmentType = value!;
                          //         _selectedAssignee = null;
                          //       });
                          //     },
                          //     activeColor: AppColors.gray800,
                          //     contentPadding: EdgeInsets.zero,
                          //   ),
                          // ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      _isLoadingAssignees
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey[50],
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Loading ${_assignmentType == 'individual' ? 'users' : 'teams'}...',
                                    style: GoogleFonts.montserrat(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedAssignee,
                              decoration: InputDecoration(
                                labelText: _assignmentType == 'individual'
                                    ? 'Select User *'
                                    : 'Select Team *',
                                hintText: _assignmentType == 'individual'
                                    ? 'Choose a user'
                                    : 'Choose a team',
                                prefixIcon: Icon(
                                  _assignmentType == 'individual'
                                      ? Icons.person
                                      : Icons.group,
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
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              items: _assignmentType == 'individual'
                                  ? _employees.map((user) {
                                      return DropdownMenuItem<String>(
                                        value: user['name'],
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: _getUserColor(
                                                user['email'],
                                              ),
                                              child: Text(
                                                user['name'][0].toUpperCase(),
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    user['name'],
                                                    style:
                                                        GoogleFonts.montserrat(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: _getUserColor(
                                                            user['email'],
                                                          ).withOpacity(0.2),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          _getEmailDomain(
                                                            user['email'],
                                                          ),
                                                          style: GoogleFonts.montserrat(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color:
                                                                _getUserColor(
                                                                  user['email'],
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          user['role'],
                                                          style:
                                                              GoogleFonts.montserrat(
                                                                fontSize: 11,
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList()
                                  : _teams.map((team) {
                                      return DropdownMenuItem<String>(
                                        value: team['name'],
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.orange[100],
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Icon(
                                                Icons.group,
                                                size: 16,
                                                color: Colors.orange[700],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    team['name'],
                                                    style:
                                                        GoogleFonts.montserrat(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedAssignee = value;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select ${_assignmentType == 'individual' ? 'a user' : 'a team'}';
                                }
                                return null;
                              },
                              isExpanded: true,
                              menuMaxHeight: 300,
                            ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Timeline card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Timeline',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray800,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(true),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey[50],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 18,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Start Date',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.gray800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(false),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey[50],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.event,
                                          size: 18,
                                          color: Colors.red[600],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Due Date',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

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
                              Icons.schedule,
                              color: Colors.blue[600],
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Duration: ${_dueDate.difference(_startDate).inDays + 1} days',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createTarget,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gray800,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Create Target',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: Colors.green[600],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Target Tips',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• Set SMART targets (Specific, Measurable, Achievable, Relevant, Time-bound)\n'
                        '• Break large targets into smaller milestones\n'
                        '• Regular progress tracking improves achievement rates\n'
                        '• Assign targets to the right people or teams for success',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: Colors.green[700],
                          height: 1.5,
                        ),
                      ),
                    ],
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
    _targetNameController.dispose();
    _targetValueController.dispose();
    super.dispose();
  }
}
