import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/user_repository.dart';
import '../models/app_role.dart';
import 'design_system.dart';

/// Lets a normal member apply to become an ambassador.
///
/// Members who already are one never see this screen; the dashboard only
/// links here when the role allows applying.
class AmbassadorApplicationScreen extends StatelessWidget {
  const AmbassadorApplicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SignedOutView();

    return AppPage(
      title: 'Become an ambassador',
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }

          final data = (snapshot.data?.data() as Map<String, dynamic>?) ?? const {};
          final name = (data['name'] ?? '').toString();
          final status = AmbassadorStatus.fromString(data['ambassadorStatus']);
          final role = AppRole.fromString(data['role']);
          final note = (data['ambassadorReviewNote'] ?? '').toString();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              GradientCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Ambassador programme'),
                    const SizedBox(height: 8),
                    const Text(
                      'Help keep your area clean',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ambassadors look after the bins near them. You will be able '
                      'to add new bins, set where they are, and flag a bin as '
                      'full so a driver knows to collect it.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (role.isAmbassadorOrAdmin)
                const SoftCard(
                  border: kBeigeDeep,
                  child: Row(
                    children: [
                      IconChip(
                        icon: Icons.verified_rounded,
                        tint: kPastelMint,
                        color: kPrimaryColor,
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'You are already an ambassador. Your tools are on the '
                          'Ambassador dashboard.',
                          style: TextStyle(fontSize: 13.5, color: kTextMuted, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                )
              else if (status == AmbassadorStatus.pending)
                const SoftCard(
                  border: kAccentOrange,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconChip(
                        icon: Icons.hourglass_top_rounded,
                        tint: Color(0xFFFBEFD9),
                        color: kAccentOrange,
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Application under review',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: kTextDark,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'An admin will look at your application. You will '
                              'get a notification once there is a decision.',
                              style: TextStyle(
                                fontSize: 13,
                                color: kTextMuted,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                if (status == AmbassadorStatus.rejected) ...[
                  SoftCard(
                    border: const Color(0xFFC0392B),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const IconChip(
                          icon: Icons.cancel_rounded,
                          tint: kPastelPink,
                          color: Color(0xFFC0392B),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Not approved this time',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: kTextDark,
                                ),
                              ),
                              if (note.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  note,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: kTextMuted,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              const Text(
                                'You are welcome to apply again.',
                                style: TextStyle(fontSize: 13, color: kTextMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const SectionHeader(title: 'What you will be able to do'),
                const _Perk(
                  icon: Icons.add_location_alt_rounded,
                  text: 'Add new bins and set exactly where they sit',
                ),
                const SizedBox(height: 10),
                const _Perk(
                  icon: Icons.delete_outline_rounded,
                  text: 'Set a bin as full or filling without waiting for staff',
                ),
                const SizedBox(height: 10),
                const _Perk(
                  icon: Icons.map_rounded,
                  text: 'See every bin and its status on the live map',
                ),
                const SizedBox(height: 10),
                const _Perk(
                  icon: Icons.local_shipping_rounded,
                  text: 'Confirm a bin was collected once the driver empties it',
                ),
                const SizedBox(height: 22),
                _ApplicationForm(
                  defaultName: name,
                  initialArea: (data['ambassadorApplication']
                          as Map<String, dynamic>?)?['area']
                      ?.toString() ??
                      '',
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 16,
      child: Row(
        children: [
          IconChip(icon: icon, size: 38, iconSize: 18, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13.5, color: kTextDark, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationForm extends StatefulWidget {
  const _ApplicationForm({required this.defaultName, required this.initialArea});

  final String defaultName;
  final String initialArea;

  @override
  State<_ApplicationForm> createState() => _ApplicationFormState();
}

class _ApplicationFormState extends State<_ApplicationForm> {
  final _repo = UserRepository();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _area;
  late final TextEditingController _name;
  late final TextEditingController _motivation;

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.defaultName);
    _area = TextEditingController(text: widget.initialArea);
    _motivation = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    _motivation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    setState(() => _sending = true);
    try {
      await _repo.applyForAmbassador(
        uid: uid,
        name: _name.text.trim(),
        area: _area.text,
        motivation: _motivation.text,
      );
      if (!mounted) return;
      showToast(context, 'Application sent for review');
    } catch (e) {
      if (mounted) showToast(context, 'Could not send your application: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Your application',
              subtitle: 'An admin reviews every request',
            ),
            const _Label('Full name'),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: _decoration('Your name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
            ),
            const SizedBox(height: 14),
            const _Label('Area you want to look after'),
            TextFormField(
              controller: _area,
              textCapitalization: TextCapitalization.words,
              decoration: _decoration('e.g. Hostel Block A, Market Square'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Tell us which area'
                  : null,
            ),
            const SizedBox(height: 14),
            const _Label('Why do you want to join?'),
            TextFormField(
              controller: _motivation,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: _decoration('A couple of sentences is plenty'),
              validator: (v) => (v == null || v.trim().length < 20)
                  ? 'Please write at least a short paragraph'
                  : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_sending ? 'SENDING…' : 'SEND APPLICATION'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13.5, color: kTextMuted),
      filled: true,
      fillColor: kBackground,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBeige),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBeige),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kPrimaryColor, width: 1.6),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: kTextMuted,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
