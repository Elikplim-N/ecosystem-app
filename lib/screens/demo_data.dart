/// Placeholder content so every screen can be reviewed before real Firebase
/// data exists.
///
/// Flip [kDemoMode] to false to hide all of it — every screen falls back to
/// its real empty state when this is off.
library;

import '../models/app_role.dart';
import '../models/member.dart';

const bool kDemoMode = true;

class DemoUser {
  const DemoUser({
    required this.uid,
    required this.nickname,
    required this.avatar,
    required this.points,
    required this.bottles,
    required this.weight,
  });

  final String uid;
  final String nickname;
  final String avatar;
  final int points;
  final int bottles;
  final double weight;
}

class DemoReward {
  const DemoReward({
    required this.title,
    required this.description,
    required this.costPoints,
    this.type = 'standard',
    this.partnerName,
  });

  final String title;
  final String description;
  final int costPoints;
  final String type;
  final String? partnerName;
}

class DemoDeposit {
  const DemoDeposit({
    required this.points,
    required this.weight,
    required this.bottleType,
    required this.when,
  });

  final int points;
  final double weight;
  final String bottleType;
  final DateTime when;
}

class DemoNotification {
  const DemoNotification({
    required this.title,
    required this.body,
    required this.read,
    required this.when,
  });

  final String title;
  final String body;
  final bool read;
  final DateTime when;
}

// ============================================================
// SAMPLES
// ============================================================

const List<DemoUser> demoUsers = [
  DemoUser(
    uid: 'd1',
    nickname: 'Amara Osei',
    avatar: '🌿',
    points: 1420,
    bottles: 268,
    weight: 214.5,
  ),
  DemoUser(
    uid: 'd2',
    nickname: 'Thabo Nkosi',
    avatar: '🦁',
    points: 1180,
    bottles: 221,
    weight: 187.2,
  ),
  DemoUser(
    uid: 'd3',
    nickname: 'Lerato Molefe',
    avatar: '🐢',
    points: 960,
    bottles: 184,
    weight: 152.8,
  ),
  DemoUser(
    uid: 'd4',
    nickname: 'Chidi Eze',
    avatar: '⚽',
    points: 740,
    bottles: 149,
    weight: 121.4,
  ),
  DemoUser(
    uid: 'd5',
    nickname: 'Naledi Dube',
    avatar: '🌻',
    points: 610,
    bottles: 132,
    weight: 104.9,
  ),
  DemoUser(
    uid: 'd6',
    nickname: 'Kofi Mensah',
    avatar: '🚀',
    points: 520,
    bottles: 118,
    weight: 96.3,
  ),
  DemoUser(
    uid: 'd7',
    nickname: 'Zanele Mbeki',
    avatar: '🐼',
    points: 430,
    bottles: 97,
    weight: 78.6,
  ),
  DemoUser(
    uid: 'd8',
    nickname: 'Ibrahim Musa',
    avatar: '🦊',
    points: 355,
    bottles: 84,
    weight: 66.1,
  ),
  DemoUser(
    uid: 'd9',
    nickname: 'Thandiwe Silva',
    avatar: '🌍',
    points: 280,
    bottles: 71,
    weight: 55.4,
  ),
  DemoUser(
    uid: 'd10',
    nickname: 'Ravi Patel',
    avatar: '🎨',
    points: 195,
    bottles: 52,
    weight: 41.7,
  ),
  DemoUser(
    uid: 'd11',
    nickname: 'Grace Mwangi',
    avatar: '🌻',
    points: 140,
    bottles: 38,
    weight: 29.3,
  ),
  DemoUser(
    uid: 'd12',
    nickname: 'Peter Banda',
    avatar: '♻️',
    points: 95,
    bottles: 26,
    weight: 19.8,
  ),
  DemoUser(
    uid: 'd13',
    nickname: 'Sara Chikwawa',
    avatar: '🐢',
    points: 60,
    bottles: 15,
    weight: 11.4,
  ),
  DemoUser(
    uid: 'd14',
    nickname: 'Daniel Kalu',
    avatar: '🌱',
    points: 30,
    bottles: 8,
    weight: 5.9,
  ),
];

const List<DemoReward> demoRewards = [
  DemoReward(
    title: '5L Water Container',
    description: 'A reusable five litre container for your kitchen.',
    costPoints: 120,
  ),
  DemoReward(
    title: 'Eco Tote Bag',
    description: 'Sturdy recycled-cotton tote for the market.',
    costPoints: 240,
  ),
  DemoReward(
    title: '10% Off at Fresh Mart',
    description: 'Discount voucher valid at any Fresh Mart branch.',
    costPoints: 400,
    type: 'partner',
    partnerName: 'Fresh Mart',
  ),
  DemoReward(
    title: 'Reusable Coffee Cup',
    description: 'Keep your coffee warm and skip the single-use cup.',
    costPoints: 650,
  ),
  DemoReward(
    title: '15% Off at Green Grocers',
    description: 'Discount voucher for fresh produce and pantry items.',
    costPoints: 900,
    type: 'partner',
    partnerName: 'Green Grocers',
  ),
  DemoReward(
    title: 'Tree Planting',
    description: 'We plant five native trees in your name.',
    costPoints: 1500,
  ),
];

final List<DemoDeposit> demoDeposits = [
  DemoDeposit(
    points: 24,
    weight: 1.4,
    bottleType: 'coloured',
    when: DateTime(2026, 9, 29, 14, 32),
  ),
  DemoDeposit(
    points: 16,
    weight: 0.9,
    bottleType: 'clear',
    when: DateTime(2026, 9, 28, 10, 5),
  ),
  DemoDeposit(
    points: 32,
    weight: 2.1,
    bottleType: 'coloured',
    when: DateTime(2026, 9, 26, 17, 48),
  ),
  DemoDeposit(
    points: 12,
    weight: 0.6,
    bottleType: 'clear',
    when: DateTime(2026, 9, 24, 8, 19),
  ),
  DemoDeposit(
    points: 28,
    weight: 1.8,
    bottleType: 'coloured',
    when: DateTime(2026, 9, 21, 19, 3),
  ),
  DemoDeposit(
    points: 14,
    weight: 0.8,
    bottleType: 'clear',
    when: DateTime(2026, 9, 19, 12, 40),
  ),
];

final List<DemoNotification> demoNotifications = [
  DemoNotification(
    title: 'Reward ready for pickup',
    body:
        'Your Eco Tote Bag redemption was approved and is waiting at the kiosk.',
    read: false,
    when: DateTime(2026, 9, 30, 9, 12),
  ),
  DemoNotification(
    title: 'You moved up 3 places',
    body:
        'You are now ranked 12th on the leaderboard. Keep recycling to climb.',
    read: false,
    when: DateTime(2026, 9, 29, 16, 45),
  ),
  DemoNotification(
    title: 'Deposit confirmed',
    body: 'We credited you 24 points for 1.4 kg of plastic at Hillcrest Kiosk.',
    read: false,
    when: DateTime(2026, 9, 28, 11, 2),
  ),
  DemoNotification(
    title: 'Welcome to BoaMe',
    body: 'Start earning by dropping your bottles at any kiosk near you.',
    read: true,
    when: DateTime(2026, 9, 20, 8, 0),
  ),
];

// ============================================================
// ADMIN / AMBASSADOR SAMPLES
// ============================================================

/// Sample accounts so the admin dashboard, user manager, card registry and
/// ambassador approvals are all reviewable before real users exist.
List<Member> demoMembers() {
  final base = DateTime(2026, 1, 12);
  return [
    Member(
      uid: 'demo-uid-admin',
      name: 'Boame Admin',
      nickname: 'Boame Admin',
      email: 'admin@boame.org',
      phone: '+233 20 000 0001',
      role: AppRole.admin,
      ambassadorStatus: AmbassadorStatus.none,
      points: 0,
      bottles: 0,
      weight: 0,
      avatarIcon: '🛡️',
      accountDisabled: false,
      createdAt: base,
    ),
    Member(
      uid: 'demo-uid-1',
      name: 'Ama Boateng',
      nickname: 'Ama',
      email: 'ama.boateng@st.knights.edu.gh',
      phone: '+233 24 555 0110',
      role: AppRole.ambassador,
      ambassadorStatus: AmbassadorStatus.approved,
      points: 1840,
      bottles: 312,
      weight: 246.8,
      avatarIcon: '🌿',
      rfidUid: 'A3F9 21C0',
      area: 'Campus North',
      createdAt: base.add(const Duration(days: 40)),
    ),
    Member(
      uid: 'demo-uid-2',
      name: 'Kofi Mensah',
      nickname: 'Kofi',
      email: 'kofi.mensah@st.knights.edu.gh',
      phone: '+233 24 555 0142',
      role: AppRole.ambassador,
      ambassadorStatus: AmbassadorStatus.approved,
      points: 1265,
      bottles: 208,
      weight: 172.3,
      avatarIcon: '🚀',
      rfidUid: '77B1 0E44',
      area: 'Hostel Block A',
      createdAt: base.add(const Duration(days: 62)),
    ),
    Member(
      uid: 'demo-uid-3',
      name: 'Efua Danso',
      nickname: 'Efua',
      email: 'efua.danso@st.knights.edu.gh',
      phone: '+233 20 888 3311',
      role: AppRole.user,
      ambassadorStatus: AmbassadorStatus.pending,
      points: 430,
      bottles: 88,
      weight: 71.2,
      avatarIcon: '🌻',
      area: 'Market Square area',
      motivation:
          'I run the Saturday clean-up at my hall and I want to keep the market '
          'bins from overflowing. Happy to take weekly readings.',
      appliedAt: DateTime(2026, 9, 27, 10, 15),
      createdAt: base.add(const Duration(days: 90)),
    ),
    Member(
      uid: 'demo-uid-4',
      name: 'Yaw Asante',
      nickname: 'Yaw',
      email: 'yaw.asante@st.knights.edu.gh',
      phone: '+233 24 777 9001',
      role: AppRole.user,
      ambassadorStatus: AmbassadorStatus.pending,
      points: 275,
      bottles: 51,
      weight: 44.9,
      avatarIcon: '🐢',
      area: 'Ring Road East',
      motivation:
          'I am in the campus media unit and we film a segment on waste each '
          'month. I can help ambassadors reach more students.',
      appliedAt: DateTime(2026, 9, 29, 15, 40),
      createdAt: base.add(const Duration(days: 110)),
    ),
    Member(
      uid: 'demo-uid-5',
      name: 'Nia Quaye',
      nickname: 'Nia',
      email: 'nia.quaye@st.knights.edu.gh',
      phone: '+233 20 333 7788',
      role: AppRole.user,
      ambassadorStatus: AmbassadorStatus.rejected,
      points: 610,
      bottles: 120,
      weight: 98.4,
      avatarIcon: '🌍',
      motivation: 'I want to organise bin days for my department.',
      appliedAt: DateTime(2026, 9, 18, 9, 0),
      createdAt: base.add(const Duration(days: 130)),
    ),
    Member(
      uid: 'demo-uid-6',
      name: 'Kojo Lartey',
      nickname: 'Kojo',
      email: 'kojo.lartey@st.knights.edu.gh',
      phone: '+233 24 111 2233',
      role: AppRole.user,
      ambassadorStatus: AmbassadorStatus.none,
      points: 1120,
      bottles: 196,
      weight: 158.1,
      avatarIcon: '🦊',
      createdAt: base.add(const Duration(days: 150)),
    ),
    Member(
      uid: 'demo-uid-7',
      name: 'Adwoa Frimpong',
      nickname: 'Adwoa',
      email: 'adwoa.frimpong@st.knights.edu.gh',
      phone: '+233 20 444 5566',
      role: AppRole.user,
      ambassadorStatus: AmbassadorStatus.none,
      points: 95,
      bottles: 22,
      weight: 18.6,
      avatarIcon: '🌱',
      accountDisabled: true,
      createdAt: base.add(const Duration(days: 170)),
    ),
  ];
}
