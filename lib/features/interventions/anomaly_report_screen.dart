import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/app_user.dart';
import '../../data/models/intervention.dart';
import '../../data/repositories/maintenance_repository.dart';
import '../../data/services/contre_piece_search_service.dart';
import '../../data/services/machine_search_service.dart';

class AnomalyReportScreen extends StatefulWidget {
  const AnomalyReportScreen({
    super.key,
    required this.currentUser,
    required this.repository,
  });

  final AppUser currentUser;
  final MaintenanceRepository repository;

  @override
  State<AnomalyReportScreen> createState() => _AnomalyReportScreenState();
}

class _AnomalyReportScreenState extends State<AnomalyReportScreen> {
  static const List<String> _projects = <String>[
    'Q7-Q9 KSK',
    'RL-TAN',
    'COCK-PIT',
    'T-ROC',
    'ID_4',
    'MEB_21',
    'HIGH VOLTAGE',
    'ID_7',
    'PORSCHE',
    'MEB_31',
    'GOLF A8',
  ];

  final _formKey = GlobalKey<FormState>();
  final _machineCtrl = TextEditingController();
  final _contrePieceCtrl = TextEditingController();
  final _interventionCtrl = TextEditingController();
  final _technicienCtrl = TextEditingController();
  final _tempsProdCtrl = TextEditingController(text: '0');
  final _tempsTechCtrl = TextEditingController(text: '0');
  final _machineFocusNode = FocusNode();
  final _contrePieceFocusNode = FocusNode();
  final _contrePieceSearchService = ContrePieceSearchService();

  late MachineSearchService _machineSearchService;
  DateTime _date = DateTime.now();
  String _project = _projects.first;
  MachineSearchHit? _selectedMachine;
  String _niveau = '1';
  TimeOfDay? _heureDebut;
  TimeOfDay? _heureFin;
  String _shift = 'A';
  bool _submitting = false;
  bool _contrePiecesReady = false;
  String? _contrePiecesError;

  @override
  void initState() {
    super.initState();
    _technicienCtrl.text = widget.currentUser.matricule;
    _machineSearchService = MachineSearchService(widget.repository.machines);
    widget.repository.addListener(_handleRepositoryChanged);
    unawaited(_loadContrePieces());
  }

  Future<void> _loadContrePieces() async {
    try {
      await _contrePieceSearchService.initialize();
      if (!mounted) {
        return;
      }
      setState(() {
        _contrePiecesReady = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _contrePiecesError = 'Impossible de charger les contre-pieces CSV';
      });
    }
  }

  @override
  void didUpdateWidget(covariant AnomalyReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository.removeListener(_handleRepositoryChanged);
      widget.repository.addListener(_handleRepositoryChanged);
      _handleRepositoryChanged();
    }
    if (oldWidget.currentUser != widget.currentUser) {
      _technicienCtrl.text = widget.currentUser.matricule;
    }
  }

  @override
  void dispose() {
    widget.repository.removeListener(_handleRepositoryChanged);
    _machineCtrl.dispose();
    _contrePieceCtrl.dispose();
    _interventionCtrl.dispose();
    _technicienCtrl.dispose();
    _tempsProdCtrl.dispose();
    _tempsTechCtrl.dispose();
    _machineFocusNode.dispose();
    _contrePieceFocusNode.dispose();
    super.dispose();
  }

  void _handleRepositoryChanged() {
    if (!mounted) {
      return;
    }
    final service = MachineSearchService(widget.repository.machines);
    setState(() {
      _machineSearchService = service;
      _selectedMachine = _findProjectMachine(_machineCtrl.text.trim());
    });
  }

  MachineSearchHit? _findProjectMachine(String value) {
    final exact = _machineSearchService.findExact(value);
    if (exact == null || !_matchesSelectedProject(exact)) {
      return null;
    }
    return exact;
  }

  Iterable<MachineSearchHit> _machineOptions(String query) {
    return _machineSearchService
        .suggest(query, limit: 40)
        .where(_matchesSelectedProject)
        .take(10);
  }

  bool _matchesSelectedProject(MachineSearchHit hit) {
    final selected = _normalize(_project);
    final project = _normalize(hit.project);
    final machineName = _normalize(hit.machine.name);
    return project.contains(selected) ||
        selected.contains(project) ||
        machineName.contains(selected) ||
        selected.contains(machineName) ||
        _projectAliasMatches(selected, project) ||
        _projectAliasMatches(selected, machineName);
  }

  bool _projectAliasMatches(String selected, String value) {
    if (selected == 'ID4') {
      return value.contains('ID4') || value.contains('IDBUZZ');
    }
    if (selected == 'Q7Q9KSK') {
      return value.contains('Q7Q9') || value.contains('KSK');
    }
    return false;
  }

  void _onProjectChanged(String value) {
    setState(() {
      _project = value;
      _selectedMachine = null;
      _machineCtrl.clear();
    });
  }

  void _onMachineChanged(String value) {
    setState(() {
      _selectedMachine = _findProjectMachine(value);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: _date,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _date = picked;
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? _heureDebut ?? TimeOfDay.now()
          : _heureFin ?? _heureDebut ?? TimeOfDay.now(),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isStart) {
        _heureDebut = picked;
      } else {
        _heureFin = picked;
      }
      _syncTempsTech();
    });
  }

  void _syncTempsTech() {
    final start = _heureDebut;
    final end = _heureFin;
    if (start == null || end == null) {
      return;
    }
    var minutes = _minutesOfDay(end) - _minutesOfDay(start);
    if (minutes < 0) {
      minutes += Duration.minutesPerDay;
    }
    _tempsTechCtrl.text = '$minutes';
  }

  Future<void> _submit() async {
    setState(() {
      _selectedMachine = _findProjectMachine(_machineCtrl.text.trim());
    });

    if (_submitting || !_formKey.currentState!.validate()) {
      return;
    }

    if (_heureDebut == null || _heureFin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Renseignez les heures de debut et de fin.'),
        ),
      );
      return;
    }

    final selectedMachine = _selectedMachine;
    if (selectedMachine == null) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    final createdAt = _dateWithStartTime();
    final intervention = Intervention(
      id: 'INT-${DateTime.now().millisecondsSinceEpoch}',
      machineId: selectedMachine.machine.id,
      machineName: selectedMachine.machineNumber,
      createdByUserId: widget.currentUser.id,
      createdByName: widget.currentUser.matricule,
      createdByRole: widget.currentUser.role.name,
      type: InterventionType.actionRequest,
      priority: InterventionPriority.medium,
      title: 'Intervention',
      description: _interventionCtrl.text.trim(),
      createdAtIso: createdAt.toIso8601String(),
      forKw: _isoWeekNumber(createdAt),
      contrePiece: _contrePieceCtrl.text.trim(),
      niveau: _niveau,
      heureDebut: _formatTime(_heureDebut),
      heureFin: _formatTime(_heureFin),
      tempsProd: int.tryParse(_tempsProdCtrl.text.trim()) ?? 0,
      tempsTech: int.tryParse(_tempsTechCtrl.text.trim()) ?? 0,
      shift: _shift,
    );

    try {
      await widget.repository.submitIntervention(intervention);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur enregistrement intervention: $e')),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Intervention enregistree.')),
    );
    _formKey.currentState!.reset();
    setState(() {
      _date = DateTime.now();
      _selectedMachine = null;
      _niveau = '1';
      _heureDebut = null;
      _heureFin = null;
      _shift = 'A';
      _submitting = false;
    });
    _machineCtrl.clear();
    _contrePieceCtrl.clear();
    _interventionCtrl.clear();
    _tempsProdCtrl.text = '0';
    _tempsTechCtrl.text = '0';
  }

  DateTime _dateWithStartTime() {
    final start = _heureDebut;
    if (start == null) {
      return DateTime(_date.year, _date.month, _date.day);
    }
    return DateTime(
        _date.year, _date.month, _date.day, start.hour, start.minute);
  }

  String _formatTime(TimeOfDay? value) {
    if (value == null) {
      return '';
    }
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  int _minutesOfDay(TimeOfDay value) {
    return value.hour * Duration.minutesPerHour + value.minute;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          'Intervention',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Enregistrez une intervention maintenance avec machine, contre-piece et temps.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _DateField(
                    label: _dateLabel(_date),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _project,
                    decoration: const InputDecoration(
                      labelText: 'Projet',
                      prefixIcon: Icon(Icons.folder_outlined),
                    ),
                    items: _projects
                        .map(
                          (project) => DropdownMenuItem<String>(
                            value: project,
                            child: Text(project),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _onProjectChanged(value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  RawAutocomplete<MachineSearchHit>(
                    textEditingController: _machineCtrl,
                    focusNode: _machineFocusNode,
                    optionsBuilder: (textEditingValue) {
                      return _machineOptions(textEditingValue.text);
                    },
                    displayStringForOption: (option) => option.machineNumber,
                    onSelected: (option) {
                      setState(() {
                        _selectedMachine = option;
                      });
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: _onMachineChanged,
                        decoration: const InputDecoration(
                          labelText: 'Machine',
                          prefixIcon:
                              Icon(Icons.precision_manufacturing_outlined),
                        ),
                        validator: (value) {
                          if (_findProjectMachine(value?.trim() ?? '') ==
                              null) {
                            return 'Selectionnez une machine du projet';
                          }
                          return null;
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return _OptionsPanel(
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              leading: const Icon(Icons.memory_outlined),
                              title: Text(option.machineNumber),
                              subtitle: Text(
                                  '${option.project} | ${option.machineType}'),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  if (!_contrePiecesReady && _contrePiecesError == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    ),
                  if (_contrePiecesError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _contrePiecesError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  RawAutocomplete<String>(
                    textEditingController: _contrePieceCtrl,
                    focusNode: _contrePieceFocusNode,
                    optionsBuilder: (textEditingValue) {
                      return _contrePieceSearchService
                          .suggest(textEditingValue.text);
                    },
                    onSelected: (option) {
                      _contrePieceCtrl.text = option;
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Contre Piece',
                          prefixIcon: Icon(Icons.search_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Contre piece obligatoire';
                          }
                          return null;
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return _OptionsPanel(
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              leading: const Icon(Icons.widgets_outlined),
                              title: Text(option),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _interventionCtrl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Intervention',
                      prefixIcon: Icon(Icons.description_outlined),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 3) {
                        return 'Intervention obligatoire';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _niveau,
                    decoration: const InputDecoration(
                      labelText: 'Niveau',
                      prefixIcon: Icon(Icons.stairs_outlined),
                    ),
                    items: const <String>['1', '2', '3']
                        .map(
                          (niveau) => DropdownMenuItem<String>(
                            value: niveau,
                            child: Text('Niveau $niveau'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _niveau = value ?? '1'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _TimeField(
                          label: 'Heure Debut',
                          value: _formatTime(_heureDebut),
                          onTap: () => _pickTime(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimeField(
                          label: 'Heure Fin',
                          value: _formatTime(_heureFin),
                          onTap: () => _pickTime(isStart: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _technicienCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Technicien',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _tempsProdCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Temps Prod (min)',
                            prefixIcon: Icon(Icons.timer_outlined),
                          ),
                          validator: _validateInteger,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _tempsTechCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Temps Tech (min)',
                            prefixIcon: Icon(Icons.engineering_outlined),
                          ),
                          validator: _validateInteger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _shift,
                    decoration: const InputDecoration(
                      labelText: 'Shift',
                      prefixIcon: Icon(Icons.schedule_outlined),
                    ),
                    items: const <String>['A', 'B', 'C']
                        .map(
                          (shift) => DropdownMenuItem<String>(
                            value: shift,
                            child: Text('Shift $shift'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _shift = value ?? 'A'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Enregistrer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? _validateInteger(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || int.tryParse(text) == null) {
      return 'Nombre requis';
    }
    return null;
  }

  static String _normalize(String value) {
    return value
        .toUpperCase()
        .replaceAll('É', 'E')
        .replaceAll('È', 'E')
        .replaceAll('Ê', 'E')
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date',
          prefixIcon: Icon(Icons.event_outlined),
        ),
        child: Text(label),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.access_time_outlined),
        ),
        child: Text(value.isEmpty ? '--:--' : value),
      ),
    );
  }
}

class _OptionsPanel extends StatelessWidget {
  const _OptionsPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260, minWidth: 320),
          child: child,
        ),
      ),
    );
  }
}

int _isoWeekNumber(DateTime date) {
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final firstDayOfYear = DateTime(thursday.year, 1, 1);
  final dayOfYear = thursday.difference(firstDayOfYear).inDays + 1;
  return ((dayOfYear - 1) / 7).floor() + 1;
}
