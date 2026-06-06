import 'package:flutter/material.dart';

import '../../data/models/intervention.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.interventions,
  });

  final List<Intervention> interventions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique')),
      body: interventions.isEmpty
          ? const Center(child: Text('Aucun historique disponible.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final item = interventions[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(item.title),
                    subtitle: Text(
                      'Machine: ${item.machineName}\nStatut: ${item.status}',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: interventions.length,
            ),
    );
  }
}
