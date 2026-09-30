class DepositModel {
  final String id;
  final String userId;
  final String kioskId;
  final int bottles;
  final double weight;
  final int points;
  final String bottleType; // 'Clear PET', 'Colored PET', 'HDPE'
  final DateTime timestamp;

  DepositModel({
    required this.id,
    required this.userId,
    required this.kioskId,
    required this.bottles,
    required this.weight,
    required this.points,
    this.bottleType = 'Clear PET',
    required this.timestamp,
  });

  // Getters for convenience
  int get bottleCount => bottles;
  int get pointsAwarded => points;
  String get materialType => bottleType;

  factory DepositModel.fromJson(Map<String, dynamic> json) {
    return DepositModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      kioskId: json['kioskId'] ?? 'kiosk_01',
      bottles: json['bottles'] ?? json['bottleCount'] ?? 1,
      weight: ((json['weight'] ?? 0.0) as num).toDouble(),
      points: json['points'] ?? json['pointsAwarded'] ?? 0,
      bottleType: json['bottleType'] ?? json['materialType'] ?? 'Clear PET',
      timestamp: json['timestamp'] != null
          ? (json['timestamp'] is String
              ? (DateTime.tryParse(json['timestamp']) ?? DateTime.now())
              : DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'kioskId': kioskId,
      'bottles': bottles,
      'weight': weight,
      'points': points,
      'bottleType': bottleType,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
