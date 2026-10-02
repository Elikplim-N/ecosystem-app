import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Raised for any non-2xx response, with the server's own message when it
/// sent one.
///
/// The API always answers failures as `{"error":{"code","message","details?"}}`,
/// and those messages are written for humans ("That phone number is already
/// registered."). Showing them verbatim is the whole point of the backend doing
/// user-facing copy, so they are preferred over anything invented here.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code, this.details});

  final String message;
  final int? statusCode;
  final String? code;
  final List<Map<String, dynamic>>? details;

  /// True when the caller should send the user back to the sign-in screen.
  bool get isUnauthorised => statusCode == 401;

  /// True when the failure is worth showing verbatim. A 500 is not: it is a
  /// bug on the server, and its message is a generic placeholder.
  bool get isUserFacing => statusCode != null && statusCode! < 500;

  @override
  String toString() => message;
}

/// Thrown when the server could not be reached at all.
///
/// A subtype of [ApiException] so a screen that just wants "something went
/// wrong" can catch one type, but distinguishable so the UI can say "check
/// your connection" instead of pretending the request was rejected.
class ApiOfflineException extends ApiException {
  ApiOfflineException([this.cause])
    : super('Cannot reach the server. Check your connection and try again.');

  /// The underlying error, kept for the log rather than shown to the user.
  final Object? cause;
}

/// Talks to the BoaMe REST API.
///
/// This replaces the Firebase SDK the app used to be built on. Three
/// responsibilities live here and nowhere else:
///
///  * holding the base URL, which the user can point at their own server
///  * attaching the bearer token, and transparently redeeming it once when
///    the access token has expired
///  * turning error responses into [ApiException] with a usable message
///
/// Token *storage* is deliberately not here — see `AuthService`.
class ApiClient {
  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _baseUrlKey = 'api_base_url';
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  static const _defaultBaseUrl = 'https://api-boame-178-105-184-157.sslip.io';

  /// Access tokens last 15 minutes by default, so anything that polls should
  /// not be much faster than this.
  static const _timeout = Duration(seconds: 15);

  String _baseUrl = _defaultBaseUrl;
  String? _accessToken;
  String? _refreshToken;

  /// Guards against a burst of parallel 401s each kicking off its own refresh
  /// and rotating the same token twice — the second would invalidate the
  /// first and sign the user out.
  Future<bool>? _refreshInFlight;

  String get baseUrl => _baseUrl;
  bool get isAuthenticated => _accessToken != null;

  /// Restores the saved base URL and tokens. Call once before `runApp`.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
    _accessToken = prefs.getString(_accessTokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
  }

  Future<void> setBaseUrl(String url) async {
    // Trailing slashes are the classic source of `//auth/login` 404s.
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);
  }

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    _accessToken = access;
    _refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, access);
    await prefs.setString(_refreshTokenKey, refresh);
  }

  /// Drops the tokens locally. Does not tell the server; see `AuthService`.
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  Map<String, String> _headers({bool auth = true, String? access}) {
    final token = access ?? _accessToken;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (auth && token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleaned = query?.map((k, v) => MapEntry(k, '$v'))
      ?..removeWhere((_, v) => v.isEmpty);
    return Uri.parse('$_baseUrl$path').replace(
      queryParameters: (cleaned == null || cleaned.isEmpty) ? null : cleaned,
    );
  }

  /// Runs [send], and if the answer is a 401, redeems the refresh token once
  /// and tries again.
  ///
  /// The retry is deliberately single-shot: if the refreshed token is also
  /// rejected the session is genuinely dead, and looping would spin.
  Future<http.Response> _withRefresh(
    Future<http.Response> Function(String? access) send,
  ) async {
    var response = await send(_accessToken);

    if (response.statusCode != 401 || _refreshToken == null) return response;

    final refreshed = await _refresh();
    if (!refreshed) return response;

    response = await send(_accessToken);
    return response;
  }

  Future<bool> _refresh() {
    // Every caller awaits the same future, so N parallel 401s cause one refresh.
    return _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _doRefresh() async {
    final token = _refreshToken;
    if (token == null) return false;

    try {
      final response = await _http
          .post(
            _uri('/api/auth/refresh'),
            headers: _headers(auth: false),
            body: jsonEncode({'refreshToken': token}),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        // A rejected refresh token means the session is over — the user was
        // signed out elsewhere, or the server revoked it. Clear it so the
        // app shows the sign-in screen rather than retrying forever.
        await clearTokens();
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await saveTokens(
        access: data['accessToken'] as String,
        refresh: data['refreshToken'] as String,
      );
      return true;
    } on Object {
      // Offline during the refresh is not a dead session. Keep the tokens and
      // let the original error surface; the next call can try again.
      return false;
    }
  }

  /// Turns a non-2xx response into an [ApiException], preferring the server's
  /// message and falling back to something a user can act on.
  ApiException _error(http.Response response) {
    String? message;
    String? code;
    List<Map<String, dynamic>>? details;

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          message = error['message']?.toString();
          code = error['code']?.toString();
          final raw = error['details'];
          if (raw is List) {
            details = raw.whereType<Map<String, dynamic>>().toList();
          }
        } else if (error is String && error.isNotEmpty) {
          message = error;
        } else if (decoded['message'] is String && (decoded['message'] as String).isNotEmpty) {
          message = decoded['message'] as String;
        }
      }
    } on Object {
      // Not JSON — a proxy or load balancer error page. Fall through.
    }

    if (message == null || message.isEmpty) {
      message = switch (response.statusCode) {
        401 => 'Your session has ended. Please sign in again.',
        403 => 'You do not have permission to do that.',
        404 => 'That could not be found.',
        >= 500 => 'Something went wrong on our end. Please try again.',
        _ => 'Request failed (${response.statusCode}).',
      };
    }

    return ApiException(
      message,
      statusCode: response.statusCode,
      code: code,
      details: details,
    );
  }

  T _unwrap<T>(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _error(response);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List && T == Map<String, dynamic>) {
      return <String, dynamic>{'items': decoded} as T;
    }
    return decoded as T;
  }

  Future<Map<String, dynamic>> getJson(
    String path, [
    Map<String, dynamic>? query,
  ]) async {
    try {
      final response = await _withRefresh(
        (access) => _http
            .get(_uri(path, query), headers: _headers(access: access))
            .timeout(_timeout),
      );
      return _unwrap<Map<String, dynamic>>(response);
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiOfflineException(e);
    }
  }

  /// Every endpoint wraps its payload in a named key (`{"rewards": [...]}`),
  /// so lists are read off the body rather than returned bare.
  List<dynamic> listOf(Map<String, dynamic> body, String key) {
    final value = body[key] ?? body['items'];
    return value is List ? value : const [];
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    try {
      final response = await _withRefresh(
        (access) => _http
            .post(
              _uri(path),
              headers: _headers(auth: auth, access: access),
              body: jsonEncode(body ?? const {}),
            )
            .timeout(_timeout),
      );
      return _unwrap<Map<String, dynamic>>(response);
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiOfflineException(e);
    }
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _withRefresh(
        (access) => _http
            .patch(
              _uri(path),
              headers: _headers(access: access),
              body: jsonEncode(body ?? const {}),
            )
            .timeout(_timeout),
      );
      return _unwrap<Map<String, dynamic>>(response);
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiOfflineException(e);
    }
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _withRefresh(
        (access) => _http
            .delete(
              _uri(path),
              headers: _headers(access: access),
              body: jsonEncode(body ?? const {}),
            )
            .timeout(_timeout),
      );
      return _unwrap<Map<String, dynamic>>(response);
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiOfflineException(e);
    }
  }

  void close() => _http.close();
}

/// Shared instance. The app configures the base URL and tokens on this one.
final ApiClient api = ApiClient();
