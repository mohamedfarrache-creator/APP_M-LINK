import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/intervention.dart';

class OpenAnomaliesListScreen extends StatelessWidget {
  const OpenAnomaliesListScreen({
    super.key,
    required this.anomalies,
  });

  final List<Intervention> anomalies;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anomalies ouvertes'),
      ),
      body: anomalies.isEmpty
          ? const Center(
              child: Text('Aucune anomalie ouverte.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: anomalies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final anomaly = anomalies[index];
                final parsedDate = DateTime.tryParse(anomaly.createdAtIso);
                final dateLabel = parsedDate == null
                    ? anomaly.createdAtIso
                    : DateFormat('dd/MM/yyyy HH:mm').format(parsedDate);

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _priorityColor(anomaly.priority).withValues(alpha: 0.16),
                      child: Icon(
                        Icons.report_problem_outlined,
                        color: _priorityColor(anomaly.priority),
                      ),
                    ),
                    title: Text(anomaly.title),
                    subtitle: Text(
                      'Date: $dateLabel\nMachine: ${anomaly.machineName}',
                    ),
                    isThreeLine: true,
                    trailing: Chip(
                      label: Text(_priorityLabel(anomaly.priority)),
                      backgroundColor: _priorityColor(anomaly.priority).withValues(alpha: 0.18),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _priorityColor(InterventionPriority priority) {
    switch (priority) {
      case InterventionPriority.low:
        return Colors.green;
      case InterventionPriority.medium:
        return Colors.orange;
      case InterventionPriority.high:
        return Colors.deepOrange;
      case InterventionPriority.urgent:
        return Colors.red;
    }
  }

  String _priorityLabel(InterventionPriority priority) {
    switch (priority) {
      case InterventionPriority.low:
        return 'Faible';
      case InterventionPriority.medium:
        return 'Moyenne';
      case InterventionPriority.high:
        return 'Haute';
      case InterventionPriority.urgent:
        return 'Urgente';
    }
  }
}
