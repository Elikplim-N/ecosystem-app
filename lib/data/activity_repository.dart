import '../models/json_readers.dart';
import '../services/api_client.dart';
import '../services/polling.dart';

/// One recycling deposit, as recorded against a bin.
class Deposit {
  const Deposit({
    required this.id,
    required this.bottleKind,
    required this.bottleCount,
    required this.weightKg,
    required this.pointsAwarded,
    required this.at,
    this.binCode,
    this.binName,
  });

  final String id;

  /// The API's `bottle_kind` enum is 'coloured' or 'clear'.
  final String bottleKind;
  final int bottleCount;
  final double weightKg;
  final int pointsAwarded;
  final DateTime at;
  final String? binCode;
  final String? binName;

  String get kindLabel {
    switch (bottleKind) {
      case 'clear':
        return 'Clear PET';
      case 'coloured':
        return 'Coloured PET';
      default:
        return bottleKind;
    }
  }

  String get locationLabel {
    if (binName != null && binName!.isNotEmpty) return binName!;
    if (binCode != null && binCode!.isNotEmpty) return binCode!;
    return 'Unknown bin';
  }

  factory Deposit.fromJson(Map<String, dynamic> data) {
    return Deposit(
      id: readString(data['id']),
      bottleKind: readString(data['bottleKind'] ?? data['bottleType']),
      bottleCount: readInt(data['bottleCount'] ?? data['bottles']),
      weightKg: readDouble(data['weightKg'] ?? data['weight']),
      pointsAwarded: readInt(data['pointsAwarded'] ?? data['points']),
      at: readDate(data['at'] ?? data['createdAt']) ?? DateTime.now(),
      binCode: readNullableString(data['binCode']),
      binName: readNullableString(data['binName']),
    );
  }
}

/// One row on the public leaderboard.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.name,
    required this.points,
    required this.bottles,
    required this.weightKg,
    this.nickname,
    this.avatarIcon,
    this.role,
  });

  final int rank;
  final String userId;
  final String name;
  final String? nickname;
  final String? avatarIcon;
  final int points;
  final int bottles;
  final double weightKg;
  final String? role;

  String get displayName {
    final nick = nickname?.trim() ?? '';
    return nick.isEmpty ? name : nick;
  }

  factory LeaderboardEntry.fromJson(Map<String, dynamic> data) {
    return LeaderboardEntry(
      rank: readInt(data['rank']),
      userId: readString(data['userId'] ?? data['id']),
      name: readString(data['name']),
      nickname: readNullableString(data['nickname']),
      avatarIcon: readNullableString(data['avatarIcon']),
      points: readInt(data['points']),
      bottles: readInt(data['bottles']),
      weightKg: readDouble(data['weightKg'] ?? data['weight']),
      role: readNullableString(data['role']),
    );
  }
}

/// A message to the member from the platform.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.isPersonal = true,
  });

  final String id;
  final String title;
  final String body;
  final String kind;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  /// False for a broadcast to the member's whole role.
  final bool isPersonal;

  factory AppNotification.fromJson(Map<String, dynamic> data) {
    return AppNotification(
      id: readString(data['id']),
      title: readString(data['title']),
      body: readString(data['body']),
      kind: readString(data['kind'], 'info'),
      isRead: readBool(data['isRead']),
      readAt: readDate(data['readAt']),
      createdAt: readDate(data['createdAt']) ?? DateTime.now(),
      isPersonal: data['isPersonal'] == null
          ? true
          : readBool(data['isPersonal']),
    );
  }
}

/// The notification feed, plus the unread count the bell badge shows.
class NotificationFeed {
  const NotificationFeed({
    required this.items,
    required this.unread,
    required this.total,
  });

  final List<AppNotification> items;
  final int unread;
  final int total;

  static const empty = NotificationFeed(items: [], unread: 0, total: 0);
}

/// Deposit history and the public leaderboard.
class ActivityRepository {
  ActivityRepository({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// The signed-in member's own deposits, newest first.
  Stream<List<Deposit>> watchMyDeposits() {
    return pollList<Deposit>(() async {
      final body = await _api.getJson('/api/users/me/deposits');
      return _api
          .listOf(body, 'deposits')
          .whereType<Map<String, dynamic>>()
          .map(Deposit.fromJson)
          .toList();
    }, interval: PollInterval.account);
  }

  /// The public ranking. No session needed, so this also works signed out.
  Stream<List<LeaderboardEntry>> watchLeaderboard({int limit = 50}) {
    return pollList<LeaderboardEntry>(() async {
      final body = await _api.getJson('/api/users/leaderboard', {
        'limit': limit,
      });
      return _api
          .listOf(body, 'leaderboard')
          .whereType<Map<String, dynamic>>()
          .map(LeaderboardEntry.fromJson)
          .toList();
    }, interval: PollInterval.standard);
  }
}

/// The member's notification feed.
class NotificationsRepository {
  NotificationsRepository({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// Items and the unread count together, because the badge and the list are
  /// always shown from the same response and would otherwise disagree.
  Stream<NotificationFeed> watchFeed({bool unreadOnly = false}) {
    return pollValue<NotificationFeed>(
      () async {
        final body = await _api.getJson('/api/notifications', {
          'limit': 100,
          if (unreadOnly) 'unreadOnly': 'true',
        });
        return NotificationFeed(
          items: _api
              .listOf(body, 'notifications')
              .whereType<Map<String, dynamic>>()
              .map(AppNotification.fromJson)
              .toList(),
          unread: readInt(body['unread']),
          total: readInt(body['total']),
        );
      },
      interval: PollInterval.standard,
      seed: NotificationFeed.empty,
    );
  }

  Future<void> markRead(String id) =>
      _api.postJson('/api/notifications/$id/read');

  Future<void> markAllRead() => _api.postJson('/api/notifications/read-all');
}

/// The support contact form.
class ContactRepository {
  ContactRepository({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// Sends a message.
  ///
  /// The endpoint works signed out on purpose — someone who cannot get past
  /// the login screen is exactly who needs to reach us — so no session is
  /// required and the sender's own details are used when there is one.
  Future<void> send(
    String message, {
    String? name,
    String? phone,
    String? email,
  }) async {
    await _api.postJson(
      '/api/contact',
      auth: false,
      body: {
        'message': message,
        if (name != null && name.isNotEmpty) 'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
  }
}

/// Password reset.
class PasswordResetRepository {
  PasswordResetRepository({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// Asks for a reset link.
  ///
  /// Always succeeds, whether or not the account exists — the server will not
  /// say, and neither should this throw on a 404 if the API ever did.
  Future<String?> requestReset(String identifier) async {
    try {
      final body = await _api.postJson(
        '/api/auth/forgot-password',
        auth: false,
        body: {'identifier': identifier.trim()},
      );
      // Only present outside production, so the flow is testable without a
      // mail provider. See the Known gaps section of the backend README.
      return body['debugToken']?.toString();
    } on ApiOfflineException {
      rethrow;
    } on ApiException {
      return null;
    }
  }

  Future<void> reset({required String token, required String password}) async {
    await _api.postJson(
      '/api/auth/reset-password',
      auth: false,
      body: {'token': token, 'password': password},
    );
  }
}
