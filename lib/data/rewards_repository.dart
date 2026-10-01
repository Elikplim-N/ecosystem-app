import '../models/json_readers.dart';
import '../services/api_client.dart';
import '../services/polling.dart';

/// A reward in the member-facing catalogue.
class Reward {
  const Reward({
    required this.id,
    required this.title,
    required this.costPoints,
    this.description,
    this.category = 'standard',
    this.partnerName,
    this.stock,
    this.myPoints,
    this.canAfford,
    this.active = true,
  });

  final String id;
  final String title;
  final String? description;
  final String category;
  final String? partnerName;
  final int costPoints;

  /// Null means unlimited, which is different from zero.
  final int? stock;

  /// The signed-in member's balance at the time of the fetch, and whether they
  /// could afford this one. Both come from the server so the button state
  /// cannot disagree with what the redeem call would do.
  final int? myPoints;
  final bool? canAfford;
  final bool active;

  bool get isPartner => category == 'partner';

  bool get outOfStock => stock != null && stock! <= 0;

  /// What the server said, or a balance check if it did not.
  bool get affordable =>
      canAfford ?? (myPoints != null && myPoints! >= costPoints);

  factory Reward.fromJson(Map<String, dynamic> data) {
    return Reward(
      id: readString(data['id']),
      title: readString(data['title']),
      description: readNullableString(data['description']),
      category: readString(data['category'], 'standard'),
      partnerName: readNullableString(data['partnerName']),
      costPoints: readInt(data['costPoints']),
      stock: data['stock'] == null ? null : readInt(data['stock']),
      myPoints: data['myPoints'] == null ? null : readInt(data['myPoints']),
      canAfford: data['canAfford'] == null ? null : readBool(data['canAfford']),
      active: data['active'] == null ? true : readBool(data['active']),
    );
  }
}

/// One request for a reward, and where it got to.
class Redemption {
  const Redemption({
    required this.id,
    required this.title,
    required this.costPoints,
    required this.status,
    this.partnerName,
    this.reviewNote,
    this.requestedAt,
    this.reviewedAt,
  });

  final String id;
  final String title;
  final String? partnerName;
  final int costPoints;
  final String status;
  final String? reviewNote;
  final DateTime? requestedAt;
  final DateTime? reviewedAt;

  String get statusLabel {
    switch (status) {
      case 'approved':
        return 'Approved — collect at the depot';
      case 'fulfilled':
        return 'Collected';
      case 'rejected':
        return 'Not approved — points refunded';
      default:
        return 'Waiting for review';
    }
  }

  factory Redemption.fromJson(Map<String, dynamic> data) {
    return Redemption(
      id: readString(data['id']),
      title: readString(data['title']),
      partnerName: readNullableString(data['partnerName']),
      costPoints: readInt(data['costPoints']),
      status: readString(data['status'], 'pending'),
      reviewNote: readNullableString(data['reviewNote']),
      requestedAt: readDate(data['requestedAt']),
      reviewedAt: readDate(data['reviewedAt']),
    );
  }
}

/// The outcome of a successful redeem, so the UI can say what happened rather
/// than guessing from the old balance.
class RedeemResult {
  const RedeemResult({
    required this.redemptionId,
    required this.rewardTitle,
    required this.pointsLeft,
  });

  final String redemptionId;
  final String rewardTitle;
  final int pointsLeft;

  factory RedeemResult.fromJson(Map<String, dynamic> data) {
    final redemption = data['redemption'] as Map<String, dynamic>? ?? const {};
    return RedeemResult(
      redemptionId: readString(redemption['id']),
      rewardTitle: readString(data['rewardTitle']),
      pointsLeft: readInt(data['pointsLeft']),
    );
  }
}

/// Rewards catalogue and redemption history.
class RewardsRepository {
  RewardsRepository({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// The catalogue a member can see. Inactive rewards are filtered by the
  /// server, so there is nothing to hide here.
  Stream<List<Reward>> watchRewards() {
    return pollList<Reward>(() async {
      final body = await _api.getJson('/api/rewards');
      return _api
          .listOf(body, 'rewards')
          .whereType<Map<String, dynamic>>()
          .map(Reward.fromJson)
          .toList();
    }, interval: PollInterval.standard);
  }

  /// The full catalogue, including inactive rows, for the admin console.
  Stream<List<Reward>> watchAllRewards() {
    return pollList<Reward>(() async {
      final body = await _api.getJson('/api/rewards/admin');
      return _api
          .listOf(body, 'rewards')
          .whereType<Map<String, dynamic>>()
          .map(Reward.fromJson)
          .toList();
    }, interval: PollInterval.standard);
  }

  Future<Reward> addReward({
    required String title,
    required int costPoints,
    String? description,
    String category = 'standard',
    String? partnerName,
    int? stock,
  }) async {
    final body = await _api.postJson(
      '/api/rewards/admin',
      body: {
        'title': title,
        'costPoints': costPoints,
        'description': description,
        'category': category,
        if (partnerName != null && partnerName.isNotEmpty)
          'partnerName': partnerName,
        'stock': ?stock,
      },
    );
    return Reward.fromJson(body['reward'] as Map<String, dynamic>);
  }

  Future<Reward> editReward(
    String id, {
    String? title,
    int? costPoints,
    String? description,
    String? category,
    String? partnerName,
    int? stock,
    bool? active,
  }) async {
    final body = await _api.patchJson(
      '/api/rewards/admin/$id',
      body: {
        'title': ?title,
        'costPoints': ?costPoints,
        'description': ?description,
        'category': ?category,
        'partnerName': ?partnerName,
        'stock': ?stock,
        'active': ?active,
      },
    );
    return Reward.fromJson(body['reward'] as Map<String, dynamic>);
  }

  /// Removes a reward. The server refuses if it has ever been redeemed, and
  /// says so; deactivate it instead in that case.
  Future<void> deleteReward(String id) =>
      _api.deleteJson('/api/rewards/admin/$id');

  /// Redeems a reward. Points are deducted server-side inside the same
  /// transaction that creates the request, so this cannot half-fail.
  Future<RedeemResult> redeem(String rewardId) async {
    final body = await _api.postJson('/api/rewards/$rewardId/redeem');
    return RedeemResult.fromJson(body);
  }

  Stream<List<Redemption>> watchMyRedemptions() {
    return pollList<Redemption>(() async {
      final body = await _api.getJson('/api/rewards/me/redemptions');
      return _api
          .listOf(body, 'redemptions')
          .whereType<Map<String, dynamic>>()
          .map(Redemption.fromJson)
          .toList();
    }, interval: PollInterval.standard);
  }
}
