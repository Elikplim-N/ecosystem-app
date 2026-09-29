import 'package:flutter/material.dart';

class BadgeInfo {
  final String label;
  final Color color;
  final IconData icon;

  const BadgeInfo(this.label, this.color, this.icon);
}

BadgeInfo getBadgeForPoints(num points) {
  if (points >= 1000) {
    return const BadgeInfo('Gold', Color(0xFFFFB020), Icons.emoji_events);
  } else if (points >= 500) {
    return const BadgeInfo('Silver', Color(0xFF9AA5B1), Icons.emoji_events);
  } else if (points >= 100) {
    return const BadgeInfo('Bronze', Color(0xFFCD7F32), Icons.emoji_events);
  }
  return const BadgeInfo('Newcomer', Color(0xFF00C896), Icons.eco);
}