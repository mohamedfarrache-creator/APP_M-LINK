import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CsvReader {
  static List<List<dynamic>> parse(String content) {
    final firstLine = content.split(RegExp(r'\r?\n')).firstWhere(
          (line) => line.trim().isNotEmpty,
          orElse: () => '',
        );
    final delimiter = firstLine.contains(';') ? ';' : ',';
    return const CsvToListConverter(shouldParseNumbers: false).convert(
      content,
      fieldDelimiter: delimiter,
      eol: '\n',
    );
  }
}

class Machine {
  const Machine({
    required this.projectName,
    required this.name,
    required this.type,
    required this.etat,
    required this.weeklyTasks,
  });

  final String projectName;
  final String name;
  final String type;
  final String etat;
  final Map<int, String> weeklyTasks;
}

class PreventiveCalendarScreen extends StatefulWidget {
  const PreventiveCalendarScreen({super.key});

  @override
  State<PreventiveCalendarScreen> createState() => _PreventiveCalendarScreenState();
}

class _PreventiveCalendarScreenState extends State<PreventiveCalendarScreen> {
  final Map<String, bool> _validated = <String, bool>{};

  int selectedWeek = _isoWeek(DateTime.now());
  bool _loading = true;
  String? _error;
  List<List<dynamic>> currentCsvData = <List<dynamic>>[];
  List<Machine> filteredMachines = <Machine>[];
  Map<String, String> _projectAssets = <String, String>{};
  String? _selectedProject;

  @override
  void initState() {
    super.initState();
    _bootstrapProjects();
  }

  static int _isoWeek(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final firstDayOfYear = DateTime(thursday.year, 1, 1);
    final dayOfYear = thursday.difference(firstDayOfYear).inDays + 1;
    return ((dayOfYear - 1) / 7).floor() + 1;
  }

  Future<void> _bootstrapProjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final projects = await _discoverProjectAssets();
      if (projects.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Aucun fichier CSV detecte dans calendrier_csv/.';
        });
        return;
      }

      final firstProject = projects.keys.first;
      setState(() {
        _projectAssets = projects;
        _selectedProject = firstProject;
      });

      await loadProjectData(firstProject);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Erreur de chargement des projets: $e';
      });
    }
  }

  Future<Map<String, String>> _discoverProjectAssets() async {
    final manifestText = await rootBundle.loadString('AssetManifest.json');
    final manifest = jsonDecode(manifestText) as Map<String, dynamic>;
    final entries = manifest.keys
        .where((path) {
          return path.startsWith('calendrier_csv/') && path.toLowerCase().endsWith('.csv');
        })
        .toList()
      ..sort();

    final map = <String, String>{};
    for (final path in entries) {
      final filename = path.split('/').last;
      final projectName = _projectNameFromFilename(filename);
      map[projectName] = path;
    }
    return map;
  }

  // Required by request: dynamically load CSV data from selected project.
  Future<void> loadProjectData(String projectName) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final assetPath = _projectAssets[projectName];
      if (assetPath == null) {
        throw StateError('Projet introuvable: $projectName');
      }

      final csvText = await rootBundle.loadString(assetPath);
      final parsedRows = CsvReader.parse(csvText);
      setState(() {
        _selectedProject = projectName;
        currentCsvData = parsedRows;
        filteredMachines = _filterMachines();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Impossible de lire le fichier CSV du projet $projectName. $e';
      });
    }
  }

  // Robust filtering for irregular CSV exports with empty/shifted rows.
  List<Machine> _filterMachines() {
    if (currentCsvData.isEmpty) {
      return <Machine>[];
    }

    final limit = currentCsvData.length < 20 ? currentCsvData.length : 20;
    var headerRowIndex = -1;

    // 1) Find header row containing the machine column label.
    for (var i = 0; i < limit; i++) {
      final row = _rowToStrings(currentCsvData[i]);
      if (row.any(_looksLikeMachineHeaderCell)) {
        headerRowIndex = i;
        break;
      }
    }

    if (headerRowIndex < 0) {
      return <Machine>[];
    }

    final header = _rowToStrings(currentCsvData[headerRowIndex]);

    // 2) Map indexes from this exact header row.
    final nameIdx = _indexOfHeaderExact(
      header,
      const <String>['Numéro de machine', 'Numero de machine', 'NumÃ©ro de machine'],
    );
    var typeIdx = _indexOfHeaderExact(header, const <String>['TYPE']);
    var etatIdx = _indexOfHeaderExact(header, const <String>['ETAT']);
    final firstWeekIdx = _indexOfHeaderExact(header, const <String>['1']);

    // Some Excel exports place TYPE/ETAT on a nearby decorative row.
    if (typeIdx < 0 || etatIdx < 0) {
      final nearby = _findTypeEtatInNearbyRows(headerRowIndex);
      if (typeIdx < 0) {
        typeIdx = nearby.$1;
      }
      if (etatIdx < 0) {
        etatIdx = nearby.$2;
      }
    }

    if (nameIdx < 0 || firstWeekIdx < 0) {
      return <Machine>[];
    }

    final output = <Machine>[];

    // 3) Parse data rows directly under header.
    for (var i = headerRowIndex + 1; i < currentCsvData.length; i++) {
      final row = currentCsvData[i];
      if (row.isEmpty) {
        continue;
      }

      // 4) Compute target cell index for selected week.
      final targetIdx = firstWeekIdx + (selectedWeek - 1);

      // 5) Protect against short rows and only include non-empty tasks.
      if (targetIdx >= row.length) {
        continue;
      }

      final machineName = _cell(row, nameIdx).trim();
      final weekValue = _cell(row, targetIdx).trim();
      if (machineName.isEmpty || weekValue.isEmpty) {
        continue;
      }

      final typeValue = typeIdx >= 0 ? _cell(row, typeIdx).trim() : '-';
      final etatValue = etatIdx >= 0 ? _cell(row, etatIdx).trim() : '';

      output.add(
        Machine(
          projectName: _selectedProject ?? '-',
          name: machineName,
          type: typeValue,
          etat: etatValue,
          weeklyTasks: <int, String>{selectedWeek: weekValue},
        ),
      );
    }

    return output;
  }

  (int, int) _findTypeEtatInNearbyRows(int headerRowIndex) {
    final from = headerRowIndex - 3 < 0 ? 0 : headerRowIndex - 3;
    final to = headerRowIndex + 3 >= currentCsvData.length
        ? currentCsvData.length - 1
        : headerRowIndex + 3;

    for (var i = from; i <= to; i++) {
      final row = _rowToStrings(currentCsvData[i]);
      final t = _indexOfHeaderExact(row, const <String>['TYPE']);
      final e = _indexOfHeaderExact(row, const <String>['ETAT']);
      if (t >= 0 || e >= 0) {
        return (t, e);
      }
    }
    return (-1, -1);
  }

  int _indexOfHeaderExact(List<String> header, List<String> acceptedValues) {
    // Exact pass.
    for (var i = 0; i < header.length; i++) {
      final value = header[i].trim();
      for (final accepted in acceptedValues) {
        if (value == accepted) {
          return i;
        }
      }
    }

    // Normalized fallback to handle spacing/encoding/accents across files.
    for (var i = 0; i < header.length; i++) {
      final value = _normalize(header[i]);
      for (final accepted in acceptedValues) {
        if (value == _normalize(accepted)) {
          return i;
        }
      }

      // Week marker fallback for column '1'.
      if (acceptedValues.length == 1 && acceptedValues.first == '1') {
        final numeric = int.tryParse(value);
        if (numeric == 1) {
          return i;
        }
      }
    }
    return -1;
  }

  bool _looksLikeMachineHeaderCell(String cell) {
    final normalized = _normalize(cell);
    return normalized == 'numero de machine' ||
        normalized == 'n° machine' ||
        normalized == 'n machine';
  }

  String _cell(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) {
      return '';
    }
    return _csvValueToString(row[index]);
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _rowToStrings(List<dynamic> row) {
    return row.map(_csvValueToString).map((v) => v.trim()).toList();
  }

  String _csvValueToString(dynamic cell) {
    final value = cell;
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  String _projectNameFromFilename(String filename) {
    final base = filename
        .replaceAll('.csv', '')
        .replaceAll('Calendrier', '')
        .replaceAll('calendrier', '')
        .replaceAll('preventive', '')
        .replaceAll('préventive', '')
        .replaceAll('2026', '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return base.isEmpty ? filename : base.toUpperCase();
  }

  Color _validationColor(Machine machine) {
    if (_validated[machine.name] == true) {
      return Colors.green;
    }

    final etat = machine.etat.toUpperCase().replaceAll(' ', '');
    if (etat == 'V') {
      return Colors.green;
    }
    if (etat == 'N.V' || etat == 'NV') {
      return Colors.red;
    }
    return Colors.grey;
  }

  IconData _typeIcon(String type) {
    final normalized = type.toUpperCase();
    if (normalized.contains('KSK')) {
      return Icons.precision_manufacturing;
    }
    if (normalized.contains('KSM')) {
      return Icons.memory;
    }
    return Icons.build_circle_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredMachines;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: DropdownButtonFormField<String>(
            value: _selectedProject,
            decoration: const InputDecoration(
              labelText: 'Projet',
              prefixIcon: Icon(Icons.folder_open_outlined),
            ),
            items: _projectAssets.keys
                .map(
                  (project) => DropdownMenuItem<String>(
                    value: project,
                    child: Text(project),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                loadProjectData(value);
              }
            },
          ),
        ),
        if (_selectedProject != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Projet selectionne: $_selectedProject',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        SizedBox(
          height: 68,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: 52,
            itemBuilder: (context, index) {
              final week = index + 1;
              final selected = week == selectedWeek;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selected,
                  label: Text('KW $week'),
                  onSelected: (_) {
                    setState(() {
                      selectedWeek = week;
                      filteredMachines = _filterMachines();
                    });
                  },
                ),
              );
            },
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Text('Aucune machine planifiee pour KW $selectedWeek'),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final machine = filtered[index];
                            final task = machine.weeklyTasks[selectedWeek]!.trim();
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Icon(_typeIcon(machine.type)),
                                ),
                                title: Text(machine.name),
                                subtitle: Text('Maintenance $task'),
                                trailing: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _validationColor(machine),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _validated[machine.name] = true;
                                    });
                                  },
                                  child: const Text('Valider'),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
