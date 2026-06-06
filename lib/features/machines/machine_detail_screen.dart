import 'package:flutter/material.dart';

import '../../data/repositories/maintenance_repository.dart';
import '../../data/models/machine.dart';

class MachineDetailScreen extends StatefulWidget {
  const MachineDetailScreen({
    super.key,
    required this.machine,
    required this.repository,
  });

  final Machine machine;
  final MaintenanceRepository repository;

  @override
  State<MachineDetailScreen> createState() => _MachineDetailScreenState();
}

class _MachineDetailScreenState extends State<MachineDetailScreen> {
  late Machine _machine;

  @override
  void initState() {
    super.initState();
    _machine = widget.machine;
  }

  Future<void> _validatePreventive() async {
    await widget.repository.validatePreventive(_machine.id);
    if (!mounted) {
      return;
    }
    final updated = widget.repository.machines.firstWhere((m) => m.id == _machine.id);
    setState(() => _machine = updated);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Maintenance preventive validee.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fiche machine ${_machine.name}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _machine.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Serie: ${_machine.serial}'),
                  Text('Localisation: ${_machine.site} / ${_machine.zone}'),
                  Text('Projet: ${_machine.project}'),
                  Text('Type machine: ${_machine.machineType}'),
                  const SizedBox(height: 8),
                  Text(
                    'Numeros DRS: ${_machine.drsNumbers.isEmpty ? 'N/A' : _machine.drsNumbers.join(', ')}',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      const Text('Etat: '),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _machine.statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(_machine.statusLabel),
                    ],
                  ),
                  Text('Rappel preventive KW: ${_machine.nextKw}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Checklist preventive',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          ..._machine.checklist.map(
            (item) => Card(
              child: CheckboxListTile(
                value: item.done,
                onChanged: null,
                title: Text(item.label),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _validatePreventive,
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Valider le realisation de preventive'),
          ),
        ],
      ),
    );
  }
}
