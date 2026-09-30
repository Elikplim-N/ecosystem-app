import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../models/kiosk_session_model.dart';

class KioskScreen extends StatefulWidget {
  const KioskScreen({super.key, this.kioskId = 'kiosk_01'});

  final String kioskId;

  @override
  State<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends State<KioskScreen> {
  final api = ApiService();
  late KioskSessionModel session;
  late StreamSubscription<KioskSessionModel> _sub;

  // On-screen phone entry state
  String enteredPhone = '';
  String rfidInput = '';
  Timer? _summaryTimer;

  @override
  void initState() {
    super.initState();
    session = api.currentKioskState;
    _sub = api.kioskStream.listen((newSession) {
      if (mounted) {
        setState(() => session = newSession);
        if (newSession.state == KioskState.sessionSummary) {
          _summaryTimer?.cancel();
          _summaryTimer = Timer(const Duration(seconds: 8), () {
            if (mounted) api.resetKiosk();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _summaryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F241D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/logo_boame.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00C896).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00C896), width: 1),
              ),
              child: const Text('BOAME KIOSK RVM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00C896))),
            ),
            const SizedBox(width: 8),
            Text(widget.kioskId.toUpperCase(), style: const TextStyle(fontSize: 14, color: Colors.white70)),
          ],
        ),
        actions: [
          if (!session.isIdle)
            TextButton.icon(
              onPressed: () => api.resetKiosk(),
              icon: const Icon(Icons.cancel_outlined, color: Colors.white70, size: 18),
              label: const Text('Cancel Session', style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildCurrentStage(),
        ),
      ),
    );
  }

  Widget _buildCurrentStage() {
    switch (session.state) {
      case KioskState.idle:
        return _buildIdleView();
      case KioskState.authenticating:
        return _buildPhoneEntryView();
      case KioskState.activeSession:
      case KioskState.processingBottle:
      case KioskState.itemAccepted:
      case KioskState.itemRejected:
        return _buildActiveRecyclingView();
      case KioskState.sessionSummary:
        return _buildSummaryView();
      default:
        return _buildIdleView();
    }
  }

  // ==========================================
  // STAGE 1: IDLE / SCREENSAVER
  // ==========================================
  Widget _buildIdleView() {
    return SingleChildScrollView(
      key: const ValueKey('idle'),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Official BoaMe Logo
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00C896).withOpacity(0.35),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  'assets/images/logo_boame.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Recycle & Earn Instant Rewards',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Deposit clean plastic bottles to earn mobile airtime, cash, or discounts.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.white70),
          ),
          const SizedBox(height: 36),

          // 3 Identification Options
          _kioskOptionCard(
            icon: Icons.contactless,
            title: 'Tap RFID Card or Fob',
            subtitle: 'Instant contactless login for registered recyclers',
            color: const Color(0xFF00C896),
            onTap: _showRfidTapDialog,
          ),
          const SizedBox(height: 14),
          _kioskOptionCard(
            icon: Icons.dialpad,
            title: 'Enter Mobile Number',
            subtitle: 'Use the kiosk keypad to link deposits to your account',
            color: const Color(0xFF5B8DEF),
            onTap: () {
              setState(() {
                enteredPhone = '';
                api.currentKioskState;
                session = KioskSessionModel(kioskId: widget.kioskId, state: KioskState.authenticating);
              });
            },
          ),
          const SizedBox(height: 14),
          _kioskOptionCard(
            icon: Icons.volunteer_activism_outlined,
            title: 'Anonymous Drop',
            subtitle: 'Recycle immediately without an account',
            color: const Color(0xFFFFB020),
            onTap: () => api.startKioskSessionAnonymous(),
          ),
        ],
      ),
    );
  }

  Widget _kioskOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1B382F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: color.withOpacity(0.18), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.white60)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STAGE 2: PHONE NUMBER KEYPAD ENTRY
  // ==========================================
  Widget _buildPhoneEntryView() {
    return SingleChildScrollView(
      key: const ValueKey('phoneEntry'),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text('Enter Your Phone Number', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          const Text('Type your registered number to credit points', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 24),
          // Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF1B382F),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00C896), width: 2),
            ),
            child: Text(
              enteredPhone.isEmpty ? '0__ ___ ____' : enteredPhone,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: enteredPhone.isEmpty ? Colors.white24 : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 4x4 Keypad Grid (matching hardware RVM matrix)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              children: [
                _keypadRow(['1', '2', '3']),
                const SizedBox(height: 12),
                _keypadRow(['4', '5', '6']),
                const SizedBox(height: 12),
                _keypadRow(['7', '8', '9']),
                const SizedBox(height: 12),
                _keypadRow(['CLR', '0', '⌫']),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: enteredPhone.length >= 10 ? () => api.startKioskSessionByPhone(enteredPhone) : null,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('CONFIRM & START RECYCLING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C896),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _keypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) {
        return SizedBox(
          width: 80,
          height: 60,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                if (k == 'CLR') {
                  enteredPhone = '';
                } else if (k == '⌫') {
                  if (enteredPhone.isNotEmpty) enteredPhone = enteredPhone.substring(0, enteredPhone.length - 1);
                } else {
                  if (enteredPhone.length < 10) enteredPhone += k;
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B382F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            child: Text(k, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
        );
      }).toList(),
    );
  }

  // ==========================================
  // STAGE 3: ACTIVE RECYCLING SESSION
  // ==========================================
  Widget _buildActiveRecyclingView() {
    return SingleChildScrollView(
      key: const ValueKey('active'),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // User banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B382F),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF00C896).withOpacity(0.2),
                  child: const Icon(Icons.person, color: Color(0xFF00C896)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.userName ?? 'Recycler', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('Session Mode: ${session.mode.toUpperCase()}', style: const TextStyle(fontSize: 12, color: Colors.white60)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF00C896), borderRadius: BorderRadius.circular(12)),
                  child: const Text('MACHINE ACTIVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Big Live Stat Ring
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF1B382F),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF00C896).withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              children: [
                const Text('BOTTLES ACCEPTED THIS SESSION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00C896), letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text('${session.sessionBottles}', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _statPill(Icons.star, '+${session.sessionPoints} Points', const Color(0xFFFFB020)),
                    const SizedBox(width: 16),
                    _statPill(Icons.scale, '${session.sessionWeight.toStringAsFixed(2)} kg', const Color(0xFF5B8DEF)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Machine Status Alert
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00C896).withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00C896)),
            ),
            child: Row(
              children: [
                const Icon(Icons.arrow_downward, color: Color(0xFF00C896)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    session.statusMessage ?? 'Iris Gate Open. Insert bottle into intake chute.',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Simulation / Hardware Trigger Buttons (Test feed bottles directly from Kiosk UI)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Simulate Bottle Drop (Hardware Testing):', style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _bottleSimButton(
                  title: 'Clear PET',
                  pts: '+10',
                  color: Colors.lightBlueAccent,
                  onTap: () => api.recordKioskBottleDeposit(bottleClass: 'Clear PET', weight: 0.022),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _bottleSimButton(
                  title: 'Color PET',
                  pts: '+8',
                  color: Colors.greenAccent,
                  onTap: () => api.recordKioskBottleDeposit(bottleClass: 'Colored PET', weight: 0.024),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _bottleSimButton(
                  title: 'HDPE Jug',
                  pts: '+12',
                  color: Colors.orangeAccent,
                  onTap: () => api.recordKioskBottleDeposit(bottleClass: 'HDPE Milk/Juice', weight: 0.038),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Finish Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => api.finishKioskSession(),
              icon: const Icon(Icons.check_circle),
              label: const Text('FINISH & CLAIM REWARDS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C896),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.16), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _bottleSimButton({required String title, required String pts, required Color color, required VoidCallback onTap}) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(pts, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ==========================================
  // STAGE 4: SUMMARY & CELEBRATION
  // ==========================================
  Widget _buildSummaryView() {
    return Center(
      key: const ValueKey('summary'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: Color(0xFF00C896), shape: BoxShape.circle),
              child: const Icon(Icons.celebration, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text('Awesome Job! 🎉', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              'You recycled ${session.sessionBottles} bottle(s) and earned ${session.sessionPoints} points!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF1B382F), borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  _summaryRow('Session User:', session.userName ?? 'Anonymous'),
                  const Divider(color: Colors.white12, height: 20),
                  _summaryRow('Bottles Recycled:', '${session.sessionBottles} items'),
                  const Divider(color: Colors.white12, height: 20),
                  _summaryRow('Total Weight:', '${session.sessionWeight.toStringAsFixed(2)} kg'),
                  const Divider(color: Colors.white12, height: 20),
                  _summaryRow('Points Earned:', '+${session.sessionPoints} PTS', isHighlight: true),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => api.resetKiosk(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C896),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('DONE (RESET TO HOME)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? const Color(0xFF00C896) : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isHighlight ? 16 : 14,
          ),
        ),
      ],
    );
  }

  void _showRfidTapDialog() {
    final controller = TextEditingController(text: 'A3 F1 82 4B');
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B382F),
          title: const Text('Simulate RFID Tap', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter RFID Card UID (or tap test card):', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: 'e.g. A3 F1 82 4B',
                  hintStyle: TextStyle(color: Colors.white30),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                api.startKioskSessionByRfid(controller.text);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C896)),
              child: const Text('TAP CARD', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
