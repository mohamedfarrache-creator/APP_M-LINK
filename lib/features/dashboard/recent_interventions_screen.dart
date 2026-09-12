import 'package:flutter/material.dart';

import '../../data/models/intervention.dart';
import '../../data/repositories/maintenance_repository.dart';

enum _InterventionFilter { machine, technicien, contrePiece }

class RecentInterventionsScreen extends StatefulWidget {
  const RecentInterventionsScreen({
    super.key,
    required this.repository,
  });

  final MaintenanceRepository repository;

  @override
  State<RecentInterventionsScreen> createState() =>
      _RecentInterventionsScreenState();
}

class _RecentInterventionsScreenState extends State<RecentInterventionsScreen> {
  final _searchCtrl = TextEditingController();
  _InterventionFilter _filter = _InterventionFilter.machine;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repository,
      builder: (context, _) {
        final interventions = _filteredInterventions();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Interventions recentes'),
          ),
          body: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: <Widget>[
                    SegmentedButton<_InterventionFilter>(
                      segments: const <ButtonSegment<_InterventionFilter>>[
                        ButtonSegment<_InterventionFilter>(
                          value: _InterventionFilter.machine,
                          icon: Icon(Icons.memory_outlined),
                          label: Text('Machine'),
                        ),
                        ButtonSegment<_InterventionFilter>(
                          value: _InterventionFilter.technicien,
                          icon: Icon(Icons.badge_outlined),
                          label: Text('Tech.'),
                        ),
                        ButtonSegment<_InterventionFilter>(
                          value: _InterventionFilter.contrePiece,
                          icon: Icon(Icons.widgets_outlined),
                          label: Text('Piece'),
                        ),
                      ],
                      selected: <_InterventionFilter>{_filter},
                      showSelectedIcon: false,
                      onSelectionChanged: (value) {
                        setState(() {
                          _filter = value.first;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Filtrer',
                        prefixIcon: Icon(Icons.search_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: interventions.isEmpty
                    ? const Center(
                        child: Text('Aucune intervention recente.'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: interventions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final intervention = interventions[index];
                          return _InterventionTile(
                            intervention: intervention,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => InterventionDetailScreen(
                                    intervention: intervention,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Intervention> _filteredInterventions() {
    final since = DateTime.now().subtract(const Duration(hours: 24));
    final query = _normalize(_searchCtrl.text);
    final items = widget.repository.interventions.where((item) {
      final createdAt = DateTime.tryParse(item.createdAtIso);
      if (createdAt == null || createdAt.isBefore(since)) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return _normalize(_filterText(item)).contains(query);
    }).toList();

    items.sort((a, b) {
      final aDate = DateTime.tryParse(a.createdAtIso) ?? DateTime(1900);
      final bDate = DateTime.tryParse(b.createdAtIso) ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });
    return items;
  }

  String _filterText(Intervention item) {
    switch (_filter) {
      case _InterventionFilter.machine:
        return item.machineName;
      case _InterventionFilter.technicien:
        return item.createdByName;
      case _InterventionFilter.contrePiece:
        return item.contrePiece;
    }
  }

  static String _normalize(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }
}

class _InterventionTile extends StatelessWidget {
  const _InterventionTile({
    required this.intervention,
    required this.onTap,
  });

  final Intervention intervention;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(
          child: Icon(Icons.build_outlined),
        ),
        title: Text(
          intervention.machineName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Technicien: ${intervention.createdByName}'),
            Text('Contre piece: ${_emptyDash(intervention.contrePiece)}'),
          ],
        ),
        trailing: Text(
          _timeLabel(intervention),
          style: theme.textTheme.titleSmall,
        ),
      ),
    );
  }
}

class InterventionDetailScreen extends StatelessWidget {
  const InterventionDetailScreen({
    super.key,
    required this.intervention,
  });

  final Intervention intervention;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail intervention'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _DetailRow(label: 'Machine', value: intervention.machineName),
          _DetailRow(label: 'Technicien', value: intervention.createdByName),
          _DetailRow(
            label: 'Contre piece',
            value: _emptyDash(intervention.contrePiece),
          ),
          _DetailRow(label: 'Niveau', value: intervention.niveau),
          _DetailRow(
              label: 'Heure debut', value: _emptyDash(intervention.heureDebut)),
          _DetailRow(
              label: 'Heure fin', value: _emptyDash(intervention.heureFin)),
          _DetailRow(
              label: 'Temps prod', value: '${intervention.tempsProd} min'),
          _DetailRow(
              label: 'Temps tech', value: '${intervention.tempsTech} min'),
          _DetailRow(label: 'Shift', value: intervention.shift),
          const SizedBox(height: 12),
          Text(
            'Intervention',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(intervention.description),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value),
      ),
    );
  }
}

String _emptyDash(String value) {
  return value.trim().isEmpty ? '-' : value;
}

String _timeLabel(Intervention intervention) {
  if (intervention.heureDebut.trim().isNotEmpty) {
    return intervention.heureDebut;
  }
  final createdAt = DateTime.tryParse(intervention.createdAtIso);
  if (createdAt == null) {
    return '--:--';
  }
  final hour = createdAt.hour.toString().padLeft(2, '0');
  final minute = createdAt.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
