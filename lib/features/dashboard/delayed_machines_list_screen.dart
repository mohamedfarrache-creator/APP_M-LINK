import 'package:flutter/material.dart';

import '../../data/models/machine.dart';

class DelayedMachinesListScreen extends StatelessWidget {
  const DelayedMachinesListScreen({
    super.key,
    required this.machines,
  });

  final List<Machine> machines;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Machines en retard'),
      ),
      body: machines.isEmpty
          ? const Center(
              child: Text('Aucune machine en retard.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: machines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final machine = machines[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.warning_amber_rounded),
                    ),
                    title: Text(machine.name),
                    subtitle: Text(
                      'Machine: ${machine.id}\nProjet: ${machine.project}\nZone: ${machine.zone}',
                    ),
                    isThreeLine: true,
                    trailing: const Chip(
                      label: Text('En retard'),
                      avatar: Icon(Icons.schedule, size: 16),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
