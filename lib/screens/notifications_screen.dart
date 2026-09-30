import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'ui_helpers.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = ApiService().currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('No user is logged in')));
    }

    final notifications = [
      {
        'title': 'Welcome to BoaMe 🌱',
        'body': 'Your account is ready! Drop by any BoaMe RVM kiosk to deposit plastic bottles and earn rewards.',
        'time': 'Just now',
        'read': false,
      },
      if (user.rfidUid != null && user.rfidUid!.isNotEmpty)
        {
          'title': 'RFID Card Linked 💳',
          'body': 'Card UID ${user.rfidUid} is active. You can tap and deposit immediately at any kiosk.',
          'time': 'Recent',
          'read': true,
        },
      if (user.bottles > 0)
        {
          'title': 'Deposit Confirmed 🎉',
          'body': 'You recycled ${user.bottles} bottle(s) and earned ${user.points} points. Keep up the green impact!',
          'time': 'Recent',
          'read': true,
        },
    ];

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(title: const Text('Notifications')),
      body: notifications.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none, size: 60, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No notifications yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final item = notifications[index];
                final title = item['title'] as String;
                final body = item['body'] as String;
                final time = item['time'] as String;
                final read = item['read'] as bool;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: read ? Colors.white : kPrimaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: read ? null : Border.all(color: kPrimaryColor.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          Text(time, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(body, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    ],
                  ),
                );
              },
            ),
    );
  }
}