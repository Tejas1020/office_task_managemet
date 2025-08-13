// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      print('🔔 Initializing notification service...');

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final initialized = await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          print('Notification clicked: ${response.payload}');
        },
      );

      print('🔔 Notification initialization result: $initialized');

      // Request permissions explicitly
      await _requestPermissions();

      // Create notification channel
      await _createNotificationChannel();

      _initialized = true;
      print('🔔 Notification service initialized successfully!');
    } catch (e) {
      print('❌ Error initializing notifications: $e');
    }
  }

  static Future<void> _requestPermissions() async {
    try {
      print('🔔 Requesting notification permissions...');

      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        print('🔔 Android notification permission granted: $granted');

        // Removed exact alarm permission - we don't need it for simple notifications
      }

      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();

      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        print('🔔 iOS notification permission granted: $granted');
      }
    } catch (e) {
      print('❌ Error requesting permissions: $e');
    }
  }

  static Future<void> _createNotificationChannel() async {
    try {
      print('🔔 Creating notification channel...');

      const androidChannel = AndroidNotificationChannel(
        'messages_channel',
        'Messages',
        description: 'Notifications for new messages',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidChannel);
        print('🔔 Notification channel created successfully!');
      }
    } catch (e) {
      print('❌ Error creating notification channel: $e');
    }
  }

  static Future<void> showMessageNotification({
    required String senderName,
    required String message,
    required String senderId,
  }) async {
    try {
      // Don't show notification for your own messages
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.uid == senderId) {
        print('🔔 Skipping notification - message from self');
        return;
      }

      print('🔔 ⚡ INSTANT NOTIFICATION TRIGGERED ⚡');
      print('🔔 Sender: $senderName');
      print('🔔 Message: $message');
      print('🔔 Initialized: $_initialized');

      if (!_initialized) {
        print('❌ Notification service not initialized! Re-initializing...');
        await initialize();
      }

      const androidDetails = AndroidNotificationDetails(
        'messages_channel',
        'Messages',
        channelDescription: 'Notifications for new messages',
        importance: Importance.max, // Changed to max for immediate display
        priority: Priority.max, // Changed to max for immediate display
        ticker: 'New message',
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        autoCancel: true,
        ongoing: false,
        fullScreenIntent: true, // Added for immediate attention
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive, // Added for iOS
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _notifications.show(
        notificationId,
        senderName,
        message,
        details,
        payload: 'message_$senderId',
      );

      print('🔔 ✅ NOTIFICATION DISPLAYED IMMEDIATELY! ID: $notificationId');
    } catch (e) {
      print('❌ Error showing notification: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  // Test notification method
  static Future<void> showTestNotification() async {
    try {
      print('🔔 Showing test notification...');

      await showMessageNotification(
        senderName: "Test User",
        message: "This is a test notification! 📱",
        senderId: "test_user_123",
      );
    } catch (e) {
      print('❌ Test notification failed: $e');
    }
  }

  // Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    try {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        final enabled = await androidPlugin.areNotificationsEnabled() ?? false;
        print('🔔 Notifications enabled: $enabled');
        return enabled;
      }

      return true; // Assume enabled for iOS
    } catch (e) {
      print('❌ Error checking notification status: $e');
      return false;
    }
  }
}
