import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'demo_data.dart';
import 'design_system.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static IconData _iconFor(String title) {
    final String t = title.toLowerCase();
    if (t.contains('reward') || t.contains('redeem')) {
      return Icons.card_giftcard_rounded;
    }
    if (t.contains('rank') || t.contains('leaderboard') || t.contains('position')) {
      return Icons.leaderboard_rounded;
    }
    if (t.contains('deposit') || t.contains('point')) {
      return Icons.recycling_rounded;
    }
    if (t.contains('welcome')) {
      return Icons.waving_hand_rounded;
    }
    return Icons.notifications_active_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;


    if (user == null) {
      return const SignedOutView();
    }

    return Scaffold(
      backgroundColor: kAdminBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .doc(user.uid)
            .collection('items')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data?.docs ?? [];

          final bool useDemo = items.isEmpty && kDemoMode;

          final List<_Note> notes = useDemo
              ? demoNotifications
                  .map((DemoNotification n) => _Note(
                        title: n.title,
                        body: n.body,
                        read: n.read,
                        when: n.when,
                      ))
                  .toList()
              : items
                  .map((QueryDocumentSnapshot doc) {
                    final Map<String, dynamic> data =
                        (doc.data() as Map<String, dynamic>?) ??
                            <String, dynamic>{};
                    final Timestamp? ts = data['timestamp'] as Timestamp?;
                    return _Note(
                      title: '${data['title'] ?? ''}',
                      body: '${data['body'] ?? ''}',
                      read: data['read'] ?? false,
                      when: ts?.toDate(),
                    );
                  })
                  .toList();

          final int unread = notes.where((_Note n) => !n.read).length;

          if (notes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        color: kMetricTealTint,
                        shape: BoxShape.circle,
                      ),

                      child: const Icon(
                        Icons.notifications_none_rounded,
                        size: 34,
                        color: kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Nothing new',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Updates about your deposits, points and rewards will show up here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, color: kTextMuted),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _Header(unread: unread),
              const SizedBox(height: 16),
              for (final _Note note in notes)
                _NoteCard(
                  note: note,
                  icon: _iconFor(note.title),
                ),

            ],
          );
        },
      ),
    );
  }
}

class _Note {
  const _Note({
    required this.title,
    required this.body,
    required this.read,
    this.when,
  });

  final String title;
  final String body;
  final bool read;
  final DateTime? when;
}

class _Header extends StatelessWidget {
  const _Header({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kMetricTeal.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: kPrimaryDark.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kMetricTealTint,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: kMetricTeal,
              size: 22,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unread == 0 ? 'All caught up' : '$unread unread',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  unread == 0
                      ? 'You have read every update.'
                      : 'Open an item below to see the details.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.icon,
  });

  final _Note note;
  final IconData icon;


  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: note.read ? Colors.white : kMetricTealTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: note.read
              ? kMetricTeal.withValues(alpha: 0.14)
              : kMetricTeal.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: kPrimaryDark.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: note.read
                  ? kMetricTealTint.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              size: 20,
              color: note.read ? kTextMuted : kMetricTeal,
            ),
          ),

          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: note.read ? kTextMuted : kTextDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  note.body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: note.read ? kTextMuted : kTextDark,
                  ),
                ),
                if (note.when != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${note.when!.day}/${note.when!.month}/${note.when!.year}  •  '
                    '${note.when!.hour.toString().padLeft(2, '0')}:'
                    '${note.when!.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: kTextMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
