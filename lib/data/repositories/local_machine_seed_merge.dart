import '../models/machine.dart';

List<Machine> mergeSeedMachinesWithLocal({
  required List<Machine> seedMachines,
  required List<Machine> localMachines,
}) {
  if (localMachines.isEmpty) {
    return List<Machine>.from(seedMachines);
  }

  final localByNormalizedId = <String, Machine>{};
  for (final local in localMachines) {
    localByNormalizedId.putIfAbsent(_normalizeMachineId(local.id), () => local);
  }

  final merged = <Machine>[];
  final usedLocalKeys = <String>{};

  for (final seed in seedMachines) {
    final key = _normalizeMachineId(seed.id);
    final local = localByNormalizedId[key];
    if (local == null) {
      merged.add(seed);
      continue;
    }

    usedLocalKeys.add(key);
    merged.add(
      Machine(
        id: seed.id,
        name: seed.name,
        serial: seed.serial,
        project: seed.project,
        site: seed.site,
        zone: seed.zone,
        mapX: _hasLocalCoordinates(local) ? local.mapX : seed.mapX,
        mapY: _hasLocalCoordinates(local) ? local.mapY : seed.mapY,
        status: local.status,
        nextKw: local.nextKw == 0 ? seed.nextKw : local.nextKw,
        machineType: seed.machineType,
        drsNumbers: _mergeDrsNumbers(seed, local),
        checklist: local.checklist.isEmpty ? seed.checklist : local.checklist,
      ),
    );
  }

  for (final local in localMachines) {
    final key = _normalizeMachineId(local.id);
    if (!usedLocalKeys.contains(key) && key.isNotEmpty) {
      merged.add(local);
    }
  }

  return merged;
}

bool _hasLocalCoordinates(Machine machine) {
  return machine.mapX != 0.0 || machine.mapY != 0.0;
}

List<String> _mergeDrsNumbers(Machine seed, Machine local) {
  final output = <String>[];
  final seen = <String>{};
  for (final value in <String>[
    seed.id,
    ...seed.drsNumbers,
    ...local.drsNumbers
  ]) {
    final key = _normalizeMachineId(value);
    if (key.isNotEmpty && seen.add(key)) {
      output.add(value);
    }
  }
  return output;
}

String _normalizeMachineId(String value) {
  return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}
