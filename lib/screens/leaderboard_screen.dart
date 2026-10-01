import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'badge_helper.dart';
import 'demo_data.dart';
import 'ui_helpers.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Leaderboard'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('points', descending: true)
            .limit(100)
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final List<_Player> players = _collect(snapshot.data?.docs ?? []);
          final String? mine = players
              .where((_Player p) => p.uid == currentUid)
              .map((_Player p) => p.uid)
              .cast<String?>()
              .firstWhere((_) => true, orElse: () => null);

          if (players.isEmpty) {
            return const Center(child: Text('No rankings yet.'));
          }

          final List<_Player> podium =
              players.take(3).toList(growable: false);
          final List<_Player> rest =
              players.skip(3).take(7).toList(growable: false);

          // A player outside the top 10 gets their own row pinned below.
          _Player? outsider;
          if (mine != null) {
            for (int i = 0; i < players.length; i++) {
              if (players[i].uid == mine && i >= 10) {
                outsider = players[i];
                break;
              }
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _Podium(players: podium, currentUid: currentUid),
              const SizedBox(height: 26),
              const _ListHeading('Top 10'),
              const SizedBox(height: 12),
              for (int i = 0; i < rest.length; i++)
                _RankRow(
                  rank: i + 4,
                  player: rest[i],
                  isMe: rest[i].uid == currentUid,
                ),
              if (rest.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Not enough recyclers yet to fill the table.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kTextMuted),
                  ),
                ),
              if (outsider != null) ...[
                const SizedBox(height: 18),
                const _ListHeading('Your position'),
                const SizedBox(height: 12),
                _RankRow(
                  rank: players.indexOf(outsider) + 1,
                  player: outsider,
                  isMe: true,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Merges live Firestore rows with demo players, ranked by points. In review
  /// mode the sample recyclers are always blended in so the podium and the
  /// full top 10 are populated even when only one real account exists.
  static List<_Player> _collect(List<QueryDocumentSnapshot> docs) {
    final List<_Player> players = docs
        .where((QueryDocumentSnapshot doc) {
          final Map<String, dynamic> data =
              (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
          return (data['role'] ?? 'user') != 'admin';
        })
        .map((QueryDocumentSnapshot doc) {
          final Map<String, dynamic> data =
              (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
          return _Player(
            uid: doc.id,
            nickname: '${data['nickname'] ?? data['name'] ?? 'User'}',
            avatar: '${data['avatarIcon'] ?? '🙂'}',
            points: (data['points'] ?? 0) as num,
          );
        })
        .toList();

    if (kDemoMode) {
      final Set<String> existing =
          players.map((_Player p) => p.uid).toSet();
      for (final DemoUser demo in demoUsers) {
        if (!existing.contains(demo.uid)) {
          players.add(
            _Player(
              uid: demo.uid,
              nickname: demo.nickname,
              avatar: demo.avatar,
              points: demo.points,
            ),
          );
        }
      }
    }

    players.sort((_Player a, _Player b) => b.points.compareTo(a.points));
    return players;
  }
}

class _Player {
  const _Player({
    required this.uid,
    required this.nickname,
    required this.avatar,
    required this.points,
  });

  final String uid;
  final String nickname;
  final String avatar;
  final num points;
}

class _ListHeading extends StatelessWidget {
  const _ListHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: kTextDark,
      ),
    );
  }
}

/// Three adjacent pastel cards: 2nd, 1st (raised), 3rd.
class _Podium extends StatelessWidget {
  const _Podium({required this.players, required this.currentUid});

  final List<_Player> players;
  final String? currentUid;

  /// Pastel tints for second, first and third.
  static const List<Color> tints = [
    Color(0xFFE4EFE9), // 2nd — pale sage
    Color(0xFFFFF1CC), // 1st — pale gold
    Color(0xFFE8EBF8), // 3rd — soft periwinkle
  ];

  static const List<Color> accents = [
    Color(0xFF2C7F63),
    Color(0xFFC08A00),
    Color(0xFF5A64A8),
  ];

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const SizedBox.shrink();

    // Arrange so first place sits in the middle and sits taller than the rest.
    final List<int> ranks = players.length >= 3
        ? [2, 1, 3]
        : List<int>.generate(players.length, (int i) => i + 1);
    final List<_Player> arranged = players.length >= 3
        ? [players[1], players[0], players[2]]
        : players;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int column = 0; column < arranged.length; column++)
          Expanded(
            child: _PodiumCard(
              rank: ranks[column],
              player: arranged[column],
              tint: tints[column % tints.length],
              accent: accents[column % accents.length],
              isWinner: ranks[column] == 1,
              isMe: arranged[column].uid == currentUid,
            ),
          ),
      ],
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.rank,
    required this.player,
    required this.tint,
    required this.accent,
    required this.isWinner,
    required this.isMe,
  });

  final int rank;
  final _Player player;
  final Color tint;
  final Color accent;
  final bool isWinner;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, isWinner ? 0 : 16, 4, 0),
      child: Container(
        padding: EdgeInsets.fromLTRB(9, isWinner ? 14 : 12, 9, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tint, Color.lerp(tint, Colors.white, 0.55)!],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isMe ? kPrimaryColor : accent.withValues(alpha: 0.28),
            width: isMe ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isWinner ? 0.30 : 0.16),
              blurRadius: isWinner ? 22 : 12,
              offset: Offset(0, isWinner ? 11 : 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Position sits at the top.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, Color.lerp(accent, Colors.black, 0.18)!],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isWinner) ...[
                    const Icon(
                      Icons.emoji_events_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    '$rank',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isWinner ? 12 : 9),
            Container(
              width: isWinner ? 58 : 46,
              height: isWinner ? 58 : 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                player.avatar,
                style: TextStyle(fontSize: isWinner ? 28 : 22),
              ),
            ),
            SizedBox(height: isWinner ? 10 : 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                player.nickname,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isWinner ? 13.5 : 12.5,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: kTextDark,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${player.points} pts',
                style: TextStyle(
                  fontSize: isWinner ? 13.5 : 12,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact row for ranks 4 through 10.
class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.player, required this.isMe});

  final int rank;
  final _Player player;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final BadgeInfo? tier = tierForPoints(player.points);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isMe ? kPastelMint : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isMe ? Border.all(color: kPrimaryColor, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: kPrimaryDark.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '#$rank',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: kTextDark,
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kPastelMint,
              shape: BoxShape.circle,
            ),
            child: Text(player.avatar, style: const TextStyle(fontSize: 19)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 2),
                if (tier != null)
                  Row(
                    children: [
                      Icon(tier.icon, size: 13, color: tier.color),
                      const SizedBox(width: 4),
                      Text(
                        tier.label,
                        style: TextStyle(fontSize: 11.5, color: tier.color),
                      ),
                    ],
                  )
                else
                  Text(
                    '${nextTierGoal(player.points)?.needed ?? 0} pts to ${nextTierGoal(player.points)?.tier ?? 'next tier'}',
                    style: const TextStyle(fontSize: 11.5, color: kTextMuted),
                  ),
              ],
            ),
          ),
          Text(
            '${player.points} pts',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: kPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }
}