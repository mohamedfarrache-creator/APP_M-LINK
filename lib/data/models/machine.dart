import 'dart:convert';

import 'package:flutter/material.dart';

enum MachineStatus { ok, due, anomaly, pending }

class ChecklistItem {
  const ChecklistItem({
    required this.label,
    this.done = false,
  });

  final String label;
  final bool done;

  ChecklistItem copyWith({bool? done}) {
    return ChecklistItem(
      label: label,
      done: done ?? this.done,
    );
  }

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      label: json['label'] as String,
      done: json['done'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'done': done,
    };
  }
}

class Machine {
  const Machine({
    required this.id,
    required this.name,
    required this.serial,
    required this.project,
    required this.site,
    required this.zone,
    required this.mapX,
    required this.mapY,
    required this.status,
    required this.nextKw,
    required this.machineType,
    required this.drsNumbers,
    required this.checklist,
  });

  final String id;
  final String name;
  final String serial;
  final String project;
  final String site;
  final String zone;
  final double mapX;
  final double mapY;
  final MachineStatus status;
  final int nextKw;
  final String machineType;
  final List<String> drsNumbers;
  final List<ChecklistItem> checklist;

  Color get statusColor {
    switch (status) {
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

  String get statusLabel {
    switch (status) {
      case MachineStatus.ok:
        return 'OK';
      case MachineStatus.due:
        return 'Preventif en retard';
      case MachineStatus.anomaly:
        return 'Anomalie signalee';
      case MachineStatus.pending:
        return 'En attente';
    }
  }

  Machine copyWith({
    double? mapX,
    double? mapY,
    MachineStatus? status,
    int? nextKw,
    String? machineType,
    List<String>? drsNumbers,
    List<ChecklistItem>? checklist,
  }) {
    return Machine(
      id: id,
      name: name,
      serial: serial,
      project: project,
      site: site,
      zone: zone,
      mapX: mapX ?? this.mapX,
      mapY: mapY ?? this.mapY,
      status: status ?? this.status,
      nextKw: nextKw ?? this.nextKw,
      machineType: machineType ?? this.machineType,
      drsNumbers: drsNumbers ?? this.drsNumbers,
      checklist: checklist ?? this.checklist,
    );
  }

  factory Machine.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final drsNumbers = (json['drsNumbers'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString())
        .toList();
    final checklistItems = (json['checklist'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => ChecklistItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return Machine(
      id: id,
      name: json['name'] as String,
      serial: json['serial'] as String,
      project: json['project'] as String,
      site: json['site'] as String,
      zone: json['zone'] as String,
      mapX: (json['mapX'] as num).toDouble(),
      mapY: (json['mapY'] as num).toDouble(),
      status: MachineStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => MachineStatus.pending,
      ),
      nextKw: json['nextKw'] as int,
      machineType: json['machineType'] as String? ?? 'EQUIPEMENT DE TEST',
      drsNumbers: drsNumbers.isEmpty ? <String>[id] : drsNumbers,
      checklist: checklistItems,
    );
  }

  factory Machine.fromDb(Map<String, Object?> row) {
    final id = row['id'] as String;
    final drsRaw = row['drsNumbers'] as String? ?? '[]';
    final checklistRaw = row['checklist'] as String? ?? '[]';
    final drsNumbers = (jsonDecode(drsRaw) as List<dynamic>)
        .map((item) => item.toString())
        .toList();
    final checklistItems = (jsonDecode(checklistRaw) as List<dynamic>)
        .map((item) => ChecklistItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return Machine(
      id: id,
      name: row['name'] as String? ?? '',
      serial: row['serial'] as String? ?? '',
      project: row['project'] as String? ?? '',
      site: row['site'] as String? ?? '',
      zone: row['zone'] as String? ?? '',
      mapX: (row['mapX'] as num? ?? 0).toDouble(),
      mapY: (row['mapY'] as num? ?? 0).toDouble(),
      status: MachineStatus.values.firstWhere(
        (value) => value.name == row['status'],
        orElse: () => MachineStatus.pending,
      ),
      nextKw: row['nextKw'] as int? ?? 0,
      machineType: row['machineType'] as String? ?? 'EQUIPEMENT DE TEST',
      drsNumbers: drsNumbers.isEmpty ? <String>[id] : drsNumbers,
      checklist: checklistItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'serial': serial,
      'project': project,
      'site': site,
      'zone': zone,
      'mapX': mapX,
      'mapY': mapY,
      'status': status.name,
      'nextKw': nextKw,
      'machineType': machineType,
      'drsNumbers': drsNumbers,
      'checklist': checklist.map((item) => item.toJson()).toList(),
    };
  }

  Map<String, Object?> toDb() {
    return {
      'id': id,
      'name': name,
      'serial': serial,
      'project': project,
      'site': site,
      'zone': zone,
      'mapX': mapX,
      'mapY': mapY,
      'status': status.name,
      'nextKw': nextKw,
      'machineType': machineType,
      'drsNumbers': jsonEncode(drsNumbers),
      'checklist': jsonEncode(checklist.map((item) => item.toJson()).toList()),
    };
  }
}
