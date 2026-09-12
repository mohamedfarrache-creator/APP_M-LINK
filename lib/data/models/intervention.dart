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
    this.contrePiece = '',
    this.niveau = '1',
    this.heureDebut = '',
    this.heureFin = '',
    this.tempsProd = 0,
    this.tempsTech = 0,
    this.shift = 'A',
    this.imageUrls = const <String>[],
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
  final String contrePiece;
  final String niveau;
  final String heureDebut;
  final String heureFin;
  final int tempsProd;
  final int tempsTech;
  final String shift;
  final List<String> imageUrls;
  final bool isRead;
  final String status;

  String? get imageUrl => imageUrls.isEmpty ? null : imageUrls.first;

  factory Intervention.fromJson(Map<String, dynamic> json) {
    final imageUrls = (json['imageUrls'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
    final legacyImageUrl = json['imageUrl'] as String?;
    if (imageUrls.isEmpty &&
        legacyImageUrl != null &&
        legacyImageUrl.trim().isNotEmpty) {
      imageUrls.add(legacyImageUrl);
    }

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
      createdAtIso:
          json['createdAtIso'] as String? ?? DateTime.now().toIso8601String(),
      forKw: json['forKw'] as int? ?? 0,
      contrePiece: json['contrePiece'] as String? ?? '',
      niveau: json['niveau'] as String? ?? '1',
      heureDebut: json['heureDebut'] as String? ?? '',
      heureFin: json['heureFin'] as String? ?? '',
      tempsProd: _readInt(json['tempsProd']),
      tempsTech: _readInt(json['tempsTech']),
      shift: json['shift'] as String? ?? 'A',
      imageUrls: imageUrls,
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
      'contrePiece': contrePiece,
      'niveau': niveau,
      'heureDebut': heureDebut,
      'heureFin': heureFin,
      'tempsProd': tempsProd,
      'tempsTech': tempsTech,
      'shift': shift,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'isRead': isRead,
      'status': status,
    };
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
