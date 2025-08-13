import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:office_task_managemet/notifications/notifications.dart';

// Import your ChatScreen from its file
import 'package:office_task_managemet/pages/messages/chat_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppUser Model
// ─────────────────────────────────────────────────────────────────────────────
class AppUser {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String? role;
  final String? department;
  final bool isOnline;
  final DateTime? lastSeen;

  AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.role,
    this.department,
    this.isOnline = false,
    this.lastSeen,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      displayName: data['displayName'] ?? 'Unknown User',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      role: data['role'],
      department: data['department'],
      isOnline: data['isOnline'] ?? false,
      lastSeen: data['lastSeen'] != null
          ? (data['lastSeen'] as Timestamp).toDate()
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message Model
// ─────────────────────────────────────────────────────────────────────────────
enum MessageType { text, image, file }

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final MessageType type;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.type = MessageType.text,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      type: MessageType.values[data['type'] ?? 0],
    );
  }

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'receiverId': receiverId,
    'content': content,
    'timestamp': Timestamp.fromDate(timestamp),
    'isRead': isRead,
    'type': type.index,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Firebase Service
// ─────────────────────────────────────────────────────────────────────────────
class FirebaseService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Set or merge the user document so it always exists when updating status
  static Future<void> updateUserOnlineStatus(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = _firestore.collection('users').doc(user.uid);
    await doc.set({
      'displayName': user.displayName ?? '',
      'email': user.email ?? '',
      'photoUrl': user.photoURL,
      'isOnline': isOnline,
      'lastSeen': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  /// Stream all users except the logged-in one
  static Stream<List<AppUser>> getUsersStream() {
    final currentUid = _auth.currentUser?.uid;
    return _firestore
        .collection('users')
        .where(FieldPath.documentId, isNotEqualTo: currentUid)
        .snapshots()
        .map((snap) => snap.docs.map((d) => AppUser.fromFirestore(d)).toList());
  }

  /// Stream messages for a 1-on-1 conversation, then sort by timestamp
  static Stream<List<Message>> getMessagesStream(
    String yourUid,
    String otherUid,
  ) {
    return _firestore
        .collection('messages')
        .where('participants', arrayContains: yourUid)
        .snapshots()
        .map((snap) {
          final convo = snap.docs
              .map((d) => Message.fromFirestore(d))
              .where(
                (m) =>
                    (m.senderId == yourUid && m.receiverId == otherUid) ||
                    (m.senderId == otherUid && m.receiverId == yourUid),
              )
              .toList();

          convo.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return convo;
        });
  }

  /// Send a new message with improved real-time triggering
  static Future<void> sendMessage(Message msg) async {
    try {
      print('📤 Sending message: ${msg.content}');
      print('   - From: ${msg.senderId}');
      print('   - To: ${msg.receiverId}');

      // Add the message to Firestore with server timestamp for accuracy
      await _firestore.collection('messages').add({
        'senderId': msg.senderId,
        'receiverId': msg.receiverId,
        'content': msg.content,
        'timestamp': FieldValue.serverTimestamp(), // Use server timestamp
        'isRead': msg.isRead,
        'type': msg.type.index,
        'participants': [msg.senderId, msg.receiverId],
      });

      print('📤 Message sent successfully!');

      // Optional: Update user's last activity
      await updateUserOnlineStatus(true);
    } catch (e) {
      print('❌ Error sending message: $e');
      throw e; // Re-throw so UI can handle it
    }
  }

  /// Listen for new messages and show notifications - SIMPLIFIED VERSION (No Index Required)
  static void startNotificationListener() {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) {
      print('❌ No current user, cannot start notification listener');
      return;
    }

    print('🔔 Starting SIMPLIFIED notification listener for user: $currentUid');

    // Simple approach: Listen to all messages, filter in app (no index needed)
    _firestore
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(20) // Only get recent messages
        .snapshots()
        .listen(
          (snapshot) {
            // Only process newly added documents
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                try {
                  final message = Message.fromFirestore(change.doc);

                  // Filter in app: Check if this message is for current user and not from them
                  if (message.receiverId == currentUid &&
                      message.senderId != currentUid) {
                    // Check if this is a recent message (within last 30 seconds)
                    final messageAge = DateTime.now().difference(
                      message.timestamp,
                    );
                    if (messageAge.inSeconds <= 30) {
                      print('🔔 NEW INCOMING MESSAGE DETECTED:');
                      print('   - From: ${message.senderId}');
                      print('   - Content: ${message.content}');
                      print('   - Age: ${messageAge.inSeconds} seconds');

                      // Show notification immediately
                      _showNotificationForMessage(message);
                    } else {
                      print(
                        '🔔 Skipping old message (${messageAge.inSeconds}s old)',
                      );
                    }
                  }
                } catch (e) {
                  print('❌ Error processing message change: $e');
                }
              }
            }
          },
          onError: (error) {
            print('❌ Error in notification listener: $error');
          },
        );

    print('🔔 Simplified notification listener started successfully!');
  }

  static Future<void> _showNotificationForMessage(Message message) async {
    try {
      // Prevent duplicate notifications using a simple cache
      final notificationKey =
          '${message.senderId}_${message.timestamp.millisecondsSinceEpoch}';

      print('🔔 Processing notification for key: $notificationKey');
      print('🔔 Getting sender info for notification...');

      // Get sender info
      final senderDoc = await _firestore
          .collection('users')
          .doc(message.senderId)
          .get();

      String senderName = 'Someone';
      if (senderDoc.exists) {
        final senderData = senderDoc.data()!;
        senderName = senderData['displayName'] ?? 'Unknown User';
        print('🔔 Sender name resolved: $senderName');
      } else {
        print('⚠️ Sender document not found, using default name');
      }

      print('🔔 Calling NotificationService.showMessageNotification...');

      await NotificationService.showMessageNotification(
        senderName: senderName,
        message: message.content,
        senderId: message.senderId,
      );
    } catch (e) {
      print('❌ Error in _showNotificationForMessage: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MessagesPage Widget
// ─────────────────────────────────────────────────────────────────────────────
class MessagesPage extends StatefulWidget {
  const MessagesPage({Key? key}) : super(key: key);

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage>
    with WidgetsBindingObserver {
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FirebaseService.updateUserOnlineStatus(true);

    // Notification listener is now started from main.dart
    // No need to start it here again
  }

  @override
  void dispose() {
    FirebaseService.updateUserOnlineStatus(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    FirebaseService.updateUserOnlineStatus(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),

        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users…',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (t) => setState(() => searchQuery = t),
            ),
          ),

          // Users list
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: FirebaseService.getUsersStream(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                final users = (snap.data ?? []).where((u) {
                  final q = searchQuery.toLowerCase();
                  return u.displayName.toLowerCase().contains(q) ||
                      u.email.toLowerCase().contains(q) ||
                      (u.role?.toLowerCase().contains(q) ?? false) ||
                      (u.department?.toLowerCase().contains(q) ?? false);
                }).toList();

                if (users.isEmpty) {
                  return const Center(child: Text('No users found'));
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (_, i) => UserTile(
                    user: users[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(user: users[i]),
                      ),
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// UserTile Widget
// ─────────────────────────────────────────────────────────────────────────────
class UserTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback onTap;

  const UserTile({Key? key, required this.user, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Stack(
        children: [
          // avatar
          CircleAvatar(
            radius: 28,
            backgroundImage: user.photoUrl != null
                ? NetworkImage(user.photoUrl!)
                : null,
            backgroundColor: user.photoUrl == null
                ? _getAvatarColor(user.displayName)
                : Colors.grey[200],
            child: user.photoUrl == null
                ? Text(
                    user.displayName
                        .split(' ')
                        .map((e) => e[0])
                        .take(2)
                        .join()
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          // online badge
          if (user.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        user.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.role != null)
            Text(
              user.role!,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          Row(
            children: [
              if (user.department != null) ...[
                const Icon(Icons.business_center, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  user.department!,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
              if (!user.isOnline && user.lastSeen != null) ...[
                const SizedBox(width: 8),
                Text(
                  '• ${_getLastSeenText(user.lastSeen!)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
    );
  }

  String _getLastSeenText(DateTime lastSeen) {
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return 'Offline';
  }

  Color _getAvatarColor(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
    ];
    return colors[name.length % colors.length];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MessageBubble Widget
// ─────────────────────────────────────────────────────────────────────────────
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String userName;
  final String? userPhotoUrl;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.userName,
    this.userPhotoUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: userPhotoUrl != null
                  ? NetworkImage(userPhotoUrl!)
                  : null,
              backgroundColor: userPhotoUrl == null
                  ? _getAvatarColor(userName)
                  : Colors.grey[200],
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Theme.of(context).primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _formatTime(DateTime ts) {
    final h = ts.hour.toString().padLeft(2, '0');
    final m = ts.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Color _getAvatarColor(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
    ];
    return colors[name.length % colors.length];
  }
}
