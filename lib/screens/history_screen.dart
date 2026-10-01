import 'package:flutter/material.dart';
import '../data/activity_repository.dart';
import 'activity_card.dart';
import 'demo_data.dart';
import 'design_system.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(title: const Text('Recycling History'), centerTitle: true),
      body: StreamBuilder<List<Deposit>>(
        stream: ActivityRepository().watchMyDeposits(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading history: ${snapshot.error}'),
            );
          }

          final deposits = snapshot.data ?? const [];

          if (deposits.isEmpty && !(kDemoMode)) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.recycling, size: 70, color: kPrimaryColor),
                    SizedBox(height: 15),
                    Text(
                      'No recycling history yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your bottle deposits will appear here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (deposits.isEmpty) {
            // Review mode — a full spread of rows so the layout can be judged.
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _TotalsCard(
                  totalKg: demoDeposits.fold(
                    0,
                    (double sum, DemoDeposit d) => sum + d.weight,
                  ),
                  totalPoints: demoDeposits.fold(
                    0,
                    (int sum, DemoDeposit d) => sum + d.points,
                  ),
                  bottles: demoDeposits.length,
                ),
                const SizedBox(height: 18),
                _WeeklyChart(
                  title: 'This week',
                  daily: _dailyWeights(
                    demoDeposits.map((d) => (d.when, d.weight)),
                  ),
                ),
                const SizedBox(height: 18),
                for (final DemoDeposit demo in demoDeposits)
                  ActivityCard(
                    row: ActivityRow(
                      kind: demo.bottleType.toLowerCase().contains('colo')
                          ? 'Coloured'
                          : 'Clear',
                      weight: '${demo.weight} kg',
                      points: '${demo.points}',
                      when: demo.when,
                    ),
                  ),
              ],
            );
          }

          final rows = deposits.map(ActivityRow.fromDeposit).toList();

          // Summed from the typed deposits rather than by parsing the display
          // strings back into numbers, which is what this used to do and which
          // broke the moment a weight was formatted differently.
          final liveTotalKg = deposits.fold<double>(
            0,
            (double sum, Deposit d) => sum + d.weightKg,
          );
          final liveTotalPoints = deposits.fold<int>(
            0,
            (int sum, Deposit d) => sum + d.pointsAwarded,
          );

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _TotalsCard(
                totalKg: liveTotalKg,
                totalPoints: liveTotalPoints,
                bottles: rows.length,
              ),
              const SizedBox(height: 18),
              _WeeklyChart(
                title: 'This week',
                daily: _dailyWeights(
                  rows.map(
                    (r) => (
                      r.when,
                      double.tryParse(r.weight.replaceAll(' kg', '')) ?? 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              for (final row in rows) ActivityCard(row: row),
            ],
          );
        },
      ),
    );
  }
}

/// Sums deposit weight into the last seven days, oldest first.
List<double> _dailyWeights(Iterable<(DateTime?, double)> entries) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final buckets = List<double>.filled(7, 0);

  for (final (date, weight) in entries) {
    if (date == null) continue;
    final day = DateTime(date.year, date.month, date.day);
    final age = today.difference(day).inDays;
    if (age >= 0 && age < 7) buckets[6 - age] += weight;
  }
  return buckets;
}

/// Lifetime totals for the signed-in member.
class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.totalKg,
    required this.totalPoints,
    required this.bottles,
  });

  final double totalKg;
  final int totalPoints;
  final int bottles;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kMetricTealTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kMetricTeal.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LIFETIME TOTALS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: kTextMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${totalKg.toStringAsFixed(1)} kg · $totalPoints pts',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$bottles deposit${bottles == 1 ? '' : 's'} recorded',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kTextMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: kMetricTeal,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

/// Seven-day recycling weight, built from the real deposit records.
class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.title, required this.daily});

  final String title;
  final List<double> daily;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final peak = daily.fold<double>(0, (double m, double v) => v > m ? v : m);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekday = today.weekday - 1;
    final labels = [
      for (var i = 0; i < 7; i++) _labels[(weekday - (6 - i) + 7) % 7],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
                color: kTextDark,
              ),
            ),
            const Spacer(),
            Text(
              '${daily.fold<double>(0, (double a, double b) => a + b).toStringAsFixed(1)} kg',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: kMetricTeal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        const Text(
          'Weight recycled on each of the last seven days',
          style: TextStyle(fontSize: 12, color: kTextMuted),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 6 ? 0 : 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: peak == 0
                                  ? 0
                                  : (daily[i] / peak).clamp(0.04, 1),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: daily[i] > 0
                                      ? kMetricTeal
                                      : kMetricTeal.withValues(alpha: 0.14),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(7),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: i == 6 ? kTextDark : kTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
