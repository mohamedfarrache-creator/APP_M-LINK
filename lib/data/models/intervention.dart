enum InterventionType { preventive, anomaly, actionRequest }

enum InterventionPriority { low, medium, high, urgent }

class Intervention {
  const Intervention({
    required this.id,
    required this.machineId,
    required this.machineName,
    required this.createdByUserId,
    required this.createdByName,
    required this.createdByRole,
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    required this.createdAtIso,
    required this.forKw,
    this.isRead = false,
    this.status = 'open',
  });

  final String id;
  final String machineId;
  final String machineName;
  final String createdByUserId;
  final String createdByName;
  final String createdByRole;
  final InterventionType type;
  final InterventionPriority priority;
  final String title;
  final String description;
  final String createdAtIso;
  final int forKw;
  final bool isRead;
  final String status;

  factory Intervention.fromJson(Map<String, dynamic> json) {
    return Intervention(
      id: json['id'] as String,
      machineId: json['machineId'] as String,
      machineName: json['machineName'] as String,
      createdByUserId: json['createdByUserId'] as String,
      createdByName: json['createdByName'] as String,
      createdByRole: json['createdByRole'] as String,
      type: InterventionType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => InterventionType.anomaly,
      ),
      priority: InterventionPriority.values.firstWhere(
        (value) => value.name == json['priority'],
        orElse: () => InterventionPriority.medium,
      ),
      title: json['title'] as String,
      description: json['description'] as String,
      createdAtIso: json['createdAtIso'] as String,
      forKw: json['forKw'] as int,
      isRead: json['isRead'] as bool? ?? false,
      status: json['status'] as String? ?? 'open',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'machineId': machineId,
      'machineName': machineName,
      'createdByUserId': createdByUserId,
      'createdByName': createdByName,
      'createdByRole': createdByRole,
      'type': type.name,
      'priority': priority.name,
      'title': title,
      'description': description,
      'createdAtIso': createdAtIso,
      'forKw': forKw,
      'isRead': isRead,
      'status': status,
    };
  }
}
