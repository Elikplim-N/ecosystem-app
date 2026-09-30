class UserModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String nickname;
  final String avatarIcon;
  final String role; // 'user' or 'admin'
  final int points;
  final int bottles;
  final double weight;
  final String? rfidUid;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.nickname,
    this.avatarIcon = '🙂',
    this.role = 'user',
    this.points = 0,
    this.bottles = 0,
    this.weight = 0.0,
    this.rfidUid,
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';
  bool get hasRfid => rfidUid != null && rfidUid!.isNotEmpty;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['uid'] ?? '',
      name: json['name'] ?? 'User',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      nickname: json['nickname'] ?? json['name'] ?? 'User',
      avatarIcon: json['avatarIcon'] ?? '🙂',
      role: json['role'] ?? 'user',
      points: (json['points'] ?? 0) is int ? (json['points'] ?? 0) : ((json['points'] as num?)?.toInt() ?? 0),
      bottles: (json['bottles'] ?? 0) is int ? (json['bottles'] ?? 0) : ((json['bottles'] as num?)?.toInt() ?? 0),
      weight: ((json['weight'] ?? 0.0) as num).toDouble(),
      rfidUid: json['rfidUid'],
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is String ? DateTime.tryParse(json['createdAt']) : null)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'nickname': nickname,
      'avatarIcon': avatarIcon,
      'role': role,
      'points': points,
      'bottles': bottles,
      'weight': weight,
      'rfidUid': rfidUid,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? email,
    String? nickname,
    String? avatarIcon,
    String? role,
    int? points,
    int? bottles,
    double? weight,
    String? rfidUid,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      role: role ?? this.role,
      points: points ?? this.points,
      bottles: bottles ?? this.bottles,
      weight: weight ?? this.weight,
      rfidUid: rfidUid ?? this.rfidUid,
      createdAt: createdAt,
    );
  }
}
