import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';

class _MachineRecord {
  const _MachineRecord({
    required this.id,
    required this.site,
    required this.project,
  });

  final String id;
  final String site;
  final String project;
}

void main() {
  final csvDir = Directory('calendrier_csv');
  if (!csvDir.existsSync()) {
    stderr.writeln('Missing calendrier_csv directory.');
    exitCode = 1;
    return;
  }

  final csvFiles = csvDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.csv'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final extracted = <String, Set<String>>{};
  for (final file in csvFiles) {
    final key = _normalizeFileName(file.uri.pathSegments.last);
    extracted[key] = _extractMachineIds(file);
  }

  const hvManualForSatellite2 = <String>{
    'TS1500.2018.401098-213',
    'TS1500.2018.401098-246',
  };

  final records = <_MachineRecord>[];

  final q7 = _byKey(extracted, 'q7q9ksk');
  records.addAll(_build(q7, site: 'Plant 1', project: 'Q7-Q9 KSK'));

  final rlTan = _byKey(extracted, 'rltan');
  final cockpit = _byKey(extracted, 'cockpit');
  final troc = _byKey(extracted, 'troc');
  final id4 = _byKey(extracted, 'id4');
  final meb21 = _byKey(extracted, 'meb21');
  records.addAll(_build(rlTan, site: 'Plant 2', project: 'RL-TAN'));
  records.addAll(_build(cockpit, site: 'Plant 2', project: 'COCK-PIT'));
  records.addAll(_build(troc, site: 'Plant 2', project: 'T-ROC'));
  records.addAll(_build(id4, site: 'Plant 2', project: 'ID_4'));
  records.addAll(_build(meb21, site: 'Plant 2', project: 'MEB_21'));

  final highVoltageAll = _byKey(extracted, 'highvoltage');
  final highVoltageSat1 = Set<String>.from(highVoltageAll)
    ..removeWhere((id) => hvManualForSatellite2.contains(id));
  final id7 = _byKey(extracted, 'id7');
  final porsche = _byKey(extracted, 'porsche');
  records.addAll(_build(highVoltageSat1, site: 'Satellite 1', project: 'HIGH VOLTAGE'));
  records.addAll(_build(id7, site: 'Satellite 1', project: 'ID_7'));
  records.addAll(_build(porsche, site: 'Satellite 1', project: 'PORSCHE'));

  final meb31 = _byKey(extracted, 'meb31');
  records.addAll(_build(meb31, site: 'Satellite 2', project: 'MEB_31'));
  records.addAll(_build(hvManualForSatellite2, site: 'Satellite 2', project: 'HIGH VOLTAGE'));

  final golfA8 = _byKey(extracted, 'golfa8');
  records.addAll(_build(golfA8, site: 'Satellite 3', project: 'GOLF A8'));

  final dedup = <String, _MachineRecord>{};
  for (final record in records) {
    final key = '${record.site}|${record.project}|${record.id}';
    dedup.putIfAbsent(key, () => record);
  }

  final sorted = dedup.values.toList()
    ..sort((a, b) {
      final siteOrder = _siteOrder(a.site).compareTo(_siteOrder(b.site));
      if (siteOrder != 0) return siteOrder;
      final projectOrder = a.project.compareTo(b.project);
      if (projectOrder != 0) return projectOrder;
      return a.id.compareTo(b.id);
    });

  final hasTroc = troc.isNotEmpty;

  final buffer = StringBuffer()
    ..writeln('class MachineLocation {')
    ..writeln('  const MachineLocation({')
    ..writeln('    required this.id,')
    ..writeln('    required this.dx,')
    ..writeln('    required this.dy,')
    ..writeln('    required this.site,')
    ..writeln('    required this.project,')
    ..writeln('  });')
    ..writeln()
    ..writeln('  final String id;')
    ..writeln('  final double dx;')
    ..writeln('  final double dy;')
    ..writeln('  final String site;')
    ..writeln('  final String project;')
    ..writeln('}')
    ..writeln()
    ..writeln('final List<MachineLocation> allMachineLocations = <MachineLocation>[');

  if (!hasTroc) {
    buffer.writeln('  // T-ROC CSV introuvable: section laissee vide selon consigne.');
  }

  String? currentSite;
  for (final item in sorted) {
    if (currentSite != item.site) {
      currentSite = item.site;
      buffer.writeln();
      buffer.writeln('  // $currentSite');
    }
    buffer.writeln(
      "  MachineLocation(id: '${_escape(item.id)}', dx: 0.0, dy: 0.0, site: '${item.site}', project: '${item.project}'),",
    );
  }

  buffer.writeln('];');

  final outFile = File('lib/data/machine_data.dart');
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(buffer.toString());

  final summary = {
    'filesDetected': csvFiles.map((f) => f.uri.pathSegments.last).toList(),
    'countsByNormalizedFile': {
      for (final e in extracted.entries) e.key: e.value.length,
    },
    'totalGenerated': sorted.length,
  };

  final summaryFile = File('docs/machine_data_summary.json');
  summaryFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(summary));

  stdout.writeln('Generated lib/data/machine_data.dart with ${sorted.length} machines.');
}

Set<String> _extractMachineIds(File file) {
  final content = file.readAsStringSync();
  final delimiter = _inferDelimiter(content);
  final rows = const CsvToListConverter(shouldParseNumbers: false).convert(
    content,
    fieldDelimiter: delimiter,
    eol: '\n',
  );

  if (rows.isEmpty) {
    return <String>{};
  }

  final headerRowIndex = _findHeaderRow(rows);
  if (headerRowIndex < 0) {
    return <String>{};
  }

  final header = _rowToStrings(rows[headerRowIndex]);
  final machineIdx = _findMachineColumnIndex(header);
  if (machineIdx < 0) {
    return <String>{};
  }

  final out = <String>{};
  for (var i = headerRowIndex + 1; i < rows.length; i++) {
    final row = rows[i];
    if (machineIdx >= row.length) {
      continue;
    }

    final value = _cleanMachineId(row[machineIdx]?.toString() ?? '');
    if (value.isEmpty) {
      continue;
    }

    final n = _normalizeText(value);
    if (n == 'numero de machine' ||
        n == 'n de machine' ||
        n == 'n machine' ||
        n == '*' ||
        n == '-' ||
        n == 'n/a') {
      continue;
    }

    if (!RegExp(r'[a-zA-Z0-9]').hasMatch(value)) {
      continue;
    }

    out.add(value);
  }

  return out;
}

String _inferDelimiter(String content) {
  final lines = content.split(RegExp(r'\r?\n'));
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    return line.contains(';') ? ';' : ',';
  }
  return ',';
}

int _findHeaderRow(List<List<dynamic>> rows) {
  final limit = rows.length < 30 ? rows.length : 30;
  for (var i = 0; i < limit; i++) {
    final row = _rowToStrings(rows[i]);
    if (row.any(_looksLikeMachineHeaderCell)) {
      return i;
    }
  }
  return -1;
}

int _findMachineColumnIndex(List<String> header) {
  for (var i = 0; i < header.length; i++) {
    if (_looksLikeMachineHeaderCell(header[i])) {
      return i;
    }
  }
  return -1;
}

bool _looksLikeMachineHeaderCell(String cell) {
  final n = _normalizeText(cell);
  return n == 'numero de machine' || n == 'n de machine' || n == 'n machine' || n == 'numaro de machine';
}

List<String> _rowToStrings(List<dynamic> row) {
  return row.map((cell) => cell?.toString() ?? '').map((v) => v.trim()).toList();
}

String _cleanMachineId(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _normalizeText(String value) {
  return value
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('°', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _normalizeFileName(String filename) {
  final lower = _normalizeText(filename)
      .replaceAll('.csv', '')
      .replaceAll('calendrier', '')
      .replaceAll('preventive', '')
      .replaceAll('preventives', '')
      .replaceAll('prevention', '')
      .replaceAll('2026', '')
      .replaceAll('_', '')
      .replaceAll('-', '')
      .replaceAll(' ', '');
  return lower;
}

Set<String> _byKey(Map<String, Set<String>> extracted, String key) {
  final match = extracted.entries.where((e) => e.key.contains(key)).toList();
  final out = <String>{};
  for (final m in match) {
    out.addAll(m.value);
  }
  return out;
}

List<_MachineRecord> _build(
  Set<String> ids, {
  required String site,
  required String project,
}) {
  final sorted = ids.toList()..sort();
  return sorted
      .map((id) => _MachineRecord(id: id, site: site, project: project))
      .toList(growable: false);
}

int _siteOrder(String site) {
  switch (site) {
    case 'Plant 1':
      return 1;
    case 'Plant 2':
      return 2;
    case 'Satellite 1':
      return 3;
    case 'Satellite 2':
      return 4;
    case 'Satellite 3':
      return 5;
    default:
      return 99;
  }
}

String _escape(String value) {
  return value.replaceAll("'", "\\'");
}
