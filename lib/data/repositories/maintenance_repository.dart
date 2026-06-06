import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/intervention.dart';
import '../models/machine.dart';
import '../models/project_calendar.dart';

abstract class MaintenanceRepository extends ChangeNotifier {
  Future<void> initialize();

  List<Machine> get machines;
  List<Intervention> get interventions;
  List<AppUser> get users;
  List<ProjectCalendar> get projectCalendars;

  Future<AppUser?> login({
    required String matricule,
    required String password,
    required UserRole role,
  });

  Future<void> logout();

  Future<void> validatePreventive(String machineId);
  Future<void> submitIntervention(Intervention intervention);
  Future<void> addUser(AppUser user);
  Future<void> updateUserPassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  });
  Future<void> updateMachineLocation({
    required String machineId,
    required double mapX,
    required double mapY,
  });

  List<Machine> machinesBySite(String site);
  List<Intervention> urgentNotifications();
  int dueTasksCount();
}
