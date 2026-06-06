import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/machine_data.dart';
import '../../data/models/machine.dart';
import '../../data/services/csv_maintenance_status_service.dart';
import '../../data/repositories/maintenance_repository.dart';
class PlantMapView extends StatefulWidget {
  const PlantMapView({
    super.key,
    required this.repository,
    required this.onMachineTap,
    this.isAdmin = false,
  });

  final MaintenanceRepository repository;
  final ValueChanged<Machine> onMachineTap;
  final bool isAdmin;

  @override
  State<PlantMapView> createState() => _PlantMapViewState();
}

class _PlantMapViewState extends State<PlantMapView> with SingleTickerProviderStateMixin {
  static const List<_SitePlan> _sitePlans = <_SitePlan>[
    _SitePlan(
      siteName: 'Plant 1',
      assetPath: 'assets/maps/plant 1.jpg',
      projects: <String>['Q7-Q9 KSK'],
    ),
    _SitePlan(
      siteName: 'Plant 2',
      assetPath: 'assets/maps/plant 2.jpg',
      projects: <String>['RL-TAN', 'COCK-PIT', 'T-ROC', 'ID_4', 'MEB_21'],
    ),
    _SitePlan(
      siteName: 'Satellite 1',
      assetPath: 'assets/maps/satellite 1.jpg',
      projects: <String>['HIGH VOLTAGE', 'ID_7', 'PORSCHE'],
    ),
    _SitePlan(
      siteName: 'Satellite 2',
      assetPath: 'assets/maps/satellite 2.jpg',
      projects: <String>['MEB_31', 'HIGH VOLTAGE #2', 'HIGH VOLTAGE #3'],
    ),
    _SitePlan(
      siteName: 'Satellite 3',
      assetPath: 'assets/maps/satellite 3.jpg',
      projects: <String>['GOLF A8'],
    ),
  ];

  int _selectedSiteIndex = 0;
  int _selectedWeek = _isoWeek(DateTime.now());
  bool _pinEditMode = false;
  String? _selectedEditMachineId;
  String? _highlightedMachineId;
  _MachineJumpTarget? _pendingJumpTarget;
  Size? _mapViewportSize;
  bool _loadingCsvStatuses = true;
  Map<String, MachineStatus> _csvStatusByMachineId = const <String, MachineStatus>{};
  final Map<String, Offset> _draftLocationOverrides = <String, Offset>{};
  late final Map<String, Map<String, MachineLocation>> _locationIndex;
  late final TransformationController _mapTransformController;
  late final AnimationController _pinPulseController;
  Timer? _pinPulseStopTimer;
  final TextEditingController _machineSearchController = TextEditingController();
  final FocusNode _machineSearchFocusNode = FocusNode();
  final GlobalKey _mapKey = GlobalKey();

  final CsvMaintenanceStatusService _csvStatusService = CsvMaintenanceStatusService();

  @override
  void initState() {
    super.initState();
    _locationIndex = _buildLocationIndex();
    _mapTransformController = TransformationController();
    _pinPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _loadCsvStatuses();
  }

  @override
  void dispose() {
    _pinPulseStopTimer?.cancel();
    _pinPulseController.dispose();
    _mapTransformController.dispose();
    _machineSearchController.dispose();
    _machineSearchFocusNode.dispose();
    super.dispose();
  }

  bool _hasAssignedCoordinates(MachineLocation location) {
    return location.dx != 0.0 || location.dy != 0.0;
  }

  MachineLocation _withCoords(MachineLocation base, double dx, double dy) {
    return MachineLocation(
      id: base.id,
      dx: dx,
      dy: dy,
      site: base.site,
      project: base.project,
    );
  }

  Map<String, Map<String, MachineLocation>> _buildLocationIndex() {
    final bySite = <String, Map<String, MachineLocation>>{};
    for (final location in allMachineLocations) {
      final siteMap = bySite.putIfAbsent(location.site, () => <String, MachineLocation>{});
      siteMap[_normalizeMachineId(location.id)] = location;
    }
    return bySite;
  }

  Future<void> _loadCsvStatuses() async {
    setState(() {
      _loadingCsvStatuses = true;
    });

    final statuses = await _csvStatusService.loadStatusesForMachines(
      widget.repository.machines,
      selectedWeek: _selectedWeek,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _csvStatusByMachineId = statuses;
      _loadingCsvStatuses = false;
    });
  }

  String get _selectedSiteName => _sitePlans[_selectedSiteIndex].siteName;

  static int _isoWeek(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final firstDayOfYear = DateTime(thursday.year, 1, 1);
    final dayOfYear = thursday.difference(firstDayOfYear).inDays + 1;
    return ((dayOfYear - 1) / 7).floor() + 1;
  }

  List<Machine> _machinesForSelectedSite() {
    return _machinesForSite(_selectedSiteName);
  }

  List<Machine> _machinesForSite(String siteName) {
    final normalizedSite = siteName.toLowerCase();
    return widget.repository.machines
        .where((machine) => machine.site.trim().toLowerCase() == normalizedSite)
        .toList();
  }

  String _siteNameForMachine(Machine machine) {
    final match = _sitePlans.firstWhere(
      (site) => site.siteName.toLowerCase() == machine.site.toLowerCase(),
      orElse: () => _sitePlans[_selectedSiteIndex],
    );
    return match.siteName;
  }

  int? _siteIndexForName(String siteName) {
    final index = _sitePlans.indexWhere(
      (site) => site.siteName.toLowerCase() == siteName.toLowerCase(),
    );
    return index < 0 ? null : index;
  }

  void _setSelectedSiteIndex(int newIndex) {
    _selectedSiteIndex = newIndex;
    final siteMachines = _machinesForSite(_sitePlans[newIndex].siteName);
    if (_selectedEditMachineId != null && !siteMachines.any((m) => m.id == _selectedEditMachineId)) {
      _selectedEditMachineId = null;
    }
  }

  MachineStatus _effectiveStatus(Machine machine) {
    if (machine.status == MachineStatus.anomaly) {
      return MachineStatus.anomaly;
    }
    return _csvStatusByMachineId[machine.id] ?? machine.status;
  }

  Color _markerColor(Machine machine) {
    switch (_effectiveStatus(machine)) {
      case MachineStatus.ok:
        return Colors.green;
      case MachineStatus.due:
        return Colors.red;
      case MachineStatus.anomaly:
        return Colors.orange;
      case MachineStatus.pending:
        return Colors.blue;
    }
  }

  String _statusDescription(Machine machine) {
    switch (_effectiveStatus(machine)) {
      case MachineStatus.ok:
        return 'V - Maintenance realisee';
      case MachineStatus.due:
        return 'N.V / vide - Maintenance due en retard';
      case MachineStatus.anomaly:
        return 'Anomalie signalee ou corrective en cours';
      case MachineStatus.pending:
        return 'Maintenance planifiee (future)';
    }
  }

  _ResolvedMachineLocation _resolveLocationForMachine(Machine machine) {
    final normalizedMachineId = _normalizeMachineId(machine.id);
    final siteMap = _locationIndex[_siteNameForMachine(machine)];
    final match = siteMap?[normalizedMachineId];

    if (match != null) {
      final override = _draftLocationOverrides[normalizedMachineId];
      if (override != null) {
        return _ResolvedMachineLocation(
          location: _withCoords(match, override.dx, override.dy),
          sourceId: match.id,
          hasPersistedCoordinates: true,
        );
      }

      if (_hasAssignedCoordinates(match)) {
        return _ResolvedMachineLocation(
          location: match,
          sourceId: match.id,
          hasPersistedCoordinates: true,
        );
      }

      return _ResolvedMachineLocation(
        location: _withCoords(match, machine.mapX, machine.mapY),
        sourceId: match.id,
        hasPersistedCoordinates: false,
      );
    }

    final fallback = MachineLocation(
      id: machine.id,
      dx: machine.mapX,
      dy: machine.mapY,
      site: _selectedSiteName,
      project: machine.name,
    );

    final fallbackOverride = _draftLocationOverrides[_normalizeMachineId(machine.id)];
    if (fallbackOverride != null) {
      return _ResolvedMachineLocation(
        location: _withCoords(fallback, fallbackOverride.dx, fallbackOverride.dy),
        sourceId: machine.id,
        hasPersistedCoordinates: false,
      );
    }

    return _ResolvedMachineLocation(
      location: fallback,
      sourceId: machine.id,
      hasPersistedCoordinates: false,
    );
  }

  String _normalizeMachineId(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  _MachineJumpTarget _buildJumpTargetForMachine(Machine machine) {
    final candidateId = _normalizeMachineId(machine.id);

    for (final siteEntry in _locationIndex.entries) {
      final match = siteEntry.value[candidateId];
      if (match == null) {
        continue;
      }

      final override = _draftLocationOverrides[_normalizeMachineId(match.id)];
      final hasPersistedCoordinates = _hasAssignedCoordinates(match);
      final dx = override?.dx ?? (hasPersistedCoordinates ? match.dx : machine.mapX);
      final dy = override?.dy ?? (hasPersistedCoordinates ? match.dy : machine.mapY);

      return _MachineJumpTarget(
        machine: machine,
        siteName: siteEntry.key,
        dx: dx,
        dy: dy,
      );
    }

    return _MachineJumpTarget(
      machine: machine,
      siteName: _siteNameForMachine(machine),
      dx: machine.mapX,
      dy: machine.mapY,
    );
  }

  Iterable<_MachineSearchHit> _suggestMachines(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      return const <_MachineSearchHit>[];
    }

    final normalizedQuery = _normalizeMachineId(query);
    final hits = <_MachineSearchHit>[];

    for (final machine in widget.repository.machines) {
      final machineId = machine.id;
      if (!_normalizeMachineId(machineId).contains(normalizedQuery)) {
        continue;
      }

      final target = _buildJumpTargetForMachine(machine);
      hits.add(
        _MachineSearchHit(
          machine: machine,
          matchedMachineNumber: machineId,
          target: target,
        ),
      );
    }

    hits.sort((a, b) => a.machine.id.compareTo(b.machine.id));
    return hits.take(14);
  }

  void _focusMapOnTarget(_MachineJumpTarget target) {
    final viewportSize = _mapViewportSize;
    if (viewportSize == null) {
      _pendingJumpTarget = target;
      return;
    }

    const zoom = 2.4;
    final targetX = _xToPx(target.dx, viewportSize.width);
    final targetY = _yToPx(target.dy, viewportSize.height);
    final translateX = (viewportSize.width / 2) - (targetX * zoom);
    final translateY = (viewportSize.height / 2) - (targetY * zoom);

    _mapTransformController.value = Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(zoom);

    _startPinHighlight(target.machine.id);
  }

  void _startPinHighlight(String machineId) {
    _pinPulseStopTimer?.cancel();

    setState(() {
      _highlightedMachineId = machineId;
    });

    _pinPulseController
      ..reset()
      ..repeat(reverse: true);

    _pinPulseStopTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      _pinPulseController
        ..stop()
        ..reset();
      setState(() {
        _highlightedMachineId = null;
      });
    });
  }

  void _selectMachineFromSearch(_MachineSearchHit hit) {
    _machineSearchController.text = hit.machine.id;
    _machineSearchFocusNode.unfocus();

    final targetSiteIndex = _siteIndexForName(hit.target.siteName);
    if (targetSiteIndex != null && targetSiteIndex != _selectedSiteIndex) {
      setState(() {
        _setSelectedSiteIndex(targetSiteIndex);
        _pendingJumpTarget = hit.target;
      });
      return;
    }

    _focusMapOnTarget(hit.target);
  }

  Future<void> _onMapLongPress({
    required Offset localPosition,
    required Size mapSize,
    required List<Machine> machines,
  }) async {
    if (!_pinEditMode) {
      return;
    }

    final selectedMachine = machines.where((m) => m.id == _selectedEditMachineId).firstOrNull;
    if (selectedMachine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selectionnez une machine a positionner.')),
      );
      return;
    }

    final dx = (localPosition.dx / mapSize.width).clamp(0.0, 1.0);
    final dy = (localPosition.dy / mapSize.height).clamp(0.0, 1.0);

    final resolved = _resolveLocationForMachine(selectedMachine);
    final sourceId = resolved.sourceId;
    final sourceKey = _normalizeMachineId(sourceId);
    final project = resolved.location.project.isEmpty ? selectedMachine.name : resolved.location.project;

    setState(() {
      _draftLocationOverrides[sourceKey] = Offset(dx, dy);
    });

    final snippet =
        "MachineLocation(id: '$sourceId', dx: ${dx.toStringAsFixed(4)}, dy: ${dy.toStringAsFixed(4)}, site: '$_selectedSiteName', project: '$project'),";

    if (!mounted) {
      return;
    }

    await _showConfirmOverride(
      sourceKey,
      snippet,
      machineId: selectedMachine.id,
      mapX: dx,
      mapY: dy,
    );
  }

  Future<void> _showConfirmOverride(
    String sourceKey,
    String snippet, {
    required String machineId,
    required double mapX,
    required double mapY,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Coordonnee capturee',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SelectableText(snippet),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: snippet));
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Snippet copie dans le presse-papiers.')),
                        );
                      },
                      icon: const Icon(Icons.copy_all_outlined),
                      label: const Text('Copier le snippet'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () async {
                        await widget.repository.updateMachineLocation(
                          machineId: machineId,
                          mapX: mapX,
                          mapY: mapY,
                        );
                        if (!context.mounted) {
                          return;
                        }
                        setState(() {
                          _draftLocationOverrides.remove(sourceKey);
                        });
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Coordonnee enregistree.')),
                        );
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Confirmer'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        // Undo: remove draft override
                        setState(() {
                          _draftLocationOverrides.remove(sourceKey);
                        });
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Capture annulee.')),
                        );
                      },
                      icon: const Icon(Icons.undo),
                      label: const Text('Annuler'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMachineSheet(Machine machine) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  machine.id,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('Projet: ${machine.name}'),
                const SizedBox(height: 4),
                Text('Type: ${machine.machineType}'),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Icon(Icons.circle, size: 12, color: _markerColor(machine)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Etat actuel: ${_statusDescription(machine)}')),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onMachineTap(machine);
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Voir details'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sitePlan = _sitePlans[_selectedSiteIndex];
    final siteMachines = _machinesForSelectedSite();

    final pendingJumpTarget = _pendingJumpTarget;
    if (pendingJumpTarget != null &&
        pendingJumpTarget.siteName.toLowerCase() == _selectedSiteName.toLowerCase() &&
        _mapViewportSize != null) {
      _pendingJumpTarget = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _focusMapOnTarget(pendingJumpTarget);
      });
    }

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'PlantMapView',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              RawAutocomplete<_MachineSearchHit>(
                textEditingController: _machineSearchController,
                focusNode: _machineSearchFocusNode,
                optionsBuilder: (textEditingValue) {
                  return _suggestMachines(textEditingValue.text);
                },
                displayStringForOption: (option) => option.machine.id,
                onSelected: _selectMachineFromSearch,
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Recherche machine',
                      hintText: 'Numero machine (ex: 23-1118)',
                      prefixIcon: Icon(Icons.search),
                    ),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280, minWidth: 320),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              leading: const Icon(Icons.location_pin),
                              title: Text(option.machine.id),
                              subtitle: Text(
                                '${option.target.siteName} | ${option.machine.name}',
                              ),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: List<ButtonSegment<int>>.generate(
                    _sitePlans.length,
                    (index) => ButtonSegment<int>(
                      value: index,
                      icon: const Icon(Icons.location_city_outlined),
                      label: Text(_sitePlans[index].siteName),
                    ),
                  ),
                  selected: <int>{_selectedSiteIndex},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _setSelectedSiteIndex(selection.first);
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Projets: ${sitePlan.projects.join(', ')} | KW $_selectedWeek',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 52,
            itemBuilder: (context, index) {
              final week = index + 1;
              final selected = week == _selectedWeek;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selected,
                  label: Text('KW $week'),
                  onSelected: (_) {
                    if (_selectedWeek == week) {
                      return;
                    }
                    setState(() {
                      _selectedWeek = week;
                    });
                    _loadCsvStatuses();
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        if (widget.isAdmin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _pinEditMode,
              onChanged: (value) {
                setState(() {
                  _pinEditMode = value;
                  if (value && siteMachines.isNotEmpty) {
                    _selectedEditMachineId ??= siteMachines.first.id;
                  }
                });
              },
              title: const Text('Mode edition pin'),
              subtitle: const Text('Appui long sur la carte pour capturer dx/dy.'),
            ),
          ),
        if (_pinEditMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: DropdownButtonFormField<String>(
              value: siteMachines.any((m) => m.id == _selectedEditMachineId) ? _selectedEditMachineId : null,
              decoration: const InputDecoration(
                labelText: 'Machine a positionner',
                prefixIcon: Icon(Icons.edit_location_alt_outlined),
              ),
              items: siteMachines
                  .map(
                    (machine) => DropdownMenuItem<String>(
                      value: machine.id,
                      child: Text('${machine.id} - ${machine.name}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedEditMachineId = value),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: const <Widget>[
              _LegendDot(color: Colors.green, label: 'V (Realise)'),
              _LegendDot(color: Colors.red, label: 'N.V / retard'),
              _LegendDot(color: Colors.orange, label: 'Anomalie/corrective'),
              _LegendDot(color: Colors.blue, label: 'En attente (futur)'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_loadingCsvStatuses)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InteractiveViewer(
                  transformationController: _mapTransformController,
                  minScale: 0.8,
                  maxScale: 4,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final height = constraints.maxHeight;
                      _mapViewportSize = Size(width, height);
                      return GestureDetector(
                        key: _mapKey,
                        behavior: HitTestBehavior.opaque,
                        onLongPressStart: (details) {
                          _onMapLongPress(
                            localPosition: details.localPosition,
                            mapSize: Size(width, height),
                            machines: siteMachines,
                          );
                        },
                        child: Stack(
                          children: <Widget>[
                            Positioned.fill(
                              child: Image.asset(
                                sitePlan.assetPath,
                                fit: BoxFit.cover,
                              ),
                            ),
                            ...siteMachines.map(
                              (machine) {
                                final resolved = _resolveLocationForMachine(machine);
                                final location = resolved.location;
                                final isEditingMachine = _pinEditMode && machine.id == _selectedEditMachineId;
                                final isHighlightedMachine = machine.id == _highlightedMachineId;
                                final showLabel = isEditingMachine || isHighlightedMachine;
                                return Positioned(
                                  left: _xToPx(location.dx, width) - 10,
                                  top: _yToPx(location.dy, height) - 10,
                                  child: GestureDetector(
                                    onTap: () {
                                      if (_pinEditMode) {
                                        setState(() {
                                          _selectedEditMachineId = machine.id;
                                        });
                                      }
                                      _showMachineSheet(machine);
                                    },
                                    onPanUpdate: (details) {
                                      if (!(_pinEditMode && machine.id == _selectedEditMachineId)) return;
                                      final box = _mapKey.currentContext?.findRenderObject() as RenderBox?;
                                      if (box == null) return;
                                      final local = box.globalToLocal(details.globalPosition);
                                      final dx = (local.dx / width).clamp(0.0, 1.0);
                                      final dy = (local.dy / height).clamp(0.0, 1.0);
                                      final sourceKey = _normalizeMachineId(resolved.sourceId);
                                      setState(() {
                                        _draftLocationOverrides[sourceKey] = Offset(dx, dy);
                                      });
                                    },
                                    onPanEnd: (_) {
                                      if (!(_pinEditMode && machine.id == _selectedEditMachineId)) return;
                                      final sourceKey = _normalizeMachineId(resolved.sourceId);
                                      final ofs = _draftLocationOverrides[sourceKey];
                                      if (ofs == null) return;
                                      final snippet =
                                          "MachineLocation(id: '${resolved.sourceId}', dx: ${ofs.dx.toStringAsFixed(4)}, dy: ${ofs.dy.toStringAsFixed(4)}, site: '$_selectedSiteName', project: '${resolved.location.project}'),";
                                      _showConfirmOverride(
                                        sourceKey,
                                        snippet,
                                        machineId: machine.id,
                                        mapX: ofs.dx,
                                        mapY: ofs.dy,
                                      );
                                    },
                                    child: AnimatedBuilder(
                                      animation: _pinPulseController,
                                      builder: (context, child) {
                                        final pulse = isHighlightedMachine ? _pinPulseController.value : 0.0;
                                        final dotBaseSize = isEditingMachine ? 14.0 : 10.0;
                                        final dotSize = dotBaseSize + (isHighlightedMachine ? (pulse * 8) : 0);
                                        final borderWidth = isHighlightedMachine ? (1.5 + pulse) : 1.0;

                                        return Column(
                                          children: <Widget>[
                                            Container(
                                              width: dotSize,
                                              height: dotSize,
                                              decoration: BoxDecoration(
                                                color: _markerColor(machine),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isHighlightedMachine
                                                      ? Colors.yellowAccent
                                                      : Colors.white,
                                                  width: borderWidth,
                                                ),
                                              ),
                                            ),
                                            if (showLabel)
                                              Container(
                                                margin: const EdgeInsets.only(top: 4),
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.65),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: isHighlightedMachine
                                                        ? Colors.yellowAccent
                                                        : Colors.amberAccent,
                                                    width: borderWidth,
                                                  ),
                                                ),
                                                child: Text(
                                                  machine.id,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // mapX and mapY are normalized ratios between 0 and 1.
  double _xToPx(double mapX, double width) => mapX * width;
  double _yToPx(double mapY, double height) => mapY * height;
}

class _SitePlan {
  const _SitePlan({
    required this.siteName,
    required this.assetPath,
    required this.projects,
  });

  final String siteName;
  final String assetPath;
  final List<String> projects;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        radius: 6,
        backgroundColor: color,
      ),
      label: Text(label),
    );
  }
}

class _ResolvedMachineLocation {
  const _ResolvedMachineLocation({
    required this.location,
    required this.sourceId,
    required this.hasPersistedCoordinates,
  });

  final MachineLocation location;
  final String sourceId;
  final bool hasPersistedCoordinates;
}

class _MachineJumpTarget {
  const _MachineJumpTarget({
    required this.machine,
    required this.siteName,
    required this.dx,
    required this.dy,
  });

  final Machine machine;
  final String siteName;
  final double dx;
  final double dy;
}

class _MachineSearchHit {
  const _MachineSearchHit({
    required this.machine,
    required this.matchedMachineNumber,
    required this.target,
  });

  final Machine machine;
  final String matchedMachineNumber;
  final _MachineJumpTarget target;
}
