import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_role.dart';
import '../models/member.dart';
import '../screens/demo_data.dart';

/// Summary of one registered RFID tag.
class RfidCard {
  const RfidCard({
    required this.id,
    required this.tag,
    required this.state,
    required this.cardType,
    this.assignedUid,
    this.assignedName,
    this.registeredAt,
    this.notes,
    this.holderRole,
  });

  final String id;

  /// The card's UID exactly as printed/scanned, e.g. `A3F9 21C0`.
  final String tag;
  final RfidState state;
  final String cardType;
  final String? assignedUid;
  final String? assignedName;
  final DateTime? registeredAt;
  final String? notes;
  final String? holderRole;

  bool get isLinked => assignedUid != null && assignedUid!.isNotEmpty;

  factory RfidCard.fromDocument(DocumentSnapshot<dynamic> snap) {
    final data = (snap.data() as Map<String, dynamic>?) ?? const {};
    return RfidCard(
      id: snap.id,
      tag: (data['tag'] ?? '').toString(),
      state: RfidState.fromString(data['state']),
      cardType: (data['cardType'] ?? 'Standard').toString(),
      assignedUid: data['assignedUid']?.toString(),
      assignedName: data['assignedName']?.toString(),
      registeredAt: data['registeredAt'] is Timestamp
          ? (data['registeredAt'] as Timestamp).toDate()
          : null,
      notes: data['notes']?.toString(),
      holderRole: data['holderRole']?.toString(),
    );
  }
}

enum RfidState {
  available,
  linked,
  lost,
  revoked;

  static RfidState fromString(Object? raw) {
    switch (raw) {
      case 'linked':
      case 'assigned':
        return RfidState.linked;
      case 'lost':
        return RfidState.lost;
      case 'revoked':
        return RfidState.revoked;
      default:
        return RfidState.available;
    }
  }

  String get id => name;

  String get label {
    switch (this) {
      case RfidState.available:
        return 'Available';
      case RfidState.linked:
        return 'Linked';
      case RfidState.lost:
        return 'Reported lost';
      case RfidState.revoked:
        return 'Revoked';
    }
  }
}

/// Users, roles, RFID cards and ambassador applications.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _cards => _db.collection('rfidCards');

  // ---------------- roles ----------------

  Future<void> setRole(String uid, AppRole role) async {
    await _users.doc(uid).update({
      'role': role.id,
      if (role == AppRole.ambassador) 'ambassadorStatus': AmbassadorStatus.approved.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------- ambassador applications ----------------

  Future<void> applyForAmbassador({
    required String uid,
    required String name,
    required String area,
    required String motivation,
  }) async {
    await _users.doc(uid).update({
      'ambassadorStatus': AmbassadorStatus.pending.id,
      'ambassadorApplication': {
        'name': name,
        'area': area.trim(),
        'motivation': motivation.trim(),
        'submittedAt': FieldValue.serverTimestamp(),
      },
      'ambassadorAppliedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reviewAmbassadorApplication({
    required String uid,
    required bool approve,
    String note = '',
  }) async {
    final batch = _db.batch();
    batch.update(_users.doc(uid), {
      'ambassadorStatus':
          (approve ? AmbassadorStatus.approved : AmbassadorStatus.rejected).id,
      'ambassadorReviewNote': note.trim(),
      'ambassadorReviewedAt': FieldValue.serverTimestamp(),
      if (approve) 'role': AppRole.ambassador.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // ---------------- RFID ----------------

  Stream<List<RfidCard>> watchCards() {
    return _cards.snapshots().map((snap) {
      final cards = snap.docs.map(RfidCard.fromDocument).toList();
      if (cards.isEmpty && kDemoMode) return demoRfidCards();
      return cards;
    });
  }

  /// Registers a card from its UID alone; everything else is derived
  /// from the member it gets linked to.
  Future<String> registerCard({required String tag}) async {
    final doc = _cards.doc();
    await doc.set({
      'tag': tag.trim().toUpperCase(),
      'state': RfidState.available.id,
      'registeredAt': FieldValue.serverTimestamp(),
      'registeredBy': FirebaseFirestore.instance.app.options.projectId,
    });
    return doc.id;
  }

  Future<void> assignCard({
    required String cardId,
    required String uid,
    required String name,
    String role = 'user',
  }) async {
    final snap = await _cards.doc(cardId).get();
    if (!snap.exists) return;
    final tag = (snap.data()?['tag'] ?? '').toString();

    final batch = _db.batch();
    batch.update(_cards.doc(cardId), {
      'state': RfidState.linked.id,
      'assignedUid': uid,
      'assignedName': name,
      'holderRole': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Mirror the link onto the user document so the profile can show it.
    batch.set(_users.doc(uid), {'rfidUid': tag}, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> unlinkCard(String cardId) async {
    final snap = await _cards.doc(cardId).get();
    if (!snap.exists) return;
    final uid = snap.data()?['assignedUid']?.toString();
    final batch = _db.batch();
    batch.update(_cards.doc(cardId), {
      'state': RfidState.available.id,
      'assignedUid': null,
      'assignedName': null,
      'holderRole': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (uid != null && uid.isNotEmpty) {
      batch.update(_users.doc(uid), {'rfidUid': null});
    }
    await batch.commit();
  }

  Future<void> setCardState(String cardId, RfidState state) async {
    await _cards.doc(cardId).update({
      'state': state.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCard(String cardId) => _cards.doc(cardId).delete();

  // ---------------- user records ----------------

  Stream<List<Member>> watchMembers() {
    return _users.snapshots().map((snap) {
      final members = snap.docs.map(Member.fromDocument).toList();
      if (members.isEmpty && kDemoMode) return demoMembers();
      members.sort((a, b) => a.displayName.compareTo(b.displayName));
      return members;
    });
  }

  /// Only the people waiting on a decision.
  Stream<List<Member>> watchApplications() {
    return _users
        .where('ambassadorStatus', isEqualTo: AmbassadorStatus.pending.id)
        .snapshots()
        .map((snap) {
          final pending = snap.docs.map(Member.fromDocument).toList();
          if (pending.isEmpty && kDemoMode) {
            return demoMembers()
                .where((m) => m.isPendingApplication)
                .toList();
          }
          return pending;
        });
  }

  Future<void> updateUserFields(String uid, Map<String, dynamic> fields) async {
    await _users.doc(uid).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Soft-disable so history and redemptions stay intact.
  Future<void> setUserEnabled(String uid, bool enabled) async {
    await _users.doc(uid).update({
      'accountDisabled': !enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

/// Sample cards so the registry is reviewable before real tags arrive.
List<RfidCard> demoRfidCards() {
  return [
    RfidCard(
      id: 'demo-card-1',
      tag: 'A3F9 21C0',
      state: RfidState.linked,
      cardType: 'Standard',
      assignedUid: 'demo-uid-1',
      assignedName: 'Ama Boateng',
      holderRole: 'ambassador',
      notes: 'Issued with the 2026 ambassador cohort.',
    ),
    RfidCard(
      id: 'demo-card-2',
      tag: '77B1 0E44',
      state: RfidState.linked,
      cardType: 'Standard',
      assignedUid: 'demo-uid-2',
      assignedName: 'Kofi Mensah',
      holderRole: 'user',
    ),
    RfidCard(
      id: 'demo-card-3',
      tag: 'C0D3 9F17',
      state: RfidState.available,
      cardType: 'Standard',
      notes: 'Spare, kept at the admin office.',
    ),
    RfidCard(
      id: 'demo-card-4',
      tag: '5D02 88AB',
      state: RfidState.lost,
      cardType: 'Standard',
      notes: 'Reported lost in March. Needs re-issue.',
    ),
  ];
}
