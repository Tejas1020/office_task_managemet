// // lib/services/attendance_service.dart

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:office_task_managemet/pages/attendance/attendance_model.dart';

// class AttendanceService {
//   static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   static final FirebaseAuth _auth = FirebaseAuth.instance;

//   // Check location permissions and get current position
//   static Future<Position?> getCurrentLocation() async {
//     try {
//       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) {
//         throw Exception('Location services are disabled');
//       }

//       LocationPermission permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//         if (permission == LocationPermission.denied) {
//           throw Exception('Location permissions are denied');
//         }
//       }

//       if (permission == LocationPermission.deniedForever) {
//         throw Exception('Location permissions are permanently denied');
//       }

//       return await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//     } catch (e) {
//       print('Error getting location: $e');
//       return null;
//     }
//   }

//   // Get address from coordinates
//   static Future<String> getAddressFromCoordinates(
//     double lat,
//     double lng,
//   ) async {
//     try {
//       List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
//       if (placemarks.isNotEmpty) {
//         Placemark place = placemarks[0];
//         return '${place.street}, ${place.locality}, ${place.administrativeArea}';
//       }
//       return 'Unknown location';
//     } catch (e) {
//       print('Error getting address: $e');
//       return 'Location: $lat, $lng';
//     }
//   }

//   // Punch In - COMPLETELY INDEX-FREE VERSION
//   static Future<void> punchIn() async {
//     try {
//       final user = _auth.currentUser;
//       if (user == null) throw Exception('User not logged in');

//       print('🕐 Checking if already punched in today...');

//       // Use only userId filter (single field = no index needed)
//       final userRecords = await _firestore
//           .collection('attendance')
//           .where('userId', isEqualTo: user.uid)
//           .get();

//       // Filter and check in app
//       final today = DateTime.now();
//       final todayStart = DateTime(today.year, today.month, today.day);

//       for (var doc in userRecords.docs) {
//         try {
//           final data = doc.data();
//           final recordDate = (data['date'] as Timestamp).toDate();
//           final recordDateOnly = DateTime(
//             recordDate.year,
//             recordDate.month,
//             recordDate.day,
//           );
//           final status = data['status'] ?? '';

//           // If found today's record and still punched in
//           if (recordDateOnly.isAtSameMomentAs(todayStart) &&
//               status == 'punched_in') {
//             throw Exception('Already punched in today');
//           }
//         } catch (e) {
//           // Skip malformed records
//           continue;
//         }
//       }

//       print('🗺️ Getting current location...');

//       // Get current location
//       final position = await getCurrentLocation();
//       if (position == null) throw Exception('Could not get location');

//       print(
//         '📍 Location obtained: ${position.latitude}, ${position.longitude}',
//       );

//       final address = await getAddressFromCoordinates(
//         position.latitude,
//         position.longitude,
//       );

//       print('🏠 Address resolved: $address');

//       final locationData = LocationData(
//         latitude: position.latitude,
//         longitude: position.longitude,
//         address: address,
//         accuracy: position.accuracy,
//       );

//       // Create attendance record with simple structure
//       final attendanceData = {
//         'userId': user.uid,
//         'userName': user.displayName ?? 'Unknown',
//         'userEmail': user.email ?? '',
//         'punchInTime': Timestamp.fromDate(DateTime.now()),
//         'punchOutTime': null,
//         'punchInLocation': locationData.toMap(),
//         'punchOutLocation': null,
//         'status': 'punched_in',
//         'date': Timestamp.fromDate(DateTime.now()),
//       };

//       print('💾 Saving attendance record to Firestore...');

//       await _firestore.collection('attendance').add(attendanceData);

//       print('📍 Updating employee location for real-time tracking...');

//       // Update employee location for real-time tracking
//       await updateEmployeeLocation(locationData, 'punched_in');

//       print('✅ Punched in successfully');
//     } catch (e) {
//       print('❌ Error punching in: $e');
//       throw e;
//     }
//   }

//   // Punch Out - COMPLETELY INDEX-FREE VERSION
//   static Future<void> punchOut() async {
//     try {
//       final user = _auth.currentUser;
//       if (user == null) throw Exception('User not logged in');

//       print('🔍 Finding today\'s punch-in record...');

//       // Use only userId filter (single field = no index needed)
//       final userRecords = await _firestore
//           .collection('attendance')
//           .where('userId', isEqualTo: user.uid)
//           .get();

//       // Find today's punch-in record
//       final today = DateTime.now();
//       final todayStart = DateTime(today.year, today.month, today.day);

//       String? recordIdToUpdate;

//       for (var doc in userRecords.docs) {
//         try {
//           final data = doc.data();
//           final recordDate = (data['date'] as Timestamp).toDate();
//           final recordDateOnly = DateTime(
//             recordDate.year,
//             recordDate.month,
//             recordDate.day,
//           );
//           final status = data['status'] ?? '';

//           // If found today's record and still punched in
//           if (recordDateOnly.isAtSameMomentAs(todayStart) &&
//               status == 'punched_in') {
//             recordIdToUpdate = doc.id;
//             break;
//           }
//         } catch (e) {
//           // Skip malformed records
//           continue;
//         }
//       }

//       if (recordIdToUpdate == null) {
//         throw Exception('No punch-in record found for today');
//       }

//       print('📍 Getting current location for punch out...');

//       // Get current location
//       final position = await getCurrentLocation();
//       if (position == null) throw Exception('Could not get location');

//       final address = await getAddressFromCoordinates(
//         position.latitude,
//         position.longitude,
//       );

//       final locationData = LocationData(
//         latitude: position.latitude,
//         longitude: position.longitude,
//         address: address,
//         accuracy: position.accuracy,
//       );

//       print('💾 Updating attendance record...');

//       // Update attendance record
//       await _firestore.collection('attendance').doc(recordIdToUpdate).update({
//         'punchOutTime': Timestamp.fromDate(DateTime.now()),
//         'punchOutLocation': locationData.toMap(),
//         'status': 'punched_out',
//       });

//       print('📍 Updating employee location...');

//       // Update employee location
//       await updateEmployeeLocation(locationData, 'punched_out');

//       print('✅ Punched out successfully');
//     } catch (e) {
//       print('❌ Error punching out: $e');
//       throw e;
//     }
//   }

//   // Update employee location for real-time tracking
//   static Future<void> updateEmployeeLocation(
//     LocationData location,
//     String status,
//   ) async {
//     try {
//       final user = _auth.currentUser;
//       if (user == null) return;

//       final employeeLocation = EmployeeLocation(
//         userId: user.uid,
//         userName: user.displayName ?? 'Unknown',
//         userEmail: user.email ?? '',
//         location: location,
//         lastUpdated: DateTime.now(),
//         status: status,
//       );

//       await _firestore
//           .collection('employee_locations')
//           .doc(user.uid)
//           .set(employeeLocation.toMap());
//     } catch (e) {
//       print('❌ Error updating employee location: $e');
//     }
//   }

//   // Get today's attendance status - COMPLETELY INDEX-FREE VERSION
//   static Future<AttendanceRecord?> getTodayAttendance() async {
//     try {
//       final user = _auth.currentUser;
//       if (user == null) return null;

//       print('📅 Getting today\'s attendance status...');

//       // Use only userId filter (single field = no index needed)
//       final userRecords = await _firestore
//           .collection('attendance')
//           .where('userId', isEqualTo: user.uid)
//           .get();

//       // Find today's record by filtering in app
//       final today = DateTime.now();
//       final todayStart = DateTime(today.year, today.month, today.day);

//       AttendanceRecord? todayRecord;

//       for (var doc in userRecords.docs) {
//         try {
//           final data = doc.data();
//           final recordDate = (data['date'] as Timestamp).toDate();
//           final recordDateOnly = DateTime(
//             recordDate.year,
//             recordDate.month,
//             recordDate.day,
//           );

//           // If found today's record
//           if (recordDateOnly.isAtSameMomentAs(todayStart)) {
//             // Convert to AttendanceRecord
//             todayRecord = AttendanceRecord(
//               id: doc.id,
//               userId: data['userId'] ?? '',
//               userName: data['userName'] ?? '',
//               userEmail: data['userEmail'] ?? '',
//               punchInTime: (data['punchInTime'] as Timestamp).toDate(),
//               punchOutTime: data['punchOutTime'] != null
//                   ? (data['punchOutTime'] as Timestamp).toDate()
//                   : null,
//               punchInLocation: LocationData.fromMap(data['punchInLocation']),
//               punchOutLocation: data['punchOutLocation'] != null
//                   ? LocationData.fromMap(data['punchOutLocation'])
//                   : null,
//               status: data['status'] ?? 'punched_in',
//               date: recordDate,
//             );
//             break; // Found today's record, exit loop
//           }
//         } catch (e) {
//           // Skip malformed records
//           continue;
//         }
//       }

//       if (todayRecord != null) {
//         print('✅ Found today\'s attendance record: ${todayRecord.status}');
//       } else {
//         print('ℹ️ No attendance record found for today');
//       }

//       return todayRecord;
//     } catch (e) {
//       print('❌ Error getting today\'s attendance: $e');
//       return null;
//     }
//   }

//   // Get all employee locations (Admin only)
//   static Stream<List<EmployeeLocation>> getEmployeeLocationsStream() {
//     return _firestore
//         .collection('employee_locations')
//         .snapshots()
//         .map(
//           (snapshot) => snapshot.docs
//               .map((doc) => EmployeeLocation.fromFirestore(doc))
//               .toList(),
//         );
//   }

//   // Get all attendance records (Admin only) - INDEX-FREE VERSION
//   static Stream<List<AttendanceRecord>> getAllAttendanceStream() {
//     // Use simple query without orderBy to avoid index
//     return _firestore.collection('attendance').snapshots().map((snapshot) {
//       final records = snapshot.docs
//           .map((doc) {
//             try {
//               return AttendanceRecord.fromFirestore(doc);
//             } catch (e) {
//               // Skip malformed records
//               return null;
//             }
//           })
//           .where((record) => record != null)
//           .cast<AttendanceRecord>()
//           .toList();

//       // Sort in app instead of Firestore
//       records.sort((a, b) => b.date.compareTo(a.date));
//       return records;
//     });
//   }

//   // Get attendance records for a specific date range - INDEX-FREE VERSION
//   static Future<List<AttendanceRecord>> getAttendanceByDateRange(
//     DateTime startDate,
//     DateTime endDate,
//   ) async {
//     try {
//       print('📊 Getting attendance records for date range...');

//       // Use simple query without where clauses for date
//       final snapshot = await _firestore.collection('attendance').get();

//       // Filter in app by date range
//       final filteredRecords = <AttendanceRecord>[];

//       for (var doc in snapshot.docs) {
//         try {
//           final record = AttendanceRecord.fromFirestore(doc);

//           // Check if record date is within range
//           if (record.date.isAfter(startDate.subtract(Duration(days: 1))) &&
//               record.date.isBefore(endDate.add(Duration(days: 1)))) {
//             filteredRecords.add(record);
//           }
//         } catch (e) {
//           // Skip malformed records
//           continue;
//         }
//       }

//       // Sort in app
//       filteredRecords.sort((a, b) => b.date.compareTo(a.date));

//       print('✅ Found ${filteredRecords.length} records in date range');
//       return filteredRecords;
//     } catch (e) {
//       print('❌ Error getting attendance by date range: $e');
//       return [];
//     }
//   }

//   // Check if user is admin
//   static bool isAdmin() {
//     final user = _auth.currentUser;
//     return user?.email?.toLowerCase().endsWith('@admin.com') ?? false;
//   }
// }



// lib/services/attendance_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:office_task_managemet/pages/attendance/attendance_model.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class AttendanceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if running on iOS
  static bool _isIOS() {
    try {
      return !kIsWeb && Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  // Enhanced location permissions check with iOS-specific handling
  static Future<Position?> getCurrentLocation() async {
    try {
      debugPrint('🗺️ Checking location services...');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Location services are disabled');
        throw Exception(
          'Please enable location services in your device settings',
        );
      }

      debugPrint('✅ Location services are enabled');

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('📍 Current permission status: $permission');

      // Handle denied permissions
      if (permission == LocationPermission.denied) {
        debugPrint('🔒 Location permission denied, requesting...');
        permission = await Geolocator.requestPermission();
        debugPrint('📍 Permission after request: $permission');

        if (permission == LocationPermission.denied) {
          throw Exception(
            'Location permissions are required for attendance tracking',
          );
        }
      }

      // Handle permanently denied permissions
      if (permission == LocationPermission.deniedForever) {
        debugPrint('🚫 Location permissions permanently denied');
        throw Exception(
          'Location permissions are permanently denied. Please enable them in device settings.',
        );
      }

      debugPrint('📍 Getting current position...');

      // iOS-specific location settings
      LocationSettings locationSettings;
      if (_isIOS()) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.high,
          activityType: ActivityType.other,
          distanceFilter: 10,
        );
      } else {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
          forceLocationManager: false,
        );
      }

      // Get current position with timeout for iOS
      final position =
          await Geolocator.getCurrentPosition(
            locationSettings: locationSettings,
          ).timeout(
            Duration(seconds: _isIOS() ? 15 : 10), // Longer timeout for iOS
            onTimeout: () {
              throw Exception('Location request timed out. Please try again.');
            },
          );

      debugPrint(
        '✅ Position obtained: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } catch (e) {
      debugPrint('❌ Error getting location: $e');

      // Provide user-friendly error messages
      if (e.toString().contains('timeout')) {
        throw Exception(
          'Location request timed out. Please ensure you have good GPS signal and try again.',
        );
      } else if (e.toString().contains('denied')) {
        throw Exception(
          'Location access denied. Please enable location permissions for this app.',
        );
      } else {
        throw Exception(
          'Could not get your location. Please check your GPS settings and try again.',
        );
      }
    }
  }

  // Enhanced address resolution with error handling
  static Future<String> getAddressFromCoordinates(
    double lat,
    double lng,
  ) async {
    try {
      debugPrint('🏠 Getting address for coordinates: $lat, $lng');

      // Add timeout for iOS compatibility
      final placemarks = await placemarkFromCoordinates(lat, lng).timeout(
        Duration(seconds: _isIOS() ? 10 : 5),
        onTimeout: () {
          debugPrint('⏰ Address lookup timed out');
          return <Placemark>[];
        },
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        final address = _buildAddressString(place);
        debugPrint('✅ Address resolved: $address');
        return address;
      }

      debugPrint('⚠️ No address found, using coordinates');
      return 'Location: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    } catch (e) {
      debugPrint('❌ Error getting address: $e');
      return 'Location: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    }
  }

  // Helper method to build address string safely
  static String _buildAddressString(Placemark place) {
    final components = <String>[];

    if (place.street?.isNotEmpty == true) components.add(place.street!);
    if (place.locality?.isNotEmpty == true) components.add(place.locality!);
    if (place.administrativeArea?.isNotEmpty == true)
      components.add(place.administrativeArea!);
    if (place.country?.isNotEmpty == true) components.add(place.country!);

    return components.isNotEmpty ? components.join(', ') : 'Unknown location';
  }

  // Enhanced punch in with better error handling
  static Future<void> punchIn() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Please log in to continue');
      }

      debugPrint('👤 User: ${user.email}');
      debugPrint('🕐 Checking if already punched in today...');

      // Check if already punched in today
      final existingRecord = await _getTodayAttendanceRecord(user.uid);
      if (existingRecord != null && existingRecord['status'] == 'punched_in') {
        throw Exception('You are already punched in today');
      }

      debugPrint('📍 Getting current location...');

      // Get current location with enhanced error handling
      final position = await getCurrentLocation();
      if (position == null) {
        throw Exception(
          'Could not determine your location. Please ensure GPS is enabled.',
        );
      }

      debugPrint('🏠 Resolving address...');
      final address = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final locationData = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        accuracy: position.accuracy,
      );

      debugPrint('💾 Creating attendance record...');

      // Create attendance record with validation
      final attendanceData = {
        'userId': user.uid,
        'userName': user.displayName ?? user.email?.split('@')[0] ?? 'Unknown',
        'userEmail': user.email ?? '',
        'punchInTime': Timestamp.fromDate(DateTime.now()),
        'punchOutTime': null,
        'punchInLocation': locationData.toMap(),
        'punchOutLocation': null,
        'status': 'punched_in',
        'date': Timestamp.fromDate(DateTime.now()),
        'createdAt': Timestamp.fromDate(
          DateTime.now(),
        ), // Add creation timestamp
      };

      // Save to Firestore with timeout
      await _firestore
          .collection('attendance')
          .add(attendanceData)
          .timeout(Duration(seconds: 10));

      debugPrint('📍 Updating employee location...');

      // Update employee location for real-time tracking
      await updateEmployeeLocation(locationData, 'punched_in');

      debugPrint('✅ Punch in completed successfully');
    } catch (e) {
      debugPrint('❌ Error in punchIn: $e');
      rethrow; // Re-throw to maintain original error message
    }
  }

  // Enhanced punch out with better error handling
  static Future<void> punchOut() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Please log in to continue');
      }

      debugPrint('🔍 Finding today\'s punch-in record...');

      // Find today's active record
      final existingRecord = await _getTodayAttendanceRecord(user.uid);
      if (existingRecord == null) {
        throw Exception('No punch-in record found for today');
      }

      if (existingRecord['status'] != 'punched_in') {
        throw Exception('You are already punched out for today');
      }

      debugPrint('📍 Getting current location for punch out...');

      // Get current location
      final position = await getCurrentLocation();
      if (position == null) {
        throw Exception('Could not determine your location for punch out');
      }

      final address = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final locationData = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        accuracy: position.accuracy,
      );

      debugPrint('💾 Updating attendance record...');

      // Update attendance record with timeout
      await _firestore
          .collection('attendance')
          .doc(existingRecord['docId'])
          .update({
            'punchOutTime': Timestamp.fromDate(DateTime.now()),
            'punchOutLocation': locationData.toMap(),
            'status': 'punched_out',
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          })
          .timeout(Duration(seconds: 10));

      debugPrint('📍 Updating employee location...');

      // Update employee location
      await updateEmployeeLocation(locationData, 'punched_out');

      debugPrint('✅ Punch out completed successfully');
    } catch (e) {
      debugPrint('❌ Error in punchOut: $e');
      rethrow;
    }
  }

  // Helper method to get today's attendance record safely
  static Future<Map<String, dynamic>?> _getTodayAttendanceRecord(
    String userId,
  ) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      debugPrint('🔍 Searching for records between $startOfDay and $endOfDay');

      // Query with timeout
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .limit(50) // Limit results to prevent large data loads
          .get()
          .timeout(Duration(seconds: 10));

      debugPrint(
        '📊 Found ${querySnapshot.docs.length} total records for user',
      );

      // Filter in app to find today's record
      for (var doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          final recordDate = (data['date'] as Timestamp).toDate();

          // Check if record is from today
          if (recordDate.isAfter(startOfDay.subtract(Duration(minutes: 1))) &&
              recordDate.isBefore(endOfDay)) {
            debugPrint(
              '✅ Found today\'s record with status: ${data['status']}',
            );
            return {...data, 'docId': doc.id};
          }
        } catch (e) {
          debugPrint('⚠️ Skipping malformed record: $e');
          continue;
        }
      }

      debugPrint('ℹ️ No record found for today');
      return null;
    } catch (e) {
      debugPrint('❌ Error finding today\'s record: $e');
      return null;
    }
  }

  // Enhanced employee location update with error handling
  static Future<void> updateEmployeeLocation(
    LocationData location,
    String status,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final employeeLocation = EmployeeLocation(
        userId: user.uid,
        userName: user.displayName ?? user.email?.split('@')[0] ?? 'Unknown',
        userEmail: user.email ?? '',
        location: location,
        lastUpdated: DateTime.now(),
        status: status,
      );

      await _firestore
          .collection('employee_locations')
          .doc(user.uid)
          .set(employeeLocation.toMap(), SetOptions(merge: true))
          .timeout(Duration(seconds: 10));

      debugPrint('✅ Employee location updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating employee location: $e');
      // Don't throw error for location update failure
    }
  }

  // Enhanced today's attendance with better error handling
  static Future<AttendanceRecord?> getTodayAttendance() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ No user logged in');
        return null;
      }

      debugPrint('📅 Getting today\'s attendance for user: ${user.email}');

      final recordData = await _getTodayAttendanceRecord(user.uid);
      if (recordData == null) {
        debugPrint('ℹ️ No attendance record found for today');
        return null;
      }

      // Convert to AttendanceRecord safely
      final record = AttendanceRecord(
        id: recordData['docId'],
        userId: recordData['userId'] ?? '',
        userName: recordData['userName'] ?? 'Unknown',
        userEmail: recordData['userEmail'] ?? '',
        punchInTime: (recordData['punchInTime'] as Timestamp).toDate(),
        punchOutTime: recordData['punchOutTime'] != null
            ? (recordData['punchOutTime'] as Timestamp).toDate()
            : null,
        punchInLocation: LocationData.fromMap(recordData['punchInLocation']),
        punchOutLocation: recordData['punchOutLocation'] != null
            ? LocationData.fromMap(recordData['punchOutLocation'])
            : null,
        status: recordData['status'] ?? 'punched_in',
        date: (recordData['date'] as Timestamp).toDate(),
      );

      debugPrint('✅ Today\'s attendance record found: ${record.status}');
      return record;
    } catch (e) {
      debugPrint('❌ Error getting today\'s attendance: $e');
      return null;
    }
  }

  // Enhanced employee locations stream with error handling
  static Stream<List<EmployeeLocation>> getEmployeeLocationsStream() {
    return _firestore
        .collection('employee_locations')
        .snapshots()
        .handleError((error) {
          debugPrint('❌ Error in employee locations stream: $error');
        })
        .map((snapshot) {
          try {
            return snapshot.docs
                .map((doc) {
                  try {
                    return EmployeeLocation.fromFirestore(doc);
                  } catch (e) {
                    debugPrint('⚠️ Skipping malformed employee location: $e');
                    return null;
                  }
                })
                .where((location) => location != null)
                .cast<EmployeeLocation>()
                .toList();
          } catch (e) {
            debugPrint('❌ Error processing employee locations: $e');
            return <EmployeeLocation>[];
          }
        });
  }

  // Enhanced all attendance stream with error handling
  static Stream<List<AttendanceRecord>> getAllAttendanceStream() {
    return _firestore
        .collection('attendance')
        .limit(100) // Limit to prevent large data loads
        .snapshots()
        .handleError((error) {
          debugPrint('❌ Error in attendance stream: $error');
        })
        .map((snapshot) {
          try {
            final records = snapshot.docs
                .map((doc) {
                  try {
                    return AttendanceRecord.fromFirestore(doc);
                  } catch (e) {
                    debugPrint('⚠️ Skipping malformed attendance record: $e');
                    return null;
                  }
                })
                .where((record) => record != null)
                .cast<AttendanceRecord>()
                .toList();

            // Sort by date descending
            records.sort((a, b) => b.date.compareTo(a.date));
            return records;
          } catch (e) {
            debugPrint('❌ Error processing attendance records: $e');
            return <AttendanceRecord>[];
          }
        });
  }

  // Enhanced date range query with better error handling
  static Future<List<AttendanceRecord>> getAttendanceByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      debugPrint('📊 Getting attendance records from $startDate to $endDate');

      // Add safety checks
      if (startDate.isAfter(endDate)) {
        debugPrint('❌ Start date is after end date');
        return [];
      }

      final daysDifference = endDate.difference(startDate).inDays;
      if (daysDifference > 365) {
        debugPrint(
          '⚠️ Date range too large ($daysDifference days), limiting to last 90 days',
        );
        startDate = DateTime.now().subtract(Duration(days: 90));
      }

      // Query with timeout
      final snapshot = await _firestore
          .collection('attendance')
          .limit(500) // Limit results
          .get()
          .timeout(Duration(seconds: 15));

      debugPrint('📊 Retrieved ${snapshot.docs.length} records from Firestore');

      // Filter and process records safely
      final filteredRecords = <AttendanceRecord>[];
      int processedCount = 0;
      int errorCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final record = AttendanceRecord.fromFirestore(doc);

          // Check if record is within date range
          if (record.date.isAfter(startDate.subtract(Duration(days: 1))) &&
              record.date.isBefore(endDate.add(Duration(days: 1)))) {
            filteredRecords.add(record);
          }
          processedCount++;
        } catch (e) {
          errorCount++;
          debugPrint('⚠️ Error processing record ${doc.id}: $e');
          continue;
        }
      }

      debugPrint(
        '✅ Processed $processedCount records, $errorCount errors, ${filteredRecords.length} in range',
      );

      // Sort by date descending
      filteredRecords.sort((a, b) => b.date.compareTo(a.date));

      return filteredRecords;
    } catch (e) {
      debugPrint('❌ Error getting attendance by date range: $e');
      return [];
    }
  }

  // Enhanced admin check
  static bool isAdmin() {
    try {
      final user = _auth.currentUser;
      final email = user?.email?.toLowerCase();
      final isAdminUser = email?.endsWith('@admin.com') ?? false;
      debugPrint('👤 Admin check for $email: $isAdminUser');
      return isAdminUser;
    } catch (e) {
      debugPrint('❌ Error checking admin status: $e');
      return false;
    }
  }

  // Helper method to test Firestore connectivity
  static Future<bool> testFirestoreConnection() async {
    try {
      debugPrint('🔗 Testing Firestore connection...');

      await _firestore
          .collection('_test')
          .limit(1)
          .get()
          .timeout(Duration(seconds: 5));

      debugPrint('✅ Firestore connection successful');
      return true;
    } catch (e) {
      debugPrint('❌ Firestore connection failed: $e');
      return false;
    }
  }

  // Helper method to get user info safely
  static Map<String, String> getCurrentUserInfo() {
    try {
      final user = _auth.currentUser;
      return {
        'uid': user?.uid ?? '',
        'email': user?.email ?? '',
        'displayName':
            user?.displayName ?? user?.email?.split('@')[0] ?? 'Unknown',
      };
    } catch (e) {
      debugPrint('❌ Error getting user info: $e');
      return {'uid': '', 'email': '', 'displayName': 'Unknown'};
    }
  }
}
