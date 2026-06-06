import '../models/machine.dart';

class MachineSearchHit {
  const MachineSearchHit({
    required this.machine,
    required this.machineNumber,
    required this.project,
    required this.machineType,
  });

  final Machine machine;
  final String machineNumber;
  final String project;
  final String machineType;

  String get searchableText => '$machineNumber $project $machineType ${machine.site}';
}

class MachineSearchService {
  MachineSearchService(List<Machine> machines)
      : _hits = _buildHits(machines),
        _index = _buildIndex(machines);

  final List<MachineSearchHit> _hits;
  final Map<String, MachineSearchHit> _index;

  List<MachineSearchHit> suggest(String query, {int limit = 8}) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      return _hits.take(limit).toList(growable: false);
    }

    final scored = <({MachineSearchHit hit, int score})>[];
    for (final hit in _hits) {
      final number = _normalize(hit.machineNumber);
      final project = _normalize(hit.project);
      final type = _normalize(hit.machineType);

      final score = _scoreMatch(
        query: normalizedQuery,
        number: number,
        project: project,
        type: type,
      );
      if (score > 0) {
        scored.add((hit: hit, score: score));
      }
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) {
        return byScore;
      }
      return a.hit.machineNumber.compareTo(b.hit.machineNumber);
    });

    return scored
        .map((item) => item.hit)
        .take(limit)
        .toList(growable: false);
  }

  MachineSearchHit? findExact(String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      return null;
    }
    return _index[normalizedQuery];
  }

  static List<MachineSearchHit> _buildHits(List<Machine> machines) {
    final hits = <MachineSearchHit>[];
    final seen = <String>{};

    for (final machine in machines) {
      final project = _resolveProject(machine);
      final uniqueNumbers = machine.drsNumbers.toSet();
      for (final number in uniqueNumbers) {
        final normalizedNumber = _normalize(number);
        if (normalizedNumber.isEmpty || !seen.add('${machine.id}::$normalizedNumber')) {
          continue;
        }

        hits.add(
          MachineSearchHit(
            machine: machine,
            machineNumber: number,
            project: project,
            machineType: machine.machineType,
          ),
        );
      }
    }

    hits.sort((a, b) => a.machineNumber.compareTo(b.machineNumber));
    return List<MachineSearchHit>.unmodifiable(hits);
  }

  static Map<String, MachineSearchHit> _buildIndex(List<Machine> machines) {
    final index = <String, MachineSearchHit>{};
    final hits = _buildHits(machines);
    for (final hit in hits) {
      final normalizedNumber = _normalize(hit.machineNumber);
      index.putIfAbsent(normalizedNumber, () => hit);
    }
    return Map<String, MachineSearchHit>.unmodifiable(index);
  }

  static int _scoreMatch({
    required String query,
    required String number,
    required String project,
    required String type,
  }) {
    if (number == query) {
      return 120;
    }
    if (number.endsWith(query)) {
      return 105;
    }
    if (number.startsWith(query)) {
      return 95;
    }
    if (number.contains(query)) {
      return 80;
    }
    if (project.contains(query)) {
      return 55;
    }
    if (type.contains(query)) {
      return 35;
    }
    return 0;
  }

  static String _resolveProject(Machine machine) {
    if (machine.project.trim().isNotEmpty && machine.project.toUpperCase() != 'SEBN-MA') {
      return machine.project;
    }
    return machine.name;
  }

  static String _normalize(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }
}
