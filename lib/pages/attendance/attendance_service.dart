// lib/services/attendance_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:office_task_managemet/pages/attendance/attendance_model.dart';

class AttendanceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check location permissions and get current position
  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  // Get address from coordinates
  static Future<String> getAddressFromCoordinates(
    double lat,
    double lng,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.locality}, ${place.administrativeArea}';
      }
      return 'Unknown location';
    } catch (e) {
      print('Error getting address: $e');
      return 'Location: $lat, $lng';
    }
  }

  // Punch In - COMPLETELY INDEX-FREE VERSION
  static Future<void> punchIn() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      print('🕐 Checking if already punched in today...');

      // Use only userId filter (single field = no index needed)
      final userRecords = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: user.uid)
          .get();

      // Filter and check in app
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      for (var doc in userRecords.docs) {
        try {
          final data = doc.data();
          final recordDate = (data['date'] as Timestamp).toDate();
          final recordDateOnly = DateTime(
            recordDate.year,
            recordDate.month,
            recordDate.day,
          );
          final status = data['status'] ?? '';

          // If found today's record and still punched in
          if (recordDateOnly.isAtSameMomentAs(todayStart) &&
              status == 'punched_in') {
            throw Exception('Already punched in today');
          }
        } catch (e) {
          // Skip malformed records
          continue;
        }
      }

      print('🗺️ Getting current location...');

      // Get current location
      final position = await getCurrentLocation();
      if (position == null) throw Exception('Could not get location');

      print(
        '📍 Location obtained: ${position.latitude}, ${position.longitude}',
      );

      final address = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      print('🏠 Address resolved: $address');

      final locationData = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        accuracy: position.accuracy,
      );

      // Create attendance record with simple structure
      final attendanceData = {
        'userId': user.uid,
        'userName': user.displayName ?? 'Unknown',
        'userEmail': user.email ?? '',
        'punchInTime': Timestamp.fromDate(DateTime.now()),
        'punchOutTime': null,
        'punchInLocation': locationData.toMap(),
        'punchOutLocation': null,
        'status': 'punched_in',
        'date': Timestamp.fromDate(DateTime.now()),
      };

      print('💾 Saving attendance record to Firestore...');

      await _firestore.collection('attendance').add(attendanceData);

      print('📍 Updating employee location for real-time tracking...');

      // Update employee location for real-time tracking
      await updateEmployeeLocation(locationData, 'punched_in');

      print('✅ Punched in successfully');
    } catch (e) {
      print('❌ Error punching in: $e');
      throw e;
    }
  }

  // Punch Out - COMPLETELY INDEX-FREE VERSION
  static Future<void> punchOut() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      print('🔍 Finding today\'s punch-in record...');

      // Use only userId filter (single field = no index needed)
      final userRecords = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: user.uid)
          .get();

      // Find today's punch-in record
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      String? recordIdToUpdate;

      for (var doc in userRecords.docs) {
        try {
          final data = doc.data();
          final recordDate = (data['date'] as Timestamp).toDate();
          final recordDateOnly = DateTime(
            recordDate.year,
            recordDate.month,
            recordDate.day,
          );
          final status = data['status'] ?? '';

          // If found today's record and still punched in
          if (recordDateOnly.isAtSameMomentAs(todayStart) &&
              status == 'punched_in') {
            recordIdToUpdate = doc.id;
            break;
          }
        } catch (e) {
          // Skip malformed records
          continue;
        }
      }

      if (recordIdToUpdate == null) {
        throw Exception('No punch-in record found for today');
      }

      print('📍 Getting current location for punch out...');

      // Get current location
      final position = await getCurrentLocation();
      if (position == null) throw Exception('Could not get location');

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

      print('💾 Updating attendance record...');

      // Update attendance record
      await _firestore.collection('attendance').doc(recordIdToUpdate).update({
        'punchOutTime': Timestamp.fromDate(DateTime.now()),
        'punchOutLocation': locationData.toMap(),
        'status': 'punched_out',
      });

      print('📍 Updating employee location...');

      // Update employee location
      await updateEmployeeLocation(locationData, 'punched_out');

      print('✅ Punched out successfully');
    } catch (e) {
      print('❌ Error punching out: $e');
      throw e;
    }
  }

  // Update employee location for real-time tracking
  static Future<void> updateEmployeeLocation(
    LocationData location,
    String status,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final employeeLocation = EmployeeLocation(
        userId: user.uid,
        userName: user.displayName ?? 'Unknown',
        userEmail: user.email ?? '',
        location: location,
        lastUpdated: DateTime.now(),
        status: status,
      );

      await _firestore
          .collection('employee_locations')
          .doc(user.uid)
          .set(employeeLocation.toMap());
    } catch (e) {
      print('❌ Error updating employee location: $e');
    }
  }

  // Get today's attendance status - COMPLETELY INDEX-FREE VERSION
  static Future<AttendanceRecord?> getTodayAttendance() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      print('📅 Getting today\'s attendance status...');

      // Use only userId filter (single field = no index needed)
      final userRecords = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: user.uid)
          .get();

      // Find today's record by filtering in app
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      AttendanceRecord? todayRecord;

      for (var doc in userRecords.docs) {
        try {
          final data = doc.data();
          final recordDate = (data['date'] as Timestamp).toDate();
          final recordDateOnly = DateTime(
            recordDate.year,
            recordDate.month,
            recordDate.day,
          );

          // If found today's record
          if (recordDateOnly.isAtSameMomentAs(todayStart)) {
            // Convert to AttendanceRecord
            todayRecord = AttendanceRecord(
              id: doc.id,
              userId: data['userId'] ?? '',
              userName: data['userName'] ?? '',
              userEmail: data['userEmail'] ?? '',
              punchInTime: (data['punchInTime'] as Timestamp).toDate(),
              punchOutTime: data['punchOutTime'] != null
                  ? (data['punchOutTime'] as Timestamp).toDate()
                  : null,
              punchInLocation: LocationData.fromMap(data['punchInLocation']),
              punchOutLocation: data['punchOutLocation'] != null
                  ? LocationData.fromMap(data['punchOutLocation'])
                  : null,
              status: data['status'] ?? 'punched_in',
              date: recordDate,
            );
            break; // Found today's record, exit loop
          }
        } catch (e) {
          // Skip malformed records
          continue;
        }
      }

      if (todayRecord != null) {
        print('✅ Found today\'s attendance record: ${todayRecord.status}');
      } else {
        print('ℹ️ No attendance record found for today');
      }

      return todayRecord;
    } catch (e) {
      print('❌ Error getting today\'s attendance: $e');
      return null;
    }
  }

  // Get all employee locations (Admin only)
  static Stream<List<EmployeeLocation>> getEmployeeLocationsStream() {
    return _firestore
        .collection('employee_locations')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => EmployeeLocation.fromFirestore(doc))
              .toList(),
        );
  }

  // Get all attendance records (Admin only) - INDEX-FREE VERSION
  static Stream<List<AttendanceRecord>> getAllAttendanceStream() {
    // Use simple query without orderBy to avoid index
    return _firestore.collection('attendance').snapshots().map((snapshot) {
      final records = snapshot.docs
          .map((doc) {
            try {
              return AttendanceRecord.fromFirestore(doc);
            } catch (e) {
              // Skip malformed records
              return null;
            }
          })
          .where((record) => record != null)
          .cast<AttendanceRecord>()
          .toList();

      // Sort in app instead of Firestore
      records.sort((a, b) => b.date.compareTo(a.date));
      return records;
    });
  }

  // Get attendance records for a specific date range - INDEX-FREE VERSION
  static Future<List<AttendanceRecord>> getAttendanceByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      print('📊 Getting attendance records for date range...');

      // Use simple query without where clauses for date
      final snapshot = await _firestore.collection('attendance').get();

      // Filter in app by date range
      final filteredRecords = <AttendanceRecord>[];

      for (var doc in snapshot.docs) {
        try {
          final record = AttendanceRecord.fromFirestore(doc);

          // Check if record date is within range
          if (record.date.isAfter(startDate.subtract(Duration(days: 1))) &&
              record.date.isBefore(endDate.add(Duration(days: 1)))) {
            filteredRecords.add(record);
          }
        } catch (e) {
          // Skip malformed records
          continue;
        }
      }

      // Sort in app
      filteredRecords.sort((a, b) => b.date.compareTo(a.date));

      print('✅ Found ${filteredRecords.length} records in date range');
      return filteredRecords;
    } catch (e) {
      print('❌ Error getting attendance by date range: $e');
      return [];
    }
  }

  // Check if user is admin
  static bool isAdmin() {
    final user = _auth.currentUser;
    return user?.email?.toLowerCase().endsWith('@admin.com') ?? false;
  }
}

