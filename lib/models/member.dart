import 'package:flutter/material.dart' show Color;
import '../models/app_role.dart';
import 'json_readers.dart';

/// Read-only view over a member, as returned by the REST API.
///
/// The id is the `users.id` uuid, which is also the JWT subject — it plays the
/// role Firebase's uid used to. Note it is a uuid string, not a Firestore
/// document id, so nothing should try to parse it as anything else.
class Member {
  const Member({
    required this.uid,
    required this.name,
    required this.nickname,
    required this.email,
    required this.phone,
    required this.role,
    required this.ambassadorStatus,
    required this.points,
    required this.bottles,
    required this.weight,
    required this.avatarIcon,
    this.accountDisabled = false,
    this.rfidUid,
    this.area,
    this.motivation,
    this.appliedAt,
    this.reviewNote,
    this.createdAt,
    this.raw = const {},
  });

  final String uid;
  final String name;
  final String nickname;
  final String email;
  final String phone;
  final AppRole role;
  final AmbassadorStatus ambassadorStatus;
  final int points;
  final int bottles;
  final double weight;
  final String avatarIcon;
  final bool accountDisabled;
  final String? rfidUid;

  // Ambassador application fields
  final String? area;
  final String? motivation;
  final DateTime? appliedAt;

  /// Why the last review decision went the way it did, shown to the applicant.
  final String? reviewNote;
  final DateTime? createdAt;
  final Map<String, dynamic> raw;

  String get displayName =>
      name.trim().isEmpty ? 'Unnamed member' : name.trim();

  String get subtitle {
    final parts = <String>[];
    if (phone.trim().isNotEmpty) parts.add(phone.trim());
    if (rfidUid != null && rfidUid!.trim().isNotEmpty) {
      parts.add('RFID $rfidUid');
    }
    if (parts.isEmpty) {
      parts.add(email.trim().isEmpty ? 'No contact details' : email.trim());
    }
    return parts.join('  •  ');
  }

  bool get isPendingApplication => ambassadorStatus == AmbassadorStatus.pending;

  bool get hasApplication =>
      ambassadorStatus == AmbassadorStatus.pending ||
      ambassadorStatus == AmbassadorStatus.rejected;

  /// Builds from the API's `publicUser`/`present` shape.
  ///
  /// `accountState` is the API's enum ('active' | 'disabled' | 'deleted')
  /// rather than the old `accountDisabled` boolean.
  factory Member.fromJson(Map<String, dynamic> data) {
    // A member with no nickname is shown by their real name rather than blank.
    final name = readString(data['name']);
    final nickname = readString(data['nickname']).trim();

    return Member(
      uid: readString(data['id']),
      name: name,
      nickname: nickname.isEmpty ? name : nickname,
      email: readString(data['email']),
      phone: readString(data['phone']),
      role: AppRole.fromString(data['role']),
      ambassadorStatus: AmbassadorStatus.fromString(data['ambassadorState']),
      points: readInt(data['points']),
      bottles: readInt(data['bottles']),
      // The API sends kilograms; the UI has always spoken kilograms.
      weight: readDouble(data['weightKg'] ?? data['weight']),
      avatarIcon: readString(data['avatarIcon'], '🙂'),
      accountDisabled:
          data['accountState'] == 'disabled' || data['accountDisabled'] == true,
      rfidUid: readNullableString(data['rfidUid']),
      area: readNullableString(data['ambassadorArea']),
      motivation: readNullableString(data['ambassadorMotivation']),
      appliedAt: readDate(data['ambassadorAppliedAt'] ?? data['appliedAt']),
      reviewNote: readNullableString(data['ambassadorReviewNote']),
      createdAt: readDate(data['createdAt']),
      raw: data,
    );
  }

  /// Only the fields the app owns, for the local cache and for PATCH bodies.
  ///
  /// Deliberately not the whole API payload: the cache should not hold the
  /// password-related or internal fields the API could start adding later.
  Map<String, dynamic> toJson() {
    return {
      'id': uid,
      'name': name,
      'nickname': nickname,
      'email': email,
      'phone': phone,
      'role': role.id,
      'ambassadorState': ambassadorStatus.id,
      'points': points,
      'bottles': bottles,
      'weightKg': weight,
      'avatarIcon': avatarIcon,
      'accountState': accountDisabled ? 'disabled' : 'active',
      if (rfidUid != null) 'rfidUid': rfidUid,
      if (area != null) 'ambassadorArea': area,
      if (motivation != null) 'ambassadorMotivation': motivation,
      if (appliedAt != null)
        'ambassadorAppliedAt': appliedAt!.toIso8601String(),
      if (reviewNote != null) 'ambassadorReviewNote': reviewNote,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  Member copyWith({
    String? name,
    String? nickname,
    String? email,
    String? phone,
    String? avatarIcon,
    AppRole? role,
    AmbassadorStatus? ambassadorStatus,
    int? points,
    int? bottles,
    double? weight,
    String? rfidUid,
  }) {
    return Member(
      uid: uid,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      ambassadorStatus: ambassadorStatus ?? this.ambassadorStatus,
      points: points ?? this.points,
      bottles: bottles ?? this.bottles,
      weight: weight ?? this.weight,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      accountDisabled: accountDisabled,
      rfidUid: rfidUid ?? this.rfidUid,
      area: area,
      motivation: motivation,
      appliedAt: appliedAt,
      reviewNote: reviewNote,
      createdAt: createdAt,
      raw: raw,
    );
  }

  /// Matches free-text search across the fields staff would search by.
  bool matches(String query) {
    if (query.trim().isEmpty) return true;
    final q = query.trim().toLowerCase();
    return name.toLowerCase().contains(q) ||
        nickname.toLowerCase().contains(q) ||
        email.toLowerCase().contains(q) ||
        phone.toLowerCase().contains(q) ||
        (rfidUid ?? '').toLowerCase().contains(q);
  }

  Color get accent => role.color;

  Color get tint => role.tint;
}
