import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bin.dart';
import '../screens/demo_data.dart';
import 'demo_bins.dart';

/// All bin reads and writes funnel through here so the demo fallback
/// and the write rules live in exactly one place.
class BinsRepository {
  BinsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const collection = 'bins';

  CollectionReference<Map<String, dynamic>> get _bins =>
      _db.collection(collection);

  /// Live bins, falling back to [demoBins] when the collection is empty
  /// and demo mode is on.
  Stream<List<Bin>> watch() {
    return _bins.orderBy('code').snapshots().map((snap) {
      final bins = snap.docs.map(Bin.fromDocument).toList();
      if (bins.isEmpty && kDemoMode) return demoBins();
      return bins;
    });
  }

  /// Bin counts derived from one snapshot, used by the dashboards.
  static BinSummary summarise(List<Bin> bins) {
    return BinSummary(
      total: bins.length,
      active: bins.where((b) => b.isActive).length,
      available: bins.where((b) => b.status == BinStatus.available).length,
      full: bins.where((b) => b.status == BinStatus.full).length,
      filling: bins.where((b) => b.status == BinStatus.filling).length,
      disabled: bins.where((b) => b.status == BinStatus.disabled).length,
      sensor: bins.where((b) => b.hasSensor).length,
      rejectedFull: bins.where((b) => b.rejectedFull).length,
    );
  }

  /// Generates the next `BIN-###` code from whatever already exists.
  Future<String> nextCode() async {
    final snap = await _bins.get();
    var highest = 0;
    for (final doc in snap.docs) {
      final raw = (doc.data()['code'] ?? '').toString();
      final digits = RegExp(r'(\d+)').firstMatch(raw)?.group(1);
      if (digits != null) {
        final value = int.tryParse(digits) ?? 0;
        if (value > highest) highest = value;
      }
    }
    return 'BIN-${(highest + 1).toString().padLeft(3, '0')}';
  }

  Future<String> create({
    required String code,
    required String name,
    required double latitude,
    required double longitude,
    required String address,
    required String collects,
    double fillLevel = 0,
    BinStatus? status,
    required String createdById,
    required String createdByRole,
    required String createdByName,
  }) async {
    final doc = _bins.doc();
    final now = DateTime.now();

    await doc.set({
      ...Bin(
        id: doc.id,
        code: code.trim(),
        name: name.trim(),
        status: status ?? BinStatus.fromFill(fillLevel),
        fillLevel: fillLevel,
        rejectedFillLevel: 0,
        collects: collects.trim(),
        latitude: latitude,
        longitude: longitude,
        address: address.trim(),
        createdById: createdById,
        createdByRole: createdByRole,
        createdByName: createdByName,
      ).toDocument(),
      'createdAt': Timestamp.fromDate(now),
    });

    return doc.id;
  }

  /// Full update. Use for edits that come from a form.
  Future<void> update(Bin bin) async {
    await _bins.doc(bin.id).set(bin.toDocument(), SetOptions(merge: true));
  }

  Future<void> setStatus(String binId, BinStatus status, {double? fillLevel}) async {
    final data = <String, dynamic>{
      'status': status.id,
      'statusSource': 'manual',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (fillLevel != null) data['fillLevel'] = fillLevel;
    await _bins.doc(binId).update(data);
  }

  /// Manual fill-level adjustment for bins without a sensor.
  Future<void> setFillLevel(String binId, double level) async {
    final clamped = level.clamp(0, 100).toDouble();

    await _bins.doc(binId).update({
      'fillLevel': clamped,
      'status': BinStatus.fromFill(clamped).id,
      'statusSource': 'manual',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Empties the bin and records the collection.
  Future<void> markCollected(String binId) async {
    await _bins.doc(binId).update({
      'status': BinStatus.available.id,
      'fillLevel': 0,
      'rejectedFillLevel': 0,
      'statusSource': 'manual',
      'lastCollectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Rejected-compartment level, reported by its own sensor.
  Future<void> setRejectedFillLevel(String binId, double level) async {
    await _bins.doc(binId).update({
      'rejectedFillLevel': level.clamp(0, 100),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String binId) async {
    await _bins.doc(binId).delete();
  }

  /// True when [role] may modify [bin]. Ambassadors own the bins they added.
  static bool canEdit(Bin bin, {required String uid, required String role}) {
    if (role == 'admin') return true;
    if (role == 'ambassador') return bin.createdById == uid;
    return false;
  }
}

/// Aggregate numbers shown on the admin and ambassador dashboards.
class BinSummary {
  const BinSummary({
    required this.total,
    required this.active,
    required this.available,
    required this.full,
    required this.filling,
    required this.disabled,
    required this.sensor,
    this.rejectedFull = 0,
  });

  final int total;
  final int active;
  final int available;
  final int full;
  final int filling;
  final int disabled;
  final int sensor;

  /// Bins whose rejected compartment has reached capacity.
  final int rejectedFull;

  static const empty = BinSummary(
    total: 0,
    active: 0,
    available: 0,
    full: 0,
    filling: 0,
    disabled: 0,
    sensor: 0,
    rejectedFull: 0,
  );
}
