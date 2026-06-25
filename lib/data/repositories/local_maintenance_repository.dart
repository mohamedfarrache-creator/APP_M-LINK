import '../local/local_calendar_store.dart';
import '../local/local_machine_store.dart';
import '../mock_data.dart';
import '../models/app_user.dart';
import '../models/intervention.dart';
import '../models/machine.dart';
import '../models/project_calendar.dart';
import 'local_machine_seed_merge.dart';
import 'maintenance_repository.dart';

class LocalMaintenanceRepository extends MaintenanceRepository {
  LocalMaintenanceRepository({
    LocalMachineStore? machineStore,
    LocalCalendarStore? calendarStore,
  })  : _machineStore = machineStore ?? LocalMachineStore(),
        _calendarStore = calendarStore ?? LocalCalendarStore();

  final LocalMachineStore _machineStore;
  final LocalCalendarStore _calendarStore;

  bool _initialized = false;

  List<Machine> _machines = <Machine>[];
  List<Intervention> _interventions = <Intervention>[];
  List<AppUser> _users = <AppUser>[];
  List<ProjectCalendar> _projectCalendars = <ProjectCalendar>[];

  @override
  List<Machine> get machines => List<Machine>.from(_machines);

  @override
  List<Intervention> get interventions =>
      List<Intervention>.from(_interventions);

  @override
  List<AppUser> get users => List<AppUser>.from(_users);

  @override
  List<ProjectCalendar> get projectCalendars =>
      List<ProjectCalendar>.from(_projectCalendars);

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    // Machines — purely local (SQLite)
    final loadedMachines = await _machineStore.fetchAll();
    _machines = mergeSeedMachinesWithLocal(
      seedMachines: seedMachines,
      localMachines: loadedMachines,
    );
    await _machineStore.saveAll(_machines);

    // Calendars — purely local (SQLite)
    final loadedCalendars = await _calendarStore.fetchAll();
    if (loadedCalendars.isEmpty) {
      await _calendarStore.saveAll(seedProjectCalendars);
      _projectCalendars = List<ProjectCalendar>.from(seedProjectCalendars);
    } else {
      _projectCalendars = loadedCalendars;
    }

    _users = List<AppUser>.from(seedUsers);
    _interventions = List<Intervention>.from(seedInterventions);

    notifyListeners();
  }

  @override
  Future<AppUser?> login({
    required String matricule,
    required String password,
    required UserRole role,
  }) async {
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

  @override
  Future<void> logout() async {}

  @override
  Future<void> validatePreventive(String machineId) async {
    final index = _machines.indexWhere((machine) => machine.id == machineId);
    if (index < 0) {
      return;
    }
    final machine = _machines[index];
    final updated = machine.copyWith(
      status: MachineStatus.ok,
      nextKw: machine.nextKw + 1,
      checklist:
          machine.checklist.map((item) => item.copyWith(done: true)).toList(),
    );
    _machines[index] = updated;
    notifyListeners();

    await _machineStore.updateMachine(updated);
  }

  @override
  Future<void> submitIntervention(Intervention intervention) async {
    _interventions.insert(0, intervention);

    final machineIndex =
        _machines.indexWhere((machine) => machine.id == intervention.machineId);
    if (machineIndex >= 0) {
      final updated = _machines[machineIndex].copyWith(
        status: MachineStatus.anomaly,
      );
      _machines[machineIndex] = updated;
      await _machineStore.updateMachine(updated);
    }
    notifyListeners();
  }

  @override
  Future<void> addUser(AppUser user) async {
    _users.add(user);
    notifyListeners();
  }

  @override
  Future<void> updateUserPassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final index = _users.indexWhere((item) => item.id == userId);
    if (index >= 0) {
      _users[index] = _users[index].copyWith(password: newPassword);
      notifyListeners();
    }
  }

  @override
  Future<void> updateMachineLocation({
    required String machineId,
    required double mapX,
    required double mapY,
  }) async {
    final index = _machines.indexWhere((machine) => machine.id == machineId);
    if (index < 0) {
      return;
    }

    final updated = _machines[index].copyWith(
      mapX: mapX,
      mapY: mapY,
    );
    _machines[index] = updated;
    notifyListeners();

    await _machineStore.updateMachine(updated);
  }

  @override
  List<Machine> machinesBySite(String site) {
    return _machines.where((machine) => machine.site == site).toList();
  }

  @override
  List<Intervention> urgentNotifications() {
    return _interventions
        .where((item) =>
            item.priority == InterventionPriority.high ||
            item.priority == InterventionPriority.urgent)
        .toList();
  }

  @override
  int dueTasksCount() {
    return _machines
        .where((machine) => machine.status == MachineStatus.due)
        .length;
  }
}
