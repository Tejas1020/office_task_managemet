// Add this import to the top of any page where you want to test
import 'package:flutter/material.dart';
import 'package:office_task_managemet/notifications/notifications.dart';

// Add this widget to any page (e.g., in your HomePage)
class NotificationTestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Notification Test Panel',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),

          // Test basic notification
          ElevatedButton(
            onPressed: () async {
              print('🔥 Test button pressed!');
              await NotificationService.showTestNotification();
            },
            child: Text('Test Notification'),
          ),

          SizedBox(height: 8),

          // Check if notifications are enabled
          ElevatedButton(
            onPressed: () async {
              final enabled =
                  await NotificationService.areNotificationsEnabled();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Notifications enabled: $enabled')),
              );
            },
            child: Text('Check Notification Status'),
          ),

          SizedBox(height: 8),

          // Re-initialize notifications
          ElevatedButton(
            onPressed: () async {
              await NotificationService.initialize();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Notification service re-initialized')),
              );
            },
            child: Text('Re-initialize Notifications'),
          ),
        ],
      ),
    );
  }
}
