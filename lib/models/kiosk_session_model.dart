enum KioskState { idle, authenticating, identified, activeSession, processingBottle, itemAccepted, itemRejected, sessionSummary }

class KioskSessionModel {
  final String kioskId;
  final KioskState state;
  final String? userId;
  final String? userName;
  final String? phone;
  final String mode; // 'rfid', 'phone', 'anonymous'
  final int sessionBottles;
  final int sessionPoints;
  final double sessionWeight;
  final String? lastBottleClass; // 'Clear PET', 'Colored PET', 'HDPE'
  final String? statusMessage;

  KioskSessionModel({
    required this.kioskId,
    this.state = KioskState.idle,
    this.userId,
    this.userName,
    this.phone,
    this.mode = 'anonymous',
    this.sessionBottles = 0,
    this.sessionPoints = 0,
    this.sessionWeight = 0.0,
    this.lastBottleClass,
    this.statusMessage,
  });

  bool get isIdle => state == KioskState.idle;
  bool get isActive => state == KioskState.activeSession || state == KioskState.processingBottle || state == KioskState.itemAccepted;

  factory KioskSessionModel.fromJson(Map<String, dynamic> json) {
    KioskState parsedState = KioskState.idle;
    final stateStr = json['state'] ?? 'idle';
    switch (stateStr) {
      case 'authenticating':
        parsedState = KioskState.authenticating;
        break;
      case 'identified':
        parsedState = KioskState.identified;
        break;
      case 'active':
      case 'activeSession':
        parsedState = KioskState.activeSession;
        break;
      case 'processing':
      case 'processingBottle':
        parsedState = KioskState.processingBottle;
        break;
      case 'success':
      case 'itemAccepted':
        parsedState = KioskState.itemAccepted;
        break;
      case 'rejected':
      case 'itemRejected':
        parsedState = KioskState.itemRejected;
        break;
      case 'summary':
      case 'sessionSummary':
        parsedState = KioskState.sessionSummary;
        break;
      default:
        parsedState = KioskState.idle;
    }

    return KioskSessionModel(
      kioskId: json['kioskId'] ?? 'kiosk_01',
      state: parsedState,
      userId: json['userId'],
      userName: json['userName'] ?? json['name'],
      phone: json['phone'],
      mode: json['mode'] ?? 'anonymous',
      sessionBottles: json['sessionBottles'] ?? json['bottles'] ?? 0,
      sessionPoints: json['sessionPoints'] ?? json['points'] ?? 0,
      sessionWeight: ((json['sessionWeight'] ?? json['weight'] ?? 0.0) as num).toDouble(),
      lastBottleClass: json['lastBottleClass'],
      statusMessage: json['statusMessage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kioskId': kioskId,
      'state': state.name,
      'userId': userId,
      'userName': userName,
      'phone': phone,
      'mode': mode,
      'sessionBottles': sessionBottles,
      'sessionPoints': sessionPoints,
      'sessionWeight': sessionWeight,
      'lastBottleClass': lastBottleClass,
      'statusMessage': statusMessage,
    };
  }
}
