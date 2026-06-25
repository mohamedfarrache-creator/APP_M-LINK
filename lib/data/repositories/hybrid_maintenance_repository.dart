import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../local/local_calendar_store.dart';
import '../local/local_machine_store.dart';
import '../mock_data.dart';
import '../models/app_user.dart';
import '../models/intervention.dart';
import '../models/machine.dart';
import '../models/project_calendar.dart';
import 'local_machine_seed_merge.dart';
import 'maintenance_repository.dart';

class HybridMaintenanceRepository extends MaintenanceRepository {
  HybridMaintenanceRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    LocalMachineStore? machineStore,
    LocalCalendarStore? calendarStore,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _machineStore = machineStore ?? LocalMachineStore(),
        _calendarStore = calendarStore ?? LocalCalendarStore();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final LocalMachineStore _machineStore;
  final LocalCalendarStore _calendarStore;

  bool _initialized = false;
  bool _remoteReady = true;

  List<Machine> _machines = <Machine>[];
  List<Intervention> _interventions = <Intervention>[];
  List<AppUser> _users = <AppUser>[];
  List<ProjectCalendar> _projectCalendars = <ProjectCalendar>[];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _interventionsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSub;

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

    await _loadLocalData();
    _listenToRemoteCollections();
  }

  @override
  Future<AppUser?> login({
    required String matricule,
    required String password,
    required UserRole role,
  }) async {
    if (!_remoteReady) {
      return null;
    }

    final email = _emailForMatricule(matricule);

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return null;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      Map<String, dynamic>? data = userDoc.data();
      if (data == null) {
        final legacy = await _firestore
            .collection('users')
            .where('matricule', isEqualTo: matricule)
            .limit(1)
            .get();
        if (legacy.docs.isNotEmpty) {
          data = legacy.docs.first.data();
          await _firestore.collection('users').doc(user.uid).set(
            {
              ...data,
              'id': user.uid,
            },
            SetOptions(merge: true),
          );
        }
      }

      if (data == null) {
        await _auth.signOut();
        return null;
      }

      final appUser = AppUser.fromJson({
        ...data,
        'id': user.uid,
      });

      if (!appUser.isActive || appUser.role != role) {
        await _auth.signOut();
        return null;
      }

      _upsertUser(appUser);
      notifyListeners();
      return appUser;
    } on FirebaseAuthException {
      return null;
    }
  }

  @override
  Future<void> logout() async {
    if (!_remoteReady) {
      return;
    }
    await _auth.signOut();
  }

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

    if (!_remoteReady) {
      return;
    }

    final batch = _firestore.batch();
    final interventionRef =
        _firestore.collection('interventions').doc(intervention.id);
    batch.set(interventionRef, intervention.toJson(), SetOptions(merge: true));
    await batch.commit();
  }

  @override
  Future<void> addUser(AppUser user) async {
    _users.add(user);
    notifyListeners();

    if (!_remoteReady) {
      return;
    }

    await _firestore.collection('users').doc(user.id).set(
          user.toJson(),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> updateUserPassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!_remoteReady) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'Serveur indisponible.',
      );
    }

    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'Utilisateur non connecte.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);

    await _firestore.collection('users').doc(user.uid).set(
      {
        'password': newPassword,
      },
      SetOptions(merge: true),
    );

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

  Future<void> _loadLocalData() async {
    final loadedMachines = await _machineStore.fetchAll();
    final loadedCalendars = await _calendarStore.fetchAll();

    _machines = mergeSeedMachinesWithLocal(
      seedMachines: seedMachines,
      localMachines: loadedMachines,
    );
    await _machineStore.saveAll(_machines);

    if (loadedCalendars.isEmpty) {
      await _calendarStore.saveAll(seedProjectCalendars);
      _projectCalendars = List<ProjectCalendar>.from(seedProjectCalendars);
    } else {
      _projectCalendars = loadedCalendars;
    }

    notifyListeners();
  }

  void _listenToRemoteCollections() {
    try {
      _interventionsSub =
          _firestore.collection('interventions').snapshots().listen((snapshot) {
        final items = snapshot.docs
            .map((doc) => Intervention.fromJson(_dataWithId(doc)))
            .toList(growable: false);
        items.sort((a, b) => b.createdAtIso.compareTo(a.createdAtIso));
        _interventions = items;
        notifyListeners();
      });

      _usersSub = _firestore.collection('users').snapshots().listen((snapshot) {
        final items = snapshot.docs
            .map((doc) => AppUser.fromJson(_dataWithId(doc)))
            .toList(growable: false);
        items.sort((a, b) => a.fullName.compareTo(b.fullName));
        _users = items;
        notifyListeners();
      });
    } catch (_) {
      _remoteReady = false;
    }
  }

  void _upsertUser(AppUser user) {
    final index = _users.indexWhere((item) => item.id == user.id);
    if (index >= 0) {
      _users[index] = user;
      return;
    }
    _users.add(user);
  }

  Map<String, dynamic> _dataWithId(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return {
      ...data,
      'id': data['id'] ?? doc.id,
    };
  }

  String _emailForMatricule(String matricule) {
    final normalized = matricule.trim().toLowerCase();
    return '$normalized@m-link.local';
  }

  @override
  void dispose() {
    _interventionsSub?.cancel();
    _usersSub?.cancel();
    super.dispose();
  }
}
