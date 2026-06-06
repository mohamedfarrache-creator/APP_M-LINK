enum UserRole { preventive, corrective, admin }

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.matricule,
    required this.password,
    required this.role,
    this.isActive = true,
  });

  final String id;
  final String fullName;
  final String matricule;
  final String password;
  final UserRole role;
  final bool isActive;

  AppUser copyWith({
    String? fullName,
    String? matricule,
    String? password,
    UserRole? role,
    bool? isActive,
  }) {
    return AppUser(
      id: id,
      fullName: fullName ?? this.fullName,
      matricule: matricule ?? this.matricule,
      password: password ?? this.password,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
    );
  }

  String get roleLabel {
    switch (role) {
      case UserRole.preventive:
        return 'Technicien Preventif';
      case UserRole.corrective:
        return 'Technicien Correctif';
      case UserRole.admin:
        return 'Admin';
    }
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      matricule: json['matricule'] as String,
      password: json['password'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (value) => value.name == json['role'],
        orElse: () => UserRole.preventive,
      ),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'matricule': matricule,
      'password': password,
      'role': role.name,
      'isActive': isActive,
    };
  }
}
