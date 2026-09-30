import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/deposit_model.dart';
import '../models/reward_model.dart';
import '../models/kiosk_session_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Configurable VPS Base URL
  String _baseUrl = 'http://localhost:3000/api';
  String? _authToken;
  UserModel? _currentUser;
  bool _useMockFallback = true; // Seamless offline/demo fallback

  String get baseUrl => _baseUrl;
  bool get isAuthenticated => _currentUser != null;
  UserModel? get currentUser => _currentUser;

  // Stream controller for live user updates
  final _userController = StreamController<UserModel?>.broadcast();
  Stream<UserModel?> get userStream => _userController.stream;

  // Stream controller for kiosk sessions
  final _kioskController = StreamController<KioskSessionModel>.broadcast();
  Stream<KioskSessionModel> get kioskStream => _kioskController.stream;

  // Current mock state for testing
  KioskSessionModel _mockKiosk = KioskSessionModel(kioskId: 'kiosk_01');
  final List<DepositModel> _mockDeposits = [];
  final List<RewardModel> _mockRewards = [
    RewardModel(id: 'rew_1', title: '5 GHS MTN Airtime', description: 'Instant mobile credit recharge', pointsCost: 50, category: 'airtime', partnerName: 'MTN'),
    RewardModel(id: 'rew_2', title: '10 GHS Telecel Cash', description: 'Mobile money voucher transfer', pointsCost: 100, category: 'momo', partnerName: 'Telecel'),
    RewardModel(id: 'rew_3', title: 'BoaMe Reusable Tote Bag', description: 'Eco-friendly recycled cotton tote bag', pointsCost: 150, category: 'merchandise', partnerName: 'BoaMe'),
    RewardModel(id: 'rew_4', title: '15% Off Campus Cafe', description: 'Discount code on healthy meals', pointsCost: 75, category: 'discount', partnerName: 'Campus Cafe'),
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('vps_base_url') ?? 'http://localhost:3000/api';
    _authToken = prefs.getString('auth_token');
    final savedUserJson = prefs.getString('cached_user');
    if (savedUserJson != null) {
      try {
        _currentUser = UserModel.fromJson(jsonDecode(savedUserJson));
        _userController.add(_currentUser);
      } catch (_) {}
    }
  }

  Future<void> setBaseUrl(String newUrl) async {
    _baseUrl = newUrl.replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vps_base_url', _baseUrl);
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  // ==========================================
  // AUTHENTICATION
  // ==========================================

  Future<UserModel> login({required String identifier, required String password}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identifier': identifier, 'password': password}),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _authToken = data['token'];
        _currentUser = UserModel.fromJson(data['user']);
        await _saveAuthData();
        _userController.add(_currentUser);
        return _currentUser!;
      }
    } catch (_) {}

    // Mock fallback when VPS is offline/local testing
    if (_useMockFallback) {
      _currentUser = UserModel(
        id: 'usr_${identifier.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}',
        name: identifier.contains('@') ? identifier.split('@')[0] : 'Kofi Mensah',
        phone: identifier.contains('@') ? '0241234567' : identifier,
        email: identifier.contains('@') ? identifier : '$identifier@boame.eco',
        nickname: 'EcoRecycler',
        role: identifier.toLowerCase().contains('admin') ? 'admin' : 'user',
        points: 240,
        bottles: 24,
        weight: 0.65,
        rfidUid: 'A3 F1 82 4B',
      );
      _authToken = 'mock_jwt_token_12345';
      await _saveAuthData();
      _userController.add(_currentUser);
      return _currentUser!;
    }
    throw Exception('Login failed. Please check credentials or VPS connection.');
  }

  Future<UserModel> register({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'phone': phone, 'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _authToken = data['token'];
        _currentUser = UserModel.fromJson(data['user']);
        await _saveAuthData();
        _userController.add(_currentUser);
        return _currentUser!;
      }
    } catch (_) {}

    if (_useMockFallback) {
      _currentUser = UserModel(
        id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        phone: phone,
        email: email,
        nickname: name,
        role: 'user',
        points: 0,
        bottles: 0,
        weight: 0.0,
      );
      _authToken = 'mock_jwt_token_reg';
      await _saveAuthData();
      _userController.add(_currentUser);
      return _currentUser!;
    }
    throw Exception('Registration failed. Unable to reach server.');
  }

  Future<void> logout() async {
    _authToken = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('cached_user');
    _userController.add(null);
  }

  Future<void> _saveAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    if (_authToken != null) await prefs.setString('auth_token', _authToken!);
    if (_currentUser != null) await prefs.setString('cached_user', jsonEncode(_currentUser!.toJson()));
  }

  // ==========================================
  // USER & PROFILE
  // ==========================================

  Future<UserModel> linkRfidCard(String rfidUid) async {
    if (_currentUser == null) throw Exception('No user logged in');
    final formattedUid = rfidUid.trim().toUpperCase();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/user/link-rfid'),
        headers: _headers,
        body: jsonEncode({'rfidUid': formattedUid}),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = UserModel.fromJson(data['user']);
        await _saveAuthData();
        _userController.add(_currentUser);
        return _currentUser!;
      }
    } catch (_) {}

    // Mock update
    _currentUser = _currentUser!.copyWith(rfidUid: formattedUid);
    await _saveAuthData();
    _userController.add(_currentUser);
    return _currentUser!;
  }

  Future<UserModel> updateProfile({String? nickname, String? avatarIcon, String? phone}) async {
    if (_currentUser == null) throw Exception('No user logged in');
    _currentUser = _currentUser!.copyWith(
      nickname: nickname,
      avatarIcon: avatarIcon,
      phone: phone,
    );
    await _saveAuthData();
    _userController.add(_currentUser);
    return _currentUser!;
  }

  Future<List<DepositModel>> getDeposits() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/user/deposits'), headers: _headers).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => DepositModel.fromJson(e)).toList();
      }
    } catch (_) {}

    return _mockDeposits.isNotEmpty
        ? _mockDeposits
        : [
            DepositModel(id: 'dep_1', userId: 'usr_me', kioskId: 'kiosk_01', bottles: 5, weight: 0.12, points: 50, bottleType: 'Clear PET', timestamp: DateTime.now().subtract(const Duration(hours: 2))),
            DepositModel(id: 'dep_2', userId: 'usr_me', kioskId: 'kiosk_01', bottles: 3, weight: 0.08, points: 30, bottleType: 'Colored PET', timestamp: DateTime.now().subtract(const Duration(days: 1))),
          ];
  }

  Future<List<UserModel>> getLeaderboard() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/leaderboard'), headers: _headers).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => UserModel.fromJson(e)).toList();
      }
    } catch (_) {}

    return [
      UserModel(id: 'u1', name: 'Ama Owusu', phone: '0241112222', email: 'ama@mail.com', nickname: 'Ama Green', points: 620, bottles: 62, weight: 1.55, avatarIcon: '🌱'),
      UserModel(id: 'u2', name: 'Kwame Asante', phone: '0203334444', email: 'kwame@mail.com', nickname: 'KwameRecycles', points: 480, bottles: 48, weight: 1.20, avatarIcon: '♻️'),
      UserModel(id: 'u3', name: 'Kofi Mensah', phone: '0241234567', email: 'kofi@mail.com', nickname: 'EcoRecycler', points: 240, bottles: 24, weight: 0.65, avatarIcon: '🙂'),
      UserModel(id: 'u4', name: 'Abena Serwaa', phone: '0555556666', email: 'abena@mail.com', nickname: 'AbenaEco', points: 190, bottles: 19, weight: 0.48, avatarIcon: '🌸'),
    ];
  }

  // ==========================================
  // REWARDS
  // ==========================================

  Future<List<RewardModel>> getRewards() async => _mockRewards;

  Future<bool> redeemReward(String rewardId) async {
    final reward = _mockRewards.firstWhere((r) => r.id == rewardId);
    if (_currentUser == null || _currentUser!.points < reward.pointsCost) return false;

    _currentUser = _currentUser!.copyWith(points: _currentUser!.points - reward.pointsCost);
    await _saveAuthData();
    _userController.add(_currentUser);
    return true;
  }

  // ==========================================
  // KIOSK / RVM REVERSE VENDING MACHINE API
  // ==========================================

  KioskSessionModel get currentKioskState => _mockKiosk;

  Future<KioskSessionModel> startKioskSessionByPhone(String phone) async {
    _mockKiosk = KioskSessionModel(
      kioskId: 'kiosk_01',
      state: KioskState.activeSession,
      phone: phone,
      userName: phone == _currentUser?.phone ? _currentUser?.name : 'User ($phone)',
      userId: phone == _currentUser?.phone ? _currentUser?.id : 'guest_$phone',
      mode: 'phone',
      sessionBottles: 0,
      sessionPoints: 0,
      sessionWeight: 0.0,
      statusMessage: 'Ready! Drop bottles into machine slot.',
    );
    _kioskController.add(_mockKiosk);
    return _mockKiosk;
  }

  Future<KioskSessionModel> startKioskSessionByRfid(String rfidUid) async {
    final formatted = rfidUid.trim().toUpperCase();
    _mockKiosk = KioskSessionModel(
      kioskId: 'kiosk_01',
      state: KioskState.activeSession,
      userName: (formatted == _currentUser?.rfidUid) ? _currentUser?.name : 'Cardholder ($formatted)',
      userId: (formatted == _currentUser?.rfidUid) ? _currentUser?.id : 'guest_rfid',
      mode: 'rfid',
      sessionBottles: 0,
      sessionPoints: 0,
      sessionWeight: 0.0,
      statusMessage: 'Card Verified! Session started.',
    );
    _kioskController.add(_mockKiosk);
    return _mockKiosk;
  }

  Future<KioskSessionModel> startKioskSessionAnonymous() async {
    _mockKiosk = KioskSessionModel(
      kioskId: 'kiosk_01',
      state: KioskState.activeSession,
      userName: 'Eco Contributor (Anonymous)',
      mode: 'anonymous',
      sessionBottles: 0,
      sessionPoints: 0,
      sessionWeight: 0.0,
      statusMessage: 'Anonymous session active. Thank you for recycling!',
    );
    _kioskController.add(_mockKiosk);
    return _mockKiosk;
  }

  Future<KioskSessionModel> recordKioskBottleDeposit({
    required String bottleClass, // 'Clear PET', 'Colored PET', 'HDPE'
    double weight = 0.025,
  }) async {
    int pointsEarned = 10;
    if (bottleClass.contains('Color')) pointsEarned = 8;
    if (bottleClass.contains('HDPE')) pointsEarned = 12;

    _mockKiosk = KioskSessionModel(
      kioskId: _mockKiosk.kioskId,
      state: KioskState.itemAccepted,
      userId: _mockKiosk.userId,
      userName: _mockKiosk.userName,
      phone: _mockKiosk.phone,
      mode: _mockKiosk.mode,
      sessionBottles: _mockKiosk.sessionBottles + 1,
      sessionPoints: _mockKiosk.sessionPoints + pointsEarned,
      sessionWeight: _mockKiosk.sessionWeight + weight,
      lastBottleClass: bottleClass,
      statusMessage: 'Accepted: $bottleClass (+$pointsEarned pts)',
    );

    // If user is currently logged in and matches session, credit their balance live!
    if (_currentUser != null && (_mockKiosk.userId == _currentUser!.id || _mockKiosk.phone == _currentUser!.phone)) {
      _currentUser = _currentUser!.copyWith(
        points: _currentUser!.points + pointsEarned,
        bottles: _currentUser!.bottles + 1,
        weight: _currentUser!.weight + weight,
      );
      _mockDeposits.insert(
        0,
        DepositModel(
          id: 'dep_${DateTime.now().millisecondsSinceEpoch}',
          userId: _currentUser!.id,
          kioskId: _mockKiosk.kioskId,
          bottles: 1,
          weight: weight,
          points: pointsEarned,
          bottleType: bottleClass,
          timestamp: DateTime.now(),
        ),
      );
      await _saveAuthData();
      _userController.add(_currentUser);
    }

    _kioskController.add(_mockKiosk);
    return _mockKiosk;
  }

  Future<KioskSessionModel> finishKioskSession() async {
    _mockKiosk = KioskSessionModel(
      kioskId: _mockKiosk.kioskId,
      state: KioskState.sessionSummary,
      userId: _mockKiosk.userId,
      userName: _mockKiosk.userName,
      phone: _mockKiosk.phone,
      mode: _mockKiosk.mode,
      sessionBottles: _mockKiosk.sessionBottles,
      sessionPoints: _mockKiosk.sessionPoints,
      sessionWeight: _mockKiosk.sessionWeight,
      statusMessage: 'Recycling complete! Thank you for protecting the environment.',
    );
    _kioskController.add(_mockKiosk);
    return _mockKiosk;
  }

  void resetKiosk() {
    _mockKiosk = KioskSessionModel(kioskId: 'kiosk_01', state: KioskState.idle);
    _kioskController.add(_mockKiosk);
  }

  // ==========================================
  // ADMIN ACTIONS
  // ==========================================
  Future<UserModel> adminRegisterUser({
    required String name,
    required String phone,
    required String email,
    String? rfidUid,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/admin/users'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'email': email,
          if (rfidUid != null && rfidUid.isNotEmpty) 'rfidUid': rfidUid,
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserModel.fromJson(data['user'] ?? data);
      }
    } catch (_) {}

    return UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      phone: phone,
      email: email,
      nickname: name,
      rfidUid: rfidUid,
      role: 'user',
      points: 0,
      bottles: 0,
      weight: 0.0,
    );
  }

  Future<RewardModel> adminAddReward({
    required String title,
    required String description,
    required int pointsCost,
    required String category,
    String? partnerName,
  }) async {
    final newReward = RewardModel(
      id: 'rew_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      pointsCost: pointsCost,
      category: category,
      partnerName: partnerName,
      isActive: true,
    );

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/admin/rewards'),
        headers: _headers,
        body: jsonEncode(newReward.toJson()),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final created = RewardModel.fromJson(data);
        _mockRewards.add(created);
        return created;
      }
    } catch (_) {}

    _mockRewards.add(newReward);
    return newReward;
  }

  Future<void> adminToggleReward(String id, bool active) async {
    try {
      await http.patch(
        Uri.parse('$_baseUrl/admin/rewards/$id'),
        headers: _headers,
        body: jsonEncode({'active': active}),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}

    final index = _mockRewards.indexWhere((r) => r.id == id);
    if (index != -1) {
      _mockRewards[index] = _mockRewards[index].copyWith(isActive: active);
    }
  }

  Future<void> adminDeleteReward(String id) async {
    try {
      await http.delete(
        Uri.parse('$_baseUrl/admin/rewards/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}

    _mockRewards.removeWhere((r) => r.id == id);
  }
}
