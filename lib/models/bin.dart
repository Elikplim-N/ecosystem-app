import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../screens/design_system.dart';

/// Operational state of a recycling bin.
enum BinStatus {
  available,
  filling,
  full,
  disabled;

  static BinStatus fromString(Object? raw) {
    switch (raw) {
      case 'available':
        return BinStatus.available;
      case 'filling':
      case 'filling_up':
        return BinStatus.filling;
      case 'full':
        return BinStatus.full;
      case 'disabled':
      case 'offline':
      case 'maintenance':
        return BinStatus.disabled;
      default:
        return BinStatus.available;
    }
  }

  String get id => name;

  /// The single source of truth for "how full is this".
  static BinStatus fromFill(double level) {
    if (level >= 90) return BinStatus.full;
    if (level >= 55) return BinStatus.filling;
    return BinStatus.available;
  }

  String get label {
    switch (this) {
      case BinStatus.available:
        return 'Available';
      case BinStatus.filling:
        return 'Filling up';
      case BinStatus.full:
        return 'Full';
      case BinStatus.disabled:
        return 'Disabled';
    }
  }

  IconData get icon {
    switch (this) {
      case BinStatus.available:
        return Icons.check_circle_rounded;
      case BinStatus.filling:
        return Icons.error_rounded;
      case BinStatus.full:
        return Icons.delete_rounded;
      case BinStatus.disabled:
        return Icons.pause_circle_rounded;
    }
  }

  Color get color {
    switch (this) {
      case BinStatus.available:
        return kPrimaryColor;
      case BinStatus.filling:
        return kAccentOrange;
      case BinStatus.full:
        return kClearBottle;
      case BinStatus.disabled:
        return kTextMuted;
    }
  }

  Color get tint {
    switch (this) {
      case BinStatus.available:
        return kPastelMint;
      case BinStatus.filling:
        return const Color(0xFFFBEFD9);
      case BinStatus.full:
        return kPastelPink;
      case BinStatus.disabled:
        return const Color(0xFFECEEEC);
    }
  }
}

/// Immutable view over a `bins/{binId}` document.
class Bin {
  const Bin({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.fillLevel,
    this.rejectedFillLevel = 0,
    this.collects = 'Plastic',
    required this.latitude,
    required this.longitude,
    required this.address,
    this.sensorId,
    this.hasSensor = false,
    this.capacityKg = 50,
    this.lastCollected,
    this.updatedAt,
    this.createdById,
    this.createdByRole,
    this.createdByName,
    this.notes,
  });

  final String id;
  final String code;
  final String name;
  final BinStatus status;

  /// 0-100. For sensor bins this is reported by the device;
  /// for manual bins it is set by whoever last marked it.
  /// 0-100 for the accepted compartment — the one that matters.
  final double fillLevel;

  /// 0-100 for the rejected compartment beside it.
  final double rejectedFillLevel;

  /// What this bin is for, e.g. Plastic or Glass.
  final String collects;
  final double latitude;
  final double longitude;
  final String address;
  final String? sensorId;
  final bool hasSensor;
  final double capacityKg;
  final DateTime? lastCollected;
  final DateTime? updatedAt;
  final String? createdById;
  final String? createdByRole;
  final String? createdByName;
  final String? notes;

  bool get isActive => status != BinStatus.disabled;

  /// The accepted compartment needs emptying.
  bool get acceptedFull => isActive && fillLevel >= 90;

  /// The rejected compartment only matters once it is genuinely full.
  bool get rejectedFull => isActive && rejectedFillLevel >= 90;

  bool get needsCollection => acceptedFull || rejectedFull;

  bool get isManual => !hasSensor;

  factory Bin.fromDocument(DocumentSnapshot<dynamic> snap) {
    final data = (snap.data() as Map<String, dynamic>?) ?? const {};

    double readDouble(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    DateTime? readDate(Object? v) => v is Timestamp ? v.toDate() : null;

    return Bin(
      id: snap.id,
      code: (data['code'] ?? '').toString(),
      name: (data['name'] ?? 'Unnamed bin').toString(),
      status: BinStatus.fromString(data['status']),
      fillLevel: readDouble(data['fillLevel']).clamp(0, 100),
      rejectedFillLevel: readDouble(data['rejectedFillLevel']).clamp(0, 100),
      collects: (data['collects'] ?? 'Plastic').toString(),
      latitude: readDouble(data['latitude'] ?? data['lat']),
      longitude: readDouble(data['longitude'] ?? data['lng']),
      address: (data['address'] ?? '').toString(),
      sensorId: data['sensorId']?.toString(),
      hasSensor: data['hasSensor'] == true,
      capacityKg: readDouble(data['capacityKg']).clamp(0, 100000) == 0
          ? 50
          : readDouble(data['capacityKg']),
      lastCollected: readDate(data['lastCollectedAt']),
      updatedAt: readDate(data['updatedAt'] ?? data['createdAt']),
      createdById: data['createdById']?.toString(),
      createdByRole: data['createdByRole']?.toString(),
      createdByName: data['createdByName']?.toString(),
      notes: data['notes']?.toString(),
    );
  }

  /// Firestore payload. Keeps sensor-owned fields separate so a manual
  /// edit never clobbers what the device reported.
  Map<String, dynamic> toDocument() {
    return {
      'code': code,
      'name': name,
      'status': status.id,
      'fillLevel': fillLevel,
      'rejectedFillLevel': rejectedFillLevel,
      'collects': collects,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'sensorId': sensorId,
      'hasSensor': hasSensor,
      'capacityKg': capacityKg,
      'lastCollectedAt': lastCollected == null ? null : Timestamp.fromDate(lastCollected!),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdById': createdById,
      'createdByRole': createdByRole,
      'createdByName': createdByName,
      'notes': notes,
    };
  }

  /// Short human summary used in lists and map callouts.
  String get locationLabel =>
      address.trim().isEmpty ? 'No location set' : address.trim();
}

/// Where a bin's status came from, so the UI can be honest about it.
enum BinSource {
  sensor,
  manual;

  static BinSource fromString(Object? raw) =>
      raw == 'sensor' ? BinSource.sensor : BinSource.manual;

  String get id => name;

  String get label => this == BinSource.sensor ? 'Sensor' : 'Manual';
}
