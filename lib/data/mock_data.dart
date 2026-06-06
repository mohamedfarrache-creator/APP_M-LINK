import 'models/app_user.dart';
import 'models/intervention.dart';
import 'models/machine.dart';
import 'machine_data.dart';
import 'models/project_calendar.dart';

final List<AppUser> seedUsers = <AppUser>[
  const AppUser(
    id: 'admin-1',
    fullName: 'Admin SEBN',
    matricule: '19879',
    password: '041125',
    role: UserRole.admin,
  ),
  const AppUser(
    id: 'prev-1',
    fullName: 'Yassine Preventif',
    matricule: '22001',
    password: '22001',
    role: UserRole.preventive,
  ),
  const AppUser(
    id: 'corr-1',
    fullName: 'Karim Correctif',
    matricule: '33001',
    password: '33001',
    role: UserRole.corrective,
  ),
];

final List<Machine> seedMachines = _buildSeedMachines();

List<Machine> _buildSeedMachines() {
  final seen = <String>{};
  final machines = <Machine>[];

  for (final location in allMachineLocations) {
    final normalizedId = _normalizeMachineId(location.id);
    if (!seen.add(normalizedId)) {
      continue;
    }

    final status = _seedAnomalyIds.contains(normalizedId)
        ? MachineStatus.anomaly
        : MachineStatus.pending;
    final machineType = _machineTypeForProject(location.project);

    machines.add(
      Machine(
        id: location.id,
        name: location.project,
        serial: 'SER-${location.id}',
        project: location.project,
        site: location.site.toLowerCase(),
        zone: location.project,
        mapX: location.dx,
        mapY: location.dy,
        status: status,
        nextKw: 16,
        machineType: machineType,
        drsNumbers: <String>[location.id],
        checklist: const <ChecklistItem>[
          ChecklistItem(label: 'Inspection visuelle'),
          ChecklistItem(label: 'Test capteurs'),
          ChecklistItem(label: 'Verification securite'),
          ChecklistItem(label: 'Nettoyage zone machine'),
        ],
      ),
    );
  }

  return machines;
}

const Set<String> _seedAnomalyIds = <String>{
  'TS15002018401098338',
  'TS15002018401098213',
};

String _machineTypeForProject(String project) {
  switch (project) {
    case 'Q7-Q9 KSK':
      return 'EQUIPEMENT DE TEST KSK';
    case 'RL-TAN':
      return 'EQUIPEMENT DE TEST KM & VT';
    case 'MEB_21':
      return 'T.E';
    case 'ID_7':
      return 'T.E';
    default:
      return 'EQUIPEMENT DE TEST';
  }
}

String _normalizeMachineId(String value) {
  return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

final List<ProjectCalendar> seedProjectCalendars = <ProjectCalendar>[
  const ProjectCalendar(
    project: 'Q7-Q9 KSK',
    sourceFile: 'Calendrier Préventive Q7-Q9 KSK.xlsx',
    machineType: 'EQUIPEMENT DE TEST KSK',
    drsNumbers: <String>[
      'TS TS1700-402197-MA01',
      'TS TS1700-402197-MA07',
      'TS TS1700-402197-MA08',
      'TS TS1700-402197-MA06',
      'TS TS1700-402197-MA04',
      'TS TS1700-402197-MA05',
      'TS TS1700-402197-MA02',
      'TS TS1700-402197-MA03',
      'TS1500-2018-401099-029',
      'TS TS1700-402197-MA09',
      'TS1500-401098.ALU-MA01',
    ],
  ),
  const ProjectCalendar(
    project: 'RL-TAN',
    sourceFile: 'Calendrier Préventive 2026 RL-TAN.xlsx',
    machineType: 'EQUIPEMENT DE TEST KM & VT',
    drsNumbers: <String>[
      'TS1700-401113-12',
      'TS1500-401099-1',
      'TS1500.2018.401098-245',
      'TS1500.2018-401098-300',
      'TS1500.2018-401098-296',
      'TS1500-2018-401099-55',
      'TS1500-401099-001',
      'TS1500-400053-66',
      'TS1500-400053-14',
      'TS1500-401098-015',
      'TS1500.2018-401098-310',
      'TS1500-400053-MA96',
      'TS1500-400053-061',
      'TS1500-400053-007',
      'TS1500-400053-005',
      'TS1500.2018-401098-301',
      'TS1500-400053-057',
      'TS1500.2018.401098-295',
      'TS1500-2018.401098-268',
      'TS1500-392',
      'TS1500-400053-187',
      'TS1500-400053-150',
      'TS1500-400057',
      'TS1500-400053-140',
      'TS1500-400053-054',
      'TS1500-117',
      'TS1500-400053-174',
      'TS1500.2018-401098-309',
    ],
  ),
  const ProjectCalendar(
    project: 'COCK-PIT',
    sourceFile: 'Calendrier préventive COCK-PIT.xlsx',
    machineType: 'EQUIPEMENT DE TEST',
    drsNumbers: <String>['TS1700-401111-MA-13', 'TS1500.2018.401098-390', 'TS1700-401111-021'],
  ),
  const ProjectCalendar(
    project: 'T-ROC',
    sourceFile: 'Calendrier préventives 2026 T-ROC.xlsx',
    machineType: 'EQUIPEMENT DE TEST',
    drsNumbers: <String>[
      'TS1700-401112-21',
      'G0124244',
      'G0244517',
      'TS1500-400053-058',
      'G0026784',
      'TS1700-401111-16',
      'TS1700-401111-KM-18',
      'G0040053',
      'G0061661',
      'G0034504',
      'TS1500-401099-KM-15',
      'TS1400-401221-003',
      'G0015243',
    ],
  ),
  const ProjectCalendar(
    project: 'ID_4',
    sourceFile: 'Calendrier préventive 2026 ID_4 & ID_BUZZ.xlsx',
    machineType: 'EQUIPEMENT DE TEST',
    drsNumbers: <String>[
      'TS1500.2018.401098-338',
      'TS1500-2018-401099-047',
      'TS1500.2018.401098.064',
      'TS1500.2018.401098.065',
      'TS1500.2018.401098-083',
      'TS1500.2018.401098-17',
      'TS1500-401098-MA45',
      'TS1500-401098-MA46',
      'TS1500-401098-MA47',
      'TS1500.2018.401098.141',
    ],
  ),
  const ProjectCalendar(
    project: 'MEB_21',
    sourceFile: 'Calendrier préventive 2026 MEB_21.xlsx',
    machineType: 'T.E',
    drsNumbers: <String>['TS1500-400053-037', 'TS1500.2018.401098-303'],
  ),
  const ProjectCalendar(
    project: 'HIGH VOLTAGE',
    sourceFile: 'Calendrier préventive 2026 HIGH VOLTAGE .xlsx',
    machineType: 'EQUIPEMENT DE TEST',
    drsNumbers: <String>['TS1500.2018.401098-213', 'TS1500.2018.401098-246'],
  ),
  const ProjectCalendar(
    project: 'ID_7',
    sourceFile: 'Calendrier préventive 2026 ID_7.xlsx',
    machineType: 'EQUIPEMENT DE TEST',
    drsNumbers: <String>[
      'TS1500.401098-MA-01',
      'TS1500.401098-MA-02',
      'TS1500.401098-MA-03',
      'TS1500.401098-MA-04',
      'TS1500.2018.401098-093',
      'TS1500.2018.401098-332',
      'TS1500.2018.401098-410',
      'TS1500.2018.401098-420',
      'TS1500-401098-MA-10',
      'TS1500-401098-MA-11',
      'TS1500-401098-MA10',
      'TS1500-401098-10',
    ],
  ),
  const ProjectCalendar(
    project: 'POURCHE',
    sourceFile: 'Calendrier préventive 2026 PORSCHE.xlsx',
    machineType: 'EQUIPEMENT DE TEST',
    drsNumbers: <String>['TS1500-400053-054', 'TS1500-400061-032', 'TS1500-400053-043'],
  ),
  const ProjectCalendar(
    project: 'MEB_31',
    sourceFile: 'Calendrier préventive 2026 MEB_31.xlsx',
    machineType: 'EQUIPEMENT DE TEST',
    drsNumbers: <String>[
      'TS500*500.402561-MA-04',
      'TS500*500.402561-MA-05',
      'TS1500-401098-KM-13',
      'TS1500-401098-KM-14',
      'TS1500-400053-19',
      'TS1500.2018.401098-090',
      'TS1500.2018.401098-343',
      'TS-TABLE-402561-MA04',
      'TS1500.2018.401098-117',
    ],
  ),
  const ProjectCalendar(
    project: 'GOLF A8',
    sourceFile: 'Calendrier préventive 2026 GOLF A8.xlsx',
    machineType: 'EQUIPEMENT DE TEST',
    drsNumbers: <String>[
      'TS1700.2018.401113-40',
      'TS1700.2018.401113-41',
      'TS1500-2018-401098-12',
      'TS1500.2018.401098-400',
      'TS1500-42',
      'TS1500-116',
      'TS1500.2018.401098-342',
      'TS1500-274',
      'TS1500-400057-54',
      'TS1500-400053-167',
      'TS1700-2018-401111-46',
      'TS1700-2018-401111-48',
    ],
  ),
];

final List<Intervention> seedInterventions = <Intervention>[
  Intervention(
    id: 'INT-9001',
    machineId: 'TS1500.2018.401098-338',
    machineName: 'ID_4',
    createdByUserId: 'prev-1',
    createdByName: 'Yassine Preventif',
    createdByRole: 'preventive',
    type: InterventionType.anomaly,
    priority: InterventionPriority.urgent,
    title: 'Capteur NOK',
    description: 'Signal capteur instable pendant controle preventif.',
    createdAtIso: DateTime.now().toIso8601String(),
    forKw: 16,
  ),
  Intervention(
    id: 'INT-9002',
    machineId: 'TS1500.2018.401098-213',
    machineName: 'HIGH VOLTAGE',
    createdByUserId: 'corr-1',
    createdByName: 'Karim Correctif',
    createdByRole: 'corrective',
    type: InterventionType.actionRequest,
    priority: InterventionPriority.high,
    title: 'Action preventive demandee',
    description: 'Verifier routine hebdo avant fermeture ticket.',
    createdAtIso: DateTime.now().toIso8601String(),
    forKw: 16,
  ),
];
