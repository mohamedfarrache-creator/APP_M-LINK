import 'package:flutter/material.dart';

import '../../data/models/machine.dart';
import '../../data/models/project_calendar.dart';

class ProjectCalendarsScreen extends StatefulWidget {
  const ProjectCalendarsScreen({
    super.key,
    required this.calendars,
    required this.machines,
  });

  final List<ProjectCalendar> calendars;
  final List<Machine> machines;

  @override
  State<ProjectCalendarsScreen> createState() => _ProjectCalendarsScreenState();
}

class _ProjectCalendarsScreenState extends State<ProjectCalendarsScreen> {
  String? _selectedProject;

  @override
  void initState() {
    super.initState();
    if (widget.calendars.isNotEmpty) {
      _selectedProject = widget.calendars.first.project;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.calendars.firstWhere(
      (item) => item.project == _selectedProject,
      orElse: () => widget.calendars.first,
    );

    final machine = widget.machines.where(
      (m) =>
          m.name.toLowerCase() == current.project.toLowerCase() ||
          (current.project == 'POURCHE' && m.name.toLowerCase().contains('pourche')),
    );

    final kw = machine.isEmpty ? 16 : machine.first.nextKw;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          'Calendriers des projets',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _selectedProject,
          decoration: const InputDecoration(
            labelText: 'Projet',
            prefixIcon: Icon(Icons.folder_open_outlined),
          ),
          items: widget.calendars
              .map(
                (c) => DropdownMenuItem<String>(
                  value: c.project,
                  child: Text(c.project),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedProject = value),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  current.project,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Fichier source Excel: ${current.sourceFile}'),
                Text('Type machine: ${current.machineType}'),
                const SizedBox(height: 8),
                Text(
                  'Numeros DRS machine',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: current.drsNumbers
                      .map(
                        (drs) => Chip(
                          avatar: const Icon(Icons.confirmation_number_outlined, size: 16),
                          label: Text(drs),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Calendrier hebdomadaire (KW)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List<Widget>.generate(52, (index) {
                final number = index + 1;
                final isDue = number == kw;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDue ? Colors.red : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDue ? Colors.red : Colors.grey.shade300),
                  ),
                  child: Text(
                    'KW $number',
                    style: TextStyle(
                      fontWeight: isDue ? FontWeight.bold : FontWeight.normal,
                      color: isDue ? Colors.white : Colors.black87,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
