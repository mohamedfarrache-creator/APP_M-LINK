import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/services.dart';

import '../models/machine.dart';

class CsvMaintenanceStatusService {
  Map<String, _CsvMachineSchedule>? _cachedSchedules;

  Future<Map<String, MachineStatus>> loadStatusesForMachines(
    List<Machine> machines, {
    DateTime? now,
    int? selectedWeek,
  }) async {
    final currentWeek = selectedWeek ?? _isoWeek(now ?? DateTime.now());
    final schedulesByNumber = await _loadSchedules();
    final result = <String, MachineStatus>{};

    for (final machine in machines) {
      if (machine.status == MachineStatus.anomaly) {
        result[machine.id] = MachineStatus.anomaly;
        continue;
      }

      final candidateStatuses = <MachineStatus>[];
      for (final number in machine.drsNumbers) {
        final schedule = schedulesByNumber[_normalize(number)];
        if (schedule == null) {
          continue;
        }

        final status = _statusFromSchedule(
          schedule: schedule,
          currentWeek: currentWeek,
        );
        candidateStatuses.add(status);
      }

      if (candidateStatuses.isEmpty) {
        result[machine.id] = machine.status;
        continue;
      }

      result[machine.id] = _pickMostRelevantStatus(candidateStatuses);
    }

    return result;
  }

  Future<Map<String, _CsvMachineSchedule>> _loadSchedules() async {
    if (_cachedSchedules != null) {
      return _cachedSchedules!;
    }

    final manifestText = await rootBundle.loadString('AssetManifest.json');
    final manifest = jsonDecode(manifestText) as Map<String, dynamic>;
    final csvAssets = manifest.keys
        .where((path) => path.startsWith('calendrier_csv/') && path.toLowerCase().endsWith('.csv'))
        .toList()
      ..sort();

    final output = <String, _CsvMachineSchedule>{};
    for (final path in csvAssets) {
      final csvText = await rootBundle.loadString(path);
      final rows = _parseCsv(csvText);
      final schedules = _extractSchedules(rows);
      schedules.forEach((machineNumber, schedule) {
        output.putIfAbsent(machineNumber, () => schedule);
      });
    }

    _cachedSchedules = output;
    return output;
  }

  List<List<dynamic>> _parseCsv(String content) {
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

  Map<String, _CsvMachineSchedule> _extractSchedules(List<List<dynamic>> rows) {
    if (rows.isEmpty) {
      return const <String, _CsvMachineSchedule>{};
    }

    final headerRowIndex = _findHeaderRowIndex(rows);
    if (headerRowIndex < 0) {
      return const <String, _CsvMachineSchedule>{};
    }

    final header = _rowToStrings(rows[headerRowIndex]);
    final machineIdx = _indexOfMachineHeader(header);
    final firstWeekIdx = _indexOfWeekHeader(header, 1);
    if (machineIdx < 0 || firstWeekIdx < 0) {
      return const <String, _CsvMachineSchedule>{};
    }

    final weekColumnMap = <int, int>{};
    for (var i = firstWeekIdx; i < header.length; i++) {
      final week = _parseWeekNumber(header[i]);
      if (week != null && week >= 1 && week <= 53) {
        weekColumnMap[i] = week;
      }
    }

    final schedules = <String, _CsvMachineSchedule>{};
    for (var i = headerRowIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      final machineNumber = _cell(row, machineIdx).trim();
      if (machineNumber.isEmpty || _looksLikeMachineHeaderCell(machineNumber)) {
        continue;
      }

      final weekValues = <int, String>{};
      weekColumnMap.forEach((columnIndex, week) {
        final value = _cell(row, columnIndex).trim();
        if (value.isNotEmpty) {
          weekValues[week] = value;
        }
      });

      schedules[_normalize(machineNumber)] = _CsvMachineSchedule(weekValues: weekValues);
    }

    return schedules;
  }

  int _findHeaderRowIndex(List<List<dynamic>> rows) {
    final limit = rows.length < 20 ? rows.length : 20;
    for (var i = 0; i < limit; i++) {
      final row = _rowToStrings(rows[i]);
      if (row.any(_looksLikeMachineHeaderCell)) {
        return i;
      }
    }
    return -1;
  }

  int _indexOfMachineHeader(List<String> header) {
    for (var i = 0; i < header.length; i++) {
      if (_looksLikeMachineHeaderCell(header[i])) {
        return i;
      }
    }
    return -1;
  }

  int _indexOfWeekHeader(List<String> header, int week) {
    for (var i = 0; i < header.length; i++) {
      if (_parseWeekNumber(header[i]) == week) {
        return i;
      }
    }
    return -1;
  }

  bool _looksLikeMachineHeaderCell(String cell) {
    final normalized = _normalizeText(cell);
    return normalized == 'numero de machine' ||
        normalized == 'n machine' ||
        normalized == 'n de machine';
  }

  int? _parseWeekNumber(String value) {
    final cleaned = value.toUpperCase().replaceAll('KW', '').trim();
    final intValue = int.tryParse(cleaned);
    if (intValue != null) {
      return intValue;
    }
    final doubleValue = double.tryParse(cleaned.replaceAll(',', '.'));
    if (doubleValue != null) {
      return doubleValue.toInt();
    }
    return null;
  }

  String _cell(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) {
      return '';
    }
    final value = row[index];
    return value == null ? '' : value.toString();
  }

  List<String> _rowToStrings(List<dynamic> row) {
    return row.map((cell) => cell == null ? '' : cell.toString()).toList();
  }

  MachineStatus _statusFromSchedule({
    required _CsvMachineSchedule schedule,
    required int currentWeek,
  }) {
    final currentRaw = schedule.weekValues[currentWeek]?.trim() ?? '';
    final currentValue = _normalizeCellValue(currentRaw);

    if (currentValue == 'V') {
      return MachineStatus.ok;
    }

    if (_isNotValidated(currentValue)) {
      return MachineStatus.due;
    }

    if (currentValue.isNotEmpty) {
      return MachineStatus.due;
    }

    final hasPastUnvalidated = schedule.weekValues.entries.any((entry) {
      if (entry.key >= currentWeek) {
        return false;
      }
      final normalized = _normalizeCellValue(entry.value);
      return normalized.isNotEmpty && normalized != 'V';
    });
    if (hasPastUnvalidated) {
      return MachineStatus.due;
    }

    final hasFuturePlan = schedule.weekValues.entries.any((entry) {
      if (entry.key <= currentWeek) {
        return false;
      }
      return _normalizeCellValue(entry.value).isNotEmpty;
    });

    if (hasFuturePlan) {
      return MachineStatus.pending;
    }

    return MachineStatus.pending;
  }

  bool _isNotValidated(String normalizedValue) {
    return normalizedValue == 'NV' || normalizedValue == 'N.V';
  }

  MachineStatus _pickMostRelevantStatus(List<MachineStatus> statuses) {
    if (statuses.contains(MachineStatus.anomaly)) {
      return MachineStatus.anomaly;
    }
    if (statuses.contains(MachineStatus.due)) {
      return MachineStatus.due;
    }
    if (statuses.contains(MachineStatus.ok)) {
      return MachineStatus.ok;
    }
    return MachineStatus.pending;
  }

  String _normalize(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  String _normalizeText(String value) {
    return value
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('°', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeCellValue(String value) {
    return value.toUpperCase().replaceAll(' ', '');
  }

  int _isoWeek(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final firstDayOfYear = DateTime(thursday.year, 1, 1);
    final dayOfYear = thursday.difference(firstDayOfYear).inDays + 1;
    return ((dayOfYear - 1) / 7).floor() + 1;
  }
}

class _CsvMachineSchedule {
  const _CsvMachineSchedule({required this.weekValues});

  final Map<int, String> weekValues;
}
