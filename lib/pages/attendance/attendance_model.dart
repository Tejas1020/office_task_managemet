// lib/models/attendance.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final DateTime punchInTime;
  final DateTime? punchOutTime;
  final LocationData punchInLocation;
  final LocationData? punchOutLocation;
  final String status; // 'punched_in', 'punched_out'
  final DateTime date;

  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.punchInTime,
    this.punchOutTime,
    required this.punchInLocation,
    this.punchOutLocation,
    required this.status,
    required this.date,
  });

  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return AttendanceRecord(
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
      date: (data['date'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'userName': userName,
    'userEmail': userEmail,
    'punchInTime': Timestamp.fromDate(punchInTime),
    'punchOutTime': punchOutTime != null
        ? Timestamp.fromDate(punchOutTime!)
        : null,
    'punchInLocation': punchInLocation.toMap(),
    'punchOutLocation': punchOutLocation?.toMap(),
    'status': status,
    'date': Timestamp.fromDate(date),
  };
}

class LocationData {
  final double latitude;
  final double longitude;
  final String address;
  final double? accuracy;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.accuracy,
  });

  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      address: map['address'] ?? '',
      accuracy: map['accuracy']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'accuracy': accuracy,
  };
}

class EmployeeLocation {
  final String userId;
  final String userName;
  final String userEmail;
  final LocationData location;
  final DateTime lastUpdated;
  final String status;

  EmployeeLocation({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.location,
    required this.lastUpdated,
    required this.status,
  });

  factory EmployeeLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return EmployeeLocation(
      userId: doc.id,
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      location: LocationData.fromMap(data['location']),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      status: data['status'] ?? 'offline',
    );
  }

  Map<String, dynamic> toMap() => {
    'userName': userName,
    'userEmail': userEmail,
    'location': location.toMap(),
    'lastUpdated': Timestamp.fromDate(lastUpdated),
    'status': status,
  };
}
