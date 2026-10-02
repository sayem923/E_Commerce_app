import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'skeleton_widgets.dart';

/// এই পেজ কাজ করার জন্য Supabase এ একটা `notifications` টেবিল ও একটা
/// trigger লাগবে (README_FIXES.md এ পুরো SQL দেওয়া আছে)।
///
/// টেবিল:
///   id, user_id (uuid), title (text), body (text), order_id (bigint, nullable),
///   is_read (bool, default false), created_at (timestamptz, default now())
///
/// এটা app বন্ধ থাকা অবস্থায় push notification পাঠায় না — শুধু app খোলা
/// থাকলে বা খুললে in-app এ notification list/badge দেখায়।
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _supabase = Supabase.instance.client;

  Future<void> _markAsRead(String id) async {
    try {
      await _supabase.from('notifications').update({'is_read': true}).eq('id', id);
    } catch (e) {
      debugPrint("Mark as read error: $e");
    }
  }

  Future<void> _markAllAsRead(List<Map<String, dynamic>> notifications) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase.from('notifications').update({'is_read': true}).eq('user_id', user.id).eq('is_read', false);
    } catch (e) {
      debugPrint("Mark all as read error: $e");
    }
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final created = DateTime.tryParse(createdAt);
    if (created == null) return '';
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return "এইমাত্র";
    if (diff.inMinutes < 60) return "${diff.inMinutes} মিনিট আগে";
    if (diff.inHours < 24) return "${diff.inHours} ঘন্টা আগে";
    return "${diff.inDays} দিন আগে";
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    final notificationsStream = _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user?.id ?? '')
        .order('created_at', ascending: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: notificationsStream,
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              if (items.isEmpty) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => _markAllAsRead(items),
                child: const Text("Mark all read", style: TextStyle(color: Colors.orange)),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListSkeleton();
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 15),
                  const Text(
                    "কোনো Notification নেই",
                    style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: Colors.orange,
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final bool isRead = item['is_read'] == true;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isRead ? Colors.grey.shade200 : Colors.orange.shade100,
                      child: Icon(Icons.notifications, color: isRead ? Colors.grey : Colors.orange[800], size: 20),
                    ),
                    title: Text(
                      item['title']?.toString() ?? '',
                      style: TextStyle(fontWeight: isRead ? FontWeight.w500 : FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(item['body']?.toString() ?? ''),
                        const SizedBox(height: 4),
                        Text(_timeAgo(item['created_at']?.toString()), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    onTap: () {
                      if (!isRead) _markAsRead(item['id'].toString());
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Bottom-nav বা drawer এ notification icon-এর পাশে unread count badge দেখানোর
/// জন্য ছোট্ট reusable widget।
class NotificationBadge extends StatelessWidget {
  final Widget child;

  const NotificationBadge({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return child;

    final stream = supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final unreadCount = (snapshot.data ?? []).where((n) => n['is_read'] != true).length;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (unreadCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
