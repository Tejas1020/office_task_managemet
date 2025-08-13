
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:intl/intl.dart';
// import 'package:go_router/go_router.dart';
// import 'package:table_calendar/table_calendar.dart';
// import 'package:office_task_managemet/pages/attendance/attendance_model.dart';
// import 'package:office_task_managemet/pages/attendance/attendance_service.dart';

// class AttendancePage extends StatefulWidget {
//   const AttendancePage({Key? key}) : super(key: key);

//   @override
//   State<AttendancePage> createState() => _AttendancePageState();
// }

// class _AttendancePageState extends State<AttendancePage> {
//   GoogleMapController? mapController;
//   AttendanceRecord? todayAttendance;
//   bool isLoading = false;
//   bool isAdmin = false;
//   Set<Marker> markers = {};

//   // Calendar and Statistics variables
//   DateTime _focusedDay = DateTime.now();
//   DateTime? _selectedDay;
//   Map<DateTime, List<AttendanceRecord>> _attendanceEvents = {};
//   List<AttendanceRecord> _allAttendanceRecords = [];

//   // Statistics variables
//   DateTime _selectedMonth = DateTime.now();
//   Map<String, Map<String, dynamic>> _attendanceStats = {};

//   @override
//   void initState() {
//     super.initState();
//     isAdmin = AttendanceService.isAdmin();
//     _selectedDay = DateTime.now();
//     _loadTodayAttendance();
//     _loadAttendanceData();
//     if (isAdmin) {
//       _loadEmployeeLocations();
//     }
//   }

//   Future<void> _loadTodayAttendance() async {
//     if (!mounted) return;
    
//     setState(() => isLoading = true);
//     try {
//       final attendance = await AttendanceService.getTodayAttendance();
//       if (mounted) {
//         setState(() {
//           todayAttendance = attendance;
//           isLoading = false;
//         });
//       }
//     } catch (e) {
//       print('Error loading today attendance: $e');
//       if (mounted) {
//         setState(() => isLoading = false);
//         _showErrorSnackBar('Error loading attendance: $e');
//       }
//     }
//   }

//   Future<void> _loadAttendanceData() async {
//     try {
//       final startDate = DateTime.now().subtract(Duration(days: 90));
//       final endDate = DateTime.now().add(Duration(days: 30));

//       List<AttendanceRecord> records;
//       if (isAdmin) {
//         // Admin can see all records
//         records = await AttendanceService.getAttendanceByDateRange(
//           startDate,
//           endDate,
//         );
//       } else {
//         // Employee sees only their records
//         records = await AttendanceService.getAttendanceByDateRange(
//           startDate,
//           endDate,
//         );
//         final currentUser = FirebaseAuth.instance.currentUser;
//         records = records.where((r) => r.userId == currentUser?.uid).toList();
//       }

//       if (mounted) {
//         setState(() {
//           _allAttendanceRecords = records;
//           _attendanceEvents = _groupRecordsByDate(records);
//         });

//         // Calculate statistics for admin asynchronously
//         if (isAdmin) {
//           // Run statistics calculation asynchronously to prevent UI freeze
//           Future.microtask(() => _calculateAttendanceStatistics());
//         }
//       }
//     } catch (e) {
//       print('Error loading attendance data: $e');
//       // Don't rethrow - let the UI continue working even if data load fails
//     }
//   }

//   void _calculateAttendanceStatistics() {
//     try {
//       // Add safety check for empty records
//       if (_allAttendanceRecords.isEmpty) {
//         setState(() {
//           _attendanceStats = {};
//         });
//         return;
//       }

//       final stats = <String, Map<String, dynamic>>{};

//       // Get start and end of selected month
//       final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
//       final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
//       final workingDays = _getWorkingDaysInMonth(monthStart, monthEnd);

//       // Safety check for reasonable date range
//       if (workingDays <= 0 || workingDays > 31) {
//         print('Invalid working days calculation: $workingDays');
//         setState(() {
//           _attendanceStats = {};
//         });
//         return;
//       }

//       // Filter records for selected month with safety checks
//       final monthRecords = _allAttendanceRecords.where((record) {
//         try {
//           final recordDate = DateTime(
//             record.date.year,
//             record.date.month,
//             record.date.day,
//           );
//           return recordDate.isAfter(monthStart.subtract(Duration(days: 1))) &&
//               recordDate.isBefore(monthEnd.add(Duration(days: 1)));
//         } catch (e) {
//           print('Error processing record date: $e');
//           return false;
//         }
//       }).toList();

//       // Group by user
//       final userRecords = <String, List<AttendanceRecord>>{};
//       for (var record in monthRecords) {
//         try {
//           final userId = record.userId;
//           if (userId.isNotEmpty) {
//             if (!userRecords.containsKey(userId)) {
//               userRecords[userId] = [];
//             }
//             userRecords[userId]!.add(record);
//           }
//         } catch (e) {
//           print('Error processing user record: $e');
//           continue;
//         }
//       }

//       // Calculate stats for each user
//       userRecords.forEach((userId, records) {
//         try {
//           if (records.isEmpty) return;
          
//           final user = records.first; // Get user info from first record

//           final presentDays = <DateTime>{};
//           final lateDays = <DateTime>{};
//           double totalWorkingHours = 0.0;

//           for (var record in records) {
//             try {
//               final recordDate = DateTime(
//                 record.date.year,
//                 record.date.month,
//                 record.date.day,
//               );

//               if (record.status == 'punched_out' || record.status == 'punched_in') {
//                 presentDays.add(recordDate);

//                 // Check if late (after 9:30 AM)
//                 final punchInTime = record.punchInTime;
//                 final lateThreshold = DateTime(
//                   punchInTime.year,
//                   punchInTime.month,
//                   punchInTime.day,
//                   9,
//                   30,
//                 );
//                 if (punchInTime.isAfter(lateThreshold)) {
//                   lateDays.add(recordDate);
//                 }

//                 // Calculate working hours with safety check
//                 if (record.punchOutTime != null) {
//                   final workingDuration = record.punchOutTime!.difference(
//                     record.punchInTime,
//                   );
//                   final hours = workingDuration.inMinutes / 60.0;
//                   // Safety check for reasonable working hours (0-24 hours)
//                   if (hours >= 0 && hours <= 24) {
//                     totalWorkingHours += hours;
//                   }
//                 }
//               }
//             } catch (e) {
//               print('Error processing individual record: $e');
//               continue;
//             }
//           }

//           final presentCount = presentDays.length;
//           final absentCount = workingDays - presentCount;
//           final lateCount = lateDays.length;
//           final attendancePercentage = workingDays > 0
//               ? (presentCount / workingDays) * 100
//               : 0.0;

//           stats[userId] = {
//             'userName': user.userName ?? 'Unknown',
//             'userEmail': user.userEmail ?? 'Unknown',
//             'presentDays': presentCount,
//             'absentDays': absentCount >= 0 ? absentCount : 0,
//             'lateDays': lateCount,
//             'workingDays': workingDays,
//             'attendancePercentage': attendancePercentage.clamp(0.0, 100.0),
//             'totalWorkingHours': totalWorkingHours,
//             'averageWorkingHours': presentCount > 0
//                 ? totalWorkingHours / presentCount
//                 : 0.0,
//           };
//         } catch (e) {
//           print('Error calculating stats for user $userId: $e');
//         }
//       });

//       // Update UI on main thread
//       if (mounted) {
//         setState(() {
//           _attendanceStats = stats;
//         });
//       }
//     } catch (e) {
//       print('Error in _calculateAttendanceStatistics: $e');
//       // Set empty stats to prevent crash
//       if (mounted) {
//         setState(() {
//           _attendanceStats = {};
//         });
//       }
//     }
//   }

//   int _getWorkingDaysInMonth(DateTime start, DateTime end) {
//     try {
//       // Safety checks to prevent infinite loops
//       if (start.isAfter(end)) {
//         print('Error: Start date is after end date');
//         return 0;
//       }
      
//       final daysDifference = end.difference(start).inDays;
//       if (daysDifference > 31) {
//         print('Error: Date range too large: $daysDifference days');
//         return 0;
//       }

//       int workingDays = 0;
//       DateTime current = start;
      
//       // Limit iterations to prevent infinite loops
//       int iterations = 0;
//       const maxIterations = 32; // Safety limit
      
//       while (current.isBefore(end.add(Duration(days: 1))) && iterations < maxIterations) {
//         // Exclude weekends (Saturday = 6, Sunday = 7)
//         if (current.weekday != DateTime.saturday && current.weekday != DateTime.sunday) {
//           workingDays++;
//         }
//         current = current.add(Duration(days: 1));
//         iterations++;
//       }
      
//       if (iterations >= maxIterations) {
//         print('Warning: Working days calculation hit iteration limit');
//       }
      
//       return workingDays;
//     } catch (e) {
//       print('Error calculating working days: $e');
//       return 0;
//     }
//   }

//   Map<DateTime, List<AttendanceRecord>> _groupRecordsByDate(
//     List<AttendanceRecord> records,
//   ) {
//     Map<DateTime, List<AttendanceRecord>> events = {};
//     try {
//       for (var record in records) {
//         try {
//           final date = DateTime(
//             record.date.year,
//             record.date.month,
//             record.date.day,
//           );
//           if (events[date] != null) {
//             events[date]!.add(record);
//           } else {
//             events[date] = [record];
//           }
//         } catch (e) {
//           print('Error processing record date: $e');
//           continue;
//         }
//       }
//     } catch (e) {
//       print('Error grouping records by date: $e');
//     }
//     return events;
//   }

//   List<AttendanceRecord> _getEventsForDay(DateTime day) {
//     final normalizedDay = DateTime(day.year, day.month, day.day);
//     return _attendanceEvents[normalizedDay] ?? [];
//   }

//   Color _getDateColor(DateTime day) {
//     final events = _getEventsForDay(day);
//     if (events.isEmpty) return Colors.grey.shade300;

//     // Check if any employee was present
//     final hasPresent = events.any(
//       (e) => e.status == 'punched_out' || e.status == 'punched_in',
//     );
//     return hasPresent ? Colors.green.shade100 : Colors.red.shade100;
//   }

//   void _loadEmployeeLocations() {
//     AttendanceService.getEmployeeLocationsStream().listen((locations) {
//       setState(() {
//         markers = locations.map((emp) {
//           return Marker(
//             markerId: MarkerId(emp.userId),
//             position: LatLng(emp.location.latitude, emp.location.longitude),
//             infoWindow: InfoWindow(
//               title: emp.userName,
//               snippet: '${emp.status} - ${emp.location.address}',
//             ),
//             icon: emp.status == 'punched_in'
//                 ? BitmapDescriptor.defaultMarkerWithHue(
//                     BitmapDescriptor.hueGreen,
//                   )
//                 : BitmapDescriptor.defaultMarkerWithHue(
//                     BitmapDescriptor.hueRed,
//                   ),
//           );
//         }).toSet();
//       });
//     });
//   }

//   Future<void> _punchIn() async {
//     if (!mounted) return;
    
//     setState(() => isLoading = true);
//     try {
//       await AttendanceService.punchIn();
//       if (mounted) {
//         await _loadTodayAttendance();
//         await _loadAttendanceData();
//         if (mounted) {
//           setState(() => isLoading = false);
//           _showSuccessSnackBar('Punched in successfully!');
//         }
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() => isLoading = false);
//         _showErrorSnackBar(e.toString());
//       }
//     }
//   }

//   Future<void> _punchOut() async {
//     if (!mounted) return;
    
//     setState(() => isLoading = true);
//     try {
//       await AttendanceService.punchOut();
//       if (mounted) {
//         await _loadTodayAttendance();
//         await _loadAttendanceData();
//         if (mounted) {
//           setState(() => isLoading = false);
//           _showSuccessSnackBar('Punched out successfully!');
//         }
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() => isLoading = false);
//         _showErrorSnackBar(e.toString());
//       }
//     }
//   }

//   void _showSuccessSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             Icon(Icons.check_circle, color: Colors.white),
//             SizedBox(width: 12),
//             Text(message),
//           ],
//         ),
//         backgroundColor: Colors.green,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         duration: Duration(seconds: 3),
//       ),
//     );
//   }

//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             Icon(Icons.error, color: Colors.white),
//             SizedBox(width: 12),
//             Expanded(child: Text(message)),
//           ],
//         ),
//         backgroundColor: Colors.red,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         duration: Duration(seconds: 4),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return PopScope(
//       canPop: false, // Prevent default back behavior
//       onPopInvoked: (didPop) {
//         if (!didPop) {
//           // Handle back button press
//           _handleBackButton(context);
//         }
//       },
//       child: Scaffold(
//         backgroundColor: Colors.grey[50],
//         appBar: AppBar(
//           title: Text(
//             isAdmin ? 'Employee Tracking' : 'Attendance',
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//           ),
//           backgroundColor: Colors.indigo.shade600,
//           elevation: 0,
//           leading: IconButton(
//             icon: const Icon(Icons.arrow_back, color: Colors.white),
//             onPressed: () => _handleBackButton(context),
//           ),
//           actions: [
//             if (isAdmin)
//               IconButton(
//                 icon: Icon(Icons.analytics, color: Colors.white),
//                 onPressed: () => _showAttendanceRecords(),
//               ),
//           ],
//         ),
//         body: isAdmin ? _buildAdminView() : _buildEmployeeView(),
//       ),
//     );
//   }

//   void _handleBackButton(BuildContext context) {
//     // Determine the appropriate back navigation based on user role
//     final user = FirebaseAuth.instance.currentUser;
//     final email = user?.email?.toLowerCase() ?? '';

//     if (email.endsWith('@admin.com')) {
//       context.go('/admin');
//     } else if (email.endsWith('@manager.com')) {
//       context.go('/manager');
//     } else {
//       context.go('/employee');
//     }
//   }

//   Widget _buildEmployeeView() {
//     return SingleChildScrollView(
//       child: Column(
//         children: [
//           // Header with gradient background
//           Container(
//             width: double.infinity,
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [Colors.indigo.shade600, Colors.purple.shade400],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//             ),
//             child: SafeArea(
//               child: Padding(
//                 padding: EdgeInsets.all(20),
//                 child: Column(
//                   children: [
//                     // Status Card
//                     _buildModernStatusCard(),
//                     SizedBox(height: 20),
//                     // Punch Buttons
//                     _buildModernPunchButtons(),
//                   ],
//                 ),
//               ),
//             ),
//           ),

//           // Calendar Section
//           Container(
//             margin: EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(20),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.1),
//                   blurRadius: 20,
//                   offset: Offset(0, 5),
//                 ),
//               ],
//             ),
//             child: Column(
//               children: [
//                 Padding(
//                   padding: EdgeInsets.all(20),
//                   child: Row(
//                     children: [
//                       Icon(Icons.calendar_today, color: Colors.indigo.shade600),
//                       SizedBox(width: 12),
//                       Text(
//                         'Attendance Calendar',
//                         style: TextStyle(
//                           fontSize: 20,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.indigo.shade600,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 _buildBeautifulCalendar(),
//                 _buildCalendarLegend(),
//               ],
//             ),
//           ),

//           // Location Map (if punched in)
//           if (todayAttendance != null) _buildLocationCard(),

//           // Today's Details
//           if (todayAttendance != null) _buildTodayDetailsCard(),

//           SizedBox(height: 20),
//         ],
//       ),
//     );
//   }

//   Widget _buildModernStatusCard() {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 20,
//             offset: Offset(0, 5),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           // Status Icon
//           Container(
//             width: 80,
//             height: 80,
//             decoration: BoxDecoration(
//               color: todayAttendance?.status == 'punched_in'
//                   ? Colors.green.shade100
//                   : todayAttendance?.status == 'punched_out'
//                   ? Colors.blue.shade100
//                   : Colors.grey.shade100,
//               shape: BoxShape.circle,
//             ),
//             child: Icon(
//               todayAttendance?.status == 'punched_in'
//                   ? Icons.work
//                   : todayAttendance?.status == 'punched_out'
//                   ? Icons.home
//                   : Icons.schedule,
//               size: 40,
//               color: todayAttendance?.status == 'punched_in'
//                   ? Colors.green.shade600
//                   : todayAttendance?.status == 'punched_out'
//                   ? Colors.blue.shade600
//                   : Colors.grey.shade600,
//             ),
//           ),
//           SizedBox(height: 16),

//           // Status Text
//           Text(
//             todayAttendance?.status == 'punched_in'
//                 ? 'Currently Working'
//                 : todayAttendance?.status == 'punched_out'
//                 ? 'Work Complete'
//                 : 'Not Checked In',
//             style: TextStyle(
//               fontSize: 24,
//               fontWeight: FontWeight.bold,
//               color: Colors.indigo.shade600,
//             ),
//           ),

//           if (todayAttendance != null) ...[
//             SizedBox(height: 8),
//             Text(
//               'Since ${DateFormat('HH:mm').format(todayAttendance!.punchInTime)}',
//               style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
//             ),

//             if (todayAttendance!.status == 'punched_in') ...[
//               SizedBox(height: 16),
//               Container(
//                 padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 decoration: BoxDecoration(
//                   color: Colors.green.shade50,
//                   borderRadius: BorderRadius.circular(20),
//                   border: Border.all(color: Colors.green.shade200),
//                 ),
//                 child: Text(
//                   '🕐 ${_getCurrentWorkingTime()}',
//                   style: TextStyle(
//                     color: Colors.green.shade700,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ],
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildModernPunchButtons() {
//     if (isLoading) {
//       return Container(
//         height: 60,
//         child: Center(child: CircularProgressIndicator(color: Colors.white)),
//       );
//     }

//     return Row(
//       children: [
//         Expanded(
//           child: Container(
//             height: 60,
//             child: ElevatedButton.icon(
//               onPressed: todayAttendance?.status != 'punched_in'
//                   ? _punchIn
//                   : null,
//               icon: Icon(Icons.login, size: 24),
//               label: Text(
//                 'Punch In',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
//               ),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.green.shade500,
//                 foregroundColor: Colors.white,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 elevation: todayAttendance?.status != 'punched_in' ? 8 : 0,
//                 shadowColor: Colors.green.shade200,
//               ),
//             ),
//           ),
//         ),
//         SizedBox(width: 16),
//         Expanded(
//           child: Container(
//             height: 60,
//             child: ElevatedButton.icon(
//               onPressed: todayAttendance?.status == 'punched_in'
//                   ? _punchOut
//                   : null,
//               icon: Icon(Icons.logout, size: 24),
//               label: Text(
//                 'Punch Out',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
//               ),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red.shade500,
//                 foregroundColor: Colors.white,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 elevation: todayAttendance?.status == 'punched_in' ? 8 : 0,
//                 shadowColor: Colors.red.shade200,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildBeautifulCalendar() {
//     return Padding(
//       padding: EdgeInsets.symmetric(horizontal: 16),
//       child: TableCalendar<AttendanceRecord>(
//         firstDay: DateTime.utc(2020, 1, 1),
//         lastDay: DateTime.utc(2030, 12, 31),
//         focusedDay: _focusedDay,
//         selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
//         eventLoader: _getEventsForDay,
//         calendarFormat: CalendarFormat.month,
//         startingDayOfWeek: StartingDayOfWeek.monday,

//         // Styling
//         calendarStyle: CalendarStyle(
//           outsideDaysVisible: false,
//           weekendTextStyle: TextStyle(color: Colors.red.shade400),
//           holidayTextStyle: TextStyle(color: Colors.red.shade400),

//           // Today styling
//           todayDecoration: BoxDecoration(
//             color: Colors.indigo.shade400,
//             shape: BoxShape.circle,
//           ),

//           // Selected day styling
//           selectedDecoration: BoxDecoration(
//             color: Colors.purple.shade400,
//             shape: BoxShape.circle,
//           ),

//           // Event markers
//           markerDecoration: BoxDecoration(
//             color: Colors.green.shade600,
//             shape: BoxShape.circle,
//           ),

//           // Default styling
//           defaultDecoration: BoxDecoration(shape: BoxShape.circle),
//         ),

//         // Header styling
//         headerStyle: HeaderStyle(
//           formatButtonVisible: false,
//           titleCentered: true,
//           titleTextStyle: TextStyle(
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//             color: Colors.indigo.shade600,
//           ),
//           leftChevronIcon: Icon(
//             Icons.chevron_left,
//             color: Colors.indigo.shade600,
//           ),
//           rightChevronIcon: Icon(
//             Icons.chevron_right,
//             color: Colors.indigo.shade600,
//           ),
//         ),

//         // Day builder for custom styling
//         calendarBuilders: CalendarBuilders(
//           defaultBuilder: (context, day, focusedDay) {
//             final events = _getEventsForDay(day);
//             Color bgColor = Colors.transparent;

//             if (events.isNotEmpty) {
//               final hasCompleteDay = events.any(
//                 (e) => e.status == 'punched_out',
//               );
//               final hasPartialDay = events.any((e) => e.status == 'punched_in');

//               if (hasCompleteDay) {
//                 bgColor = Colors.green.shade100;
//               } else if (hasPartialDay) {
//                 bgColor = Colors.orange.shade100;
//               }
//             }

//             return Container(
//               margin: EdgeInsets.all(4),
//               decoration: BoxDecoration(
//                 color: bgColor,
//                 shape: BoxShape.circle,
//                 border: events.isNotEmpty
//                     ? Border.all(
//                         color: events.any((e) => e.status == 'punched_out')
//                             ? Colors.green
//                             : Colors.orange,
//                         width: 2,
//                       )
//                     : null,
//               ),
//               child: Center(
//                 child: Text(
//                   '${day.day}',
//                   style: TextStyle(
//                     color: events.isNotEmpty ? Colors.white : Colors.black87,
//                     fontWeight: events.isNotEmpty
//                         ? FontWeight.bold
//                         : FontWeight.normal,
//                   ),
//                 ),
//               ),
//             );
//           },
//         ),

//         onDaySelected: (selectedDay, focusedDay) {
//           setState(() {
//             _selectedDay = selectedDay;
//             _focusedDay = focusedDay;
//           });
//           _showDayDetails(selectedDay);
//         },

//         onPageChanged: (focusedDay) {
//           _focusedDay = focusedDay;
//         },
//       ),
//     );
//   }

//   Widget _buildCalendarLegend() {
//     return Padding(
//       padding: EdgeInsets.all(20),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//         children: [
//           _buildLegendItem(Colors.green, 'Present'),
//           _buildLegendItem(Colors.orange, 'Partial'),
//           _buildLegendItem(Colors.grey.shade300, 'Absent'),
//         ],
//       ),
//     );
//   }

//   Widget _buildLegendItem(Color color, String label) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Container(
//           width: 16,
//           height: 16,
//           decoration: BoxDecoration(color: color, shape: BoxShape.circle),
//         ),
//         SizedBox(width: 6),
//         Text(
//           label,
//           style: TextStyle(
//             fontSize: 12,
//             color: Colors.grey.shade600,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildLocationCard() {
//     return Container(
//       margin: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 20,
//             offset: Offset(0, 5),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Padding(
//             padding: EdgeInsets.all(20),
//             child: Row(
//               children: [
//                 Icon(Icons.location_on, color: Colors.red.shade400),
//                 SizedBox(width: 12),
//                 Text(
//                   'Work Location',
//                   style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.indigo.shade600,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Container(
//             height: 200,
//             margin: EdgeInsets.symmetric(horizontal: 20),
//             decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(16),
//               child: GoogleMap(
//                 onMapCreated: (GoogleMapController controller) {
//                   mapController = controller;
//                 },
//                 initialCameraPosition: CameraPosition(
//                   target: LatLng(
//                     todayAttendance!.punchInLocation.latitude,
//                     todayAttendance!.punchInLocation.longitude,
//                   ),
//                   zoom: 16,
//                 ),
//                 markers: {
//                   Marker(
//                     markerId: MarkerId('punch_location'),
//                     position: LatLng(
//                       todayAttendance!.punchInLocation.latitude,
//                       todayAttendance!.punchInLocation.longitude,
//                     ),
//                     infoWindow: InfoWindow(
//                       title: 'Work Location',
//                       snippet: todayAttendance!.punchInLocation.address,
//                     ),
//                   ),
//                 },
//                 myLocationEnabled: true,
//                 myLocationButtonEnabled: true,
//               ),
//             ),
//           ),
//           Padding(
//             padding: EdgeInsets.all(20),
//             child: Text(
//               todayAttendance!.punchInLocation.address,
//               style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTodayDetailsCard() {
//     return Container(
//       margin: EdgeInsets.all(16),
//       padding: EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 20,
//             offset: Offset(0, 5),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.today, color: Colors.blue.shade400),
//               SizedBox(width: 12),
//               Text(
//                 'Today\'s Summary',
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.indigo.shade600,
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 20),

//           _buildDetailCard(
//             'Check In',
//             DateFormat('HH:mm:ss').format(todayAttendance!.punchInTime),
//             Icons.login,
//             Colors.green,
//           ),

//           SizedBox(height: 12),

//           if (todayAttendance!.punchOutTime != null) ...[
//             _buildDetailCard(
//               'Check Out',
//               DateFormat('HH:mm:ss').format(todayAttendance!.punchOutTime!),
//               Icons.logout,
//               Colors.red,
//             ),

//             SizedBox(height: 12),

//             _buildDetailCard(
//               'Total Hours',
//               _calculateWorkingHours(),
//               Icons.schedule,
//               Colors.blue,
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildDetailCard(
//     String label,
//     String value,
//     IconData icon,
//     Color color,
//   ) {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: color.withOpacity(0.3)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: color,
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Icon(icon, color: Colors.white, size: 20),
//           ),
//           SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   label,
//                   style: TextStyle(
//                     color: Colors.grey.shade600,
//                     fontSize: 14,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 SizedBox(height: 4),
//                 Text(
//                   value,
//                   style: TextStyle(
//                     color: color,
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String _getCurrentWorkingTime() {
//     if (todayAttendance?.status != 'punched_in') return '';

//     final duration = DateTime.now().difference(todayAttendance!.punchInTime);
//     final hours = duration.inHours;
//     final minutes = duration.inMinutes % 60;

//     return '${hours}h ${minutes}m';
//   }

//   String _calculateWorkingHours() {
//     if (todayAttendance?.punchOutTime == null) return 'Still working...';

//     final duration = todayAttendance!.punchOutTime!.difference(
//       todayAttendance!.punchInTime,
//     );

//     final hours = duration.inHours;
//     final minutes = duration.inMinutes % 60;

//     return '${hours}h ${minutes}m';
//   }

//   Widget _buildAttendanceStatistics() {
//     return SingleChildScrollView(
//       padding: EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Month Selector
//           Container(
//             padding: EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(12),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.1),
//                   blurRadius: 8,
//                   offset: Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Row(
//               children: [
//                 Icon(Icons.date_range, color: Colors.indigo.shade600),
//                 SizedBox(width: 12),
//                 Text(
//                   'Select Month',
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w600,
//                     color: Colors.indigo.shade600,
//                   ),
//                 ),
//                 Spacer(),
//                 InkWell(
//                   onTap: _selectMonth,
//                   child: Container(
//                     padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                     decoration: BoxDecoration(
//                       color: Colors.indigo.shade50,
//                       borderRadius: BorderRadius.circular(8),
//                       border: Border.all(color: Colors.indigo.shade200),
//                     ),
//                     child: Text(
//                       DateFormat('MMM yyyy').format(_selectedMonth),
//                       style: TextStyle(
//                         fontWeight: FontWeight.w600,
//                         color: Colors.indigo.shade700,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           SizedBox(height: 16),

//           // Overall Statistics Summary
//           if (_attendanceStats.isNotEmpty) _buildOverallSummary(),

//           SizedBox(height: 16),

//           // User-wise Statistics
//           if (_attendanceStats.isNotEmpty) _buildUserWiseStatistics(),

//           // Empty state
//           if (_attendanceStats.isEmpty) _buildEmptyStatistics(),
//         ],
//       ),
//     );
//   }

//   Widget _buildOverallSummary() {
//     final totalUsers = _attendanceStats.length;
//     final totalWorkingDays = _attendanceStats.values.first['workingDays'] ?? 0;
//     final avgAttendance = _attendanceStats.values.isEmpty
//         ? 0.0
//         : _attendanceStats.values
//                   .map((stats) => stats['attendancePercentage'] as double)
//                   .reduce((a, b) => a + b) /
//               totalUsers;

//     final totalPresent = _attendanceStats.values
//         .map((stats) => stats['presentDays'] as int)
//         .reduce((a, b) => a + b);

//     final totalAbsent = _attendanceStats.values
//         .map((stats) => stats['absentDays'] as int)
//         .reduce((a, b) => a + b);

//     return Container(
//       padding: EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Colors.indigo.shade400, Colors.purple.shade400],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.indigo.withOpacity(0.3),
//             blurRadius: 12,
//             offset: Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.analytics, color: Colors.white, size: 24),
//               SizedBox(width: 12),
//               Text(
//                 'Overall Statistics',
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 20),

//           Row(
//             children: [
//               Expanded(
//                 child: _buildSummaryCard(
//                   'Total Users',
//                   totalUsers.toString(),
//                   Icons.people,
//                   Colors.white,
//                 ),
//               ),
//               SizedBox(width: 12),
//               Expanded(
//                 child: _buildSummaryCard(
//                   'Working Days',
//                   totalWorkingDays.toString(),
//                   Icons.calendar_today,
//                   Colors.white,
//                 ),
//               ),
//             ],
//           ),

//           SizedBox(height: 12),

//           Row(
//             children: [
//               Expanded(
//                 child: _buildSummaryCard(
//                   'Avg Attendance',
//                   '${avgAttendance.toStringAsFixed(1)}%',
//                   Icons.trending_up,
//                   Colors.white,
//                 ),
//               ),
//               SizedBox(width: 12),
//               Expanded(
//                 child: _buildSummaryCard(
//                   'Total Present',
//                   totalPresent.toString(),
//                   Icons.check_circle,
//                   Colors.white,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSummaryCard(
//     String title,
//     String value,
//     IconData icon,
//     Color textColor,
//   ) {
//     return Container(
//       padding: EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.2),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         children: [
//           Icon(icon, color: textColor, size: 20),
//           SizedBox(height: 8),
//           Text(
//             value,
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: textColor,
//             ),
//           ),
//           Text(
//             title,
//             style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.9)),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildUserWiseStatistics() {
//     final sortedUsers = _attendanceStats.entries.toList()
//       ..sort(
//         (a, b) => b.value['attendancePercentage'].compareTo(
//           a.value['attendancePercentage'],
//         ),
//       );

//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 8,
//             offset: Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Padding(
//             padding: EdgeInsets.all(20),
//             child: Row(
//               children: [
//                 Icon(Icons.person_search, color: Colors.indigo.shade600),
//                 SizedBox(width: 12),
//                 Text(
//                   'User-wise Attendance',
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.indigo.shade600,
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           ListView.separated(
//             shrinkWrap: true,
//             physics: NeverScrollableScrollPhysics(),
//             itemCount: sortedUsers.length,
//             separatorBuilder: (context, index) => Divider(height: 1),
//             itemBuilder: (context, index) {
//               final userId = sortedUsers[index].key;
//               final stats = sortedUsers[index].value;

//               return _buildUserStatCard(stats, index + 1);
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildUserStatCard(Map<String, dynamic> stats, int rank) {
//     final attendancePercentage = stats['attendancePercentage'] as double;
//     final presentDays = stats['presentDays'] as int;
//     final absentDays = stats['absentDays'] as int;
//     final lateDays = stats['lateDays'] as int;
//     final workingDays = stats['workingDays'] as int;
//     final avgHours = stats['averageWorkingHours'] as double;

//     Color getPerformanceColor(double percentage) {
//       if (percentage >= 90) return Colors.green;
//       if (percentage >= 75) return Colors.orange;
//       return Colors.red;
//     }

//     return Padding(
//       padding: EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // User Header
//           Row(
//             children: [
//               Container(
//                 width: 24,
//                 height: 24,
//                 decoration: BoxDecoration(
//                   color: getPerformanceColor(attendancePercentage),
//                   shape: BoxShape.circle,
//                 ),
//                 child: Center(
//                   child: Text(
//                     '$rank',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 12,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//               SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       stats['userName'],
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     Text(
//                       stats['userEmail'],
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: Colors.grey.shade600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Container(
//                 padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: getPerformanceColor(
//                     attendancePercentage,
//                   ).withOpacity(0.2),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Text(
//                   '${attendancePercentage.toStringAsFixed(1)}%',
//                   style: TextStyle(
//                     color: getPerformanceColor(attendancePercentage),
//                     fontWeight: FontWeight.bold,
//                     fontSize: 14,
//                   ),
//                 ),
//               ),
//             ],
//           ),

//           SizedBox(height: 16),

//           // Progress Bar
//           Container(
//             height: 8,
//             decoration: BoxDecoration(
//               color: Colors.grey.shade200,
//               borderRadius: BorderRadius.circular(4),
//             ),
//             child: FractionallySizedBox(
//               widthFactor: attendancePercentage / 100,
//               alignment: Alignment.centerLeft,
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: getPerformanceColor(attendancePercentage),
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//               ),
//             ),
//           ),

//           SizedBox(height: 16),

//           // Statistics Grid
//           Row(
//             children: [
//               Expanded(
//                 child: _buildStatItem(
//                   'Present',
//                   presentDays.toString(),
//                   Colors.green,
//                   Icons.check_circle,
//                 ),
//               ),
//               Expanded(
//                 child: _buildStatItem(
//                   'Absent',
//                   absentDays.toString(),
//                   Colors.red,
//                   Icons.cancel,
//                 ),
//               ),
//               Expanded(
//                 child: _buildStatItem(
//                   'Late',
//                   lateDays.toString(),
//                   Colors.orange,
//                   Icons.schedule,
//                 ),
//               ),
//               Expanded(
//                 child: _buildStatItem(
//                   'Avg Hours',
//                   avgHours.toStringAsFixed(1),
//                   Colors.blue,
//                   Icons.access_time,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatItem(
//     String label,
//     String value,
//     Color color,
//     IconData icon,
//   ) {
//     return Column(
//       children: [
//         Container(
//           padding: EdgeInsets.all(8),
//           decoration: BoxDecoration(
//             color: color.withOpacity(0.1),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Icon(icon, color: color, size: 16),
//         ),
//         SizedBox(height: 4),
//         Text(
//           value,
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 14,
//             color: color,
//           ),
//         ),
//         Text(
//           label,
//           style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
//         ),
//       ],
//     );
//   }

//   Widget _buildEmptyStatistics() {
//     return Container(
//       padding: EdgeInsets.all(40),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 8,
//             offset: Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade400),
//           SizedBox(height: 16),
//           Text(
//             'No Attendance Data',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.w600,
//               color: Colors.grey.shade600,
//             ),
//           ),
//           SizedBox(height: 8),
//           Text(
//             'No attendance records found for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
//             style: TextStyle(color: Colors.grey.shade500),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _selectMonth() async {
//     try {
//       final DateTime? picked = await showDatePicker(
//         context: context,
//         initialDate: _selectedMonth,
//         firstDate: DateTime(2020),
//         lastDate: DateTime.now(),
//         initialDatePickerMode: DatePickerMode.year,
//       );

//       if (picked != null && mounted) {
//         setState(() {
//           _selectedMonth = picked;
//         });
//         // Run calculation asynchronously to prevent UI freeze
//         Future.microtask(() => _calculateAttendanceStatistics());
//       }
//     } catch (e) {
//       print('Error selecting month: $e');
//       _showErrorSnackBar('Error selecting month: $e');
//     }
//   }

//   void _showDayDetails(DateTime selectedDay) {
//     final events = _getEventsForDay(selectedDay);
//     if (events.isEmpty) return;

//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => DayDetailsSheet(date: selectedDay, records: events),
//     );
//   }

//   Widget _buildAdminView() {
//     return DefaultTabController(
//       length: 2, // Changed from 3 to 2
//       child: Column(
//         children: [
//           // Tab Bar
//           Container(
//             margin: EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(12),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.1),
//                   blurRadius: 8,
//                   offset: Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: TabBar(
//               indicator: BoxDecoration(
//                 borderRadius: BorderRadius.circular(12),
//                 color: Colors.indigo.shade600,
//               ),
//               labelColor: Colors.white,
//               unselectedLabelColor: Colors.grey.shade600,
//               labelStyle: TextStyle(fontWeight: FontWeight.w600),
//               tabs: [
//                 Tab(icon: Icon(Icons.analytics), text: 'Statistics'),
//                 Tab(icon: Icon(Icons.location_on), text: 'User Locations'),
//               ],
//             ),
//           ),

//           // Tab Views
//           Expanded(
//             child: TabBarView(
//               children: [
//                 // Statistics Tab
//                 _buildAttendanceStatistics(),

//                 // User Locations Tab
//                 _buildUserLocationsView(),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildUserLocationsView() {
//     return Container(
//       margin: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 20,
//             offset: Offset(0, 5),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Padding(
//             padding: EdgeInsets.all(20),
//             child: Row(
//               children: [
//                 Icon(Icons.location_on, color: Colors.indigo.shade600),
//                 SizedBox(width: 12),
//                 Text(
//                   'Current User Locations',
//                   style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.indigo.shade600,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Expanded(
//             child: StreamBuilder<List<EmployeeLocation>>(
//               stream: AttendanceService.getEmployeeLocationsStream(),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return Center(child: CircularProgressIndicator());
//                 }

//                 final employees = snapshot.data ?? [];

//                 if (employees.isEmpty) {
//                   return Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(
//                           Icons.location_off,
//                           size: 64,
//                           color: Colors.grey.shade400,
//                         ),
//                         SizedBox(height: 16),
//                         Text(
//                           'No Active Users',
//                           style: TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.w600,
//                             color: Colors.grey.shade600,
//                           ),
//                         ),
//                         SizedBox(height: 8),
//                         Text(
//                           'No employees are currently active',
//                           style: TextStyle(
//                             color: Colors.grey.shade500,
//                             fontSize: 14,
//                           ),
//                         ),
//                       ],
//                     ),
//                   );
//                 }

//                 return ListView.builder(
//                   padding: EdgeInsets.symmetric(horizontal: 16),
//                   itemCount: employees.length,
//                   itemBuilder: (context, index) {
//                     final emp = employees[index];
                    
//                     // Get today's attendance for punch-in time
//                     return FutureBuilder<AttendanceRecord?>(
//                       future: _getTodayAttendanceForUser(emp.userId),
//                       builder: (context, attendanceSnapshot) {
//                         final todayRecord = attendanceSnapshot.data;
                        
//                         return Container(
//                           margin: EdgeInsets.only(bottom: 16),
//                           decoration: BoxDecoration(
//                             gradient: LinearGradient(
//                               colors: emp.status == 'punched_in'
//                                   ? [
//                                       Colors.green.shade50,
//                                       Colors.green.shade100,
//                                     ]
//                                   : [
//                                       Colors.red.shade50,
//                                       Colors.red.shade100,
//                                     ],
//                               begin: Alignment.topLeft,
//                               end: Alignment.bottomRight,
//                             ),
//                             borderRadius: BorderRadius.circular(16),
//                             border: Border.all(
//                               color: emp.status == 'punched_in'
//                                   ? Colors.green.shade200
//                                   : Colors.red.shade200,
//                               width: 1,
//                             ),
//                           ),
//                           child: Padding(
//                             padding: EdgeInsets.all(16),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 // User Header
//                                 Row(
//                                   children: [
//                                     Container(
//                                       width: 50,
//                                       height: 50,
//                                       decoration: BoxDecoration(
//                                         gradient: LinearGradient(
//                                           colors: emp.status == 'punched_in'
//                                               ? [
//                                                   Colors.green.shade400,
//                                                   Colors.green.shade600,
//                                                 ]
//                                               : [
//                                                   Colors.red.shade400,
//                                                   Colors.red.shade600,
//                                                 ],
//                                         ),
//                                         shape: BoxShape.circle,
//                                       ),
//                                       child: Center(
//                                         child: Text(
//                                           emp.userName.isNotEmpty
//                                               ? emp.userName[0].toUpperCase()
//                                               : '?',
//                                           style: TextStyle(
//                                             color: Colors.white,
//                                             fontWeight: FontWeight.bold,
//                                             fontSize: 20,
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                     SizedBox(width: 16),
//                                     Expanded(
//                                       child: Column(
//                                         crossAxisAlignment: CrossAxisAlignment.start,
//                                         children: [
//                                           Text(
//                                             emp.userName,
//                                             style: TextStyle(
//                                               fontWeight: FontWeight.bold,
//                                               fontSize: 18,
//                                               color: Colors.indigo.shade600,
//                                             ),
//                                           ),
//                                           SizedBox(height: 4),
//                                           Text(
//                                             emp.userEmail,
//                                             style: TextStyle(
//                                               color: Colors.grey.shade600,
//                                               fontSize: 14,
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                     Container(
//                                       padding: EdgeInsets.symmetric(
//                                         horizontal: 12,
//                                         vertical: 6,
//                                       ),
//                                       decoration: BoxDecoration(
//                                         color: emp.status == 'punched_in'
//                                             ? Colors.green.shade600
//                                             : Colors.red.shade600,
//                                         borderRadius: BorderRadius.circular(20),
//                                       ),
//                                       child: Row(
//                                         mainAxisSize: MainAxisSize.min,
//                                         children: [
//                                           Icon(
//                                             emp.status == 'punched_in'
//                                                 ? Icons.work
//                                                 : Icons.work_off,
//                                             color: Colors.white,
//                                             size: 16,
//                                           ),
//                                           SizedBox(width: 4),
//                                           Text(
//                                             emp.status == 'punched_in'
//                                                 ? 'Active'
//                                                 : 'Offline',
//                                             style: TextStyle(
//                                               color: Colors.white,
//                                               fontWeight: FontWeight.w600,
//                                               fontSize: 12,
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   ],
//                                 ),

//                                 SizedBox(height: 16),

//                                 // Status Information
//                                 Container(
//                                   padding: EdgeInsets.all(12),
//                                   decoration: BoxDecoration(
//                                     color: Colors.white.withOpacity(0.7),
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                   child: Column(
//                                     children: [
//                                       // Punch-in time
//                                       if (todayRecord != null) ...[
//                                         Row(
//                                           children: [
//                                             Icon(
//                                               Icons.access_time,
//                                               color: Colors.blue.shade600,
//                                               size: 20,
//                                             ),
//                                             SizedBox(width: 8),
//                                             Text(
//                                               'Punched In: ',
//                                               style: TextStyle(
//                                                 fontWeight: FontWeight.w500,
//                                                 color: Colors.grey.shade700,
//                                               ),
//                                             ),
//                                             Text(
//                                               DateFormat('HH:mm:ss').format(
//                                                 todayRecord.punchInTime,
//                                               ),
//                                               style: TextStyle(
//                                                 fontWeight: FontWeight.bold,
//                                                 color: Colors.blue.shade600,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                         SizedBox(height: 8),
                                        
//                                         // Working duration if active
//                                         if (emp.status == 'punched_in') ...[
//                                           Row(
//                                             children: [
//                                               Icon(
//                                                 Icons.timer,
//                                                 color: Colors.green.shade600,
//                                                 size: 20,
//                                               ),
//                                               SizedBox(width: 8),
//                                               Text(
//                                                 'Working for: ',
//                                                 style: TextStyle(
//                                                   fontWeight: FontWeight.w500,
//                                                   color: Colors.grey.shade700,
//                                                 ),
//                                               ),
//                                               Text(
//                                                 _getWorkingDuration(todayRecord.punchInTime),
//                                                 style: TextStyle(
//                                                   fontWeight: FontWeight.bold,
//                                                   color: Colors.green.shade600,
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                           SizedBox(height: 8),
//                                         ],
//                                       ],

//                                       // Location
//                                       Row(
//                                         crossAxisAlignment: CrossAxisAlignment.start,
//                                         children: [
//                                           Icon(
//                                             Icons.location_on,
//                                             color: Colors.red.shade600,
//                                             size: 20,
//                                           ),
//                                           SizedBox(width: 8),
//                                           Expanded(
//                                             child: Column(
//                                               crossAxisAlignment: CrossAxisAlignment.start,
//                                               children: [
//                                                 Text(
//                                                   'Location:',
//                                                   style: TextStyle(
//                                                     fontWeight: FontWeight.w500,
//                                                     color: Colors.grey.shade700,
//                                                   ),
//                                                 ),
//                                                 SizedBox(height: 2),
//                                                 Text(
//                                                   emp.location.address,
//                                                   style: TextStyle(
//                                                     fontSize: 13,
//                                                     color: Colors.grey.shade600,
//                                                   ),
//                                                 ),
//                                                 SizedBox(height: 4),
//                                                 Text(
//                                                   'Lat: ${emp.location.latitude.toStringAsFixed(6)}, '
//                                                   'Lng: ${emp.location.longitude.toStringAsFixed(6)}',
//                                                   style: TextStyle(
//                                                     fontSize: 11,
//                                                     color: Colors.grey.shade500,
//                                                     fontFamily: 'monospace',
//                                                   ),
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ],
//                                   ),
//                                 ),

//                                 // View on Map Button
//                                 SizedBox(height: 12),
//                                 SizedBox(
//                                   width: double.infinity,
//                                   child: ElevatedButton.icon(
//                                     onPressed: () => _showUserLocationOnMap(emp),
//                                     icon: Icon(Icons.map, size: 18),
//                                     label: Text('View on Map'),
//                                     style: ElevatedButton.styleFrom(
//                                       backgroundColor: Colors.indigo.shade600,
//                                       foregroundColor: Colors.white,
//                                       padding: EdgeInsets.symmetric(vertical: 12),
//                                       shape: RoundedRectangleBorder(
//                                         borderRadius: BorderRadius.circular(8),
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         );
//                       },
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String _getWorkingDuration(DateTime punchInTime) {
//     final duration = DateTime.now().difference(punchInTime);
//     final hours = duration.inHours;
//     final minutes = duration.inMinutes % 60;
//     return '${hours}h ${minutes}m';
//   }

//   Future<AttendanceRecord?> _getTodayAttendanceForUser(String userId) async {
//     try {
//       final today = DateTime.now();
//       final startOfDay = DateTime(today.year, today.month, today.day);
//       final endOfDay = startOfDay.add(Duration(days: 1));
      
//       final records = await AttendanceService.getAttendanceByDateRange(
//         startOfDay,
//         endOfDay,
//       );
      
//       return records
//           .where((record) => 
//               record.userId == userId && 
//               record.date.day == today.day)
//           .isNotEmpty
//           ? records.firstWhere((record) => 
//               record.userId == userId && 
//               record.date.day == today.day)
//           : null;
//     } catch (e) {
//       return null;
//     }
//   }

//   void _showUserLocationOnMap(EmployeeLocation employee) {
//     showDialog(
//       context: context,
//       builder: (context) => Dialog(
//         child: Container(
//           height: 400,
//           width: 300,
//           child: Column(
//             children: [
//               Container(
//                 padding: EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.indigo.shade600,
//                   borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
//                 ),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         '${employee.userName}\'s Location',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 16,
//                         ),
//                       ),
//                     ),
//                     IconButton(
//                       onPressed: () => Navigator.of(context).pop(),
//                       icon: Icon(Icons.close, color: Colors.white),
//                     ),
//                   ],
//                 ),
//               ),
//               Expanded(
//                 child: GoogleMap(
//                   initialCameraPosition: CameraPosition(
//                     target: LatLng(
//                       employee.location.latitude,
//                       employee.location.longitude,
//                     ),
//                     zoom: 16,
//                   ),
//                   markers: {
//                     Marker(
//                       markerId: MarkerId(employee.userId),
//                       position: LatLng(
//                         employee.location.latitude,
//                         employee.location.longitude,
//                       ),
//                       infoWindow: InfoWindow(
//                         title: employee.userName,
//                         snippet: employee.location.address,
//                       ),
//                       icon: employee.status == 'punched_in'
//                           ? BitmapDescriptor.defaultMarkerWithHue(
//                               BitmapDescriptor.hueGreen,
//                             )
//                           : BitmapDescriptor.defaultMarkerWithHue(
//                               BitmapDescriptor.hueRed,
//                             ),
//                     ),
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   void _showAttendanceRecords() {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => AttendanceRecordsSheet(),
//     );
//   }
// }

// // Day Details Sheet Widget
// class DayDetailsSheet extends StatelessWidget {
//   final DateTime date;
//   final List<AttendanceRecord> records;

//   const DayDetailsSheet({Key? key, required this.date, required this.records})
//     : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: MediaQuery.of(context).size.height * 0.6,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       child: Column(
//         children: [
//           // Handle bar
//           Container(
//             width: 40,
//             height: 4,
//             margin: EdgeInsets.symmetric(vertical: 12),
//             decoration: BoxDecoration(
//               color: Colors.grey.shade300,
//               borderRadius: BorderRadius.circular(2),
//             ),
//           ),

//           // Header
//           Padding(
//             padding: EdgeInsets.all(20),
//             child: Row(
//               children: [
//                 Icon(Icons.calendar_today, color: Colors.indigo.shade600),
//                 SizedBox(width: 12),
//                 Text(
//                   DateFormat('EEEE, MMM dd, yyyy').format(date),
//                   style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.indigo.shade600,
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // Records
//           Expanded(
//             child: ListView.builder(
//               padding: EdgeInsets.symmetric(horizontal: 20),
//               itemCount: records.length,
//               itemBuilder: (context, index) {
//                 final record = records[index];
//                 return Container(
//                   margin: EdgeInsets.only(bottom: 12),
//                   padding: EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade50,
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(color: Colors.grey.shade200),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           CircleAvatar(
//                             radius: 20,
//                             backgroundColor: record.status == 'punched_in'
//                                 ? Colors.green.shade100
//                                 : Colors.blue.shade100,
//                             child: Icon(
//                               record.status == 'punched_in'
//                                   ? Icons.work
//                                   : Icons.home,
//                               color: record.status == 'punched_in'
//                                   ? Colors.green.shade600
//                                   : Colors.blue.shade600,
//                             ),
//                           ),
//                           SizedBox(width: 12),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   record.userName,
//                                   style: TextStyle(
//                                     fontWeight: FontWeight.w600,
//                                     fontSize: 16,
//                                   ),
//                                 ),
//                                 Text(
//                                   'In: ${DateFormat('HH:mm').format(record.punchInTime)}',
//                                   style: TextStyle(color: Colors.grey.shade600),
//                                 ),
//                                 if (record.punchOutTime != null)
//                                   Text(
//                                     'Out: ${DateFormat('HH:mm').format(record.punchOutTime!)}',
//                                     style: TextStyle(
//                                       color: Colors.grey.shade600,
//                                     ),
//                                   ),
//                               ],
//                             ),
//                           ),
//                           Container(
//                             padding: EdgeInsets.symmetric(
//                               horizontal: 8,
//                               vertical: 4,
//                             ),
//                             decoration: BoxDecoration(
//                               color: record.status == 'punched_in'
//                                   ? Colors.green.shade100
//                                   : Colors.blue.shade100,
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: Text(
//                               record.status == 'punched_in'
//                                   ? 'Active'
//                                   : 'Complete',
//                               style: TextStyle(
//                                 color: record.status == 'punched_in'
//                                     ? Colors.green.shade700
//                                     : Colors.blue.shade700,
//                                 fontWeight: FontWeight.w600,
//                                 fontSize: 12,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // Enhanced Attendance Records Sheet
// class AttendanceRecordsSheet extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: MediaQuery.of(context).size.height * 0.85,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       child: Column(
//         children: [
//           // Handle bar
//           Container(
//             width: 40,
//             height: 4,
//             margin: EdgeInsets.symmetric(vertical: 12),
//             decoration: BoxDecoration(
//               color: Colors.grey.shade300,
//               borderRadius: BorderRadius.circular(2),
//             ),
//           ),

//           // Header
//           Padding(
//             padding: EdgeInsets.all(20),
//             child: Row(
//               children: [
//                 Icon(Icons.analytics, color: Colors.indigo.shade600),
//                 SizedBox(width: 12),
//                 Text(
//                   'Attendance Analytics',
//                   style: TextStyle(
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.indigo.shade600,
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // Records
//           Expanded(
//             child: StreamBuilder<List<AttendanceRecord>>(
//               stream: AttendanceService.getAllAttendanceStream(),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return Center(child: CircularProgressIndicator());
//                 }

//                 final records = snapshot.data ?? [];

//                 return ListView.builder(
//                   padding: EdgeInsets.symmetric(horizontal: 20),
//                   itemCount: records.length,
//                   itemBuilder: (context, index) {
//                     final record = records[index];
//                     return Container(
//                       margin: EdgeInsets.only(bottom: 12),
//                       decoration: BoxDecoration(
//                         color: Colors.grey.shade50,
//                         borderRadius: BorderRadius.circular(16),
//                         border: Border.all(color: Colors.grey.shade200),
//                       ),
//                       child: ListTile(
//                         contentPadding: EdgeInsets.all(16),
//                         leading: Container(
//                           width: 50,
//                           height: 50,
//                           decoration: BoxDecoration(
//                             gradient: LinearGradient(
//                               colors: record.status == 'punched_in'
//                                   ? [
//                                       Colors.green.shade400,
//                                       Colors.green.shade600,
//                                     ]
//                                   : [
//                                       Colors.blue.shade400,
//                                       Colors.blue.shade600,
//                                     ],
//                             ),
//                             shape: BoxShape.circle,
//                           ),
//                           child: Center(
//                             child: Text(
//                               record.userName.isNotEmpty
//                                   ? record.userName[0].toUpperCase()
//                                   : '?',
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 18,
//                               ),
//                             ),
//                           ),
//                         ),
//                         title: Text(
//                           record.userName,
//                           style: TextStyle(
//                             fontWeight: FontWeight.w600,
//                             fontSize: 16,
//                           ),
//                         ),
//                         subtitle: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             SizedBox(height: 4),
//                             Text(
//                               '📅 ${DateFormat('dd/MM/yyyy').format(record.date)}',
//                             ),
//                             Text(
//                               '🕐 In: ${DateFormat('HH:mm').format(record.punchInTime)}',
//                             ),
//                             if (record.punchOutTime != null)
//                               Text(
//                                 '🕐 Out: ${DateFormat('HH:mm').format(record.punchOutTime!)}',
//                               ),
//                           ],
//                         ),
//                         trailing: Container(
//                           padding: EdgeInsets.symmetric(
//                             horizontal: 12,
//                             vertical: 6,
//                           ),
//                           decoration: BoxDecoration(
//                             color: record.status == 'punched_in'
//                                 ? Colors.green.shade100
//                                 : Colors.blue.shade100,
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                           child: Text(
//                             record.status == 'punched_in'
//                                 ? 'Active'
//                                 : 'Complete',
//                             style: TextStyle(
//                               color: record.status == 'punched_in'
//                                   ? Colors.green.shade700
//                                   : Colors.blue.shade700,
//                               fontWeight: FontWeight.w600,
//                               fontSize: 12,
//                             ),
//                           ),
//                         ),
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Add this import for kIsWeb
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:office_task_managemet/pages/attendance/attendance_model.dart';
import 'package:office_task_managemet/pages/attendance/attendance_service.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({Key? key}) : super(key: key);

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  GoogleMapController? mapController;
  AttendanceRecord? todayAttendance;
  bool isLoading = false;
  bool isAdmin = false;
  Set<Marker> markers = {};

  // Calendar and Statistics variables
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<AttendanceRecord>> _attendanceEvents = {};
  List<AttendanceRecord> _allAttendanceRecords = [];

  // Statistics variables
  DateTime _selectedMonth = DateTime.now();
  Map<String, Map<String, dynamic>> _attendanceStats = {};

  @override
  void initState() {
    super.initState();
    isAdmin = AttendanceService.isAdmin();
    _selectedDay = DateTime.now();
    _loadTodayAttendance();
    _loadAttendanceData();
    if (isAdmin && !kIsWeb) {
      // Only load employee locations on mobile
      _loadEmployeeLocations();
    }
  }

  Future<void> _loadTodayAttendance() async {
    if (!mounted) return;

    setState(() => isLoading = true);
    try {
      final attendance = await AttendanceService.getTodayAttendance();
      if (mounted) {
        setState(() {
          todayAttendance = attendance;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading today attendance: $e');
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackBar('Error loading attendance: $e');
      }
    }
  }

  Future<void> _loadAttendanceData() async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: 90));
      final endDate = DateTime.now().add(Duration(days: 30));

      List<AttendanceRecord> records;
      if (isAdmin) {
        // Admin can see all records
        records = await AttendanceService.getAttendanceByDateRange(
          startDate,
          endDate,
        );
      } else {
        // Employee sees only their records
        records = await AttendanceService.getAttendanceByDateRange(
          startDate,
          endDate,
        );
        final currentUser = FirebaseAuth.instance.currentUser;
        records = records.where((r) => r.userId == currentUser?.uid).toList();
      }

      if (mounted) {
        setState(() {
          _allAttendanceRecords = records;
          _attendanceEvents = _groupRecordsByDate(records);
        });

        // Calculate statistics for admin asynchronously
        if (isAdmin) {
          // Run statistics calculation asynchronously to prevent UI freeze
          Future.microtask(() => _calculateAttendanceStatistics());
        }
      }
    } catch (e) {
      print('Error loading attendance data: $e');
      // Don't rethrow - let the UI continue working even if data load fails
    }
  }

  void _calculateAttendanceStatistics() {
    try {
      // Add safety check for empty records
      if (_allAttendanceRecords.isEmpty) {
        setState(() {
          _attendanceStats = {};
        });
        return;
      }

      final stats = <String, Map<String, dynamic>>{};

      // Get start and end of selected month
      final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final monthEnd = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
      );
      final workingDays = _getWorkingDaysInMonth(monthStart, monthEnd);

      // Safety check for reasonable date range
      if (workingDays <= 0 || workingDays > 31) {
        print('Invalid working days calculation: $workingDays');
        setState(() {
          _attendanceStats = {};
        });
        return;
      }

      // Filter records for selected month with safety checks
      final monthRecords = _allAttendanceRecords.where((record) {
        try {
          final recordDate = DateTime(
            record.date.year,
            record.date.month,
            record.date.day,
          );
          return recordDate.isAfter(monthStart.subtract(Duration(days: 1))) &&
              recordDate.isBefore(monthEnd.add(Duration(days: 1)));
        } catch (e) {
          print('Error processing record date: $e');
          return false;
        }
      }).toList();

      // Group by user
      final userRecords = <String, List<AttendanceRecord>>{};
      for (var record in monthRecords) {
        try {
          final userId = record.userId;
          if (userId.isNotEmpty) {
            if (!userRecords.containsKey(userId)) {
              userRecords[userId] = [];
            }
            userRecords[userId]!.add(record);
          }
        } catch (e) {
          print('Error processing user record: $e');
          continue;
        }
      }

      // Calculate stats for each user
      userRecords.forEach((userId, records) {
        try {
          if (records.isEmpty) return;

          final user = records.first; // Get user info from first record

          final presentDays = <DateTime>{};
          final lateDays = <DateTime>{};
          double totalWorkingHours = 0.0;

          for (var record in records) {
            try {
              final recordDate = DateTime(
                record.date.year,
                record.date.month,
                record.date.day,
              );

              if (record.status == 'punched_out' ||
                  record.status == 'punched_in') {
                presentDays.add(recordDate);

                // Check if late (after 9:30 AM)
                final punchInTime = record.punchInTime;
                final lateThreshold = DateTime(
                  punchInTime.year,
                  punchInTime.month,
                  punchInTime.day,
                  9,
                  30,
                );
                if (punchInTime.isAfter(lateThreshold)) {
                  lateDays.add(recordDate);
                }

                // Calculate working hours with safety check
                if (record.punchOutTime != null) {
                  final workingDuration = record.punchOutTime!.difference(
                    record.punchInTime,
                  );
                  final hours = workingDuration.inMinutes / 60.0;
                  // Safety check for reasonable working hours (0-24 hours)
                  if (hours >= 0 && hours <= 24) {
                    totalWorkingHours += hours;
                  }
                }
              }
            } catch (e) {
              print('Error processing individual record: $e');
              continue;
            }
          }

          final presentCount = presentDays.length;
          final absentCount = workingDays - presentCount;
          final lateCount = lateDays.length;
          final attendancePercentage = workingDays > 0
              ? (presentCount / workingDays) * 100
              : 0.0;

          stats[userId] = {
            'userName': user.userName ?? 'Unknown',
            'userEmail': user.userEmail ?? 'Unknown',
            'presentDays': presentCount,
            'absentDays': absentCount >= 0 ? absentCount : 0,
            'lateDays': lateCount,
            'workingDays': workingDays,
            'attendancePercentage': attendancePercentage.clamp(0.0, 100.0),
            'totalWorkingHours': totalWorkingHours,
            'averageWorkingHours': presentCount > 0
                ? totalWorkingHours / presentCount
                : 0.0,
          };
        } catch (e) {
          print('Error calculating stats for user $userId: $e');
        }
      });

      // Update UI on main thread
      if (mounted) {
        setState(() {
          _attendanceStats = stats;
        });
      }
    } catch (e) {
      print('Error in _calculateAttendanceStatistics: $e');
      // Set empty stats to prevent crash
      if (mounted) {
        setState(() {
          _attendanceStats = {};
        });
      }
    }
  }

  int _getWorkingDaysInMonth(DateTime start, DateTime end) {
    try {
      // Safety checks to prevent infinite loops
      if (start.isAfter(end)) {
        print('Error: Start date is after end date');
        return 0;
      }

      final daysDifference = end.difference(start).inDays;
      if (daysDifference > 31) {
        print('Error: Date range too large: $daysDifference days');
        return 0;
      }

      int workingDays = 0;
      DateTime current = start;

      // Limit iterations to prevent infinite loops
      int iterations = 0;
      const maxIterations = 32; // Safety limit

      while (current.isBefore(end.add(Duration(days: 1))) &&
          iterations < maxIterations) {
        // Exclude weekends (Saturday = 6, Sunday = 7)
        if (current.weekday != DateTime.saturday &&
            current.weekday != DateTime.sunday) {
          workingDays++;
        }
        current = current.add(Duration(days: 1));
        iterations++;
      }

      if (iterations >= maxIterations) {
        print('Warning: Working days calculation hit iteration limit');
      }

      return workingDays;
    } catch (e) {
      print('Error calculating working days: $e');
      return 0;
    }
  }

  Map<DateTime, List<AttendanceRecord>> _groupRecordsByDate(
    List<AttendanceRecord> records,
  ) {
    Map<DateTime, List<AttendanceRecord>> events = {};
    try {
      for (var record in records) {
        try {
          final date = DateTime(
            record.date.year,
            record.date.month,
            record.date.day,
          );
          if (events[date] != null) {
            events[date]!.add(record);
          } else {
            events[date] = [record];
          }
        } catch (e) {
          print('Error processing record date: $e');
          continue;
        }
      }
    } catch (e) {
      print('Error grouping records by date: $e');
    }
    return events;
  }

  List<AttendanceRecord> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _attendanceEvents[normalizedDay] ?? [];
  }

  Color _getDateColor(DateTime day) {
    final events = _getEventsForDay(day);
    if (events.isEmpty) return Colors.grey.shade300;

    // Check if any employee was present
    final hasPresent = events.any(
      (e) => e.status == 'punched_out' || e.status == 'punched_in',
    );
    return hasPresent ? Colors.green.shade100 : Colors.red.shade100;
  }

  void _loadEmployeeLocations() {
    // Only load employee locations on mobile
    if (!kIsWeb) {
      AttendanceService.getEmployeeLocationsStream().listen((locations) {
        setState(() {
          markers = locations.map((emp) {
            return Marker(
              markerId: MarkerId(emp.userId),
              position: LatLng(emp.location.latitude, emp.location.longitude),
              infoWindow: InfoWindow(
                title: emp.userName,
                snippet: '${emp.status} - ${emp.location.address}',
              ),
              icon: emp.status == 'punched_in'
                  ? BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    )
                  : BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
            );
          }).toSet();
        });
      });
    }
  }

  Future<void> _punchIn() async {
    if (!mounted) return;

    setState(() => isLoading = true);
    try {
      await AttendanceService.punchIn();
      if (mounted) {
        await _loadTodayAttendance();
        await _loadAttendanceData();
        if (mounted) {
          setState(() => isLoading = false);
          _showSuccessSnackBar('Punched in successfully!');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackBar(e.toString());
      }
    }
  }

  Future<void> _punchOut() async {
    if (!mounted) return;

    setState(() => isLoading = true);
    try {
      await AttendanceService.punchOut();
      if (mounted) {
        await _loadTodayAttendance();
        await _loadAttendanceData();
        if (mounted) {
          setState(() => isLoading = false);
          _showSuccessSnackBar('Punched out successfully!');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackBar(e.toString());
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent default back behavior
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Handle back button press
          _handleBackButton(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            isAdmin ? 'Employee Tracking' : 'Attendance',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.indigo.shade600,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => _handleBackButton(context),
          ),
          actions: [
            if (isAdmin)
              IconButton(
                icon: Icon(Icons.analytics, color: Colors.white),
                onPressed: () => _showAttendanceRecords(),
              ),
          ],
        ),
        body: isAdmin ? _buildAdminView() : _buildEmployeeView(),
      ),
    );
  }

  void _handleBackButton(BuildContext context) {
    // Determine the appropriate back navigation based on user role
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

  Widget _buildEmployeeView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header with gradient background
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade600, Colors.purple.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Status Card
                    _buildModernStatusCard(),
                    SizedBox(height: 20),
                    // Punch Buttons
                    _buildModernPunchButtons(),
                  ],
                ),
              ),
            ),
          ),

          // Calendar Section
          Container(
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.indigo.shade600),
                      SizedBox(width: 12),
                      Text(
                        'Attendance Calendar',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildBeautifulCalendar(),
                _buildCalendarLegend(),
              ],
            ),
          ),

          // Location Map (if punched in and not on web)
          if (todayAttendance != null && !kIsWeb) _buildLocationCard(),

          // Location Info Card for Web (if punched in and on web)
          if (todayAttendance != null && kIsWeb) _buildLocationInfoCard(),

          // Today's Details
          if (todayAttendance != null) _buildTodayDetailsCard(),

          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildModernStatusCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Status Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: todayAttendance?.status == 'punched_in'
                  ? Colors.green.shade100
                  : todayAttendance?.status == 'punched_out'
                  ? Colors.blue.shade100
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              todayAttendance?.status == 'punched_in'
                  ? Icons.work
                  : todayAttendance?.status == 'punched_out'
                  ? Icons.home
                  : Icons.schedule,
              size: 40,
              color: todayAttendance?.status == 'punched_in'
                  ? Colors.green.shade600
                  : todayAttendance?.status == 'punched_out'
                  ? Colors.blue.shade600
                  : Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 16),

          // Status Text
          Text(
            todayAttendance?.status == 'punched_in'
                ? 'Currently Working'
                : todayAttendance?.status == 'punched_out'
                ? 'Work Complete'
                : 'Not Checked In',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade600,
            ),
          ),

          if (todayAttendance != null) ...[
            SizedBox(height: 8),
            Text(
              'Since ${DateFormat('HH:mm').format(todayAttendance!.punchInTime)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),

            if (todayAttendance!.status == 'punched_in') ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  '🕐 ${_getCurrentWorkingTime()}',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildModernPunchButtons() {
    if (isLoading) {
      return Container(
        height: 60,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 60,
            child: ElevatedButton.icon(
              onPressed: todayAttendance?.status != 'punched_in'
                  ? _punchIn
                  : null,
              icon: Icon(Icons.login, size: 24),
              label: Text(
                'Punch In',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: todayAttendance?.status != 'punched_in' ? 8 : 0,
                shadowColor: Colors.green.shade200,
              ),
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 60,
            child: ElevatedButton.icon(
              onPressed: todayAttendance?.status == 'punched_in'
                  ? _punchOut
                  : null,
              icon: Icon(Icons.logout, size: 24),
              label: Text(
                'Punch Out',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: todayAttendance?.status == 'punched_in' ? 8 : 0,
                shadowColor: Colors.red.shade200,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBeautifulCalendar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: TableCalendar<AttendanceRecord>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        eventLoader: _getEventsForDay,
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.monday,

        // Styling
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          weekendTextStyle: TextStyle(color: Colors.red.shade400),
          holidayTextStyle: TextStyle(color: Colors.red.shade400),

          // Today styling
          todayDecoration: BoxDecoration(
            color: Colors.indigo.shade400,
            shape: BoxShape.circle,
          ),

          // Selected day styling
          selectedDecoration: BoxDecoration(
            color: Colors.purple.shade400,
            shape: BoxShape.circle,
          ),

          // Event markers
          markerDecoration: BoxDecoration(
            color: Colors.green.shade600,
            shape: BoxShape.circle,
          ),

          // Default styling
          defaultDecoration: BoxDecoration(shape: BoxShape.circle),
        ),

        // Header styling
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade600,
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left,
            color: Colors.indigo.shade600,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: Colors.indigo.shade600,
          ),
        ),

        // Day builder for custom styling
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) {
            final events = _getEventsForDay(day);
            Color bgColor = Colors.transparent;

            if (events.isNotEmpty) {
              final hasCompleteDay = events.any(
                (e) => e.status == 'punched_out',
              );
              final hasPartialDay = events.any((e) => e.status == 'punched_in');

              if (hasCompleteDay) {
                bgColor = Colors.green.shade100;
              } else if (hasPartialDay) {
                bgColor = Colors.orange.shade100;
              }
            }

            return Container(
              margin: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: events.isNotEmpty
                    ? Border.all(
                        color: events.any((e) => e.status == 'punched_out')
                            ? Colors.green
                            : Colors.orange,
                        width: 2,
                      )
                    : null,
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: events.isNotEmpty ? Colors.white : Colors.black87,
                    fontWeight: events.isNotEmpty
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),

        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          _showDayDetails(selectedDay);
        },

        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
      ),
    );
  }

  Widget _buildCalendarLegend() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem(Colors.green, 'Present'),
          _buildLegendItem(Colors.orange, 'Partial'),
          _buildLegendItem(Colors.grey.shade300, 'Absent'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Modified Location Card - Only show on mobile
  Widget _buildLocationCard() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.location_on, color: Colors.red.shade400),
                SizedBox(width: 12),
                Text(
                  'Work Location',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 200,
            margin: EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GoogleMap(
                onMapCreated: (GoogleMapController controller) {
                  mapController = controller;
                },
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    todayAttendance!.punchInLocation.latitude,
                    todayAttendance!.punchInLocation.longitude,
                  ),
                  zoom: 16,
                ),
                markers: {
                  Marker(
                    markerId: MarkerId('punch_location'),
                    position: LatLng(
                      todayAttendance!.punchInLocation.latitude,
                      todayAttendance!.punchInLocation.longitude,
                    ),
                    infoWindow: InfoWindow(
                      title: 'Work Location',
                      snippet: todayAttendance!.punchInLocation.address,
                    ),
                  ),
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              todayAttendance!.punchInLocation.address,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // New Location Info Card - Show on web instead of map
  Widget _buildLocationInfoCard() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.red.shade400),
                SizedBox(width: 12),
                Text(
                  'Work Location',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Location details without map
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.place,
                        color: Colors.indigo.shade600,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Address:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    todayAttendance!.punchInLocation.address,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  SizedBox(height: 16),

                  Row(
                    children: [
                      Icon(
                        Icons.my_location,
                        color: Colors.indigo.shade600,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Coordinates:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Lat: ${todayAttendance!.punchInLocation.latitude.toStringAsFixed(6)}\n'
                    'Lng: ${todayAttendance!.punchInLocation.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 12),

            // Note for web users
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Interactive map is available on mobile app',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayDetailsCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today, color: Colors.blue.shade400),
              SizedBox(width: 12),
              Text(
                'Today\'s Summary',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade600,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          _buildDetailCard(
            'Check In',
            DateFormat('HH:mm:ss').format(todayAttendance!.punchInTime),
            Icons.login,
            Colors.green,
          ),

          SizedBox(height: 12),

          if (todayAttendance!.punchOutTime != null) ...[
            _buildDetailCard(
              'Check Out',
              DateFormat('HH:mm:ss').format(todayAttendance!.punchOutTime!),
              Icons.logout,
              Colors.red,
            ),

            SizedBox(height: 12),

            _buildDetailCard(
              'Total Hours',
              _calculateWorkingHours(),
              Icons.schedule,
              Colors.blue,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentWorkingTime() {
    if (todayAttendance?.status != 'punched_in') return '';

    final duration = DateTime.now().difference(todayAttendance!.punchInTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return '${hours}h ${minutes}m';
  }

  String _calculateWorkingHours() {
    if (todayAttendance?.punchOutTime == null) return 'Still working...';

    final duration = todayAttendance!.punchOutTime!.difference(
      todayAttendance!.punchInTime,
    );

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return '${hours}h ${minutes}m';
  }

  Widget _buildAttendanceStatistics() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Selector
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.date_range, color: Colors.indigo.shade600),
                SizedBox(width: 12),
                Text(
                  'Select Month',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo.shade600,
                  ),
                ),
                Spacer(),
                InkWell(
                  onTap: _selectMonth,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: Text(
                      DateFormat('MMM yyyy').format(_selectedMonth),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.indigo.shade700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Overall Statistics Summary
          if (_attendanceStats.isNotEmpty) _buildOverallSummary(),

          SizedBox(height: 16),

          // User-wise Statistics
          if (_attendanceStats.isNotEmpty) _buildUserWiseStatistics(),

          // Empty state
          if (_attendanceStats.isEmpty) _buildEmptyStatistics(),
        ],
      ),
    );
  }

  Widget _buildOverallSummary() {
    final totalUsers = _attendanceStats.length;
    final totalWorkingDays = _attendanceStats.values.first['workingDays'] ?? 0;
    final avgAttendance = _attendanceStats.values.isEmpty
        ? 0.0
        : _attendanceStats.values
                  .map((stats) => stats['attendancePercentage'] as double)
                  .reduce((a, b) => a + b) /
              totalUsers;

    final totalPresent = _attendanceStats.values
        .map((stats) => stats['presentDays'] as int)
        .reduce((a, b) => a + b);

    final totalAbsent = _attendanceStats.values
        .map((stats) => stats['absentDays'] as int)
        .reduce((a, b) => a + b);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade400, Colors.purple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                'Overall Statistics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Users',
                  totalUsers.toString(),
                  Icons.people,
                  Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Working Days',
                  totalWorkingDays.toString(),
                  Icons.calendar_today,
                  Colors.white,
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Avg Attendance',
                  '${avgAttendance.toStringAsFixed(1)}%',
                  Icons.trending_up,
                  Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Total Present',
                  totalPresent.toString(),
                  Icons.check_circle,
                  Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color textColor,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: textColor, size: 20),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.9)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUserWiseStatistics() {
    final sortedUsers = _attendanceStats.entries.toList()
      ..sort(
        (a, b) => b.value['attendancePercentage'].compareTo(
          a.value['attendancePercentage'],
        ),
      );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.person_search, color: Colors.indigo.shade600),
                SizedBox(width: 12),
                Text(
                  'User-wise Attendance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade600,
                  ),
                ),
              ],
            ),
          ),

          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: sortedUsers.length,
            separatorBuilder: (context, index) => Divider(height: 1),
            itemBuilder: (context, index) {
              final userId = sortedUsers[index].key;
              final stats = sortedUsers[index].value;

              return _buildUserStatCard(stats, index + 1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserStatCard(Map<String, dynamic> stats, int rank) {
    final attendancePercentage = stats['attendancePercentage'] as double;
    final presentDays = stats['presentDays'] as int;
    final absentDays = stats['absentDays'] as int;
    final lateDays = stats['lateDays'] as int;
    final workingDays = stats['workingDays'] as int;
    final avgHours = stats['averageWorkingHours'] as double;

    Color getPerformanceColor(double percentage) {
      if (percentage >= 90) return Colors.green;
      if (percentage >= 75) return Colors.orange;
      return Colors.red;
    }

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Header
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: getPerformanceColor(attendancePercentage),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats['userName'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      stats['userEmail'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: getPerformanceColor(
                    attendancePercentage,
                  ).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${attendancePercentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: getPerformanceColor(attendancePercentage),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Progress Bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              widthFactor: attendancePercentage / 100,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: getPerformanceColor(attendancePercentage),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          SizedBox(height: 16),

          // Statistics Grid
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Present',
                  presentDays.toString(),
                  Colors.green,
                  Icons.check_circle,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Absent',
                  absentDays.toString(),
                  Colors.red,
                  Icons.cancel,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Late',
                  lateDays.toString(),
                  Colors.orange,
                  Icons.schedule,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Avg Hours',
                  avgHours.toStringAsFixed(1),
                  Colors.blue,
                  Icons.access_time,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildEmptyStatistics() {
    return Container(
      padding: EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            'No Attendance Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'No attendance records found for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _selectMonth() async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedMonth,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDatePickerMode: DatePickerMode.year,
      );

      if (picked != null && mounted) {
        setState(() {
          _selectedMonth = picked;
        });
        // Run calculation asynchronously to prevent UI freeze
        Future.microtask(() => _calculateAttendanceStatistics());
      }
    } catch (e) {
      print('Error selecting month: $e');
      _showErrorSnackBar('Error selecting month: $e');
    }
  }

  void _showDayDetails(DateTime selectedDay) {
    final events = _getEventsForDay(selectedDay);
    if (events.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DayDetailsSheet(date: selectedDay, records: events),
    );
  }

  Widget _buildAdminView() {
    return DefaultTabController(
      length: 2, // Changed from 3 to 2
      child: Column(
        children: [
          // Tab Bar
          Container(
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.indigo.shade600,
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: TextStyle(fontWeight: FontWeight.w600),
              tabs: [
                Tab(icon: Icon(Icons.analytics), text: 'Statistics'),
                Tab(icon: Icon(Icons.location_on), text: 'User Locations'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              children: [
                // Statistics Tab
                _buildAttendanceStatistics(),

                // User Locations Tab
                _buildUserLocationsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserLocationsView() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.location_on, color: Colors.indigo.shade600),
                SizedBox(width: 12),
                Text(
                  'Current User Locations',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<EmployeeLocation>>(
              stream: AttendanceService.getEmployeeLocationsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final employees = snapshot.data ?? [];

                if (employees.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No Active Users',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No employees are currently active',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final emp = employees[index];

                    // Get today's attendance for punch-in time
                    return FutureBuilder<AttendanceRecord?>(
                      future: _getTodayAttendanceForUser(emp.userId),
                      builder: (context, attendanceSnapshot) {
                        final todayRecord = attendanceSnapshot.data;

                        return Container(
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: emp.status == 'punched_in'
                                  ? [
                                      Colors.green.shade50,
                                      Colors.green.shade100,
                                    ]
                                  : [Colors.red.shade50, Colors.red.shade100],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: emp.status == 'punched_in'
                                  ? Colors.green.shade200
                                  : Colors.red.shade200,
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // User Header
                                Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: emp.status == 'punched_in'
                                              ? [
                                                  Colors.green.shade400,
                                                  Colors.green.shade600,
                                                ]
                                              : [
                                                  Colors.red.shade400,
                                                  Colors.red.shade600,
                                                ],
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          emp.userName.isNotEmpty
                                              ? emp.userName[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            emp.userName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Colors.indigo.shade600,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            emp.userEmail,
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: emp.status == 'punched_in'
                                            ? Colors.green.shade600
                                            : Colors.red.shade600,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            emp.status == 'punched_in'
                                                ? Icons.work
                                                : Icons.work_off,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            emp.status == 'punched_in'
                                                ? 'Active'
                                                : 'Offline',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 16),

                                // Status Information
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      // Punch-in time
                                      if (todayRecord != null) ...[
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              color: Colors.blue.shade600,
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Punched In: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            Text(
                                              DateFormat(
                                                'HH:mm:ss',
                                              ).format(todayRecord.punchInTime),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8),

                                        // Working duration if active
                                        if (emp.status == 'punched_in') ...[
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.timer,
                                                color: Colors.green.shade600,
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Working for: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                              Text(
                                                _getWorkingDuration(
                                                  todayRecord.punchInTime,
                                                ),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                        ],
                                      ],

                                      // Location
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            color: Colors.red.shade600,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Location:',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  emp.location.address,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Lat: ${emp.location.latitude.toStringAsFixed(6)}, '
                                                  'Lng: ${emp.location.longitude.toStringAsFixed(6)}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade500,
                                                    fontFamily: 'monospace',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // View on Map Button - Only show on mobile
                                if (!kIsWeb) ...[
                                  SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _showUserLocationOnMap(emp),
                                      icon: Icon(Icons.map, size: 18),
                                      label: Text('View on Map'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.indigo.shade600,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],

                                // Web note
                                if (kIsWeb) ...[
                                  SizedBox(height: 12),
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info,
                                          color: Colors.blue.shade600,
                                          size: 14,
                                        ),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Interactive map available on mobile app',
                                            style: TextStyle(
                                              color: Colors.blue.shade700,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getWorkingDuration(DateTime punchInTime) {
    final duration = DateTime.now().difference(punchInTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  Future<AttendanceRecord?> _getTodayAttendanceForUser(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      final records = await AttendanceService.getAttendanceByDateRange(
        startOfDay,
        endOfDay,
      );

      return records
              .where(
                (record) =>
                    record.userId == userId && record.date.day == today.day,
              )
              .isNotEmpty
          ? records.firstWhere(
              (record) =>
                  record.userId == userId && record.date.day == today.day,
            )
          : null;
    } catch (e) {
      return null;
    }
  }

  // Modified - Only show map dialog on mobile
  void _showUserLocationOnMap(EmployeeLocation employee) {
    if (kIsWeb) {
      // On web, show a simple alert instead
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Map Not Available'),
          content: Text(
            'Interactive maps are only available on mobile devices. Location details are shown in the user card above.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Show map only on mobile
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          height: 400,
          width: 300,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade600,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${employee.userName}\'s Location',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      employee.location.latitude,
                      employee.location.longitude,
                    ),
                    zoom: 16,
                  ),
                  markers: {
                    Marker(
                      markerId: MarkerId(employee.userId),
                      position: LatLng(
                        employee.location.latitude,
                        employee.location.longitude,
                      ),
                      infoWindow: InfoWindow(
                        title: employee.userName,
                        snippet: employee.location.address,
                      ),
                      icon: employee.status == 'punched_in'
                          ? BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueGreen,
                            )
                          : BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueRed,
                            ),
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAttendanceRecords() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AttendanceRecordsSheet(),
    );
  }
}

// Day Details Sheet Widget
class DayDetailsSheet extends StatelessWidget {
  final DateTime date;
  final List<AttendanceRecord> records;

  const DayDetailsSheet({Key? key, required this.date, required this.records})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.indigo.shade600),
                SizedBox(width: 12),
                Text(
                  DateFormat('EEEE, MMM dd, yyyy').format(date),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Records
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 20),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: record.status == 'punched_in'
                                ? Colors.green.shade100
                                : Colors.blue.shade100,
                            child: Icon(
                              record.status == 'punched_in'
                                  ? Icons.work
                                  : Icons.home,
                              color: record.status == 'punched_in'
                                  ? Colors.green.shade600
                                  : Colors.blue.shade600,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record.userName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'In: ${DateFormat('HH:mm').format(record.punchInTime)}',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                if (record.punchOutTime != null)
                                  Text(
                                    'Out: ${DateFormat('HH:mm').format(record.punchOutTime!)}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: record.status == 'punched_in'
                                  ? Colors.green.shade100
                                  : Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              record.status == 'punched_in'
                                  ? 'Active'
                                  : 'Complete',
                              style: TextStyle(
                                color: record.status == 'punched_in'
                                    ? Colors.green.shade700
                                    : Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced Attendance Records Sheet
class AttendanceRecordsSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.analytics, color: Colors.indigo.shade600),
                SizedBox(width: 12),
                Text(
                  'Attendance Analytics',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Records
          Expanded(
            child: StreamBuilder<List<AttendanceRecord>>(
              stream: AttendanceService.getAllAttendanceStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final records = snapshot.data ?? [];

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: record.status == 'punched_in'
                                  ? [
                                      Colors.green.shade400,
                                      Colors.green.shade600,
                                    ]
                                  : [
                                      Colors.blue.shade400,
                                      Colors.blue.shade600,
                                    ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              record.userName.isNotEmpty
                                  ? record.userName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          record.userName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text(
                              '📅 ${DateFormat('dd/MM/yyyy').format(record.date)}',
                            ),
                            Text(
                              '🕐 In: ${DateFormat('HH:mm').format(record.punchInTime)}',
                            ),
                            if (record.punchOutTime != null)
                              Text(
                                '🕐 Out: ${DateFormat('HH:mm').format(record.punchOutTime!)}',
                              ),
                          ],
                        ),
                        trailing: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: record.status == 'punched_in'
                                ? Colors.green.shade100
                                : Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            record.status == 'punched_in'
                                ? 'Active'
                                : 'Complete',
                            style: TextStyle(
                              color: record.status == 'punched_in'
                                  ? Colors.green.shade700
                                  : Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
