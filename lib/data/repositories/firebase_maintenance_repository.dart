import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../mock_data.dart';
import '../models/app_user.dart';
import '../models/intervention.dart';
import '../models/machine.dart';
import '../models/project_calendar.dart';
import 'maintenance_repository.dart';

class FirebaseMaintenanceRepository extends MaintenanceRepository {
  FirebaseMaintenanceRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  bool _initialized = false;

  List<Machine> _machines = <Machine>[];
  List<Intervention> _interventions = <Intervention>[];
  List<AppUser> _users = <AppUser>[];
  List<ProjectCalendar> _projectCalendars = <ProjectCalendar>[];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _machinesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _interventionsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _calendarsSub;

  @override
  List<Machine> get machines => List<Machine>.from(_machines);

  @override
  List<Intervention> get interventions => List<Intervention>.from(_interventions);

  @override
  List<AppUser> get users => List<AppUser>.from(_users);

  @override
  List<ProjectCalendar> get projectCalendars => List<ProjectCalendar>.from(_projectCalendars);

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    await _ensureSeedData();
    _listenToCollections();
  }

  @override
  Future<AppUser?> login({
    required String matricule,
    required String password,
    required UserRole role,
  }) async {
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
      checklist: machine.checklist.map((item) => item.copyWith(done: true)).toList(),
    );
    _machines[index] = updated;
    notifyListeners();

    await _firestore.collection('machines').doc(machineId).set(
          updated.toJson(),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> submitIntervention(Intervention intervention) async {
    _interventions.insert(0, intervention);

    final machineIndex = _machines.indexWhere((machine) => machine.id == intervention.machineId);
    if (machineIndex >= 0) {
      _machines[machineIndex] = _machines[machineIndex].copyWith(
        status: MachineStatus.anomaly,
      );
    }
    notifyListeners();

    final batch = _firestore.batch();
    final interventionRef = _firestore.collection('interventions').doc(intervention.id);
    batch.set(interventionRef, intervention.toJson(), SetOptions(merge: true));

    final machineRef = _firestore.collection('machines').doc(intervention.machineId);
    batch.set(
      machineRef,
      {
        'status': MachineStatus.anomaly.name,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  @override
  Future<void> addUser(AppUser user) async {
    _users.add(user);
    notifyListeners();

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

    await _firestore.collection('machines').doc(machineId).set(
      {
        'mapX': mapX,
        'mapY': mapY,
      },
      SetOptions(merge: true),
    );
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
    return _machines.where((machine) => machine.status == MachineStatus.due).length;
  }

  Future<void> _ensureSeedData() async {
    final machineSnap = await _firestore.collection('machines').limit(1).get();
    if (machineSnap.docs.isNotEmpty) {
      return;
    }

    await _batchSet<Machine>(
      'machines',
      seedMachines,
      (machine) => machine.id,
      (machine) => machine.toJson(),
    );
    await _batchSet<Intervention>(
      'interventions',
      seedInterventions,
      (intervention) => intervention.id,
      (intervention) => intervention.toJson(),
    );
    await _batchSet<AppUser>(
      'users',
      seedUsers,
      (user) => user.id,
      (user) => user.toJson(),
    );
    await _batchSet<ProjectCalendar>(
      'project_calendars',
      seedProjectCalendars,
      (calendar) => calendar.project,
      (calendar) => {
        'project': calendar.project,
        'sourceFile': calendar.sourceFile,
        'machineType': calendar.machineType,
        'drsNumbers': calendar.drsNumbers,
      },
    );
  }

  void _listenToCollections() {
    _machinesSub = _firestore.collection('machines').snapshots().listen((snapshot) {
      final items = snapshot.docs
          .map((doc) => Machine.fromJson(_dataWithId(doc)))
          .toList(growable: false);
      items.sort((a, b) => a.id.compareTo(b.id));
      _machines = items;
      notifyListeners();
    });

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

    _calendarsSub =
        _firestore.collection('project_calendars').snapshots().listen((snapshot) {
      final items = snapshot.docs.map((doc) {
        final data = _dataWithId(doc);
        return ProjectCalendar(
          project: data['project'] as String,
          sourceFile: data['sourceFile'] as String,
          machineType: data['machineType'] as String,
          drsNumbers: (data['drsNumbers'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList(),
        );
      }).toList(growable: false);
      items.sort((a, b) => a.project.compareTo(b.project));
      _projectCalendars = items;
      notifyListeners();
    });
  }

  Future<void> _batchSet<T>(
    String collection,
    List<T> items,
    String Function(T item) idFor,
    Map<String, dynamic> Function(T item) toJson,
  ) async {
    const chunkSize = 400;
    for (var i = 0; i < items.length; i += chunkSize) {
      final batch = _firestore.batch();
      final slice = items.skip(i).take(chunkSize);
      for (final item in slice) {
        final docId = idFor(item);
        batch.set(
          _firestore.collection(collection).doc(docId),
          toJson(item),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
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
    _machinesSub?.cancel();
    _interventionsSub?.cancel();
    _usersSub?.cancel();
    _calendarsSub?.cancel();
    super.dispose();
  }
}
