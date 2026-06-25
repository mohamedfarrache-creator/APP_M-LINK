// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:m_link_sebn/app.dart';
import 'package:m_link_sebn/data/models/app_user.dart';
import 'package:m_link_sebn/data/models/intervention.dart';
import 'package:m_link_sebn/data/models/machine.dart';
import 'package:m_link_sebn/data/models/project_calendar.dart';
import 'package:m_link_sebn/data/repositories/maintenance_repository.dart';

void main() {
  testWidgets('App shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(MLinkApp(repository: _TestMaintenanceRepository()));
    await tester.pump();

    expect(find.text('M-link SEBN'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });
}

class _TestMaintenanceRepository extends MaintenanceRepository {
  @override
  Future<void> initialize() async {}

  @override
  List<Machine> get machines => const <Machine>[];

  @override
  List<Intervention> get interventions => const <Intervention>[];

  @override
  List<AppUser> get users => const <AppUser>[];

  @override
  List<ProjectCalendar> get projectCalendars => const <ProjectCalendar>[];

  @override
  Future<AppUser?> login({
    required String matricule,
    required String password,
    required UserRole role,
  }) async {
    return null;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> validatePreventive(String machineId) async {}

  @override
  Future<void> submitIntervention(Intervention intervention) async {}

  @override
  Future<void> addUser(AppUser user) async {}

  @override
  Future<void> updateUserPassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> updateMachineLocation({
    required String machineId,
    required double mapX,
    required double mapY,
  }) async {}

  @override
  List<Machine> machinesBySite(String site) => const <Machine>[];

  @override
  List<Intervention> urgentNotifications() => const <Intervention>[];

  @override
  int dueTasksCount() => 0;
}
