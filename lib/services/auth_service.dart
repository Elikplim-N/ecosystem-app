import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/member.dart';
import 'api_client.dart';

/// Where the app should be right now.
enum AuthStatus {
  /// Still reading the stored session; the splash screen shows a spinner.
  unknown,

  /// No valid session. The welcome screen is shown.
  signedOut,

  /// A session exists and the member is known.
  signedIn,
}

/// Holds the current session and the signed-in [Member].
///
/// The app used to get all of this from `FirebaseAuth.instance` plus a
/// `users/{uid}` document. It is all in the `Authorization` header and
/// `GET /api/auth/me` now, so this class is what those two used to be.
///
/// [statusChanges] replaces `authStateChanges()`. It replays the current status
/// to each new listener, so a `StreamBuilder` that subscribes after sign-in has
/// already happened still renders the right thing instead of waiting forever.
class AuthService {
  AuthService({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  static const _cachedUserKey = 'cached_user';

  final _status = StreamController<AuthStatus>.broadcast();
  final _member = StreamController<Member?>.broadcast();
  final _session = StreamController<MemberSession>.broadcast();

  /// Fires on every transition, and immediately on subscribe.
  ///
  /// Replays [_current] first, because the app restores the session before
  /// `runApp` — every listener would otherwise subscribe after the only
  /// events that mattered had already gone by.
  Stream<AuthStatus> get statusChanges async* {
    yield _current;
    yield* _status.stream;
  }

  /// The signed-in member, re-emitted whenever their data is refetched.
  Stream<Member?> get memberChanges async* {
    yield _memberValue;
    yield* _member.stream;
  }

  /// Status and member together, which is what a routing widget needs.
  ///
  /// Firebase needed two nested `StreamBuilder`s — one for the auth token and
  /// one for the profile document. Here both live in one place, so they cannot
  /// be momentarily out of step and produce a frame that says "signed in, no
  /// profile" or the reverse.
  Stream<MemberSession> get sessions async* {
    yield MemberSession(_current, _memberValue);
    yield* _session.stream;
  }

  AuthStatus _current = AuthStatus.unknown;
  Member? _memberValue;

  AuthStatus get status => _current;
  Member? get currentMember => _memberValue;
  String get currentUid => _memberValue?.uid ?? '';
  bool get isSignedIn => _current == AuthStatus.signedIn;
  bool get isAdmin => _memberValue?.role.isAdmin ?? false;
  bool get isAmbassador => _memberValue?.role.isAmbassador ?? false;

  void _set(AuthStatus status, [Member? member]) {
    _current = status;
    if (member != null) _memberValue = member;
    if (status != AuthStatus.signedIn) _memberValue = null;
    if (!_status.isClosed) _status.add(status);
    if (!_member.isClosed) _member.add(_memberValue);
    if (!_session.isClosed) _session.add(MemberSession(status, _memberValue));
  }

  /// Restores a session from disk at startup.
  ///
  /// The cached member is shown immediately so the app does not flash the
  /// welcome screen on every launch, then [refreshCurrentMember] confirms it
  /// against the server. A server that rejects the token is the signal that the
  /// session is genuinely over, which is when the tokens get cleared.
  Future<void> restore() async {
    await _api.restore();

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cachedUserKey);

    if (!_api.isAuthenticated) {
      _set(AuthStatus.signedOut);
      return;
    }

    if (cached != null) {
      try {
        _set(
          AuthStatus.signedIn,
          Member.fromJson(jsonDecode(cached) as Map<String, dynamic>),
        );
      } on Object {
        // Corrupt cache; the refresh below will replace it.
      }
    }

    try {
      await refreshCurrentMember();
    } on ApiOfflineException {
      // Offline at launch with a valid cached member: stay signed in. The
      // member is the last known state, and failing them out because the
      // network is down would be wrong.
      if (_memberValue != null) {
        _set(AuthStatus.signedIn);
      } else {
        await signOut();
      }
    } on ApiException catch (e) {
      if (e.isUnauthorised) {
        await _api.clearTokens();
        _set(AuthStatus.signedOut);
      } else {
        _set(_memberValue == null ? AuthStatus.signedOut : AuthStatus.signedIn);
      }
    }
  }

  /// POST /api/auth/login. [identifier] may be a phone number or an email.
  Future<Member> signIn({
    required String identifier,
    required String password,
  }) async {
    final body = await _api.postJson(
      '/api/auth/login',
      auth: false,
      body: {'identifier': identifier.trim(), 'password': password},
    );

    await _api.saveTokens(
      access: body['accessToken'] as String,
      refresh: body['refreshToken'] as String,
    );

    final member = Member.fromJson(body['user'] as Map<String, dynamic>);
    await _cache(member);
    _set(AuthStatus.signedIn, member);
    return member;
  }

  /// POST /api/auth/register. The backend normalises the phone number and
  /// creates the session in the same transaction, so this signs you in.
  Future<Member> register({
    required String name,
    required String phone,
    required String password,
    String? email,
    String? nickname,
    String? avatarIcon,
  }) async {
    final body = await _api.postJson(
      '/api/auth/register',
      auth: false,
      body: {
        'name': name.trim(),
        'phone': phone.trim(),
        'password': password,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (nickname != null && nickname.trim().isNotEmpty)
          'nickname': nickname.trim(),
        if (avatarIcon != null && avatarIcon.trim().isNotEmpty)
          'avatarIcon': avatarIcon.trim(),
      },
    );

    await _api.saveTokens(
      access: body['accessToken'] as String,
      refresh: body['refreshToken'] as String,
    );

    final member = Member.fromJson(body['user'] as Map<String, dynamic>);
    await _cache(member);
    _set(AuthStatus.signedIn, member);
    return member;
  }

  /// GET /api/auth/me. Call after anything that changes the member's own
  /// points, role or profile so the header and dashboard stay in step.
  Future<Member> refreshCurrentMember() async {
    final body = await _api.getJson('/api/auth/me');
    final member = Member.fromJson(body['user'] as Map<String, dynamic>);
    await _cache(member);
    _set(AuthStatus.signedIn, member);
    return member;
  }

  Future<void> signOut() async {
    // Best effort: revoke the session server-side so the refresh token dies
    // even if this device is wiped without a network round trip.
    final refreshToken = await _refreshTokenIfAny();
    if (refreshToken != null) {
      try {
        await _api.postJson(
          '/api/auth/logout',
          auth: false,
          body: {'refreshToken': refreshToken},
        );
      } on Object {
        // Offline sign-out still signs out this device.
      }
    }

    await _api.clearTokens();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedUserKey);
    _set(AuthStatus.signedOut);
  }

  Future<String?> _refreshTokenIfAny() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  Future<void> _cache(Member member) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedUserKey, jsonEncode(member.toJson()));
  }

  /// Replaces the cached member without a round trip, after a screen edits
  /// their own profile.
  Future<void> updateCachedMember(Member member) async {
    await _cache(member);
    _set(AuthStatus.signedIn, member);
  }

  void dispose() {
    _status.close();
    _member.close();
    _session.close();
  }
}

/// A snapshot of who is signed in: the status and the member it belongs to.
class MemberSession {
  const MemberSession(this.status, this.member);

  final AuthStatus status;
  final Member? member;

  bool get signedIn => status == AuthStatus.signedIn && member != null;
}

/// Shared instance, so the whole app agrees on who is signed in.
final AuthService auth = AuthService();
