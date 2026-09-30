import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/deposit_model.dart';
import 'ui_helpers.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<DepositModel>> _depositsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _depositsFuture = ApiService().getDeposits();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService().currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('No user is logged in')));
    }

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Recycling History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<DepositModel>>(
        future: _depositsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading history: ${snapshot.error}'));
          }

          final deposits = snapshot.data ?? [];

          if (deposits.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.recycling, size: 70, color: kPrimaryColor),
                    const SizedBox(height: 15),
                    const Text('No recycling history yet',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Your bottle deposits at the BoaMe RVM will appear here.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: deposits.length,
              itemBuilder: (context, index) {
                final deposit = deposits[index];
                final dateText = DateFormat('dd MMM yyyy, HH:mm').format(deposit.timestamp);

                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(18),
                  decoration: kCardDecoration(),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.recycling, size: 30, color: kPrimaryDark),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deposit.materialType.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: kTextDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${deposit.bottleCount} bottle(s) • ${deposit.weight.toStringAsFixed(2)} kg',
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateText,
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '+${deposit.pointsAwarded} pts',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryDark,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}