import 'package:flutter/material.dart';

class BadgeInfo {
  final String label;
  final Color color;
  final IconData icon;

  const BadgeInfo(this.label, this.color, this.icon);
}

/// Points needed before each tier begins.
const int kBronzeTier = 100;
const int kSilverTier = 500;
const int kGoldTier = 1000;

/// The tier a user has reached, or null if they have not reached Bronze yet.
BadgeInfo? tierForPoints(num points) {
  if (points >= kGoldTier) {
    return const BadgeInfo('Gold', Color(0xFFFFB020), Icons.emoji_events_rounded);
  }
  if (points >= kSilverTier) {
    return const BadgeInfo('Silver', Color(0xFF9AA5B1), Icons.workspace_premium_rounded);
  }
  if (points >= kBronzeTier) {
    return const BadgeInfo('Bronze', Color(0xFFCD7F32), Icons.military_tech_rounded);
  }
  return null;
}

/// The next tier the user is working towards and how many points remain.
///
/// Returns null once the top tier is reached.
({String tier, int needed})? nextTierGoal(num points) {
  if (points >= kGoldTier) return null;

  final int target = points >= kSilverTier
      ? kGoldTier
      : points >= kBronzeTier
          ? kSilverTier
          : kBronzeTier;

  final String tier = points >= kSilverTier
      ? 'Gold'
      : points >= kBronzeTier
          ? 'Silver'
          : 'Bronze';

  return (tier: tier, needed: (target - points).ceil().clamp(0, target));
}