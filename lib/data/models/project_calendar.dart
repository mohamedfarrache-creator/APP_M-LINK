import 'dart:convert';

class ProjectCalendar {
  const ProjectCalendar({
    required this.project,
    required this.sourceFile,
    required this.machineType,
    required this.drsNumbers,
  });

  final String project;
  final String sourceFile;
  final String machineType;
  final List<String> drsNumbers;

  factory ProjectCalendar.fromDb(Map<String, Object?> row) {
    final drsRaw = row['drsNumbers'] as String? ?? '[]';
    final drsNumbers = (jsonDecode(drsRaw) as List<dynamic>)
        .map((item) => item.toString())
        .toList();
    return ProjectCalendar(
      project: row['project'] as String? ?? '',
      sourceFile: row['sourceFile'] as String? ?? '',
      machineType: row['machineType'] as String? ?? '',
      drsNumbers: drsNumbers,
    );
  }

  Map<String, Object?> toDb() {
    return {
      'project': project,
      'sourceFile': sourceFile,
      'machineType': machineType,
      'drsNumbers': jsonEncode(drsNumbers),
    };
  }
}
