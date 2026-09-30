class RewardModel {
  final String id;
  final String title;
  final String description;
  final int pointsCost;
  final String category; // 'airtime', 'momo', 'discount', 'merchandise'
  final bool isActive;
  final String? partnerName;

  RewardModel({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsCost,
    this.category = 'airtime',
    this.isActive = true,
    this.partnerName,
  });

  factory RewardModel.fromJson(Map<String, dynamic> json) {
    return RewardModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      pointsCost: json['pointsCost'] ?? json['costPoints'] ?? json['cost'] ?? 100,
      category: json['category'] ?? 'airtime',
      isActive: json['isActive'] ?? json['active'] ?? true,
      partnerName: json['partnerName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'pointsCost': pointsCost,
      'category': category,
      'isActive': isActive,
      'partnerName': partnerName,
    };
  }

  RewardModel copyWith({
    String? id,
    String? title,
    String? description,
    int? pointsCost,
    String? category,
    bool? isActive,
    String? partnerName,
  }) {
    return RewardModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      pointsCost: pointsCost ?? this.pointsCost,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      partnerName: partnerName ?? this.partnerName,
    );
  }
}
