import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show Color;
import '../models/app_role.dart';

/// Read-only view over a `users/{uid}` document.
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
  final DateTime? createdAt;
  final Map<String, dynamic> raw;

  String get displayName => name.trim().isEmpty ? 'Unnamed member' : name.trim();

  String get subtitle {
    final parts = <String>[];
    if (phone.trim().isNotEmpty) parts.add(phone.trim());
    if (rfidUid != null && rfidUid!.trim().isNotEmpty) {
      parts.add('RFID $rfidUid');
    }
    if (parts.isEmpty) parts.add(email.trim().isEmpty ? 'No contact details' : email.trim());
    return parts.join('  •  ');
  }

  bool get isPendingApplication =>
      ambassadorStatus == AmbassadorStatus.pending;

  bool get hasApplication =>
      ambassadorStatus == AmbassadorStatus.pending ||
      ambassadorStatus == AmbassadorStatus.rejected;

  factory Member.fromDocument(DocumentSnapshot<dynamic> snap) {
    final data = (snap.data() as Map<String, dynamic>?) ?? const {};
    final application = data['ambassadorApplication'] as Map<String, dynamic>?;

    int readInt(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    double readDouble(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

    return Member(
      uid: snap.id,
      name: (data['name'] ?? '').toString(),
      nickname: (data['nickname'] ?? data['name'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      role: AppRole.fromString(data['role']),
      ambassadorStatus: AmbassadorStatus.fromString(data['ambassadorStatus']),
      points: readInt(data['points']),
      bottles: readInt(data['bottles']),
      weight: readDouble(data['weight']),
      avatarIcon: (data['avatarIcon'] ?? '🙂').toString(),
      accountDisabled: data['accountDisabled'] == true,
      rfidUid: data['rfidUid']?.toString(),
      area: application?['area']?.toString(),
      motivation: application?['motivation']?.toString(),
      appliedAt: data['ambassadorAppliedAt'] is Timestamp
          ? (data['ambassadorAppliedAt'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      raw: data,
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
