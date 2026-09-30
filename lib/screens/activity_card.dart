import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ui_helpers.dart';

/// One deposit row, shared by the dashboard activity feed and the full
/// Recycling History list so the two are guaranteed to look identical.
class ActivityRow {
  ActivityRow({
    required this.kind,
    required this.weight,
    required this.points,
    required this.when,
  });

  /// Either `Clear` or `Coloured`.
  final String kind;
  final String weight;
  final String points;
  final DateTime? when;

  bool get isColoured => kind.toLowerCase().contains('colo');

  /// Builds a row from a raw Firestore deposit document.
  factory ActivityRow.fromDocument(Map<String, dynamic> data) {
    return ActivityRow(
      kind: bottleKindFrom(data),
      weight: '${data['weight'] ?? 0.0} kg',
      points: '${data['points'] ?? 0}',
      when: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}

/// Coloured bottles return `Coloured`, everything else `Clear`.
String bottleKindFrom(Map<String, dynamic> data) {
  final String raw =
      '${data['bottleType'] ?? data['type'] ?? 'clear'}'.toLowerCase();
  return raw.contains('colo') ? 'Coloured' : 'Clear';
}

/// The single deposit card design used across both surfaces.
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.row});

  final ActivityRow row;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  Color get _accent => row.isColoured ? kColouredBottle : kClearBottle;

  @override
  Widget build(BuildContext context) {
    final DateTime? when = row.when;
    final String date = when == null
        ? ''
        : '${when.day} ${_months[when.month - 1]} ${when.year}';

    final List<String> parts = [
      row.weight,
      row.kind,
      if (date.isNotEmpty) date,
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: _accent, width: 6)),
        boxShadow: [
          BoxShadow(
            color: kPrimaryDark.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Same bottle icon either way — only the tint changes.
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.local_drink_rounded,
              size: 21,
              color: _accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Plastic Bottle',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  parts.join('  •  '),
                  style: const TextStyle(fontSize: 12.5, color: kTextMuted),
                ),
              ],
            ),
          ),
          Text(
            '+${row.points} pts',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _accent,
            ),
          ),
        ],
      ),
    );
  }
}
