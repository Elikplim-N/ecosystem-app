import 'dart:async';

import 'api_client.dart';

/// Re-runs [fetch] on a timer and pushes the results into a broadcast stream.
///
/// The API has no push channel — no Firestore snapshots, no websockets, no SSE
/// — so this is what replaces the live queries the app used to have. Anything
/// that was `StreamBuilder(stream: firestore.snapshots())` is now
/// `StreamBuilder(stream: poll(...))` and behaves the same way to the widget:
/// first value arrives, then the screen updates on its own.
///
/// Two details matter for correctness:
///
///  * A failed poll does **not** end the stream. Keeping the last good list
///    means a blip of bad mobile data does not blank a dashboard the user is
///    mid-way through reading; they see slightly stale numbers instead, and it
///    recovers on the next tick.
///  * A poll never overlaps itself. If a request is still in flight when the
///    timer comes round, the tick is skipped rather than queued, so a slow
///    connection cannot pile up requests against the API's rate limit.
Stream<List<T>> pollList<T>(
  Future<List<T>> Function() fetch, {
  required Duration interval,
  List<T> seed = const [],
}) {
  late StreamController<List<T>> controller;
  Timer? timer;
  var inFlight = false;
  var closed = false;

  Future<void> tick() async {
    if (inFlight || closed) return;
    inFlight = true;
    try {
      final items = await fetch();
      if (!closed) controller.add(items);
    } on Object {
      // Swallowed on purpose — see the note above about keeping the last
      // known-good list. A genuinely broken server is visible as numbers that
      // never move, which is a better failure mode than an error screen on
      // every dashboard.
    } finally {
      inFlight = false;
    }
  }

  controller = StreamController<List<T>>.broadcast(
    onListen: () {
      // Seed synchronously so a StreamBuilder has something on its first
      // frame rather than showing an empty state for one interval.
      if (seed.isNotEmpty) controller.add(seed);
      tick();
      timer = Timer.periodic(interval, (_) => tick());
    },
    onCancel: () {
      closed = true;
      timer?.cancel();
      timer = null;
    },
  );

  return controller.stream;
}

/// A single value, refetched on a timer. For "the current member" style reads
/// where there is no list to reconcile.
Stream<T> pollValue<T>(
  Future<T> Function() fetch, {
  required Duration interval,
  T? seed,
}) {
  late StreamController<T> controller;
  Timer? timer;
  var inFlight = false;
  var closed = false;

  Future<void> tick() async {
    if (inFlight || closed) return;
    inFlight = true;
    try {
      final value = await fetch();
      if (!closed) controller.add(value);
    } on ApiException catch (e) {
      if (closed) return;
      // A rejected session is not transient, so the caller does need to hear
      // about it — the auth gate is listening to know to sign the user out.
      controller.addError(e);
    } on Object {
      // Network trouble: stay quiet, try again next tick.
    } finally {
      inFlight = false;
    }
  }

  controller = StreamController<T>.broadcast(
    onListen: () {
      if (seed != null) controller.add(seed);
      tick();
      timer = Timer.periodic(interval, (_) => tick());
    },
    onCancel: () {
      closed = true;
      timer?.cancel();
      timer = null;
    },
  );

  return controller.stream;
}

/// How often live views refetch.
///
/// Deliberately not fast. Fill levels change when someone empties a bin, not
/// continuously, and the API rate limit is 300 requests a minute — a one-second
/// poll across a handful of open screens would be a meaningful share of that.
class PollInterval {
  /// Dashboards and lists the user is actively looking at.
  static const standard = Duration(seconds: 20);

  /// Bin detail, where a slider move should feel reflected.
  static const brisk = Duration(seconds: 10);

  /// The signed-in member's own balance.
  static const account = Duration(seconds: 30);
}
