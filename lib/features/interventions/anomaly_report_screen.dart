import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/app_user.dart';
import '../../data/models/intervention.dart';
import '../../data/repositories/maintenance_repository.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _machineCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _machineFocusNode = FocusNode();

  late MachineSearchService _searchService;
  final ImagePicker _imagePicker = ImagePicker();

  MachineSearchHit? _selectedMachine;
  String _problemType = 'Panne';
  InterventionPriority _priority = InterventionPriority.high;
  String? _photoLabel;

  @override
  void initState() {
    super.initState();
    _searchService = MachineSearchService(widget.repository.machines);
    widget.repository.addListener(_handleRepositoryChanged);
  }

  @override
  void didUpdateWidget(covariant AnomalyReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository.removeListener(_handleRepositoryChanged);
      widget.repository.addListener(_handleRepositoryChanged);
      _handleRepositoryChanged();
    }
  }

  @override
  void dispose() {
    widget.repository.removeListener(_handleRepositoryChanged);
    _machineCtrl.dispose();
    _descriptionCtrl.dispose();
    _machineFocusNode.dispose();
    super.dispose();
  }

  void _handleRepositoryChanged() {
    if (!mounted) {
      return;
    }

    final updated = MachineSearchService(widget.repository.machines);
    setState(() {
      _searchService = updated;
      _selectedMachine = updated.findExact(_machineCtrl.text.trim());
    });
  }

  void _onMachineChanged(String value) {
    final exact = _searchService.findExact(value);
    setState(() {
      _selectedMachine = exact;
    });
  }

  Future<void> _selectPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Prendre une photo'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choisir depuis la galerie'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _photoLabel = picked.name;
    });
  }

  InterventionType _toInterventionType(String value) {
    switch (value) {
      case 'Amelioration':
      case 'Action preventive':
        return InterventionType.actionRequest;
      default:
        return InterventionType.anomaly;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedMachine == null) {
      return;
    }

    final machine = _selectedMachine!.machine;
    final description = _descriptionCtrl.text.trim();
    final enrichedDescription = _photoLabel == null ? description : '$description\nPhoto: $_photoLabel';

    final intervention = Intervention(
      id: 'INT-${DateTime.now().millisecondsSinceEpoch}',
      machineId: machine.id,
      machineName: machine.name,
      createdByUserId: widget.currentUser.id,
      createdByName: widget.currentUser.fullName,
      createdByRole: widget.currentUser.role.name,
      type: _toInterventionType(_problemType),
      priority: _priority,
      title: _problemType,
      description: enrichedDescription,
      createdAtIso: DateTime.now().toIso8601String(),
      forKw: machine.nextKw,
    );

    await widget.repository.submitIntervention(intervention);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signalement envoye avec succes.')),
    );
    _formKey.currentState!.reset();
    setState(() {
      _selectedMachine = null;
      _problemType = 'Panne';
      _priority = InterventionPriority.high;
      _photoLabel = null;
    });
    _machineCtrl.clear();
    _descriptionCtrl.clear();
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      child: Text(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          'Signaler une anomalie',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Saisissez le numero machine pour detecter automatiquement le projet et le type.',
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
                  RawAutocomplete<MachineSearchHit>(
                    textEditingController: _machineCtrl,
                    focusNode: _machineFocusNode,
                    optionsBuilder: (textEditingValue) {
                      return _searchService.suggest(textEditingValue.text);
                    },
                    displayStringForOption: (option) => option.machineNumber,
                    onSelected: (option) {
                      setState(() {
                        _selectedMachine = option;
                      });
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: _onMachineChanged,
                        decoration: const InputDecoration(
                          labelText: 'Machine',
                          hintText: 'Ex: TS1700... ou 3 derniers chiffres',
                          prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                        ),
                        validator: (_) {
                          if (_selectedMachine == null) {
                            return 'Selectionnez une machine valide';
                          }
                          return null;
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(14),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 260, minWidth: 320),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  leading: const Icon(Icons.memory_outlined),
                                  title: Text(option.machineNumber),
                                  subtitle: Text('${option.project} | ${option.machineType}'),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _infoTile(
                    icon: Icons.factory_outlined,
                    label: 'Projet detecte',
                    value: _selectedMachine?.project ?? 'Aucun projet detecte',
                  ),
                  const SizedBox(height: 12),
                  _infoTile(
                    icon: Icons.category_outlined,
                    label: 'Type machine detecte',
                    value: _selectedMachine?.machineType ?? 'Aucun type detecte',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _problemType,
                    decoration: const InputDecoration(
                      labelText: 'Type de probleme',
                      prefixIcon: Icon(Icons.report_problem_outlined),
                    ),
                    items: const <String>[
                      'Panne',
                      'Securite',
                      'Amelioration',
                      'Action preventive',
                      'Autre',
                    ]
                        .map(
                          (label) => DropdownMenuItem<String>(
                            value: label,
                            child: Text(label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _problemType = value ?? 'Panne'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Priorite',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<InterventionPriority>(
                    segments: const <ButtonSegment<InterventionPriority>>[
                      ButtonSegment<InterventionPriority>(
                        value: InterventionPriority.low,
                        icon: Icon(Icons.keyboard_double_arrow_down_rounded),
                        label: Text('Basse'),
                      ),
                      ButtonSegment<InterventionPriority>(
                        value: InterventionPriority.high,
                        icon: Icon(Icons.priority_high_rounded),
                        label: Text('Haute'),
                      ),
                      ButtonSegment<InterventionPriority>(
                        value: InterventionPriority.urgent,
                        icon: Icon(Icons.warning_amber_rounded),
                        label: Text('Critique'),
                      ),
                    ],
                    selected: <InterventionPriority>{_priority},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) {
                      setState(() {
                        _priority = value.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionCtrl,
                    onChanged: (_) => setState(() {}),
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description_outlined),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 8) {
                        return 'Description minimum 8 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _selectPhoto,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(_photoLabel == null ? 'Ajouter une photo' : 'Photo ajoutee'),
                  ),
                  if (_photoLabel != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'Fichier: $_photoLabel',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _selectedMachine == null ? null : _submit,
                    icon: const Icon(Icons.notification_add_outlined),
                    label: const Text('Envoyer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
