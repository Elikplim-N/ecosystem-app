import 'package:flutter/material.dart';
import '../screens/design_system.dart';
import 'json_readers.dart';

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

  factory Bin.fromJson(Map<String, dynamic> data) {
    final capacity = readDouble(data['capacityKg']);

    return Bin(
      id: readString(data['id']),
      code: readString(data['code']),
      name: readString(data['name'], 'Unnamed bin'),
      status: BinStatus.fromString(data['status']),
      fillLevel: readPercent(data['fillLevel']),
      rejectedFillLevel: readPercent(data['rejectedFillLevel']),
      collects: readString(data['collects'], 'Plastic'),
      latitude: readDouble(data['latitude'] ?? data['lat']),
      longitude: readDouble(data['longitude'] ?? data['lng']),
      address: readString(data['address']),
      sensorId: readNullableString(data['sensorId']),
      hasSensor: readBool(data['hasSensor']),
      capacityKg: capacity <= 0 ? 50 : capacity,
      lastCollected: readDate(data['lastCollectedAt'] ?? data['lastCollected']),
      updatedAt: readDate(data['updatedAt'] ?? data['createdAt']),
      createdById: readNullableString(data['createdById']),
      createdByRole: readNullableString(data['createdByRole']),
      createdByName: readNullableString(data['createdByName']),
      notes: readNullableString(data['notes']),
    );
  }

  /// Body for POST /api/bins. [id] is ignored there — the server assigns it.
  Map<String, dynamic> toRequest() {
    return {
      'code': code,
      'name': name,
      'collects': collects,
      'fillPercent': fillLevel,
      'rejectedFillPercent': rejectedFillLevel,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'sensorId': sensorId,
      'capacityKg': capacityKg,
      if (notes != null) 'notes': notes,
    };
  }

  /// Body for PATCH /api/bins/:id.
  ///
  /// Returns null when there is nothing to send, so the caller can skip the
  /// request entirely instead of sending a no-op update the server would audit.
  Map<String, dynamic>? toPatch(Bin previous) {
    final body = <String, dynamic>{};

    void put(String key, Object? value, Object? old) {
      if (value != old) body[key] = value;
    }

    put('name', name, previous.name);
    put('collects', collects, previous.collects);
    put('fillPercent', fillLevel, previous.fillLevel);
    put('rejectedFillPercent', rejectedFillLevel, previous.rejectedFillLevel);
    put('latitude', latitude, previous.latitude);
    put('longitude', longitude, previous.longitude);
    put('address', address, previous.address);
    put('sensorId', sensorId, previous.sensorId);
    put('capacityKg', capacityKg, previous.capacityKg);
    put('notes', notes, previous.notes);
    put('disabled', isActive ? null : true, previous.isActive ? null : true);

    return body.isEmpty ? null : body;
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
