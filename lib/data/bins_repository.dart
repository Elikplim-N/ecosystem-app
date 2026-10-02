import '../models/bin.dart';
import '../screens/demo_data.dart' show kDemoMode;
import '../services/api_client.dart';
import '../services/polling.dart';
import 'demo_bins.dart';

/// All bin reads and writes go through here.
///
/// This used to sit on top of a Firestore collection. The interface is
/// unchanged — the screens still call `watch()`, `create()`, `setStatus()` —
/// but the storage is now the REST API, and two consequences come with that:
///
///  * `watch()` is a poll, not a push. See `pollList` for why.
///  * The server owns `bin_state`. It is derived from the fill level, never
///    accepted from the client, so a manual "mark as full" has to be expressed
///    as a fill level instead. `setStatus` does that translation.
class BinsRepository {
  BinsRepository({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// Live bins, falling back to [demoBins] when the server has none yet and
  /// demo mode is on.
  Stream<List<Bin>> watch() {
    return pollList<Bin>(
      () async {
        final body = await _api.getJson('/api/bins');
        final bins = _api
            .listOf(body, 'bins')
            .whereType<Map<String, dynamic>>()
            .map(Bin.fromJson)
            .toList();
        if (bins.isEmpty && kDemoMode) return demoBins();
        return bins;
      },
      interval: PollInterval.standard,
      seed: kDemoMode ? demoBins() : const [],
    );
  }

  /// Bin counts derived from one fetch, used by the dashboards.
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

  /// The dashboard's own aggregate, straight from the database.
  ///
  /// Preferred over [summarise] where it is available: the server can count
  /// every bin, whereas the client has only fetched the first page.
  Future<BinSummary?> fetchSummary() async {
    try {
      final body = await _api.getJson('/api/bins/summary');
      final s = body['summary'];
      if (s is! Map<String, dynamic>) return null;

      int readCount(String key) {
        final value = s[key];
        return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
      }

      return BinSummary(
        total: readCount('total'),
        active: readCount('total') - readCount('disabled'),
        available: readCount('available'),
        full: readCount('full'),
        filling: readCount('filling'),
        disabled: readCount('disabled'),
        sensor: readCount('with_sensor'),
        rejectedFull: readCount('rejected_full'),
      );
    } on Object {
      return null;
    }
  }

  /// Generates the next `BIN-###` code from whatever already exists.
  ///
  /// The server can allocate one atomically via `next_bin_code()`, which is why
  /// `create` does not trust this value — two admins adding a bin at the same
  /// moment would otherwise both pick the same code and one would fail on the
  /// UNIQUE constraint.
  Future<String> nextCode() async {
    final body = await _api.getJson('/api/bins', {'limit': 200});
    var highest = 0;
    for (final raw in _api.listOf(body, 'bins')) {
      if (raw is! Map<String, dynamic>) continue;
      final code = '${raw['code'] ?? ''}';
      final digits = RegExp(r'(\d+)').firstMatch(code)?.group(1);
      if (digits != null) {
        final value = int.tryParse(digits) ?? 0;
        if (value > highest) highest = value;
      }
    }
    return 'BIN-${(highest + 1).toString().padLeft(3, '0')}';
  }

  Future<Bin> create({
    required String code,
    required String name,
    required double latitude,
    required double longitude,
    required String address,
    required String collects,
    double fillLevel = 0,
    BinStatus? status,
    String? rejectedFillLevel,
    required String createdById,
    required String createdByRole,
    required String createdByName,
  }) async {
    final body = await _api.postJson(
      '/api/bins',
      body: {
        'code': code.trim().isEmpty ? null : code.trim(),
        'name': name.trim(),
        'collects': collects.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'address': address.trim(),
        'fillPercent': fillLevel,
        if (rejectedFillLevel != null) 'rejectedFillPercent': rejectedFillLevel,
      },
    );
    return Bin.fromJson(body['bin'] as Map<String, dynamic>);
  }

  /// Full update. Use for edits that come from a form.
  ///
  /// [previous] is the bin as it was before the edit, and is used to send only
  /// the fields that actually changed — otherwise every save would re-audit
  /// every field.
  Future<Bin> update(Bin bin, {required Bin previous}) async {
    final body = bin.toPatch(previous);
    if (body == null) return bin;

    final response = await _api.patchJson('/api/bins/${bin.id}', body: body);
    return Bin.fromJson(response['bin'] as Map<String, dynamic>);
  }

  /// Status-only update, used by the quick action buttons.
  ///
  /// The API derives `bin_state` from a fill percentage and ignores any state
  /// sent to it, so a target status becomes its representative fill level.
  /// "Full" at 95, "filling up" at 70, anything else at 0 — which is exactly
  /// what [BinStatus.fromFill] inverts.
  Future<void> setStatus(
    String binId,
    BinStatus status, {
    double? fillLevel,
  }) async {
    await _api.postJson(
      '/api/bins/$binId/status',
      body: {
        if (fillLevel != null)
          'fillPercent': fillLevel
        else
          'fillPercent': _fillForStatus(status),
        'disabled': status == BinStatus.disabled,
      },
    );
  }

  static double _fillForStatus(BinStatus status) {
    switch (status) {
      case BinStatus.full:
        return 95;
      case BinStatus.filling:
        return 70;
      case BinStatus.available:
      case BinStatus.disabled:
        return 0;
    }
  }

  /// Manual fill-level adjustment for bins without a sensor.
  Future<void> setFillLevel(String binId, double level) {
    return _api.postJson(
      '/api/bins/$binId/status',
      body: {'fillPercent': level.clamp(0, 100)},
    );
  }

  /// Empties the bin and records the collection.
  ///
  /// The weight is not known from the app, so it is sent as an estimate of 0
  /// and flagged as such rather than being invented.
  Future<void> markCollected(
    String binId, {
    double weightKg = 0,
    String? notes,
  }) async {
    await _api.postJson(
      '/api/bins/$binId/collect',
      body: {
        'weightKg': weightKg,
        'isEstimated': true,
        if (notes != null) 'notes': notes,
      },
    );
  }

  /// Rejected-compartment level, reported by its own sensor or by hand.
  Future<void> setRejectedFillLevel(String binId, double level) {
    return _api.postJson(
      '/api/bins/$binId/status',
      body: {'rejectedFillPercent': level.clamp(0, 100)},
    );
  }

  Future<void> delete(String binId) async {
    await _api.deleteJson('/api/bins/$binId');
  }

  /// True when [role] may modify [bin]. Ambassadors own the bins they added.
  ///
  /// The server enforces the same rule in `assertCanEditBin`; this copy is so
  /// the UI can hide the controls rather than let the request fail.
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
