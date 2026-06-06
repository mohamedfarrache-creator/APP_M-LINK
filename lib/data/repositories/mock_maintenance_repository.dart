import '../models/app_user.dart';
import '../models/intervention.dart';
import '../models/machine.dart';
import '../models/project_calendar.dart';

class MockMaintenanceRepository {
  MockMaintenanceRepository({
    required List<Machine> machines,
    required List<Intervention> interventions,
    required List<AppUser> users,
    required List<ProjectCalendar> projectCalendars,
  })  : _machines = List<Machine>.from(machines),
        _interventions = List<Intervention>.from(interventions),
        _users = List<AppUser>.from(users),
        _projectCalendars = List<ProjectCalendar>.from(projectCalendars);

  final List<Machine> _machines;
  final List<Intervention> _interventions;
  final List<AppUser> _users;
  final List<ProjectCalendar> _projectCalendars;

  List<Machine> get machines => List<Machine>.from(_machines);
  List<Intervention> get interventions => List<Intervention>.from(_interventions);
  List<AppUser> get users => List<AppUser>.from(_users);
  List<ProjectCalendar> get projectCalendars => List<ProjectCalendar>.from(_projectCalendars);

  AppUser? login({
    required String matricule,
    required String password,
    required UserRole role,
  }) {
    try {
      return _users.firstWhere(
        (user) =>
            user.matricule == matricule &&
            user.password == password &&
            user.role == role,
      );
    } catch (_) {
      return null;
    }
  }

  List<Machine> machinesBySite(String site) {
    return _machines.where((machine) => machine.site == site).toList();
  }

  void validatePreventive(String machineId) {
    final index = _machines.indexWhere((machine) => machine.id == machineId);
    if (index < 0) {
      return;
    }
    final machine = _machines[index];
    _machines[index] = machine.copyWith(
      status: MachineStatus.ok,
      nextKw: machine.nextKw + 1,
      checklist: machine.checklist.map((item) => item.copyWith(done: true)).toList(),
    );
  }

  void submitIntervention(Intervention intervention) {
    _interventions.insert(0, intervention);

    final machineIndex = _machines.indexWhere((machine) => machine.id == intervention.machineId);
    if (machineIndex >= 0) {
      _machines[machineIndex] = _machines[machineIndex].copyWith(
        status: MachineStatus.anomaly,
      );
    }
  }

  void addUser(AppUser user) {
    _users.add(user);
  }

  void updateUserPassword({
    required String userId,
    required String newPassword,
  }) {
    final index = _users.indexWhere((user) => user.id == userId);
    if (index < 0) {
      return;
    }
    _users[index] = _users[index].copyWith(password: newPassword);
  }

  List<Intervention> urgentNotifications() {
    return _interventions
        .where((item) =>
            item.priority == InterventionPriority.high ||
            item.priority == InterventionPriority.urgent)
        .toList();
  }

  int dueTasksCount() {
    return _machines.where((machine) => machine.status == MachineStatus.due).length;
  }
}
