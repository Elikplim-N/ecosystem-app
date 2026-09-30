import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DepositScreen extends StatelessWidget {
  const DepositScreen({super.key, this.kioskId = 'kiosk_01'});

  final String kioskId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'BoaMe Kiosk',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('kiosk_sessions')
            .doc(kioskId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildIdle();
          }

          final data = snapshot.data!.data()!;
          final state = data['state'] ?? 'idle';

          switch (state) {
            case 'identified':
              return _buildIdentified(data);
            case 'processing':
              return _buildProcessing(data);
            case 'success':
              return _buildSuccess(data);
            case 'rejected':
              return _buildRejected(data);
            default:
              return _buildIdle();
          }
        },
      ),
    );
  }

  // ----------------------------------------------------------
  // IDLE — waiting for RFID tap / phone entry / anonymous start
  // ----------------------------------------------------------
  Widget _buildIdle() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.recycling, size: 100),
            SizedBox(height: 20),
            Text(
              'Tap your RFID card,\nor use the keypad on the kiosk.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'No account? Choose Anonymous on the kiosk keypad.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // IDENTIFIED — user found, waiting for bottle insertion
  // ----------------------------------------------------------
  Widget _buildIdentified(Map<String, dynamic> data) {
    final name = data['userName'] ?? 'User';
    final isAnonymous = data['mode'] == 'anonymous';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 90),
            const SizedBox(height: 20),
            Text(
              isAnonymous ? 'Anonymous mode' : 'Welcome, $name!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Insert your bottle now.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // PROCESSING — weighing / verifying
  // ----------------------------------------------------------
  Widget _buildProcessing(Map<String, dynamic> data) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Checking bottle...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // SUCCESS — deposit accepted
  // ----------------------------------------------------------
  Widget _buildSuccess(Map<String, dynamic> data) {
    final points = data['pointsEarned'] ?? 0;
    final isAnonymous = data['mode'] == 'anonymous';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events, size: 90),
            const SizedBox(height: 20),
            const Text(
              'Deposit Successful 🎉',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              isAnonymous
                  ? 'Thank you for recycling!'
                  : '+$points points added to your account.',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // REJECTED — wrong item / sensor mismatch
  // ----------------------------------------------------------
  Widget _buildRejected(Map<String, dynamic> data) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 90),
          SizedBox(height: 20),
          Text(
            'Item Not Accepted',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'Please make sure it is a recyclable bottle.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}