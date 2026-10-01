import '../models/app_role.dart';
import '../models/json_readers.dart';
import '../models/member.dart';
import '../screens/demo_data.dart' show kDemoMode, demoMembers;
import '../services/api_client.dart';
import '../services/polling.dart';

/// Summary of one registered RFID tag.
class RfidCard {
  const RfidCard({
    required this.id,
    required this.tag,
    required this.state,
    required this.cardType,
    this.assignedUid,
    this.assignedName,
    this.registeredAt,
    this.notes,
    this.holderRole,
  });

  final String id;

  /// The card's UID exactly as printed/scanned, e.g. `A3F9 21C0`.
  final String tag;
  final RfidState state;
  final String cardType;
  final String? assignedUid;
  final String? assignedName;
  final DateTime? registeredAt;
  final String? notes;
  final String? holderRole;

  bool get isLinked => assignedUid != null && assignedUid!.isNotEmpty;

  /// The API calls these `cardKind`, `assignedUserId` and `createdAt`. They are
  /// renamed here so the rest of the app keeps the vocabulary it had.
  factory RfidCard.fromJson(Map<String, dynamic> data) {
    return RfidCard(
      id: readString(data['id']),
      tag: readString(data['tag']),
      state: RfidState.fromString(data['state']),
      cardType: _labelForKind(readString(data['cardKind'])),
      assignedUid: readNullableString(data['assignedUserId']),
      assignedName: readNullableString(data['assignedUserName']),
      registeredAt: readDate(data['createdAt'] ?? data['registeredAt']),
      notes: readNullableString(data['notes']),
    );
  }
}

/// The card technology, spelled out for the registry screen.
String _labelForKind(String kind) {
  switch (kind) {
    case 'mifare_1k':
      return 'MIFARE 1K';
    case 'mifare_ultralight':
      return 'MIFARE Ultralight';
    case 'em4100':
      return 'EM4100';
    case 'hid_prox':
      return 'HID Prox';
    case 'student_id':
      return 'Student ID';
    case 'staff_id':
      return 'Staff ID';
    case 'standard':
    default:
      return 'Standard';
  }
}

enum RfidState {
  available,
  linked,
  lost,
  revoked;

  static RfidState fromString(Object? raw) {
    switch (raw) {
      case 'linked':
      case 'assigned':
        return RfidState.linked;
      case 'lost':
        return RfidState.lost;
      case 'revoked':
        return RfidState.revoked;
      default:
        return RfidState.available;
    }
  }

  String get id => name;

  String get label {
    switch (this) {
      case RfidState.available:
        return 'Available';
      case RfidState.linked:
        return 'Linked';
      case RfidState.lost:
        return 'Reported lost';
      case RfidState.revoked:
        return 'Revoked';
    }
  }
}

/// Users, roles, RFID cards and ambassador applications.
class UserRepository {
  UserRepository({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  // ---------------- roles ----------------

  /// Changes a member's role.
  ///
  /// The API is stricter than the old write: it is admin-only, it refuses to
  /// let an admin demote themselves, and it writes an audit row. Promoting
  /// someone to ambassador no longer also flips `ambassadorStatus` here,
  /// because the server owns that and the review endpoint is the way in.
  Future<void> setRole(String uid, AppRole role) async {
    await _api.postJson('/api/users/$uid/role', body: {'role': role.id});
  }

  // ---------------- ambassador applications ----------------

  /// Submits the signed-in member's own application.
  ///
  /// There is deliberately no `uid` parameter. The API reads the applicant
  /// from the session, so the client cannot submit an application on someone
  /// else's behalf even by mistake.
  Future<void> applyForAmbassador({
    required String area,
    required String motivation,
  }) async {
    await _api.postJson(
      '/api/ambassador/apply',
      body: {'area': area.trim(), 'motivation': motivation.trim()},
    );
  }

  Future<void> reviewAmbassadorApplication({
    required String uid,
    required bool approve,
    String note = '',
  }) async {
    await _api.postJson(
      '/api/ambassador/applications/$uid/review',
      body: {
        'decision': approve ? 'approve' : 'reject',
        if (note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  // ---------------- RFID ----------------

  Stream<List<RfidCard>> watchCards() {
    return pollList<RfidCard>(
      () async {
        final body = await _api.getJson('/api/rfid/cards', {'limit': 200});
        final cards = _api
            .listOf(body, 'cards')
            .whereType<Map<String, dynamic>>()
            .map(RfidCard.fromJson)
            .toList();
        if (cards.isEmpty && kDemoMode) return demoRfidCards();
        return cards;
      },
      interval: PollInterval.standard,
      seed: kDemoMode ? demoRfidCards() : const [],
    );
  }

  /// Registers a card from its UID alone; everything else is derived
  /// from the member it gets linked to.
  Future<String> registerCard({required String tag}) async {
    final body = await _api.postJson(
      '/api/rfid/cards',
      body: {'tag': tag.trim()},
    );
    return (body['card'] as Map<String, dynamic>?)?['id']?.toString() ?? '';
  }

  Future<void> assignCard({
    required String cardId,
    required String uid,
    required String name,
    String role = 'user',
  }) async {
    // The member's own copy of the tag is derived by the server from the link,
    // so there is no second write to keep in step here.
    await _api.patchJson('/api/rfid/cards/$cardId/link', body: {'userId': uid});
  }

  Future<void> unlinkCard(String cardId) {
    return _api.patchJson(
      '/api/rfid/cards/$cardId/link',
      body: {'userId': null},
    );
  }

  Future<void> setCardState(String cardId, RfidState state) {
    return _api.postJson(
      '/api/rfid/cards/$cardId/status',
      body: {'state': state.id},
    );
  }

  Future<void> deleteCard(String cardId) =>
      _api.deleteJson('/api/rfid/cards/$cardId');

  // ---------------- user records ----------------

  Stream<List<Member>> watchMembers() {
    return pollList<Member>(
      () async {
        final body = await _api.getJson('/api/users', {'limit': 200});
        var members = _api
            .listOf(body, 'users')
            .whereType<Map<String, dynamic>>()
            .map(Member.fromJson)
            .toList();
        if (members.isEmpty && kDemoMode) members = demoMembers();
        members.sort((a, b) => a.displayName.compareTo(b.displayName));
        return members;
      },
      interval: PollInterval.standard,
      seed: kDemoMode ? demoMembers() : const [],
    );
  }

  /// Only the people waiting on a decision.
  Stream<List<Member>> watchApplications() {
    return pollList<Member>(() async {
      final body = await _api.getJson('/api/ambassador/applications', {
        'status': 'pending',
      });
      var pending = _api
          .listOf(body, 'applications')
          .whereType<Map<String, dynamic>>()
          .map(Member.fromJson)
          .toList();
      if (pending.isEmpty && kDemoMode) {
        pending = demoMembers().where((m) => m.isPendingApplication).toList();
      }
      return pending;
    }, interval: PollInterval.standard);
  }

  /// PATCH /api/users/me. The API only accepts the fields a member may change
  /// about themselves, so [fields] is filtered rather than passed wholesale —
  /// sending `role` or `points` here would be rejected, and should be.
  Future<Member> updateOwnProfile(Map<String, dynamic> fields) async {
    const allowed = {'name', 'nickname', 'email', 'avatarIcon'};
    final body = {
      for (final entry in fields.entries)
        if (allowed.contains(entry.key)) entry.key: entry.value,
    };
    if (body.isEmpty) throw ApiException('Nothing to update.');

    final response = await _api.patchJson('/api/users/me', body: body);
    return Member.fromJson(response['user'] as Map<String, dynamic>);
  }

  /// Changes your own phone number.
  ///
  /// Separate from [updateOwnProfile] because the server insists on the
  /// current password for this one edit — the phone number is also the login
  /// identifier, so moving it silently would be how someone takes over an
  /// account.
  Future<Member> changeOwnPhone({
    required String phone,
    required String currentPassword,
  }) async {
    final body = await _api.postJson(
      '/api/users/me/phone',
      body: {'phone': phone.trim(), 'currentPassword': currentPassword},
    );
    return Member.fromJson(body['user'] as Map<String, dynamic>);
  }

  /// Adjusts a member's point balance, which is how the admin console credits
  /// or penalises recycling outside the normal deposit flow.
  Future<int> adjustPoints(String uid, int delta, {String? reason}) async {
    final body = await _api.postJson(
      '/api/users/$uid/points',
      body: {
        'delta': delta,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return readInt(body['points']);
  }

  /// Locks or unlocks an account.
  ///
  /// Revoking the sessions is the server's job and happens in the same request,
  /// so this takes effect immediately rather than when the old token expires.
  Future<void> setUserEnabled(String uid, bool enabled) async {
    await _api.postJson(
      '/api/users/$uid/disable',
      body: {'disabled': !enabled},
    );
  }

  /// Soft-deletes an account. The reason is required by the API and is audited.
  Future<void> deleteUser(String uid, {required String reason}) async {
    await _api.deleteJson('/api/users/$uid', body: {'reason': reason});
  }
}

/// Sample cards so the registry is reviewable before real tags arrive.
List<RfidCard> demoRfidCards() {
  return [
    RfidCard(
      id: 'demo-card-1',
      tag: 'A3F9 21C0',
      state: RfidState.linked,
      cardType: 'Standard',
      assignedUid: 'demo-uid-1',
      assignedName: 'Ama Boateng',
      holderRole: 'ambassador',
      notes: 'Issued with the 2026 ambassador cohort.',
    ),
    RfidCard(
      id: 'demo-card-2',
      tag: '77B1 0E44',
      state: RfidState.linked,
      cardType: 'Standard',
      assignedUid: 'demo-uid-2',
      assignedName: 'Kofi Mensah',
      holderRole: 'user',
    ),
    RfidCard(
      id: 'demo-card-3',
      tag: 'C0D3 9F17',
      state: RfidState.available,
      cardType: 'Standard',
      notes: 'Spare, kept at the admin office.',
    ),
    RfidCard(
      id: 'demo-card-4',
      tag: '5D02 88AB',
      state: RfidState.lost,
      cardType: 'Standard',
      notes: 'Reported lost in March. Needs re-issue.',
    ),
  ];
}
